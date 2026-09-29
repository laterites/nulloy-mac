# Building Nulloy on macOS (Apple Silicon, Qt 6)

**English** | [Русский](BUILD-macOS.ru.md)

A native arm64 build with Qt 6. The build system is qmake (`./configure` +
`make`). `./macdeploy.sh` bundles Qt, TagLib and GStreamer into
`Nulloy Mac.app`, so the finished app runs on a Mac without Homebrew.

## Build requirements

System: Xcode or the Command Line Tools, `zip`, `iconutil`.

Homebrew packages: exactly these four, and only for building. Users of the
finished app do not need Homebrew at all.

| Package       | Purpose                                                          |
|---------------|------------------------------------------------------------------|
| `qt`          | Qt 6: qmake, moc, lrelease, macdeployqt, frameworks              |
| `taglib`      | reading and writing tags (TagLib plugin), copied into the bundle |
| `pkgconf`     | `pkg-config`, used by `./configure` to find GStreamer and TagLib |
| `imagemagick` | `convert`: app icons from SVG                                    |

```sh
brew install qt taglib pkgconf imagemagick
```

`brew install` marks all four packages as installed on request, so
`brew autoremove` will not remove them even if they were previously
installed as dependencies of other packages.

**Not needed** for building: Homebrew's `gstreamer` (GStreamer.framework is
used instead, see below) and `qt@5`.

### GStreamer.framework

GStreamer comes from the official framework, not from Homebrew:
https://gstreamer.freedesktop.org/download/ → macOS, the runtime and
development packages (universal). Tested with version 1.28.7.

Both packages install into `/Library/Frameworks/GStreamer.framework`. The
full development package takes 4.7 GB; Nulloy only needs its
"GStreamer 1.0 core" component (≈ 2.3 GB, headers and `.pc` files). The
runtime takes 682 MB.

```sh
sudo installer -pkg gstreamer-1.0-1.28.7-universal.pkg -target /

# development: the core component only
installer -showChoicesXML -pkg gstreamer-1.0-devel-1.28.7-universal.pkg \
          -target / > choices.plist
# in choices.plist, deselect (attributeSetting = 0) every *-devel choice
# except gstreamer-1.0-core-devel, then:
sudo installer -pkg gstreamer-1.0-devel-1.28.7-universal.pkg \
     -applyChoiceChangesXML choices.plist -target /
```

`./configure` finds the framework automatically. A different location can be
set with `GSTREAMER_FRAMEWORK=/path/to/GStreamer.framework/Versions/1.0 ./configure`.
Without the framework, the build uses whatever GStreamer `pkg-config` finds
(for example Homebrew's). Such a build works, but `./macdeploy.sh` cannot
bundle it.

## Building

```sh
./configure
make -j8
./macdeploy.sh    # bundle Qt, TagLib and GStreamer into Nulloy Mac.app
open "Nulloy Mac.app"
```

Release archive:

```sh
ditto -c -k --keepParent "Nulloy Mac.app" Nulloy-Mac-<version>-arm64.zip
```

`./configure` takes `qmake` from `PATH`. A different Qt can be set explicitly:
`QMAKE=/opt/homebrew/opt/qt/bin/qmake ./configure`.

If Makefiles from a previous build (another Qt version, another GStreamer)
are still in the tree, remove them first:

```sh
rm -rf tmp "Nulloy Mac.app" .qmake.stash Makefile src/Makefile \
       src/widgetCollection/Makefile src/plugins/*/Makefile
```

Run `./macdeploy.sh` again after every `make`.

## What macdeploy.sh does

- **Qt:** `macdeployqt` copies Qt 6 and its dependencies into
  `Contents/Frameworks`. Unused Qt plugins (qpdf, virtual keyboard) are
  removed.
- **TagLib:** `libtag` is copied into `Contents/Frameworks`; the plugin links
  it via `@rpath`.
- **GStreamer:** the plugins listed in `GST_PLUGINS` at the top of the script,
  `gst-plugin-scanner` and every library they need are copied into
  `Contents/Frameworks/GStreamer`, keeping the framework layout (`lib/`,
  `lib/gstreamer-1.0/`, `libexec/gstreamer-1.0/`). A separate directory is
  needed because GStreamer ships its own GLib with the same file names as
  Qt's dependencies. The current list:
  - core: `coreelements`, `typefindfunctions`, `playback`, `autodetect`;
  - audio output: `osxaudio`;
  - `audioconvert`, `audioresample`, `volume`;
  - parsers and tags: `audioparsers`, `id3demux`, `apetag`;
  - formats: `wavparse`, `aiff`, `flac`, `mpg123`, `ogg`, `vorbis`, `opus`,
    `opusparse`, `isomp4`, `wavpack`, `asf` (WMA);
  - `libav` (FFmpeg): ALAC and AAC in M4A, the WMA decoders, and the
    demuxers and decoders for APE, TTA and Musepack.

  FFmpeg in the framework is built as LGPL-2.1-or-later (no GPL, version3 or
  nonfree parts), as reported by `avcodec_license()` and
  `avcodec_configuration()`.

  To add a format, add its plugin to `GST_PLUGINS`; the script finds the
  dependencies itself.
- **Architecture:** universal binaries are thinned to arm64.
- **Linking and signing:** absolute rpaths are removed, and every Mach-O file is
  ad-hoc signed.
- **Check:** at the end the script fails if any binary refers to a library
  outside the bundle other than `/usr/lib` and `/System`.

At startup, `main()` points GStreamer only to the plugins and
`gst-plugin-scanner` inside the bundle. The plugin registry is stored in
`~/Library/Application Support/Nulloy/gstreamer-1.0.registry.bin`.
GStreamer from Homebrew, `/Library/Frameworks` or `~/.local` is never used.

## Name and data

The bundle is called `Nulloy Mac.app` (bundle identifier
`io.github.laterites.nulloy-mac`, shown as "Nulloy Mac" in the Dock and menu
bar), so that macOS does not confuse it with the original Nulloy. The
executable inside is still `Contents/MacOS/nulloy`. The bundle name is set in
`configure` (`MAC_BUNDLE_NAME`), the other keys in
`src/platform/Info.plist.in`. qmake does not regenerate `Contents/Info.plist`
after the template changes: delete that file from the bundle before running
`make`.

User data (settings, playlist, waveform cache, your own skins and
translations) is stored in `~/Library/Application Support/Nulloy`. The bundle
is not modified while the app is running.

## When development is finished

After `./macdeploy.sh`, `Nulloy Mac.app` depends neither on Homebrew nor on
`/Library/Frameworks/GStreamer.framework`: everything it needs is inside the
bundle.

### Homebrew's gstreamer

It is no longer needed, neither for building nor for running. `taglib` and
`pkgconf` are still needed for building, and if they were once installed as
dependencies of `gstreamer`, `brew autoremove` would remove them together
with it. So mark them as installed on request first:

```sh
brew install taglib pkgconf   # mark as wanted; already installed packages are not reinstalled
brew uninstall gstreamer
brew autoremove --dry-run     # see what would be removed
brew autoremove
```

### Build tools

If you no longer need to rebuild Nulloy, remove the build packages:

```sh
brew uninstall imagemagick qt taglib pkgconf
brew autoremove --dry-run
brew autoremove
```

Leave out anything other software still uses. You can check with
`brew uses --installed <package>`.

### GStreamer.framework

The installer puts the framework into `/Library/Frameworks` and leaves package
receipts (`org.freedesktop.gstreamer.*`). To remove it:

```sh
sudo rm -rf /Library/Frameworks/GStreamer.framework
pkgutil --pkgs | grep '^org\.freedesktop\.gstreamer' | xargs -n1 sudo pkgutil --forget
```

After that, rebuilding Nulloy requires installing the framework again.
