# iOS port (cross-compile from Linux)

NBCraft-style cross compilation: iOS 8.0 SDK + [Un1q32/cctools-port](https://github.com/Un1q32/cctools-port) `ld64` + `ldid`.

## Layout

- `build.sh` — downloads the iOS 8.0 SDK, builds the cross toolchain (ld64, lipo, strip, ldid), then runs the cmake build per target, lipos the slices together, strips, signs with `ldid`, and packs an `.ipa`.
- `ios-cc` / `ios-c++` — compiler wrappers. They require `NBC_TARGET` (e.g. `armv7-apple-ios6.0`) and inject `-isysroot`, `-target`, `-stdlib`, `-fuse-ld=ld64`.
- `build-ipa.sh` — packages the signed binary + `game/assets` into `Payload/<app>.app` and zips an `.ipa`.
- `mcpe.entitlements` — minimal `get-task-allow` entitlements for sideloading.

## Targets / deployment floor

- Default: `armv7-apple-ios6.0` (override with `NBC_TARGETS`, space-separated).
- arm64 floor for this SDK is iOS 7.0 (`arm64-apple-ios7.0`).
- Goal is to lower armv7 to iOS 5.0, then evaluate 4.3 once the C++ standard usage is checked (the core is C++11, which is the main blocker for very old targets).

## Host requirements (Linux)

`clang`, `clang++`, `cmake`, `make`, `llvm-ar`, `llvm-ranlib`, `wget`, `tar`, `cmp`, and `plistutil` (for the ipa step). `ldid` is built automatically if not present.

## How the core build switches to iOS

The build passes `-DMCPE_IOS=ON`. In the core `minecraftpe/CMakeLists.txt` that:

- skips SDL / desktop OpenGL / desktop CURL `find_package`s,
- compiles with `-DUSEGLES -DMCPE_IOS`,
- drops `impl/main.cpp` and `impl/AppPlatform_sdl.cpp` from the source set,
- links the UIKit / OpenGLES / OpenAL / Foundation / QuartzCore / CoreGraphics / AVFoundation frameworks,
- pulls in the Objective-C(++) shell from this directory.

Platform header selection (see the matching guards in the tree):

- sound: `SoundEngine` / `SoundSystemAL` route Apple to OpenAL (`<OpenAL/al.h>`),
- GL: `unigl.h` selects `<OpenGLES/ES1/gl.h>` on Apple,
- `AppContext` / `_pengine` drop EGL types on Apple (no EGL on iOS; EAGL is owned by the shell),
- networking: `CurlRestRequestJob` is excluded on iOS (no libcurl in the public SDK) — a native rest job is a TODO.

## Status / TODO

This commit lands the cross-compile plumbing and the mechanical platform guards. Still to do:

1. Objective-C(++) UIKit app shell in this directory (`main.m`, app delegate, view controller, EAGL view, `AppPlatform_iOS`) — bridges to `NinecraftApp`/`AppPlatform` like the SDL path does.
2. Touch input wiring into `Mouse`/`Multitouch`, on-screen keyboard.
3. A native networking backend to replace the curl rest job.
4. Lower the deployment target (iOS 6 → 5 → maybe 4.3).
