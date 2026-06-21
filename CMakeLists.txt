cmake_minimum_required(VERSION 3.16)

if(ANDROID)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++11")
ENDIF()

project(minecraftpe08decomp)
set (CMAKE_CXX_STANDARD 11)

# Older Apple clang (Xcode 6.x) does not recognise several of the modern
# -Wno-* flag names sprinkled across the third-party CMakeLists, and emits a
# noisy "unknown warning option" diagnostic for each one. Silence that meta
# diagnostic tree-wide for Clang/AppleClang so the real build output is readable.
if(CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wno-unknown-warning-option)
endif()

include_directories(stb)
include_directories(glm)
include_directories(OpenAES/inc/)
include_directories(RakNet/Source/)

# i love python
OPTION(JSONCPP_WITH_TESTS "Compile and run JsonCpp test executables" ON)
OPTION(JSONCPP_WITH_POST_BUILD_UNITTEST "Automatically run unit-tests as a post build step" ON)
SET(JSONCPP_WITH_TESTS OFF)
SET(JSONCPP_WITH_POST_BUILD_UNITTEST OFF)

include_directories(jsoncpp/jsoncpp/include)
add_subdirectory(jsoncpp/jsoncpp)
include_directories(jsoncpp/jsoncpp/src/lib_json/)

include_directories(utf8proc)

add_subdirectory(RakNet)
add_subdirectory(utf8proc)
add_subdirectory(OpenAES)
add_subdirectory(minecraftpe)
