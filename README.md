# MCPE 0.8.1
An attempt to decompile MCPE 0.8.1 and to make it possible to run it on different platforms. Currently it should be possible to run it on linux and windows. The project is not affiliated with mojang or microsoft.

## Building

## Cloning the repo and extracting sounds
* Clone the repo with `--recursive` flag(or use `git submodule init` and `git submodule update` after cloning if you forgot to add it). Note: `RakNet` and `OpenAES` are vendored directly in the repo now (forked with build fixes), so only `glm`, `stb`, `jsoncpp` and `utf8proc` remain as submodules.
* Run `python tools/get_sound_data.py <path/to/libminecraftpe.so>` - it should generate `pcm_data.c`
* Move `pcm_data.c` to `./minecraftpe/impl/`

### Linux
Requires SDL1(`libsdl1.2-dev` and `libsdl1.2debian`), OpenAL(`libopenal-dev` and `libopenal1`), OpenGL(`libgl1-mesa-dev`), zlib (`zlib1g` and `zlib1g-dev`), curl (`libcurl4` and `libcurl4-openssl-dev`).
You must also have original 0.8.1 apk file to extract sounds(won't compile without them) and obtain assets(the compiled file will crash or not work properly without them).
* ```
  mkdir build
  cd build
  cmake .. -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF
  make
  ```
* the output should be `minecraftpe/build/minecraftpe08decomp`

### Android
Use https://github.com/oldminecraftcommunity/MCPE-0.8.1-Android

### Other OSes
Currently the project should also support windows.

Windows version does not require OpenAL(it uses DirectSound instead). It should be possible to cross compile this project for windows by using something like
```
cmake .. -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} -static" -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DSDL_LIBRARY=/usr/x86_64-w64-mingw32/lib/SDL.dll -DZLIB_LIBRARY=/usr/x86_64-w64-mingw32/lib/zlib1.dll -DCMAKE_FIND_ROOT_PATH=/usr/x86_64-w64-mingw32/
```
(def should be simplifed later)

**Building on windows was not tested!**

### Running
* extract `assets` from real MCPE 0.8.1 apk into the folder you're running the executable from
* run compiled executable

## Some additional info:
* JSON library that was probably used by Mojang: https://chromium.googlesource.com/external/jsoncpp/+/6921bf1feef6f1fb83935ae3943f07753488311d/jsoncpp
* RakNet: https://web.archive.org/web/20260101222408if_/http://www.raknet.com/raknet/downloads/RakNet_PC-4.036.zip (might be some other version, probably modifed by mojang in 0.1.x)
* GZIP stuff - zlib 1.2.3, based on https://zlib.net/zpipe.c
* https://github.com/nothings/stb/
* GLM - commit before https://github.com/g-truc/glm/commit/2b747cbbadfd3af39b443e88902f1c98bd231083 and -DGLM_FORCE_RADIANS <?>
* OpenAES - used for realms stuff
