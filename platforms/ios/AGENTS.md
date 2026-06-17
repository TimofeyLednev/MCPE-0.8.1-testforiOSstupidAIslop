# platforms/ios — porting notes

NBCraft-style Linux cross-compile path for an iOS build of MCPE 0.8.1.

## How the build is wired
- `build.sh` is run from this directory. It downloads the iOS 8.0 SDK, builds
  `cctools-port` (`ld64`, `lipo`, `strip`) and `ldid`, then runs CMake on the
  repo root (`platforms/ios/../..`) once per target in `NBC_TARGETS`.
- `ios-cc` / `ios-c++` are the compiler wrappers CMake calls. They require
  `NBC_TARGET` and `NBC_SDK` in the environment (build.sh sets both).
- The build passes `-DMCPE_IOS=ON`, which is the single switch the CMake and the
  C/C++ source guards key off of.

## What `-DMCPE_IOS=ON` changes (root `minecraftpe/CMakeLists.txt`)
- Skips `find_package(SDL/OpenGL/CURL)`; keeps `ZLIB`.
- Adds `-DUSEGLES -DMCPE_IOS` (GLES 1.x render path, same family as Android).
- Excludes `impl/main.cpp` and `impl/AppPlatform_sdl.cpp` from the core sources
  (the UIKit shell replaces them).
- Compiles `platforms/ios/*.mm` + `*.m` into the executable.
- Links `objc` + the iOS frameworks: Foundation, CoreGraphics, QuartzCore,
  UIKit, OpenGLES, OpenAL, AVFoundation.

## Source-level guards already added
- `headers/sound/SoundEngine.hpp` — Apple routes to `SoundSystemAL` (OpenAL).
- `sound/SoundSystemAL.{hpp,cpp}` — guard now matches Apple; `<OpenAL/*>`
  headers on Apple, `<AL/*>` elsewhere.
- `headers/unigl.h` — Apple uses `<OpenGLES/ES1/*>`; no EGL on iOS.
- `headers/AppContext.hpp`, `headers/_pengine.hpp` — EGL-typed fields only for
  non-Apple GLES; Apple uses `void*` (EAGL is managed by the shell).
- `headers/main.hpp` — no SDL include on iOS.
- Networking (`CurlRestRequestJob.*`, `RestRequestJob::CreateJob`) — Curl is
  excluded on iOS (no libcurl in the public SDK); `CreateJob` returns the
  stubbed job like Android. Re-implementing networking is a TODO.

## App shell — DONE (it links + produces an ipa)
The Objective-C++ shell now exists in this directory and matches THIS decomp's
API:
- `main.mm` — `UIApplicationMain` entry, app delegate, `UIViewController` with a
  `CADisplayLink` loop calling `NinecraftApp::update()`, touch fed to
  `Multitouch`/`Mouse`, soft-keyboard text view fed to `Keyboard`.
- `EAGLView.{h,mm}` — `CAEAGLLayer` + GLES1 framebuffer (color + depth).
- `AppPlatform_iOS.{hpp,mm}` — implements the `AppPlatform` pure-virtuals
  (`getImagePath`, `loadPNG`, `readAssetFile` bundle-relative; screen size;
  `supportsTouchscreen`; `getLoginInformation`; `showKeyboard`/`hideKeyboard`).
- `tools/gen_silent_pcm.py` writes a silent `pcm_data.c` so it links without the
  original APK sounds.

Build extras that were required (see CLAUDE.md): host `libc++-dev` headers,
`#include_next <_types.h>` on Apple, `-DSTBI_NO_THREAD_LOCALS`, and the OpenAL
typedef fix in `SoundSystemAL.hpp`.

## Deployment target
Default `NBC_TARGETS=armv7-apple-ios6.0`. arm64 floor is iOS 7.0
(`arm64-apple-ios7.0`). Lower to ios5.0 (and later test ios4.3) only after
on-device testing with real assets.
