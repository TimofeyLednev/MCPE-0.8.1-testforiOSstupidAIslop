#!/usr/bin/env python3
# Generates a STUB minecraftpe/impl/pcm_data.c with silent placeholder sounds.
#
# The real sounds are extracted from an original 0.8.1 libminecraftpe.so via
# tools/get_sound_data.py. That requires the proprietary APK, which is not in
# this repo. This stub lets the project LINK (and run, silently) without it,
# so the iOS/desktop binary can be produced and tested.
#
# Each PCM_* symbol is laid out exactly how SoundDesc(char_t*) expects:
#   int32 channels, int32 bytesPerSample, int32 sampleRate, int32 length(frames)
#   followed by length*channels*bytesPerSample bytes of PCM.
# We emit length=0 (no audio frames) => valid, silent.
#
# Usage: python3 tools/gen_silent_pcm.py            # -> minecraftpe/impl/pcm_data.c
#        python3 tools/gen_silent_pcm.py <outfile>

import sys, os

# Symbol list mirrors minecraftpe/headers/pcm_data.h
SYMBOLS = [
    "PCM_fuse","PCM_eat3","PCM_eat2","PCM_eat1","PCM_creeperdeath","PCM_creeper4",
    "PCM_creeper3","PCM_creeper2","PCM_creeper1","PCM_spiderdeath","PCM_spider4",
    "PCM_spider3","PCM_spider2","PCM_spider1","PCM_skeletonhurt4","PCM_skeletonhurt3",
    "PCM_skeletonhurt2","PCM_skeletonhurt1","PCM_skeletondeath","PCM_skeleton3",
    "PCM_skeleton2","PCM_skeleton1","PCM_fallsmall","PCM_fallbig2","PCM_fallbig1",
    "PCM_bowhit4","PCM_bowhit3","PCM_bowhit2","PCM_bowhit1","PCM_bow","PCM_zpighurt2",
    "PCM_zpighurt1","PCM_zpigdeath","PCM_zpigangry4","PCM_zpigangry3","PCM_zpigangry2",
    "PCM_zpigangry1","PCM_zpig4","PCM_zpig3","PCM_zpig2","PCM_zpig1","PCM_zombiehurt2",
    "PCM_zombiehurt1","PCM_zombiedeath","PCM_zombie3","PCM_zombie2","PCM_zombie1",
    "PCM_cowhurt3","PCM_cowhurt2","PCM_cowhurt1","PCM_cow4","PCM_cow3","PCM_cow2",
    "PCM_cow1","PCM_chickenhurt2","PCM_chickenhurt1","PCM_chicken3","PCM_chicken2",
    "PCM_pigdeath","PCM_pig3","PCM_pig2","PCM_pig1","PCM_sheep3","PCM_sheep2",
    "PCM_sheep1","PCM_ignite","PCM_fire","PCM_burp","PCM_break","PCM_glass3",
    "PCM_glass2","PCM_glass1","PCM_chestopen","PCM_chestclosed","PCM_door_close",
    "PCM_door_open","PCM_hurt","PCM_pop2","PCM_pop","PCM_splash","PCM_explode",
    "PCM_click","PCM_wood4","PCM_wood3","PCM_wood2","PCM_wood1","PCM_stone4",
    "PCM_stone3","PCM_stone2","PCM_stone1","PCM_sand4","PCM_sand3","PCM_sand2",
    "PCM_sand1","PCM_gravel4","PCM_gravel3","PCM_gravel2","PCM_gravel1","PCM_grass4",
    "PCM_grass3","PCM_grass2","PCM_grass1","PCM_cloth4","PCM_cloth3","PCM_cloth2",
    "PCM_cloth1",
]

# 16-byte header: channels=1, bytesPerSample=2, sampleRate=44100, length=0
# little-endian int32 x4
HEADER = "0x1,0x0,0x0,0x0, 0x2,0x0,0x0,0x0, 0x44,0xac,0x0,0x0, 0x0,0x0,0x0,0x0"

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "..", "minecraftpe", "impl", "pcm_data.c")
    lines = ["#include <pcm_data.h>\n",
             "/* AUTO-GENERATED SILENT STUB - see tools/gen_silent_pcm.py */\n"]
    for s in SYMBOLS:
        lines.append("uint8_t %s[] = {%s};\n" % (s, HEADER))
    with open(out, "w") as f:
        f.writelines(lines)
    print("Wrote silent stub to", os.path.abspath(out))
    print("Replace with real sounds via tools/get_sound_data.py for audio.")

if __name__ == "__main__":
    main()
