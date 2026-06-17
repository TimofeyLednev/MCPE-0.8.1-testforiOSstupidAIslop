# Claude notes

Read `AGENTS.md` first, then `platforms/ios/AGENTS.md`.

This fork is being prepared for an iOS port. Keep the existing desktop build
intact, and make iOS work as a separate path rather than a destructive rewrite.

## iOS port status — IT LINKS AND PRODUCES AN IPA ✅

The iOS cross-compile (from Linux) now compiles **all** of the game code with
`-stdlib=libc++`, links a signed `armv7` Mach-O, and packs an `.ipa`.

Milestones done:
1. ✅ NBCraft-style cross toolchain (iOS 8.0 SDK + cctools-port `ld64`/`lipo`/
   `strip` + `ldid`) builds from Linux via `platforms/ios/build.sh`.
2. ✅ Forced `libc++` in `ios-cc` / `ios-c++` wrappers (was libstdc++).
3. ✅ Mechanical platform guards (GLES/OpenAL/EGL/SDL/curl) compile clean.
4. ✅ Objective-C++ UIKit app shell written in `platforms/ios/`:
   - `main.mm` — `UIApplicationMain` entry, app delegate, view controller with
     a `CADisplayLink` loop calling `NinecraftApp::update()`, touch input fed to
     `Multitouch`/`Mouse`, soft-keyboard text view fed to `Keyboard`.
   - `EAGLView.{h,mm}` — `CAEAGLLayer` + GLES1 framebuffer.
   - `AppPlatform_iOS.{hpp,mm}` — implements the `AppPlatform` pure-virtuals
     (asset/image paths bundle-relative, screen metrics, touchscreen, login,
     keyboard).
5. ✅ Silent PCM stub generator (`tools/gen_silent_pcm.py`) so it links without
   the original APK sounds.

## Important build gotchas (already solved — don't regress)
- **libc++ iostream link wall**: the host libc++ headers (libc++-18) are a
  *non-vendor* build, so they define
  `_LIBCPP_HAS_NO_VENDOR_AVAILABILITY_ANNOTATIONS`. That makes `<sstream>` emit
  `extern template` decls for `basic_stringbuf`/`basic_stringstream`/
  `basic_ostringstream`, expecting their vtables + `str()` from the shared
  `libc++.dylib`. The iOS 8.0 SDK's 2014 `libc++.dylib` doesn't export them, so
  the link dies at 100% with `Undefined symbols for architecture armv7`
  (vtables / VTT / `basic_stringbuf::str()`). Fixed with
  `platforms/ios/libcxx/__config_site` (force-included via `-I` in the wrappers)
  which `#include_next`s the host config then `#undef`s that macro, sending
  `<__availability>` into the `__APPLE__` branch where the instantiations are
  disabled for iOS < 15.0 (vtables then emitted locally). Don't drop the
  `-I .../libcxx` flag.
- **libc++ headers**: the iOS 8.0 SDK ships `libc++.dylib` but NOT the libc++
  headers (`c++/v1`). We use the host's `libc++-dev` headers (apt) which clang
  picks up automatically. So the host needs `libc++-dev libc++abi-dev`.
- **`_types.h` clash**: the core ships `minecraftpe/headers/_types.h`, which is
  on the `-Iheaders` path and shadows the iOS SDK's internal `<_types.h>`. The
  SDK's `_wctype.h`/`_wchar.h` `#include <_types.h>` and need the Darwin
  typedefs. Fixed with an `#ifdef __APPLE__ #include_next <_types.h>` at the top
  of the project `_types.h`.
- **stb thread_local**: `thread_local` is unsupported on armv7/iOS6 with this
  toolchain. Fixed by defining `STBI_NO_THREAD_LOCALS` for the iOS build.
- **OpenAL typedefs**: on Apple `ALCdevice`/`ALCcontext` are typedefs of
  `*_struct`, which clashed with `struct ALCdevice*` forward decls in
  `SoundSystemAL.hpp`. Fixed by including `<OpenAL/alc.h>` and using the
  typedef names on Apple.

## Sounds
The real sounds come from an original 0.8.1 `libminecraftpe.so`
(`tools/get_sound_data.py`). Without it, `tools/gen_silent_pcm.py` writes a
silent `minecraftpe/impl/pcm_data.c` so the binary links (no audio).

## Deployment target
Default `NBC_TARGETS=armv7-apple-ios6.0`. arm64 floor for this SDK is iOS 7.0
(`arm64-apple-ios7.0`). Lowering further (ios5.0 / 4.3) is still TODO and needs
C++11 usage review.

## Still TODO (runtime, not build)
- Real assets (`assets/` from the APK) for the app to actually run.
- Native networking backend (curl is excluded; realms/multiplayer over HTTP).
- Lower deployment target; arm64 slice; test on device.
