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

## Known TODO (the actual app shell)
The Objective-C++ shell files do NOT exist yet. They must be created here and
must match THIS decomp's API (NOT NBCraft's), specifically:
- `main.m` — `UIApplicationMain` entry.
- App delegate + view controller (`UIViewController`) driving a CADisplayLink
  loop that calls `Minecraft::update()`.
- `EAGLView` (CAEAGLLayer + GLES1 framebuffer) for the GL surface.
- `AppPlatform_iOS : AppPlatform` implementing the pure-virtuals from
  `headers/AppPlatform.hpp` (note: `getImagePath`, `loadPNG`, `readAssetFile`,
  `getLoginInformation`, screen size, touchscreen) and feeding
  `Mouse`/`Multitouch`/`Keyboard`.
- A keyboard input view for chat/sign text.
- `Info.plist` (build-ipa.sh currently writes a minimal one inline) and an
  asset-copy step for `assets/`.

Until those exist, the iOS link step will fail at the entry point / platform
symbols — that is expected for this milestone (scaffolding + guards only).

## Deployment target
Default `NBC_TARGETS=armv7-apple-ios6.0`. Lower to ios5.0 (and later test
ios4.3 / arm64) only after the shell links and runs.
