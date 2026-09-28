#!/bin/bash
#
# Makes nulloy.app independent of the Qt installation it was built with:
# copies Qt frameworks and plugins into the bundle using macdeployqt.
#
# GStreamer and TagLib are NOT bundled: GStreamer loads its plugins from
# its own prefix and a second libgstreamer/libgobject copy inside the
# bundle would clash with them. Nulloy plugins keep linking them from
# where they were found at build time.
#
# Usage: ./macdeploy.sh [path/to/nulloy.app]
#        MACDEPLOYQT=/path/to/macdeployqt ./macdeploy.sh

set -eu

APP="${1:-$(dirname "$0")/nulloy.app}"
MACDEPLOYQT="${MACDEPLOYQT:-macdeployqt}"

APP="$(cd "$APP" && pwd)"
EXE="$APP/Contents/MacOS/nulloy"
FRAMEWORKS="$APP/Contents/Frameworks"
QT_PLUGINS="$APP/Contents/PlugIns"
N_PLUGINS="$APP/Contents/MacOS/plugins"

macho_files() {
    find "$APP/Contents" -type f -print0 | while IFS= read -r -d '' f; do
        if [[ "$(file -b "$f")" == Mach-O* ]]; then
            echo "$f"
        fi
    done
}

# 1. Hide Nulloy plugins, otherwise macdeployqt bundles GStreamer and TagLib.
HIDDEN="$(mktemp -d)"
trap 'rm -rf "$HIDDEN"' EXIT
if [[ -d "$N_PLUGINS" ]]; then
    mv "$N_PLUGINS" "$HIDDEN/plugins"
fi

"$MACDEPLOYQT" "$APP" -always-overwrite -no-codesign -verbose=1 2>&1 |
    grep -v 'is not an object file' || true

if [[ -d "$HIDDEN/plugins" ]]; then
    mv "$HIDDEN/plugins" "$N_PLUGINS"
fi

# 2. Drop Qt plugins Nulloy does not use and whose dependencies
#    (QtPdf, QtVirtualKeyboard/QtQuick, a GLib network backend) are not deployed.
rm -f  "$QT_PLUGINS/imageformats/libqpdf.dylib"
rm -rf "$QT_PLUGINS/platforminputcontexts"
rm -f  "$QT_PLUGINS/networkinformation/libqglib.dylib"

# 3. Remove frameworks and libraries nothing in the bundle links to anymore.
while :; do
    # "<file>\t<dependency>" pairs; a library lists its own install name too
    macho_files | while read -r f; do
        otool -L "$f" | awk -v f="$f" 'NR > 1 { print f "\t" $1 }'
    done > "$HIDDEN/deps"
    removed=0
    for item in "$FRAMEWORKS"/*; do
        name="$(basename "$item")"
        if ! awk -F '\t' -v item="$item" -v name="/$name" '
                $1 != item && index($1, item "/") != 1 && index($2, name) { found = 1 }
                END { exit !found }' "$HIDDEN/deps"; then
            echo "removing unused $name"
            rm -rf "$item"
            removed=1
        fi
    done
    [[ $removed == 0 ]] && break
done

# 4. Give bundled libraries relative install names, some keep the Homebrew ones.
find "$FRAMEWORKS" -type f -print0 | while IFS= read -r -d '' f; do
    id="$(otool -D "$f" 2>/dev/null | awk 'NR == 2')"
    if [[ "$id" == /* ]]; then
        install_name_tool -id "@rpath/${f#"$FRAMEWORKS"/}" "$f" 2>/dev/null
    fi
done

# 5. Point Nulloy plugins to the bundled Qt frameworks.
for plugin in "$N_PLUGINS"/*.dylib; do
    otool -L "$plugin" | awk 'NR > 1 { print $1 }' |
        grep -E '/Qt[A-Za-z0-9]+\.framework/' | grep -v '^@' |
        while read -r dep; do
            rel="${dep##*/lib/}"
            install_name_tool -change "$dep" "@executable_path/../Frameworks/$rel" "$plugin" 2>/dev/null
        done
done

# 6. Ad-hoc sign every Mach-O (required on Apple Silicon). The bundle itself
#    is not sealed: Nulloy keeps data files (skins, i18n, settings) in
#    Contents/MacOS, which codesign rejects. The main executable is signed
#    outside the bundle for the same reason.
macho_files | while read -r f; do
    if [[ "$f" == "$EXE" ]]; then
        cp "$f" "$HIDDEN/nulloy"
        codesign --force -s - "$HIDDEN/nulloy" 2>/dev/null
        cp "$HIDDEN/nulloy" "$f"
    else
        codesign --force -s - "$f" 2>/dev/null
    fi
done

# 7. Verify: no references to Qt outside the bundle.
if macho_files | while read -r f; do otool -L "$f" | awk 'NR > 1 { print $1 }'; done |
        grep -E '/Qt[A-Za-z0-9]+\.framework/' | grep -v '^@'; then
    echo "error: references to external Qt remain" >&2
    exit 1
fi
echo "Qt has been deployed into $APP"
