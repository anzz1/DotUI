#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>

#define	AXPDEV	"/dev/i2c-1"
#define	AXPID	(0x68 >> 1)

int main() {
	struct i2c_msg msg[2];
	struct i2c_rdwr_ioctl_data packets;
	unsigned char address = 0;
	unsigned char val;
	int ret;
	int fd = open(AXPDEV, O_RDWR);
	ioctl(fd, I2C_TIMEOUT, 5);
	ioctl(fd, I2C_RETRIES, 1);

	msg[0].addr = AXPID;
	msg[0].flags = 0;
	msg[0].len = 1;
	msg[0].buf = &address;
	msg[1].addr = AXPID;
	msg[1].flags = I2C_M_RD;
	msg[1].len = 1;
	msg[1].buf = &val;

	packets.nmsgs = 2;
	packets.msgs = &msg[0];
	ret = (ioctl(fd, I2C_RDWR, &packets) < 0) ? 1 : 0;
	close(fd);

	printf("return code: %d / axp223 is ", ret);
	if (ret) puts("not present (og mini)");
	else puts("present (mini+)");
	return ret;
}
