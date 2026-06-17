cmake_minimum_required(VERSION 3.16)
project(minecraftpe08decomp LANGUAGES CXX)
#evil jsoncpp overring this thing </3
SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/build)

# MCPE_IOS is set by platforms/ios/build.sh. It is a cross-compile (Darwin)
# build that uses OpenGL ES + OpenAL + a UIKit app shell instead of SDL.
if(ANDROID)

elseif(MCPE_IOS)
	# iOS uses OpenAL from the SDK and OpenGL ES; SDL/desktop GL are not used.
	# We do not run find_package here because the cross SDK is located via
	# CMAKE_FIND_ROOT_PATH and the frameworks are linked explicitly below.
	find_package(ZLIB REQUIRED)
else()
	find_package(OpenGL REQUIRED)

	if(WIN32)

	else()
		find_package(OpenAL REQUIRED)
	endif()

	find_package(SDL REQUIRED)
	find_package(CURL REQUIRED)
endif()

if(NOT MCPE_IOS)
	find_package(ZLIB REQUIRED)
endif()

add_compile_options(-fpermissive -Wno-out-of-line-declaration -Wno-write-strings -Werror=infinite-recursion -Werror=return-type)
add_compile_options(-DDIFFERENTTWEAKS)
if(ANDROID)
	add_compile_options(-DUSEGLES -DIMTOOLAZYTOFIX16ERRS)
	#fix crash in CThread::~CThread when launching on newer(android 9) devices and targeting sdk 36
	add_compile_options(-DEVILOREOBROKEPTHREADS)
elseif(MCPE_IOS)
	# iOS renders with OpenGL ES 1.x (same as the original game / android path).
	add_compile_options(-DUSEGLES -DIMTOOLAZYTOFIX16ERRS -DMCPE_IOS)
else()
	add_compile_options(-DIMTOOLAZYTOFIX16ERRS -DPCTWEAKS)
endif()

if(DEBUG)
	add_compile_options(-DAUTH_SERVER="127.0.0.1:8000" -DPEOAPI_SERVER="127.0.0.1:8001")
	add_compile_options(-g -DDEBUG)
else()
	add_compile_options(-g0)
endif()
file(GLOB_RECURSE IMPLCPP *.cpp)
file(GLOB_RECURSE IMPLC *.c)
file(GLOB_RECURSE HEADC *.h)
file(GLOB_RECURSE HEADCPP *.hpp)

if(MCPE_IOS)
	# The SDL desktop entry point and platform are replaced by the UIKit shell
	# living in platforms/ios. Drop them from the core source set.
	list(FILTER IMPLCPP EXCLUDE REGEX ".*/impl/main\\.cpp$")
	list(FILTER IMPLCPP EXCLUDE REGEX ".*/impl/AppPlatform_sdl\\.cpp$")
endif()

if(ANDROID)
	add_library(native_app_glue STATIC ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c)
	add_library(minecraftpe SHARED ${IMPLCPP} ${IMPLC} ${HEADC} ${HEADCPP})
	target_include_directories(minecraftpe PUBLIC "headers/" ${ANDROID_NDK}/sources/android/native_app_glue/)
	target_link_libraries(minecraftpe ZLIB::ZLIB EGL GLESv1_CM OpenSLES oaes_lib RakNetStatic native_app_glue jsoncpp_lib utf8proc log native_app_glue android)
elseif(MCPE_IOS)
	# UIKit app shell sources (Objective-C++ / Objective-C).
	set(IOS_PLATFORM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../platforms/ios")
	file(GLOB IOS_PLATFORM_SRC
		"${IOS_PLATFORM_DIR}/*.mm"
		"${IOS_PLATFORM_DIR}/*.m"
	)
	add_executable(minecraftpe08decomp ${IMPLCPP} ${IMPLC} ${HEADC} ${HEADCPP} ${IOS_PLATFORM_SRC})
	target_include_directories(minecraftpe08decomp PUBLIC "headers/" "${IOS_PLATFORM_DIR}")
	target_link_libraries(minecraftpe08decomp
		oaes_lib RakNetStatic jsoncpp_lib utf8proc
		ZLIB::ZLIB
		objc
		# NOTE: the public iOS SDK does not ship libcurl. The desktop network
		# layer (CurlRestRequestJob) still needs an iOS strategy (system
		# libcurl, NSURLSession bridge, or a stub). See AGENTS.md milestone 4.
		"-framework Foundation"
		"-framework CoreGraphics"
		"-framework QuartzCore"
		"-framework UIKit"
		"-framework OpenGLES"
		"-framework OpenAL"
		"-framework AVFoundation"
	)
else()
	add_executable(minecraftpe08decomp ${IMPLCPP} ${IMPLC} ${HEADC} ${HEADCPP})
	target_precompile_headers(minecraftpe08decomp PRIVATE
		"$<$<COMPILE_LANGUAGE:CXX>:<vector$<ANGLE-R>>"
		"$<$<COMPILE_LANGUAGE:CXX>:<string$<ANGLE-R>>"
	)
	target_include_directories(minecraftpe08decomp PUBLIC "headers/")
	target_link_libraries(minecraftpe08decomp)
	if(WIN32)
		target_link_libraries(minecraftpe08decomp pthread dsound dxguid)
	else()
		target_link_libraries(minecraftpe08decomp ${OPENAL_LIBRARY})
	endif()
	target_link_libraries(minecraftpe08decomp CURL::libcurl ZLIB::ZLIB ${OPENGL_LIBRARIES} ${SDL_LIBRARIES} oaes_lib RakNetStatic jsoncpp_lib utf8proc)
endif()
