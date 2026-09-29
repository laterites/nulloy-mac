#!/bin/bash
#
# Makes "Nulloy Mac.app" self-contained: copies Qt (via macdeployqt), TagLib
# and GStreamer (from the official GStreamer.framework) into the bundle.
#
# Layout inside Contents/Frameworks:
#   Qt*.framework, lib*.dylib      Qt and its dependencies, TagLib
#   GStreamer/lib/                 GStreamer libraries (own GLib copy)
#   GStreamer/lib/gstreamer-1.0/   GStreamer plugins listed in GST_PLUGINS
#   GStreamer/libexec/gstreamer-1.0/gst-plugin-scanner
# GStreamer keeps its own directory because it ships libraries with the same
# names as Qt's Homebrew dependencies (libglib, libintl, ...). main() points
# GStreamer to this directory at startup.
#
# Usage: ./macdeploy.sh ["path/to/Nulloy Mac.app"]
#        MACDEPLOYQT=/path/to/macdeployqt ./macdeploy.sh
#        GSTREAMER_FRAMEWORK=/path/to/GStreamer.framework/Versions/1.0 ./macdeploy.sh

set -eu

# GStreamer plugins to bundle (lib/gstreamer-1.0/libgst<name>.dylib)
GST_PLUGINS="
    coreelements typefindfunctions playback autodetect osxaudio
    audioconvert audioresample volume
    audioparsers id3demux apetag
    wavparse aiff flac mpg123 ogg vorbis opus opusparse isomp4
    libav
"
# libav: ALAC and AAC decoders (M4A); atdec from applemedia cannot decode ALAC

ARCH=arm64

APP="${1:-$(dirname "$0")/Nulloy Mac.app}"
MACDEPLOYQT="${MACDEPLOYQT:-macdeployqt}"
GST_ROOT="${GSTREAMER_FRAMEWORK:-/Library/Frameworks/GStreamer.framework/Versions/1.0}"

APP="$(cd "$APP" && pwd)"
EXE="$APP/Contents/MacOS/nulloy"
FRAMEWORKS="$APP/Contents/Frameworks"
QT_PLUGINS="$APP/Contents/PlugIns"
N_PLUGINS="$APP/Contents/MacOS/plugins"
GST_DIR="$FRAMEWORKS/GStreamer"

macho_files() {
    find "${1:-$APP/Contents}" -type f -print0 | while IFS= read -r -d '' f; do
        if [[ "$(file -b "$f")" == Mach-O* ]]; then
            echo "$f"
        fi
    done
}

# dependencies, without a library's own install name
deps_of() {
    local id
    id="$(otool -D "$1" 2>/dev/null | awk 'NR == 2')"
    otool -L "$1" | awk -v id="$id" 'NR > 1 && $1 != id { print $1 }'
}

is_system() {
    [[ "$1" == /usr/lib/* || "$1" == /System/* ]]
}

thin() {
    if lipo -archs "$1" 2>/dev/null | grep -qw "$ARCH" &&
            [[ "$(lipo -archs "$1")" != "$ARCH" ]]; then
        lipo "$1" -thin "$ARCH" -output "$1.thin" && mv "$1.thin" "$1"
    fi
}

HIDDEN="$(mktemp -d)"
trap 'rm -rf "$HIDDEN"' EXIT

# 1. Qt. Hide Nulloy plugins and drop a previously bundled GStreamer, otherwise
#    macdeployqt copies Homebrew/framework libraries next to Qt.
rm -rf "$GST_DIR"
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

# 4. Qt libraries: install names relative to the executable, some keep the
#    Homebrew ones. Not @rpath: GStreamer libraries use @rpath/<same name>.
find "$FRAMEWORKS" -type f -print0 | while IFS= read -r -d '' f; do
    id="$(otool -D "$f" 2>/dev/null | awk 'NR == 2')"
    if [[ "$id" == /* ]]; then
        install_name_tool -id "@executable_path/../Frameworks/${f#"$FRAMEWORKS"/}" "$f" 2>/dev/null
    fi
done

# 5. Point Nulloy plugins to the bundled Qt frameworks.
for plugin in "$N_PLUGINS"/*.dylib; do
    install_name_tool -id "@executable_path/plugins/$(basename "$plugin")" "$plugin" 2>/dev/null
    deps_of "$plugin" | grep -E '/Qt[A-Za-z0-9]+\.framework/' | grep -v '^@' |
        while read -r dep; do
            rel="${dep##*/lib/}"
            install_name_tool -change "$dep" "@executable_path/../Frameworks/$rel" "$plugin" 2>/dev/null
        done
done

# 6. TagLib and any other non-GStreamer library Nulloy plugins link by absolute
#    path: copy into Frameworks/ and link via @rpath (plugins have
#    @loader_path/../../Frameworks in their rpath).
bundle_absolute_deps() {
    deps_of "$1" | while read -r dep; do
        if [[ "$dep" != /* ]] || is_system "$dep" || [[ "$dep" == "$GST_ROOT"/* ]]; then
            continue
        fi
        name="$(basename "$dep")"
        if [[ ! -f "$FRAMEWORKS/$name" ]]; then
            echo "bundling $dep"
            cp "$dep" "$FRAMEWORKS/$name"
            chmod u+w "$FRAMEWORKS/$name"
            thin "$FRAMEWORKS/$name"
            install_name_tool -id "@rpath/$name" "$FRAMEWORKS/$name" 2>/dev/null
            install_name_tool -add_rpath @loader_path "$FRAMEWORKS/$name" 2>/dev/null || true
            bundle_absolute_deps "$FRAMEWORKS/$name"
        fi
        install_name_tool -change "$dep" "@rpath/$name" "$1" 2>/dev/null
    done
}
for plugin in "$N_PLUGINS"/*.dylib; do
    bundle_absolute_deps "$plugin"
done

# 7. GStreamer: the listed plugins, the plugin scanner and every library they
#    need, resolved from GStreamer.framework. Files keep the framework layout,
#    so the framework's relative rpaths (@loader_path/../lib, ...) still work.
if [[ -f "$N_PLUGINS/libplugin_gstreamer.dylib" ]]; then
    if [[ ! -d "$GST_ROOT/lib/gstreamer-1.0" ]]; then
        echo "error: GStreamer framework not found at $GST_ROOT" >&2
        exit 1
    fi
    mkdir -p "$GST_DIR/lib/gstreamer-1.0" "$GST_DIR/libexec/gstreamer-1.0"

    queue=()
    for p in $GST_PLUGINS; do
        src="$GST_ROOT/lib/gstreamer-1.0/libgst$p.dylib"
        if [[ ! -f "$src" ]]; then
            echo "error: GStreamer plugin $p not found: $src" >&2
            exit 1
        fi
        cp "$src" "$GST_DIR/lib/gstreamer-1.0/"
        queue+=("$GST_DIR/lib/gstreamer-1.0/libgst$p.dylib")
    done
    cp "$GST_ROOT/libexec/gstreamer-1.0/gst-plugin-scanner" "$GST_DIR/libexec/gstreamer-1.0/"
    queue+=("$GST_DIR/libexec/gstreamer-1.0/gst-plugin-scanner" "$N_PLUGINS/libplugin_gstreamer.dylib")

    # transitive @rpath libraries
    while ((${#queue[@]})); do
        f="${queue[0]}"
        queue=("${queue[@]:1}")
        [[ "$f" == "$GST_DIR"/* ]] && chmod u+w "$f" && thin "$f"
        for dep in $(deps_of "$f" | grep '^@rpath/'); do
            name="${dep#@rpath/}"
            [[ "$f" == "$N_PLUGINS"/* && -f "$FRAMEWORKS/$name" ]] && continue # TagLib
            [[ -f "$GST_DIR/lib/$name" ]] && continue
            if [[ ! -f "$GST_ROOT/lib/$name" ]]; then
                echo "error: $dep needed by $f not found in $GST_ROOT/lib" >&2
                exit 1
            fi
            cp "$GST_ROOT/lib/$name" "$GST_DIR/lib/$name"
            queue+=("$GST_DIR/lib/$name")
        done
    done

    echo "bundled $(ls "$GST_DIR/lib/gstreamer-1.0" | wc -l | tr -d ' ') GStreamer plugins," \
         "$(ls "$GST_DIR/lib" | grep -c '\.dylib$') libraries"
fi

# 8. Drop absolute rpaths to the build machine (/opt/homebrew/..., the
#    GStreamer.framework); only relative ones stay.
macho_files | while read -r f; do
    otool -l "$f" | awk '/LC_RPATH/ { getline; getline; print $2 }' | grep '^/' |
        while read -r rpath; do
            install_name_tool -delete_rpath "$rpath" "$f" 2>/dev/null
        done
done

# 9. Ad-hoc sign every Mach-O (required on Apple Silicon). The bundle itself
#    is not sealed: Nulloy ships skins and translations in
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

# 10. Verify: only system libraries and libraries inside the bundle, no
#    absolute rpaths to the build machine.
bad=0
while read -r f; do
    if deps_of "$f" | grep -v -e '^@rpath/' -e '^@executable_path/' -e '^@loader_path/' |
            grep -v -e '^/usr/lib/' -e '^/System/' | sed "s|^|$f: |" | grep .; then
        bad=1
    fi
    if otool -l "$f" | awk '/LC_RPATH/ { getline; getline; print $2 }' | grep '^/' |
            sed "s|^|$f: rpath |" | grep .; then
        bad=1
    fi
done < <(macho_files)
if [[ $bad == 1 ]]; then
    echo "error: references outside the bundle remain" >&2
    exit 1
fi
echo "Deployed into $APP"
