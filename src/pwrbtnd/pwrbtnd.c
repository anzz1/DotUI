
#include <fcntl.h>
#include <linux/input.h>
#include <sys/time.h>
#include <unistd.h>

#if 0
void init_283_pwr_btn() {
	if (access("/sys/devices/gpiochip0/gpio/gpio86/direction", F_OK)) {
		int fd;
		short s;
		fd = open("/sys/class/gpio/export", O_WRONLY);
		if (fd > 0) {
			s = 0x3638; // "86"
			write(fd, &s, sizeof(s));
			close(fd);
			fd = open("/sys/devices/gpiochip0/gpio/gpio86/direction", O_WRONLY);
			if (fd > 0) {
				s = 0x6E69; // "in"
				write(fd, &s, sizeof(s));
				close(fd);
			}
		}
	}
}
#endif

char get_283_pwr_btn() {
	char ret = -1;
	int fd = open("/sys/devices/gpiochip0/gpio/gpio86/value", O_RDONLY);
	if (fd > 0) {
		if (read(fd, &ret, 1) == 1) ret -= 48;
		close(fd);
	}
	return ret;
}

void send_input_event(struct input_event* pev) {
	int fd = open("/dev/input/event0", O_WRONLY);
	if (fd > 0) {
		write(fd, pev, sizeof(struct input_event));
		close(fd);
	}
}

int main(int argc , char* argv[]) {
	char was_pressed = 0;
	struct input_event ev;
	ev.type = EV_KEY;
	ev.code = KEY_POWER;

	//init_283_pwr_btn();

	while (1) {
		ev.value = get_283_pwr_btn();
		if ((ev.value != was_pressed) && (ev.value == 0 || ev.value == 1)) {
			was_pressed = ev.value;
			gettimeofday(&(ev.time), NULL);
			send_input_event(&ev);
		}
		usleep(100 * 1000);
	}

	return 0;
}
