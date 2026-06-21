# platforms/ios — porting notes

NBCraft-style Linux cross-compile path for an iOS build of MCPE 0.8.1.

## How the build is wired
- `build.sh` is run from this directory. It downloads the iOS 8.0 SDK, builds
  `cctools-port` (`ld64`, `lipo`, `strip`) and `ldid`, then runs CMake on the
  repo root (`platforms/ios/../..`) once per target in `NBC_TARGETS`.
- `build-native.sh` is the second console path (macOS only). Same CMake config,
  but it sets `NBC_TOOLCHAIN=native` so `ios-cc`/`ios-c++` shell out to `xcrun
  clang/clang++` against the installed Xcode's iOS SDK, and it uses Xcode's
  `lipo`/`strip`/`codesign` for the fuse/strip/sign steps. It is still a pure
  command-line build (NOT opening an `.xcodeproj`). The cctools path is
  unchanged.
- `ios-cc` / `ios-c++` are the compiler wrappers CMake calls. They require
  `NBC_TARGET` in the environment (both build scripts set it). `NBC_TOOLCHAIN`
  selects cctools (default) vs. the native Xcode toolchain.
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

## libc++ iostream link wall (SOLVED — don't regress)
Symptom: at 100% (linking) the build dies with `Undefined symbols for
architecture armv7` for `vtable for std::__1::basic_stringstream`, `VTT for
...`, `vtable for basic_stringbuf`, `basic_ostringstream`, and
`basic_stringbuf::str() const` — referenced from `Options.cpp`, `I18n.cpp`,
`ExternalServerFile.cpp`, `libjsoncpp.a(json_writer.cpp.o)`, etc.

Cause: the host libc++ headers (libc++-18) are a *non-vendor* build, so they
define `_LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS`. That makes `<sstream>`
emit `extern template` declarations for the string-stream classes — i.e. it
expects their vtables / `str()` to come from the shared `libc++.dylib`. The iOS
8.0 SDK's `libc++.dylib` (2014) never exported those symbols, so the link fails.

Fix: `platforms/ios/libcxx/__config_site` is force-included ahead of the host
one (via `-I "$scriptroot/libcxx"` in `ios-cc`/`ios-c++`). It `#include_next`s
the real config and then `#undef`s `_LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS`,
pushing `<__availability>` into the `__APPLE__` branch. There the extra iostream
instantiations are disabled for iOS < 15.0, so the stream vtables are emitted
locally (weak) in our objects and the link succeeds. Don't remove the
`-I .../libcxx` flag or that shim.

## Deployment target
Default `NBC_TARGETS="armv7-apple-ios5.0 arm64-apple-ios7.0"` (fat binary;
lipo fuses the slices). armv7 floor is iOS 5.0; arm64 floor is iOS 7.0, the
minimum the iOS 8.0 SDK supports for 64-bit. Evaluate lowering armv7 to 4.3
only after on-device testing with real assets.
