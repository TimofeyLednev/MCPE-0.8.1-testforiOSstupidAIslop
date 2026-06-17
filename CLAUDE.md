# Claude notes

Read `AGENTS.md` first, then `platforms/ios/AGENTS.md`.

This fork is being prepared for an iOS port. Keep the existing desktop build
intact, and make iOS work as a separate path rather than a destructive rewrite.

Current focus:
- NBCraft-style cross compilation from Linux
- iOS 8.0 SDK baseline, **forced `libc++`** (the SDK's libstdc++ is too old for C++11)
- armv7 first (iOS 6.0 floor), arm64 later
- explicit Apple/iOS platform guards in the codebase

## iOS port progress log (newest first)

### Step 1 — force libc++ (DONE)
- `platforms/ios/ios-cc` and `ios-c++` now always pass `-stdlib=libc++`
  regardless of target. The iOS 8.0 SDK ships libc++ + its C++11 headers; its
  bundled libstdc++ is ancient and breaks the C++11 decomp core. This is the
  deliberate override the user asked for.

### Step 2 — Objective-C++ UIKit app shell (IN PROGRESS)
Goal: create the files listed in `platforms/ios/AGENTS.md` "Known TODO" so the
link step has an entry point + a concrete `AppPlatform` subclass.
Files being added under `platforms/ios/`:
- `main.m` — `UIApplicationMain` entry.
- `MCPEAppDelegate.{h,mm}` — app delegate, sets up window + view controller.
- `MCPEViewController.{h,mm}` — CADisplayLink loop -> `NinecraftApp::update()`.
- `EAGLView.{h,mm}` — CAEAGLLayer + GLES1 framebuffer surface.
- `AppPlatform_iOS.{hpp,mm}` — concrete `AppPlatform` implementing the
  pure-virtuals this decomp needs.

The shell must match THIS decomp's API (not NBCraft's). API is discovered by
reading `minecraftpe/headers/AppPlatform.hpp`, `App.hpp`, `NinecraftApp.hpp`,
`_pengine.hpp`, input headers, etc.

## Build (Linux cross-compile) — see README at repo root for the full copy
```
git clone --recursive <repo>
python tools/get_sound_data.py <path/to/libminecraftpe.so>   # -> pcm_data.c
mv pcm_data.c minecraftpe/impl/
cd platforms/ios && ./build.sh
```
`build.sh` downloads the iOS 8.0 SDK, builds cctools-port ld64 + ldid, then
runs cmake per target in `NBC_TARGETS` (default `armv7-apple-ios6.0`).
