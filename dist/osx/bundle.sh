#!/usr/bin/env bash

set -euo pipefail

LANGUAGES="bs ca cs da de el eo es fi fr gl he hr hu id it ja ko lv nb nl nn pl pt_BR ru sk sr@latin sv th tr uk vi zh_CN zh_TW"

# Detect Homebrew prefix: /opt/homebrew on Apple Silicon, /usr/local on Intel.
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix)
else
    case "$(uname -m)" in
        arm64) BREW_PREFIX=/opt/homebrew ;;
        *)     BREW_PREFIX=/usr/local ;;
    esac
fi

ARCH=$(uname -m)
echo "Building for $ARCH using Homebrew prefix $BREW_PREFIX"

cd $(dirname $0)/../..

rm -f src/spek

./autogen.sh && make -j$(sysctl -n hw.ncpu) || exit 1

# Ensure .gmo translation catalogs are generated; the gettext-provided po
# Makefile defaults to all-no, so they aren't built by the top-level make.
make -C po update-gmo

cd dist/osx
rm -fr Spek.app
mkdir -p Spek.app/Contents/MacOS
mkdir -p Spek.app/Contents/Frameworks
mkdir -p Spek.app/Contents/Resources
mv ../../src/spek Spek.app/Contents/MacOS/Spek
cp Info.plist Spek.app/Contents/
cp Spek.icns Spek.app/Contents/Resources/
cp *.png Spek.app/Contents/Resources/
cp ../../CREDITS.md Spek.app/Contents/Resources/
cp ../../LICENSE Spek.app/Contents/Resources/
cp ../../README.md Spek.app/Contents/Resources/
mkdir Spek.app/Contents/Resources/lic
cp ../../lic/* Spek.app/Contents/Resources/lic/

for lang in $LANGUAGES; do
    mkdir -p Spek.app/Contents/Resources/"$lang".lproj
    cp -v ../../po/"$lang".gmo Spek.app/Contents/Resources/"$lang".lproj/spek.mo
    wx_mo=$(ls "$BREW_PREFIX"/share/locale/"$lang"/LC_MESSAGES/wxstd-*.mo 2>/dev/null | head -1 || true)
    if [ -n "$wx_mo" ]; then
        cp -v "$wx_mo" Spek.app/Contents/Resources/"$lang".lproj/
    else
        echo "No WX translation for $lang"
    fi
done
mkdir -p Spek.app/Contents/Resources/en.lproj

BINS="Spek.app/Contents/MacOS/Spek"
while [ ! -z "$BINS" ]; do
    NEWBINS=""
    for bin in $BINS; do
        echo "Updating dependendies for $bin."
        LIBS=$(otool -L $bin | tail -n +2 | tr -d '\t' | awk '{print $1}')
        for lib in $LIBS; do
            # Resolve the reference to a real source file. Skip system libs
            # and already-rewritten @executable_path references.
            case "$lib" in
                @rpath/*)
                    # Resolve via Homebrew's lib dir — that's where bottles
                    # land, and brew dylibs typically rpath into it.
                    candidate="$BREW_PREFIX/lib/${lib#@rpath/}"
                    [ -e "$candidate" ] || continue
                    src="$candidate"
                    ;;
                /opt/homebrew/*|/usr/local/*)
                    src="$lib"
                    ;;
                *)
                    continue
                    ;;
            esac
            reallib=$(realpath "$src")
            libname=$(basename "$reallib")
            install_name_tool -change "$lib" @executable_path/../Frameworks/$libname $bin
            if [ ! -f Spek.app/Contents/Frameworks/$libname ]; then
                echo "\tBundling $reallib."
                cp "$reallib" Spek.app/Contents/Frameworks/
                chmod +w Spek.app/Contents/Frameworks/$libname
                install_name_tool -id @executable_path/../Frameworks/$libname Spek.app/Contents/Frameworks/$libname
                NEWBINS="$NEWBINS Spek.app/Contents/Frameworks/$libname"
            fi
        done
    done
    BINS="$NEWBINS"
done

# install_name_tool invalidates the ad-hoc signature linkers now embed by
# default. On Apple Silicon, an invalid signature makes dyld kill the process
# at load (SIGKILL "Code Signature Invalid"). Re-sign every Mach-O in the
# bundle ad-hoc so it loads.
echo "Re-signing bundle (ad-hoc)..."
codesign --force --sign - Spek.app/Contents/Frameworks/*.dylib
codesign --force --sign - Spek.app/Contents/MacOS/Spek

# Make DMG image
VOLUME_NAME=Spek
DMG_APP=Spek.app
DMG_FILE=$VOLUME_NAME-$ARCH.dmg
MOUNT_POINT=$VOLUME_NAME.mounted

rm -f $DMG_FILE
rm -f $DMG_FILE.master

# Compute an approximated image size in MB, and bloat by 1MB
image_size=$(du -ck $DMG_APP | tail -n1 | cut -f1)
image_size=$((($image_size + 5000) / 1000))

echo "Creating disk image (${image_size}MB)..."
hdiutil create $DMG_FILE -megabytes $image_size -volname $VOLUME_NAME -fs HFS+ -quiet || exit $?

echo "Attaching to disk image..."
hdiutil attach $DMG_FILE -readwrite -noautoopen -mountpoint $MOUNT_POINT -quiet

echo "Populating image..."
cp -Rp $DMG_APP $MOUNT_POINT
cd $MOUNT_POINT
ln -s /Applications " "
cd ..
cp DS_Store $MOUNT_POINT/.DS_Store

echo "Detaching from disk image..."
hdiutil detach $MOUNT_POINT -quiet
mv $DMG_FILE $DMG_FILE.master

echo "Creating distributable image..."
hdiutil convert -quiet -format UDBZ -o $DMG_FILE $DMG_FILE.master
rm $DMG_FILE.master

echo "Done."

cd ../..
