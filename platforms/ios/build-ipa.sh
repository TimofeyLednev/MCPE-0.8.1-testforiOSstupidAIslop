#!/bin/sh
# shellcheck disable=2016
set -e

ipaname='MCPE08DECOMP.ipa'
bin="${1:-build/minecraftpe08decomp}"
execname='minecraftpe08decomp'

platformdir='platforms/ios'
resdir="$platformdir/resources"
builddir="$platformdir/build"
# Game assets: default to platforms/ios/resources/assets (unpack the APK's
# assets/ there), override with ASSET_DIR=/path/to/assets.
assetdir="${ASSET_DIR:-$resdir/assets}"
ipadir="$builddir/ipa"
apppath="$ipadir/Payload/$execname.app"

[ "${0%/*}" = "$0" ] && scriptroot="." || scriptroot="${0%/*}"
cd "$scriptroot/../.."

if ! [ -f "$bin" ]; then
    printf 'Expected working binary at %s.\n' "$bin"
    printf 'Please do a cmake build before running this script.\n'
    exit 1
fi

if ! command -v plistutil >/dev/null; then
    printf 'note: plistutil not found (only needed on Linux); continuing.\n'
fi

rm -rf "$ipadir"
mkdir -p "$apppath"
cp "$bin" "$apppath/$execname"

# Info.plist: prefer the editable one in resources/, fall back to a minimal
# inline default so the build still works on a bare checkout.
if [ -f "$resdir/Info.plist" ]; then
    cp "$resdir/Info.plist" "$apppath/Info.plist"
else
    cat > "$apppath/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>minecraftpe08decomp</string>
	<key>CFBundleIdentifier</key>
	<string>com.example.minecraftpe08decomp</string>
	<key>CFBundleName</key>
	<string>minecraftpe08decomp</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.8.1</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
</dict>
</plist>
EOF
fi

# Launch images + icons live at the .app root (legacy naming).
if [ -d "$resdir" ]; then
    for f in "$resdir"/Default*.png "$resdir"/Icon*.png; do
        [ -f "$f" ] && cp "$f" "$apppath/"
    done
fi

# Game assets -> <app>/assets (AppPlatform_iOS resolves bundle + "assets/...").
if [ -d "$assetdir" ]; then
    rm -rf "$apppath/assets"
    cp -a "$assetdir" "$apppath/assets"
    if [ -z "$(ls -A "$assetdir" 2>/dev/null | grep -v '^\.gitkeep$')" ]; then
        printf 'WARNING: %s is empty. Unpack a real MCPE 0.8.1 APK assets/ there;\n' "$assetdir"
        printf '         the app will launch but cannot load textures/UI.\n'
    fi
else
    printf 'WARNING: no asset dir at %s (set ASSET_DIR). App will lack assets.\n' "$assetdir"
fi

cd "$ipadir"
rm -f "../$ipaname"
zip -r "../$ipaname" Payload >/dev/null

printf '\nDone! Your IPA is at %s/%s\n' "$builddir" "$ipaname"
