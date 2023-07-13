#include <SDL/SDL.h>
#include <SDL/SDL_image.h>

#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <linux/input.h>
#include <pthread.h>

static volatile int screen_on = 0;
static volatile unsigned long screen_start;
void screenOn(void) {
	screen_start = SDL_GetTicks();
	if (!screen_on) {
		int fd = open("/sys/class/pwm/pwmchip0/pwm0/duty_cycle", O_WRONLY);
		if (fd>=0) {
			dprintf(fd,"%d",9);
			close(fd);
		}
	}
	screen_on = 1;
}
void screenOff(void) {
	int fd = open("/sys/class/pwm/pwmchip0/pwm0/duty_cycle", O_WRONLY);
	if (fd>=0) {
		dprintf(fd,"%d",0);
		close(fd);
	}
	screen_on = 0;
}

static volatile int is_charging = 1;
void checkCharging_MMP(void) {
	// Code adapted from OnionOS
	char *cmd = "cd /customer/app/ ; ./axp_test";  
	int batJsonSize = 100;
	char buf[batJsonSize];
	int charge_number;

	FILE *fp;      
	fp = popen(cmd, "r");
	if (fgets(buf, batJsonSize, fp) != NULL) {
		sscanf(buf,  "{\"battery\":%*d, \"voltage\":%*d, \"charging\":%d}", &charge_number);
		is_charging = (charge_number==3);
	}
	pclose(fp);   
}
void checkCharging_MM(void) {
	int i = 0;
	FILE *file = fopen("/sys/devices/gpiochip0/gpio/gpio59/value", "r");
	if (file) {
		fscanf(file, "%d", &i);
		fclose(file);
	}
	is_charging = i;
}
static pthread_t charging_pt;
void* chargingThread_MMP(void* arg) {
	while (1) {
		sleep(1);
		checkCharging_MMP();
	}
}
void* chargingThread_MM(void* arg) {
	while (1) {
		sleep(1);
		checkCharging_MM();
	}
}

static int input_fd;
static pthread_t input_pt;
static volatile int launch = 0;
void* inputThread(void* arg) {
	struct input_event	event;
	while (read(input_fd, &event, sizeof(event))==sizeof(event)) {
		if (event.type!=EV_KEY || event.value>1) continue;
		if (event.type==EV_KEY) screenOn();
		if (event.code==KEY_POWER) launch = 1;
	}
	return 0;
}

int main(void) {
	const char* model = getenv("MIYOO_DEV");
	int mmplus = (!model || strcmp(model, "283"));

	int fb0_fd = open("/dev/fb0", O_RDWR);
	struct fb_var_screeninfo vinfo;
	ioctl(fb0_fd, FBIOGET_VSCREENINFO, &vinfo);
	int map_size = vinfo.xres * vinfo.yres * (vinfo.bits_per_pixel / 8); // 640x480x4
	char* fb0_map = (char*)mmap(0, map_size, PROT_READ | PROT_WRITE, MAP_SHARED, fb0_fd, 0);

	memset(fb0_map, 0, map_size); // clear screen

	char charging_path[128];
	sprintf(charging_path, "%s/charging.png", getenv("RES_PATH"));
	SDL_Surface* img = IMG_Load(charging_path); // 24-bit opaque png

	uint8_t* dst = (uint8_t*)fb0_map; // rgba
	uint8_t* src = (uint8_t*)img->pixels; // bgr
	//src += ((img->h * img->w) - 1) * 3;
	for (int y=0; y<img->h; y++) {
		for (int x=0; x<img->w; x++) {
			*(dst+0) = *(src+2); // r
			*(dst+1) = *(src+1); // g
			*(dst+2) = *(src+0); // b
			*(dst+3) = 0xf; // alpha
			dst += 4;
			src += 3;
		}
	}
	SDL_FreeSurface(img);

	screenOn();

	input_fd = open("/dev/input/event0", O_RDONLY);
	pthread_create(&input_pt, NULL, &inputThread, NULL);

	pthread_create(&charging_pt, NULL, mmplus ? &chargingThread_MMP : &chargingThread_MM, NULL);

	while (!launch && is_charging) {
		unsigned long t = SDL_GetTicks()-screen_start;
		if (screen_on) {
			if (t>=10000) screenOff(); // Dim screen after 10 sec
		}
		else if (mmplus && t>=30000) break; // Shutdown after 30 sec (MMP can charge while off)
		usleep(200000);
	}

	memset(fb0_map, 0, map_size); // clear screen

	close(input_fd);

	pthread_cancel(input_pt);
	pthread_join(input_pt, NULL);

	pthread_cancel(charging_pt);
	pthread_join(charging_pt, NULL);

	munmap(fb0_map, map_size);
	close(fb0_fd);

	if (!launch) {
		system("shutdown");
		while (1) pause();
	}

    return EXIT_SUCCESS;
}
