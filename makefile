.PHONY: clean

###########################################################

ifeq (,$(PLATFORM))
PLATFORM=$(UNION_PLATFORM)
endif

ifeq (,$(PLATFORM))
$(error please specify PLATFORM, eg. PLATFORM=trimui make)
endif

###########################################################

BUILD_ARCH!=uname -m
BUILD_HASH!=git rev-parse --short HEAD
BUILD_TIME!=date "+%Y-%m-%d %H:%M:%S %Z"
BUILD_REPO=https://github.com/anzz1/DotUI-X
BUILD_GCC:=$(shell $(CROSS_COMPILE)gcc -dumpfullversion -dumpversion)

RELEASE_TIME!=date +%Y%m%d
RELEASE_BASE=DotUI-X-$(RELEASE_TIME)
RELEASE_DOT!=find ./releases/. -regex ".*/$(RELEASE_BASE)-[0-9]+-base\.zip" -printf '.' | wc -m
RELEASE_NAME=$(RELEASE_BASE)-$(RELEASE_DOT)

PATCH = git apply

LIBC_LIB=/opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib
BUNDLE_LIBS=

GCC_VER_GTE9_0 := $(shell echo `gcc -dumpversion | cut -f1-2 -d.` \>= 9.0 | bc )
ifeq "$(GCC_VER_GTE9_0)" "1"
  BUNDLE_LIBS=bundle
endif

all: lib sdl deps core emu tools payload readmes $(BUNDLE_LIBS) zip

extras: emu tools

lib:
	cd ./src/libmsettings && make
	cd ./src/libmmenu && make
	cd ./third-party/latency_reduction && make
	cd ./third-party/libmamedb && make

deps:
	cd ./third-party/deps && ./make-deps.sh
	cd ./third-party/minizip && make miniunz

sdl: lib
	cd ./third-party/SDL-1.2 && MSETTINGS=1 ./make.sh

core: lib
	cd ./src/batmon && make
	cd ./src/keymon && make
	# cd ./src/lumon && make
	cd ./src/progressui && make
	cd ./src/miniui && make
	cd ./src/show && make
	cd ./src/confirm && make
	cd ./src/say && make
	cd ./src/blank && make
	cd ./src/keyboard && make
	cd ./src/oss && make
	cd ./src/axpchk && make
	cd ./src/pwrbtnd && make

emu:
	cd ./third-party/picoarch && make platform=miyoomini -j
	cd ./third-party/vvvvvv && make -j
	./bits/commits.sh > ./commits.txt

tools:
	cd ./third-party/DinguxCommander && make -j
	cd ./third-party/screenshot && make
	cd ./third-party/logotweak/logomake && make
	cd ./third-party/logotweak/logowrite && make
	cd ./third-party/st-sdl && make platform=miyoomini
	cd ./third-party/dropbear-embedded && make
	cd ./src/clock && make

readmes:
	fmt -w 40 -s ./skeleton//README.txt > ./build/PAYLOAD/README.txt
	fmt -w 40 -s ./extras//README.txt > ./build/EXTRAS/README.txt

payload:
	rm -rf ./build
	mkdir -p ./releases
	mkdir -p ./build
	cp -R ./skeleton/. ./build/PAYLOAD
	cp -R ./extras/. ./build/EXTRAS
	mv ./build/PAYLOAD/miyoo354/app/keymon.sh ./build/PAYLOAD/miyoo354/app/keymon
	cp ./build/PAYLOAD/miyoo354/app/keymon ./build/PAYLOAD/miyoo/app/keymon
	cd ./build && find . -type f -name '.keep' -delete
	cd ./build && find . -type f -name '.DS_Store' -delete
	cp ./src/libmsettings/libmsettings.so ./build/PAYLOAD/.system/lib/
	cp ./src/libmmenu/libmmenu.so ./build/PAYLOAD/.system/lib/
	cp ./third-party/latency_reduction/as_preload.so ./build/PAYLOAD/.system/lib/
	cp ./third-party/latency_reduction/audioserver.mod ./build/PAYLOAD/.system/bin/
	cp ./third-party/SDL-1.2/build/.libs/libSDL-1.2.so.0.11.5 ./build/PAYLOAD/.system/lib/libSDL-1.2.so.0
	cp ./third-party/deps/tiny-curl-7.72.0/lib/.libs/libcurl.so.4.6.0 ./build/PAYLOAD/.system/lib/libcurl.so.4
	cp ./third-party/deps/tiny-curl-7.72.0/src/.libs/curl ./build/PAYLOAD/.system/bin/
	cp ./third-party/minizip/miniunz ./build/PAYLOAD/.system/bin/
	cp ./third-party/libmamedb/libmamedb.so ./build/PAYLOAD/.system/lib/
	cp ./src/batmon/batmon ./build/PAYLOAD/.system/bin/
	cp ./src/keymon/keymon ./build/PAYLOAD/.system/bin/
	# cp ./src/lumon/lumon ./build/PAYLOAD/.system/bin/
	cp ./src/progressui/progressui ./build/PAYLOAD/.system/bin/
	cp ./src/progressui/progress.sh ./build/PAYLOAD/.system/bin/progress
	cp ./src/miniui/MiniUI ./build/PAYLOAD/.system/paks/MiniUI.pak/
	cp ./src/show/show ./build/PAYLOAD/.system/bin/
	cp ./src/confirm/confirm ./build/PAYLOAD/.system/bin/
	cp ./src/say/say ./build/PAYLOAD/.system/bin/
	cp ./src/blank/blank ./build/PAYLOAD/.system/bin/
	cp ./src/keyboard/keyboard ./build/PAYLOAD/.system/bin/
	cp ./src/oss/oss ./build/PAYLOAD/.system/bin/
	cp ./src/axpchk/axpchk ./build/PAYLOAD/.system/bin/
	cp ./src/pwrbtnd/pwrbtnd ./build/PAYLOAD/.system/bin/
	cp ./src/say/say ./build/PAYLOAD/miyoo354/app/
	cp ./src/blank/blank ./build/PAYLOAD/miyoo354/app/
	cp ./third-party/minizip/miniunz ./build/PAYLOAD/miyoo354/app/
	cp ./third-party/picoarch/output/picoarch ./build/PAYLOAD/.system/bin/
	cp ./third-party/picoarch/output/fceumm_libretro.so ./build/PAYLOAD/.system/cores/
	cp ./third-party/picoarch/output/gambatte_libretro.so ./build/PAYLOAD/.system/cores/
	cp ./third-party/picoarch/output/gpsp_libretro.so ./build/PAYLOAD/.system/cores/
	cp ./third-party/picoarch/output/pcsx_rearmed_libretro.so ./build/PAYLOAD/.system/cores/
	cp ./third-party/picoarch/output/picodrive_libretro.so ./build/PAYLOAD/.system/cores/
	cp ./third-party/picoarch/output/mednafen_supafaust_libretro.so ./build/PAYLOAD/.system/cores/
	cp ./third-party/DinguxCommander/output/DinguxCommander ./build/EXTRAS/Tools/Files.pak/
	cp ./src/clock/clock ./build/EXTRAS/Tools/Clock.pak/
	cp -r ./third-party/DinguxCommander/res ./build/EXTRAS/Tools/Files.pak/
	cp ./third-party/screenshot/screenshot ./build/EXTRAS/Tools/Screenshots.pak/
	cp ./third-party/picoarch/output/beetle-ngp_libretro.so ./build/EXTRAS/Emus/NGP.pak/mednafen_ngp_libretro.so
	cp ./third-party/picoarch/output/beetle-pce-fast_libretro.so ./build/EXTRAS/Emus/PCE.pak/mednafen_pce_fast_libretro.so
	cp ./third-party/picoarch/output/beetle-supergrafx_libretro.so ./build/EXTRAS/Emus/SGX.pak/mednafen_supergrafx_libretro.so
	cp ./third-party/picoarch/output/pokemini_libretro.so ./build/EXTRAS/Emus/PKM.pak/
	cp ./third-party/picoarch/output/mgba_libretro.so ./build/EXTRAS/Emus/MGBA.pak/
	cp ./third-party/picoarch/output/mgba_sgb_libretro.so ./build/EXTRAS/Emus/SGB.pak/
	cp ./third-party/picoarch/output/fake-08_libretro.so ./build/EXTRAS/Emus/P8.pak/
	cp ./third-party/picoarch/output/smsplus-gx_libretro.so ./build/EXTRAS/Emus/GG.pak/smsplus_libretro.so
	cp ./third-party/picoarch/output/mame2000_libretro.so ./build/EXTRAS/Emus/MAME.pak/
	cp ./third-party/picoarch/output/prboom_libretro.so ./build/EXTRAS/Emus/DOOM.pak/
	cp ./third-party/picoarch/cores/prboom/prboom.wad ./build/EXTRAS/Bios/DOOM/
	cp ./third-party/picoarch/output/nxengine_libretro.so "./build/EXTRAS/Roms/Native Games (SH)/Cave Story/"
	cp ./third-party/picoarch/output/xrick_libretro.so "./build/EXTRAS/Roms/Native Games (SH)/Rick Dangerous/"
	cp ./third-party/st-sdl/st ./build/EXTRAS/Tools/Terminal.pak/
	cp ./third-party/dropbear-embedded/dropbear ./build/EXTRAS/Tools/SSH.pak/
	cp ./third-party/vvvvvv/vvvvvv "./build/EXTRAS/Roms/Native Games (SH)/VVVVVV/"
	# cp -R ./bits/bootlogos/pak/. ./build/EXTRAS/Tools/Single-use/bootlogo.tmp
	# cp ./third-party/logotweak/logomake/logomake ./build/EXTRAS/Tools/Single-use/bootlogo.tmp/
	# cp ./third-party/logotweak/logowrite/logowrite ./build/EXTRAS/Tools/Single-use/bootlogo.tmp/
	# cd ./build/EXTRAS/Tools/Single-use/ && cp -R ./bootlogo.tmp/. "02) Remove MiniUI Boot Logo.pak"
	# cp -R ./bits/bootlogos/miniui/. ./build/EXTRAS/Tools/Single-use/bootlogo.tmp/
	# cd ./build/EXTRAS/Tools/Single-use/ && cp -R ./bootlogo.tmp/. "02) Add MiniUI Boot Logo.pak"
	# rm -rf ./build/EXTRAS/Tools/Single-use/bootlogo.tmp

bundle:
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/ld-linux-armhf.so.3 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libc.so.6 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libcrypt.so.1 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libdl.so.2 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libgcc_s.so.1 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libm.so.6 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libpcprofile.so ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libpthread.so.0 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libresolv.so.2 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/librt.so.1 ./build/PAYLOAD/.system/lib/
	cp -L /opt/miyoomini-toolchain/arm-none-linux-gnueabihf/libc/lib/libstdc++.so.6 ./build/PAYLOAD/.system/lib/

zip:
	cd ./build/PAYLOAD/.system/paks/MiniUI.pak && echo "$(RELEASE_NAME)\n$(BUILD_HASH)" > version.txt
	cp ./commits.txt ./build/PAYLOAD/.system/paks/MiniUI.pak
	cd ./build/PAYLOAD && zip -r MiniUI.zip .system .tmp_update
	mv ./build/PAYLOAD/MiniUI.zip ./build/PAYLOAD/miyoo354/app/
	cd ./build/PAYLOAD && zip -r ../../releases/$(RELEASE_NAME)-base.zip Bios Roms Saves miyoo354 miyoo README.txt
	cd ./build/EXTRAS && zip -r ../../releases/$(RELEASE_NAME)-extras.zip Bios Emus Roms Saves Tools README.txt
	echo "$(RELEASE_NAME)" > ./build/latest.txt

rezip: payload $(BUNDLE_LIBS) zip

clean:
	rm -rf ./build
	cd ./src/libmsettings && make clean
	cd ./src/libmmenu && make clean
	cd ./third-party/SDL-1.2 && make distclean || :
	cd ./src/batmon && make clean
	cd ./src/keymon && make clean
	# cd ./src/lumon && make clean
	cd ./src/progressui && make clean
	cd ./src/miniui && make clean
	cd ./src/show && make clean
	cd ./src/confirm && make clean
	cd ./src/say && make clean
	cd ./src/blank && make clean
	cd ./src/clock && make clean
	cd ./src/keyboard && make clean
	cd ./src/oss && make clean
	cd ./src/axpchk && make clean
	cd ./src/pwrbtnd && make clean
	cd ./third-party/deps && ./make-deps.sh clean
	cd ./third-party/minizip && make clean
	cd ./third-party/libmamedb && make clean
	cd ./third-party/DinguxCommander && make clean
	cd ./third-party/latency_reduction && make clean
	cd ./third-party/logotweak/logomake && make clean
	cd ./third-party/logotweak/logoread && make clean
	cd ./third-party/logotweak/logowrite && make clean
	cd ./third-party/picoarch && make platform=miyoomini clean-all
	cd ./third-party/screenshot && make clean
	cd ./third-party/st-sdl && make platform=miyoomini clean
	cd ./third-party/dropbear-embedded && make clean
	cd ./third-party/vvvvvv && make clean

info:
	@uname -srmo
	@echo "CROSS_COMPILE=$(CROSS_COMPILE)"
	@"$(CROSS_COMPILE)gcc" --version | head -1
	@echo "$(BUILD_GCC)"
