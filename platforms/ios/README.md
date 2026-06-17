# iOS port (cross-compile from Linux)

NBCraft-style cross compilation: iOS 8.0 SDK + [Un1q32/cctools-port](https://github.com/Un1q32/cctools-port) `ld64` + `ldid`.

**Status: the build compiles all game code with `libc++`, links a signed `armv7`
Mach-O, and packs an `.ipa`.** (No audio unless you supply real sounds, and you
must add `assets/` for the app to actually run — see below.)

## Layout

- `build.sh` — downloads the iOS 8.0 SDK, builds the cross toolchain (ld64, lipo, strip, ldid), then runs the cmake build per target, lipos the slices together, strips, signs with `ldid`, and packs an `.ipa`.
- `ios-cc` / `ios-c++` — compiler wrappers. They require `NBC_TARGET` (e.g. `armv7-apple-ios6.0`) and inject `-isysroot`, `-target`, `-stdlib=libc++`, `-fuse-ld=ld64`.
- `build-ipa.sh` — packages the signed binary + everything in `resources/` (Info.plist, launch images, icons, `assets/`) into `Payload/<app>.app` and zips an `.ipa`.
- `mcpe.entitlements` — minimal `get-task-allow` entitlements for sideloading.
- `resources/` — everything bundled into the `.app`: `Info.plist`, launch images (incl. `Default-568h@2x.png` for iPhone 5), icons, and `assets/` (unpack the game's resources here). See `resources/README.md`.
- `main.mm`, `EAGLView.{h,mm}`, `AppPlatform_iOS.{hpp,mm}` — the UIKit / GLES1
  Objective-C++ app shell (entry point, GL surface, platform layer, input).

## Full build from a clean Linux box (step by step)

Tested on Debian 12 (bookworm), x86-64. Anything Debian/Ubuntu-like works.

### 1. Install host tooling

```sh
sudo apt-get update
sudo apt-get install -y \
    clang llvm llvm-dev \
    libc++-dev libc++abi-dev \
    cmake make wget tar zip xz-utils cmp \
    libssl-dev libplist-dev libplist-utils pkg-config \
    git python3
```

Why these matter:
- `clang`/`llvm` — host compiler used for both cctools and the cross build.
- **`libc++-dev libc++abi-dev`** — the iOS 8.0 SDK ships `libc++.dylib` but
  **not** the libc++ headers. clang reuses the host's libc++ headers (they are
  platform-independent), so this is mandatory.
- `libssl-dev libplist-dev libplist-utils pkg-config` — needed to build `ldid`
  and for the `.ipa` packaging step (`plistutil`).

### 2. Clone with submodules

```sh
git clone --recursive https://github.com/TimofeyLednev/MCPE-0.8.1-testforiOSstupidAIslop.git
cd MCPE-0.8.1-testforiOSstupidAIslop
# if you forgot --recursive:
git submodule update --init --recursive
```

### 3. Sounds (pick one)

The game references PCM sound symbols; the link step needs them.

- **Real sounds** (recommended): extract from an original 0.8.1
  `libminecraftpe.so`:
  ```sh
  python3 tools/get_sound_data.py /path/to/libminecraftpe.so
  mv pcm_data.c minecraftpe/impl/
  ```
- **Silent stub** (just to get it to link, no audio):
  ```sh
  python3 tools/gen_silent_pcm.py
  ```

### 4. Build (downloads SDK + builds toolchain on first run)

```sh
cd platforms/ios
./build.sh
```

First run downloads the iOS 8.0 SDK and builds `cctools-port` + `ldid` (a few
minutes). Subsequent runs are cached and fast. The result:

- signed binary: `platforms/ios/minecraftpe08decomp`
- packaged app:  `platforms/ios/build/MCPE08DECOMP.ipa`

Override the target set with `NBC_TARGETS` (space-separated), e.g.:

```sh
NBC_TARGETS="armv7-apple-ios6.0 arm64-apple-ios7.0" ./build.sh
```

Skip the `.ipa` step with `NBC_NO_IPA=1`. Debug build with `DEBUG=1`.

### 5. Assets (needed to actually run on device)

`build-ipa.sh` bundles everything in `platforms/ios/resources/` into the `.app`.
Unpack a real MCPE 0.8.1 APK's `assets/` tree into
`platforms/ios/resources/assets/` before building. At runtime `AppPlatform_iOS`
resolves files against `<bundle>/assets/...`, so the layout must match the APK.
Override the source with `ASSET_DIR=/path/to/assets`. Without assets the app
launches but cannot load textures/UI. See `resources/README.md` for the
expected layout, launch-image sizes, and icon sizes.

## Targets / deployment floor

- Default: `armv7-apple-ios6.0` (override with `NBC_TARGETS`, space-separated).
- arm64 floor for this SDK is iOS 7.0 (`arm64-apple-ios7.0`).
- Goal is to lower armv7 to iOS 5.0, then evaluate 4.3 once the C++ standard
  usage is checked (the core is C++11).

## How the core build switches to iOS

The build passes `-DMCPE_IOS=ON`. In the core `minecraftpe/CMakeLists.txt` that:

- skips SDL / desktop OpenGL / desktop CURL `find_package`s,
- compiles with `-DUSEGLES -DMCPE_IOS -DSTBI_NO_THREAD_LOCALS`,
- drops `impl/main.cpp` and `impl/AppPlatform_sdl.cpp` from the source set,
- links the UIKit / OpenGLES / OpenAL / Foundation / QuartzCore / CoreGraphics / AVFoundation frameworks,
- pulls in the Objective-C(++) shell from this directory.

Platform header selection (see the matching guards in the tree):

- sound: `SoundEngine` / `SoundSystemAL` route Apple to OpenAL (`<OpenAL/al.h>`),
- GL: `unigl.h` selects `<OpenGLES/ES1/gl.h>` on Apple,
- `AppContext` / `_pengine` drop EGL types on Apple (no EGL on iOS; EAGL is owned by the shell),
- networking: `CurlRestRequestJob` is excluded on iOS (no libcurl in the public SDK) — a native rest job is a TODO,
- `_types.h`: on Apple does `#include_next <_types.h>` so the SDK's Darwin
  typedefs survive being shadowed by the core's own `_types.h`.

## Still TODO (runtime, not build)

1. Ship real `assets/` so the app runs past launch.
2. Native networking backend to replace the excluded curl rest job.
3. Lower the deployment target (iOS 6 → 5 → maybe 4.3); add an arm64 slice and test on device.
