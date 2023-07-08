#!/bin/sh
# MiniUI.pak

/mnt/SDCARD/.system/bin/blank

# init backlight
echo 0 > /sys/class/pwm/pwmchip0/export
echo 800 > /sys/class/pwm/pwmchip0/pwm0/period
echo 6 > /sys/class/pwm/pwmchip0/pwm0/duty_cycle
echo 1 > /sys/class/pwm/pwmchip0/pwm0/enable

# init lcd
# cat /proc/ls
/mnt/SDCARD/.system/bin/l_354 &
sleep 0.5

# init charger detection
if [ ! -f /sys/devices/gpiochip0/gpio/gpio59/direction ]; then
	echo 59 > /sys/class/gpio/export
	echo in > /sys/devices/gpiochip0/gpio/gpio59/direction
fi

export SDCARD_PATH=/mnt/SDCARD
export BIOS_PATH=/mnt/SDCARD/Bios
export ROMS_PATH=/mnt/SDCARD/Roms
export SAVES_PATH=/mnt/SDCARD/Saves
export TOOLS_PATH=/mnt/SDCARD/Tools
export USERDATA_PATH=/mnt/SDCARD/.userdata
export LOGS_PATH=/mnt/SDCARD/.userdata/logs
export CORES_PATH=/mnt/SDCARD/.system/cores
export RES_PATH=/mnt/SDCARD/.system/res
export DATETIME_PATH=$USERDATA_PATH/.miniui/datetime.txt # used by bin/shutdown

# killall tee # NOTE: killing tee is somehow responsible for audioserver crashes
rm -f "$SDCARD_PATH/update.log"

export LD_LIBRARY_PATH="/mnt/SDCARD/.system/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/.system/bin:$PATH"

# NOTE: could cause performance issues on more demanding cores...maybe?
if [ -f /customer/lib/libpadsp.so ]; then
	LD_PRELOAD=as_preload.so audioserver.mod &
	export LD_PRELOAD=libpadsp.so
fi

# adjust lcd luma and saturation
# lumon & 
# csc [dev] [cscMatrix] [contrast] [hue] [luma] [saturation] [sharpness] [gain]
echo csc 0 3 50 50 45 45 0 0 > /proc/mi_modules/mi_disp/mi_disp0

CHARGING=`/customer/app/axp_test | awk -F'[,: {}]+' '{print $7}'`
if [ "$CHARGING" == "3" ]; then
	batmon
fi

keymon &

mkdir -p "$LOGS_PATH"
mkdir -p "$USERDATA_PATH/.mmenu"
mkdir -p "$USERDATA_PATH/.miniui"

# init datetime
if [ -f "$DATETIME_PATH" ]; then
	DATETIME=$(cat "$DATETIME_PATH")
	if [ -n "$DATETIME" ] && [ "$DATETIME" -eq "$DATETIME" ]; then
		if [ ! -f "$USERDATA_PATH/.wifi/ntp_on.txt" ]; then
			DATETIME=$((DATETIME + 6 * 60 * 60))
		fi
		date -u +%s -s "@$DATETIME"
	fi
fi

# wifi
if [ -f /mnt/SDCARD/.system/paks/WiFi.pak/boot.sh ]; then
	LD_PRELOAD= /mnt/SDCARD/.system/paks/WiFi.pak/boot.sh > /dev/null 2>&1 &
else
	killall telnetd > /dev/null 2>&1 &
fi

AUTO_PATH=$USERDATA_PATH/auto.sh
if [ -f "$AUTO_PATH" ]; then
	"$AUTO_PATH"
fi

cd $(dirname "$0")

EXEC_PATH=/tmp/miniui_exec
touch "$EXEC_PATH"  && sync

MIYOO_VERSION=`/etc/fw_printenv miyoo_version`
export MIYOO_VERSION=${MIYOO_VERSION#miyoo_version=}

# Battery level debug info
# ls /customer/app > "$USERDATA_PATH/.miniui/app_contents.txt"
# /customer/app/axp_test > "$USERDATA_PATH/.miniui/axp_result.txt"

export CPU_PATH=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
while [ -f "$EXEC_PATH" ]; do
	echo ondemand > "$CPU_PATH"

	./MiniUI &> "$LOGS_PATH/MiniUI.txt"

	date -u +%s > "$DATETIME_PATH"
	sync

	NEXT="/tmp/next"
	if [ -f $NEXT ]; then
		CMD=`cat $NEXT`
		eval $CMD
		rm -f $NEXT
		if [ -f "/tmp/using-swap" ]; then
			swapoff $USERDATA_PATH/swapfile
			rm -f "/tmp/using-swap"
		fi

		date -u +%s > "$DATETIME_PATH"
		sync
	fi
done

shutdown
while true; do
	sync && poweroff && sleep 10
done
