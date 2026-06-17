#pragma once
#include <_types.h>
#ifdef MCPE_IOS
// iOS provides its own UIKit entry point and platform object in
// platforms/ios; nothing desktop/SDL-specific is pulled in here.
#elif !defined(ANDROID)
#include <AppPlatform_sdl.hpp>

extern AppPlatform_sdl appPlatform;
#else
#include <android/AppPlatform_android.hpp>
extern bool contextWasLost;
extern jobject mainActivity_ref;
extern struct NinecraftApp* ninecraftApp;
extern AppPlatform_android appPlatform;
extern pthread_mutex_t _D6E04480;
#endif
