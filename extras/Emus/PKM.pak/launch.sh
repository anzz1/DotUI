#!/bin/sh

EMU_EXE=pokemini
PERF_LEVEL=performance
CORES_PATH=$(dirname "$0")

###############################

EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG"
mkdir -p "$SAVES_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"
echo "$PERF_LEVEL" > "$CPU_PATH"
picoarch "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM" DMG &> "$LOGS_PATH/$EMU_TAG.txt"
