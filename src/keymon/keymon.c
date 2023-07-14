// miyoomini/keymon.c

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <dirent.h>
#include <linux/input.h>

#include <msettings.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <pthread.h>

//	Button Defines
#define	BUTTON_MENU		KEY_ESC
#define	BUTTON_POWER	KEY_POWER
#define	BUTTON_SELECT	KEY_RIGHTCTRL
#define	BUTTON_START	KEY_ENTER
#define	BUTTON_L1		KEY_E
#define	BUTTON_R1		KEY_T
#define	BUTTON_L2		KEY_TAB
#define	BUTTON_R2		KEY_BACKSPACE
#define BUTTON_VOLUP	KEY_VOLUMEUP
#define BUTTON_VOLDOWN	KEY_VOLUMEDOWN

//	for keyshm
#define VOLUME		0
#define BRIGHTNESS	1
#define VOLMAX		20
#define BRIMAX		10

//	for ev.value
#define RELEASED	0
#define PRESSED		1
#define REPEAT		2

//	for button_flag
#define SELECT_BIT	0
#define START_BIT	1
#define SELECT		(1<<SELECT_BIT)
#define START		(1<<START_BIT)

//	for DEBUG
//#define	DEBUG
#ifdef	DEBUG
#define ERROR(str)	fprintf(stderr,str"\n"); quit(EXIT_FAILURE)
#else
#define ERROR(str)	quit(EXIT_FAILURE)
#endif

//	Global Variables
typedef struct {
	int channel_value;
	int adc_value;
} SAR_ADC_CONFIG_READ;

#define SARADC_IOC_MAGIC                     'a'
#define IOCTL_SAR_INIT                       _IO(SARADC_IOC_MAGIC, 0)
#define IOCTL_SAR_SET_CHANNEL_READ_VALUE     _IO(SARADC_IOC_MAGIC, 1)

static SAR_ADC_CONFIG_READ adc_config = {0,0};
static int sar_fd = 0;

static struct input_event	ev;
static int input_fd = 0;
static int bat_fd = 0;
static pthread_t adc_pt;

int exists(const char* path) {
	return access(path, F_OK)==0;
}
void touch(const char* path) {
	close(open(path, O_RDWR|O_CREAT, 0777));
}

static void quit(int exitcode) {
	pthread_cancel(adc_pt);
	pthread_join(adc_pt, NULL);
	QuitSettings();

	if (input_fd > 0) close(input_fd);
	if (sar_fd > 0) close(sar_fd);
	if (bat_fd > 0) close(bat_fd);
	exit(exitcode);
}

static void writeBatt(int value, int is_charging) {
	char str[4];
	sprintf(str, "%d", value);
	write(bat_fd, str, (value == 100 ? 3 : (value >= 10 ? 2 : 1)));
	lseek(bat_fd, 0, 0);
	if (exists("/tmp/charging")) {
		if (!is_charging) unlink("/tmp/charging");
	} else if (is_charging) {
		touch("/tmp/charging");
	}
}
static void checkAXP() {
	// Code adapted from OnionOS
	const char *cmd = "cd /customer/app/ ; ./axp_test";
	FILE *fp;
	fp = popen(cmd, "r");
	if (fp) {
		int battery_number = 0;
		int charge_number = 0;
		if (fscanf(fp, "{\"battery\":%d, \"voltage\":%*d, \"charging\":%d}", &battery_number, &charge_number) == 2 && battery_number <= 100) {
			writeBatt(battery_number, (charge_number == 3));
		}
		pclose(fp);
	}
}

static void initADC(void) {
	sar_fd = open("/dev/sar", O_WRONLY);
	ioctl(sar_fd, IOCTL_SAR_INIT, NULL);
}
static void checkADC(void) {
	ioctl(sar_fd, IOCTL_SAR_SET_CHANNEL_READ_VALUE, &adc_config);

	int current_charge = 0;
	if (adc_config.adc_value>=528) {
		current_charge = adc_config.adc_value - 478;
	}
	else if (adc_config.adc_value>=512){
		current_charge = adc_config.adc_value * 2.125 - 1068;
	}
	else if (adc_config.adc_value>=480){
		current_charge = adc_config.adc_value * 0.51613 - 243.742;
	}

	if (current_charge<0) current_charge = 0;
	else if (current_charge>100) current_charge = 100;

	int charging = 0;
    FILE *fp = fopen("/sys/devices/gpiochip0/gpio/gpio59/value", "r");
    if (fp) {
        fscanf(fp, "%d", &charging); 
        fclose(fp);
    }

	writeBatt(current_charge, charging);
}

static void* runAXP(void *arg) {
	while(1) {
		sleep(1);
		checkAXP();
	}
	return 0;
}

static void* runADC(void *arg) {
	while(1) {
		sleep(1);
		checkADC();
	}
	return 0;
}

int main (int argc, char *argv[]) {
	bat_fd = open("/tmp/battery", O_CREAT | O_WRONLY | O_TRUNC, 0666);
	if (bat_fd < 0) ERROR("Failed to open /tmp/battery");

	const char* model = getenv("MIYOO_DEV");
	int mmplus = (!model || strcmp(model, "283"));
	if (mmplus) {
		checkAXP();
		pthread_create(&adc_pt, NULL, &runAXP, NULL);
	} else {
		initADC();
		checkADC();
		pthread_create(&adc_pt, NULL, &runADC, NULL);
	}

	// Set Initial Volume / Brightness
	InitSettings();

	input_fd = open("/dev/input/event0", O_RDONLY);
	if (input_fd < 0) ERROR("Failed to open /dev/input/event0");

	// Main Loop
	register uint32_t val;
	register uint32_t button_flag = 0;
	register uint32_t menu_pressed = 0;
	register uint32_t power_pressed = 0;
	uint32_t repeat_vol = 0;
	while( read(input_fd, &ev, sizeof(ev)) == sizeof(ev) ) {
		val = ev.value;
		if (( ev.type != EV_KEY ) || ( val > REPEAT )) continue;
		switch (ev.code) {
		case BUTTON_MENU:
			if ( val != REPEAT ) menu_pressed = val;
			break;
		case BUTTON_POWER:
			if ( val != REPEAT ) power_pressed = val;
			break;
		case BUTTON_START:
			if ( val != REPEAT ) {
				button_flag = button_flag & (~START) | (val<<START_BIT);
			} 
			break;
		case BUTTON_R1:
			if (mmplus) break;
		case BUTTON_VOLUP:
			if ( val == REPEAT ) {
				// Adjust repeat speed to 1/2
				val = repeat_vol;
				repeat_vol ^= PRESSED;
			} else {
				repeat_vol = 0;
			}
			if ( val == PRESSED ) {
				if (menu_pressed > 0) {
					val = GetBrightness();
					if (val<BRIMAX) SetBrightness(++val);
				} else {
					val = GetVolume();
					if (val<VOLMAX) SetVolume(++val);
					if (val>0) SetMute(0);
				}
			}
			break;
		case BUTTON_L1:
			if (mmplus) break;
		case BUTTON_VOLDOWN:
			if ( val == REPEAT ) {
				// Adjust repeat speed to 1/2
				val = repeat_vol;
				repeat_vol ^= PRESSED;
			} else {
				repeat_vol = 0;
			}
			if ( val == PRESSED ) {
				if (menu_pressed > 0) {
					val = GetBrightness();
					if (val>0) SetBrightness(--val);
				} else {
					val = GetVolume();
					if (val>0) SetVolume(--val);
					if (val==0) SetMute(1);
				}
			}
			break;
		default:
			break;
		}

		if (menu_pressed && power_pressed) {
			menu_pressed = power_pressed = 0;
			while(1) {
				execlp("shutdown", "shutdown", NULL);
				pause(); // we will never reach here when execlp is successful
			}
			//system("shutdown");
			//while (1) pause();
		}
	}
	ERROR("Failed to read input event");
}
