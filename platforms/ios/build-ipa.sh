#!/bin/sh
# shellcheck disable=2016
set -e

ipaname='MCPE08DECOMP.ipa'
bin="${1:-build/minecraftpe08decomp}"
execname='minecraftpe08decomp'

platformdir='platforms/ios'
builddir="$platformdir/build"
assetdir="${ASSET_DIR:-assets}"
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
    printf 'plistutil not found!\n'
    exit 1
fi

rm -rf "$ipadir"
mkdir -p "$apppath"
cp "$bin" "$apppath/$execname"

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

cp -a "$assetdir" "$apppath" || true
cd "$ipadir"
rm -f "../$ipaname"
zip -r "../$ipaname" Payload >/dev/null

printf '\nDone! Your IPA is at %s/%s\n' "$builddir" "$ipaname"
