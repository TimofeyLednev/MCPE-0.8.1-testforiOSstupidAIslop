#pragma once
#ifdef __APPLE__
// The iOS SDK has its own internal <_types.h> that defines Darwin typedefs
// (__darwin_wctype_t, __DARWIN_WEOF, etc). Because the core ships its own
// headers/ on the include path, an SDK `#include <_types.h>` resolves to THIS
// file instead, hiding those typedefs and breaking libc++ <string>/<wchar.h>.
// Pull the real SDK header in first so both definitions coexist.
#include_next <_types.h>
#endif
#define UNK
#include <stdint.h>
typedef char char_t;
typedef	unsigned char bool_t;
#ifdef DEBUG

#ifdef ANDROID
#include <android/log.h>
inline void _android_debug_thingy(const char* fmt, ...){
	va_list args;
	va_start(args, fmt);
	__android_log_vprint(ANDROID_LOG_DEBUG, "MCPE081DECOMP", fmt, args);
	va_end(args);
}
#define DEBUGMSG _android_debug_thingy
#else
#include <stdio.h>
#define DEBUGMSG printf
#endif

#else
#define DEBUGMSG(...)
#endif
