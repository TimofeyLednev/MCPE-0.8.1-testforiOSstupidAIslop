#!/bin/sh
# Linux cross-compile launcher for the MCPE 0.8.1 iOS port.
# Mirrors the NBCraft approach: iOS 8.0 SDK + cctools-port ld64 + ldid.
set -e

scriptroot="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
platformdir="$scriptroot"

# Default build target(s). Override with NBC_TARGETS to build a custom set.
# armv7 floor is iOS 6.0 (per project goal); arm64 floor is iOS 7.0.
NBC_TARGETS="${NBC_TARGETS:-armv7-apple-ios6.0}"

bin='minecraftpe08decomp'
entitlements="$platformdir/mcpe.entitlements"

workdir="$platformdir/build/work"
sdk="$workdir/sdks/ios-sdk"
export NBC_SDK="$sdk"
mkdir -p "$workdir/sdks"
cd "$workdir"

# ---- iOS SDK ----------------------------------------------------------------
sdkver=1
if ! [ -d "$sdk" ] || [ "$(cat sdks/sdkver 2>/dev/null)" != "$sdkver" ]; then
    printf '\nDownloading iOS 8.0 SDK...\n\n'
    rm -rf "$sdk" iPhoneOS8.0.sdk.tar.lzma iPhoneOS8.0.sdk
    wget https://invoxiplaygames.uk/sdks/iPhoneOS8.0.sdk.tar.lzma
    tar -x --lzma -f iPhoneOS8.0.sdk.tar.lzma
    mv iPhoneOS8.0.sdk "$sdk"
    rm -f iPhoneOS8.0.sdk.tar.lzma
    printf '%s' "$sdkver" > sdks/sdkver
fi

# ---- host tooling -----------------------------------------------------------
if command -v nproc >/dev/null; then ncpus="$(nproc)"; else ncpus=2; fi

ar="${AR:-llvm-ar}"
ranlib="${RANLIB:-llvm-ranlib}"

for dep in "$ar" "$ranlib" clang clang++ cmake cmp wget tar; do
    command -v "$dep" >/dev/null || { printf '%s not found!\n' "$dep"; exit 1; }
done

if [ -z "$LLVM_CONFIG" ]; then
    if command -v llvm-config >/dev/null; then export LLVM_CONFIG=llvm-config
    else export LLVM_CONFIG=false; fi
fi

# ---- cross toolchain (cctools-port ld64 + lipo/strip + ldid) ----------------
toolchainver=1
[ "$(cat toolchain/toolchainver 2>/dev/null)" != "$toolchainver" ] && rm -rf toolchain

mkdir -p toolchain/bin
export PATH="$workdir/toolchain/bin:$PATH"

ccache="$(command -v ccache || true)"
printf '#!/bin/sh\nexec %s clang "$@"\n' "$ccache" > toolchain/bin/mcpe-clang
printf '#!/bin/sh\nexec %s clang++ "$@"\n' "$ccache" > toolchain/bin/mcpe-clang++
chmod +x toolchain/bin/mcpe-clang toolchain/bin/mcpe-clang++

if [ ! -x toolchain/bin/ld64.ld64 ] || [ ! -x toolchain/bin/lipo ] || [ ! -x toolchain/bin/cctools-strip ]; then
    printf '\nBuilding cctools-port (ld64)...\n\n'
    cctools_commit=fee8115127bb849d7481ea0015f181d3ebbd33cf
    rm -rf cctools-port-*
    wget -O- "https://github.com/Un1q32/cctools-port/archive/$cctools_commit.tar.gz" | tar -xz
    cd "cctools-port-$cctools_commit/cctools"
    ./configure --enable-silent-rules --with-llvm-config="$LLVM_CONFIG" CC=mcpe-clang CXX=mcpe-clang++
    make -C ld64 -j"$ncpus"
    strip ld64/src/ld/ld
    mv ld64/src/ld/ld "$workdir/toolchain/bin/ld64.ld64"
    make -C libmacho -j"$ncpus"
    make -C libstuff -j"$ncpus"
    make -C misc strip lipo -j"$ncpus"
    strip misc/strip misc/lipo
    mv misc/strip "$workdir/toolchain/bin/cctools-strip"
    mv misc/lipo "$workdir/toolchain/bin/lipo"
    cd "$workdir"
    rm -rf "cctools-port-$cctools_commit"
    printf '%s' "$toolchainver" > toolchain/toolchainver
fi

if [ ! -x toolchain/bin/ldid ]; then
    if command -v ldid >/dev/null; then
        ln -sf "$(command -v ldid)" toolchain/bin/ldid
    else
        printf '\nBuilding ldid...\n\n'
        ldid_commit=ef330422ef001ef2aa5792f4c6970d69f3c1f478
        rm -rf ldid-*
        wget -O- "https://github.com/ProcursusTeam/ldid/archive/$ldid_commit.tar.gz" | tar -xz
        cd "ldid-$ldid_commit"
        make CXX=mcpe-clang++
        strip ldid
        mv ldid "$workdir/toolchain/bin"
        cd "$workdir"
        rm -rf "ldid-$ldid_commit"
    fi
fi

# ---- cmake build per target -------------------------------------------------
if [ -z "$DEBUG" ]; then build=Release; else build=Debug; fi

built=
for target in $NBC_TARGETS; do
    printf '\nBuilding for %s\n\n' "$target"
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
        -DCMAKE_AR="$(command -v "$ar")" \
        -DCMAKE_RANLIB="$(command -v "$ranlib")" \
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

# ---- lipo + sign ------------------------------------------------------------
if [ -n "$built" ]; then
    # shellcheck disable=2086
    lipo -create $built -output "$platformdir/$bin"
    [ -z "$DEBUG" ] && [ -z "$NOSTRIP" ] && cctools-strip -no_code_signature_warning "$platformdir/$bin" || true
    if command -v ldid >/dev/null; then
        ldid -S"$entitlements" "$platformdir/$bin"
    fi
    printf '\nBuilt binary: %s\n' "$platformdir/$bin"
    [ -n "$NBC_NO_IPA" ] || "$platformdir/build-ipa.sh" "$platformdir/$bin"
else
    printf '\nNo binary produced (build failed).\n'
    exit 1
fi
