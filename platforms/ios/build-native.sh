#!/bin/sh
# Native macOS build launcher for the MCPE 0.8.1 iOS port.
#
# Same console workflow as build.sh, but it compiles and links with the REAL
# Xcode toolchain (xcrun clang / clang++ / lipo / strip / codesign) against the
# iOS SDK that ships with the installed Xcode — instead of downloading the iOS
# 8.0 SDK and building cctools-port + ldid.
#
# This is NOT "open the .xcodeproj in Xcode". It is a pure command-line build,
# exactly like build.sh; it just points CMake at the Apple toolchain via the
# ios-cc / ios-c++ wrappers running in NBC_TOOLCHAIN=native mode.
#
# The original cctools cross-compile path (build.sh) is left untouched.
#
# Requirements: macOS with Xcode (or Command Line Tools) installed, plus cmake.
#   xcode-select --install            # if you only need the CLT
#   xcrun --sdk iphoneos --show-sdk-path   # must print a valid SDK path
set -e

scriptroot="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
platformdir="$scriptroot"

# Native toolchain: tell the ios-cc / ios-c++ wrappers to use xcrun clang.
export NBC_TOOLCHAIN=native

# Default build target(s). With the modern SDK we can go straight to arm64.
# Override with NBC_TARGETS (space-separated) to build a custom/fat set, e.g.
#   NBC_TARGETS="armv7-apple-ios9.0 arm64-apple-ios9.0" ./build-native.sh
# Note: recent Xcode SDKs no longer ship the 32-bit armv7 slice, so the default
# here is arm64 only. The deployment floor is whatever your SDK supports.
NBC_TARGETS="${NBC_TARGETS:-arm64-apple-ios9.0}"

bin='minecraftpe08decomp'
entitlements="$platformdir/mcpe.entitlements"

workdir="$platformdir/build/work-native"
mkdir -p "$workdir"
cd "$workdir"

# ---- sanity: we are on macOS with a working Xcode toolchain ----------------
if ! command -v xcrun >/dev/null 2>&1; then
    printf 'xcrun not found. This script needs macOS + Xcode (or Command Line Tools).\n'
    printf 'Use ./build.sh for the Linux cctools cross-compile path instead.\n'
    exit 1
fi

# Resolve and export the iOS SDK so the wrappers and CMake agree on one path.
sdk="${NBC_SDK:-$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)}"
if [ -z "$sdk" ] || [ ! -d "$sdk" ]; then
    printf 'Could not locate an iOS SDK via xcrun.\n'
    printf 'Make sure Xcode is installed and selected:\n'
    printf '  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer\n'
    exit 1
fi
export NBC_SDK="$sdk"
printf 'Using iOS SDK: %s\n' "$NBC_SDK"

if command -v sysctl >/dev/null 2>&1; then
    ncpus="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)"
elif command -v nproc >/dev/null 2>&1; then
    ncpus="$(nproc)"
else
    ncpus=2
fi

for dep in cmake xcrun; do
    command -v "$dep" >/dev/null || { printf '%s not found!\n' "$dep"; exit 1; }
done

# Xcode toolchain binaries (ar/ranlib/lipo/strip) come from xcrun.
ar="$(xcrun -f ar)"
ranlib="$(xcrun -f ranlib)"

# ---- cmake build per target -------------------------------------------------
if [ -z "$DEBUG" ]; then build=Release; else build=Debug; fi

built=
for target in $NBC_TARGETS; do
    printf '\nBuilding for %s (native Xcode toolchain)\n\n' "$target"
    export NBC_TARGET="$target"
    mkdir -p "build-$target"
    cd "build-$target"
    cmake "$platformdir/../.." \
        -DCMAKE_BUILD_TYPE="$build" \
        -DCMAKE_SYSTEM_NAME=Darwin \
        -DNBC_PLATFORM=ios \
        -DMCPE_IOS=ON \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_AR="$ar" \
        -DCMAKE_RANLIB="$ranlib" \
        -DCMAKE_C_COMPILER="$platformdir/ios-cc" \
        -DCMAKE_CXX_COMPILER="$platformdir/ios-c++" \
        -DCMAKE_FIND_ROOT_PATH="$NBC_SDK/usr" \
        -DCMAKE_C_FLAGS="${CFLAGS:-}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS:-}" \
        -DJSONCPP_WITH_TESTS=OFF \
        -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF \
        -DWERROR="${WERROR:-OFF}"
    cmake --build . --parallel "$ncpus"
    found="$(find . -maxdepth 3 -type f -name "$bin" | head -1)"
    [ -n "$found" ] && built="$built $PWD/$found"
    cd "$workdir"
done

# ---- lipo + sign (all via the Xcode toolchain) ------------------------------
if [ -n "$built" ]; then
    # shellcheck disable=2086
    xcrun lipo -create $built -output "$platformdir/$bin"
    [ -z "$DEBUG" ] && [ -z "$NOSTRIP" ] && xcrun strip -x "$platformdir/$bin" || true

    # Sign with the real codesign. Default to ad-hoc ("-") so the binary is
    # valid for jailbroken / sideload-with-resign workflows; override with
    # CODESIGN_IDENTITY="iPhone Developer: ..." for a real signing identity.
    identity="${CODESIGN_IDENTITY:--}"
    xcrun codesign --force --sign "$identity" \
        --entitlements "$entitlements" \
        --timestamp=none \
        "$platformdir/$bin" 2>/dev/null \
        || xcrun codesign --force --sign "$identity" "$platformdir/$bin"

    printf '\nBuilt binary: %s\n' "$platformdir/$bin"
    [ -n "$NBC_NO_IPA" ] || "$platformdir/build-ipa.sh" "$platformdir/$bin"
else
    printf '\nNo binary produced (build failed).\n'
    exit 1
fi
