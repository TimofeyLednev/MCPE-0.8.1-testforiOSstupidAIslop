# Repository index

## What this fork is
- Decompiled Minecraft PE 0.8.1 source tree.
- Current baseline: Linux/Windows desktop build with SDL/OpenAL/OpenGL.
- Port goal: add a separate iOS cross-compile path in the style of NBCraft, starting from iOS 8.0 SDK + cctools-port + ldid.

## Where to work
- `minecraftpe/` — core game code, platform layer, rendering, audio, input, networking.
- `platforms/ios/` — iOS cross-compile launcher and packaging scripts.
- `tools/` — asset/sound extraction helpers.
- Root `CMakeLists.txt` and `minecraftpe/CMakeLists.txt` — build wiring.

## Porting rules
- Don’t break the existing Linux/Windows path while adding iOS.
- Prefer small, mechanical platform guards first: Apple/iOS detection, GLES/OpenAL header selection, and build-script scaffolding.
- Keep iOS-specific code behind explicit macros such as `MCPE_IOS` or Apple checks.
- Treat `platforms/ios/` as the place for NBCraft-style cross-compile plumbing.
- Future work should separate the real iOS app shell from desktop SDL logic instead of overloading it.

## Practical order
1. Add Apple/iOS build scaffolding.
2. Introduce iOS-safe platform guards in headers.
3. Split the runtime entry/platform class for iOS.
4. Wire UIKit/OpenGLES/OpenAL and input.
5. Only then chase lowering the deployment target.
