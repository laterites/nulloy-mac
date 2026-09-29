# Nulloy Mac

This is a fork of [Nulloy](https://github.com/nulloy/nulloy), the music player
with a waveform seekbar by Sergey Vlasov, maintained for macOS on Apple Silicon.

## What is different from upstream

* Ported to **Qt 6**: QtScript was replaced with QJSEngine, and the skin loader
  now uses public Qt APIs. All bundled skins (Slim, Silver, Metro, Native)
  work, including waveform colours set via `qproperty` in skin CSS. Based on
  the Qt 6 work in [Auda29/nulloy](https://github.com/Auda29/nulloy).
* **Native arm64 build**: no Rosetta needed.
* **Self-contained app**: Qt, GStreamer (from the official GStreamer.framework)
  and TagLib are bundled inside `Nulloy Mac.app`, so no Homebrew is needed.
  Plays FLAC, WAV, MP3, Ogg Vorbis, Opus, AIFF, M4A (ALAC and AAC), APE,
  WavPack, WMA, TTA and Musepack.
* **User data lives in `~/Library/Application Support/Nulloy`**: settings,
  playlist, waveform cache, and your own skins and translations. The app bundle
  is no longer modified at runtime. Data from older versions that kept it
  inside the bundle is copied over on first launch.
* Own bundle identifier (`io.github.laterites.nulloy-mac`) and the name
  "Nulloy Mac", so macOS does not confuse it with the original Nulloy.
* Unicode tag fixes in the TagLib plugin.

## Requirements

* A Mac with Apple Silicon (M1 or later), macOS 14 or newer. Nothing else to
  install.

## Installation

Download the zip from [Releases](https://github.com/laterites/nulloy-mac/releases),
unpack it and move `Nulloy Mac.app` to `/Applications`.

The app is not signed with an Apple Developer ID, so macOS quarantines it after
download and refuses to open it. Before the first launch, remove the quarantine
attribute:

```sh
xattr -dr com.apple.quarantine "/Applications/Nulloy Mac.app"
```

Or try to open the app, then go to System Settings → Privacy & Security and
click Open Anyway.

## Building

Full instructions: [BUILD-macOS.md](BUILD-macOS.md) (in Russian). In short:

* Homebrew packages needed to build: `qt`, `taglib`, `pkgconf`, `imagemagick`.
  Homebrew's `gstreamer` and `qt@5` are not used.
* GStreamer comes from the official
  [GStreamer.framework](https://gstreamer.freedesktop.org/download/) (runtime
  and development packages, installed into `/Library/Frameworks`).
* `./configure && make -j8 && ./macdeploy.sh` builds `Nulloy Mac.app` and copies
  Qt, TagLib and GStreamer into it. The list of bundled GStreamer plugins is
  at the top of `macdeploy.sh`.

When you are done developing, the build tools can be removed:
`brew uninstall imagemagick qt taglib pkgconf && brew autoremove`, and the
framework with
`sudo rm -rf /Library/Frameworks/GStreamer.framework` followed by
`pkgutil --pkgs | grep '^org\.freedesktop\.gstreamer' | xargs -n1 sudo pkgutil --forget`.

## License

GPL-3.0, same as upstream Nulloy. See [LICENSE.GPL3](LICENSE.GPL3).

The app bundle also contains unmodified third-party libraries under their own
licenses: Qt 6 (LGPL-3.0), GStreamer 1.28 and its plugins (LGPL-2.1+),
FFmpeg 7.1 via gst-libav (built as LGPL-2.1-or-later: no GPL, version3 or
nonfree components), and TagLib (LGPL-2.1 / MPL-1.1). Their sources are
available from the respective projects.

The upstream README follows below. Its Windows and Linux instructions are
kept as they are (Qt 5) and are not tested in this fork; for macOS use
[BUILD-macOS.md](BUILD-macOS.md).

---

# Nulloy Music Player

![Screenshot](http://nulloy.com/files/screen.png)

More screenshots: https://nulloy.com/screenshots/

## Build Instructions

<details>
<summary>Windows</summary>

### Prerequisites

* Qt 5 offline installer https://www.qt.io/offline-installers/
* GStreamer 1.0 MinGW 32-bit (runtime and development installers) http://gstreamer.freedesktop.org/download/
* pkg-config and its dependencies (glib and gettext-runtime) https://download.gnome.org/binaries/win32/dependencies/, https://download.gnome.org/binaries/win32/glib/
* CMake http://www.cmake.org/
* TagLib source code https://github.com/taglib/taglib/
* ImageMagick https://imagemagick.org/script/download.php#windows
* 7zip http://www.7-zip.org/

Disconnect from the Internet to skip creating Qt account. Run Qt 5 offline installer and select only the following components:
```
+ Qt
  + Qt 5
    - Qt Prebuilt Components for MinGW 32-bit
    - Qt Script
  + Developer and Designer Tools
    - MinGW 32-bit toolchain
```

Extract pkg-config and its dependencies into `C:\Downloads\pkg-config`.

Install GStreamer runtime and development packages. Open command prompt and execute:
```bat
del C:\gstreamer\1.0\mingw_x86\lib\libstdc++.a
```

Extract and / or install the rest of the prerequisites.

### Build TagLib

Run Qt MinGW terminal and execute:

```bat
C:\Downloads\taglib
cmake.exe -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DZLIB_INCLUDE_DIR=C:\gstreamer\1.0\mingw_x86\include -DCMAKE_INSTALL_PREFIX="."
mingw32-make
mingw32-make install
```

### Build & Run Nulloy

In the same terminal execute:

```bat
set PATH=C:\Program Files\7-Zip;%PATH%
set PATH=C:\gstreamer\1.0\mingw_x86\bin;%PATH%
set PATH=C:\Downloads\pkg-config\bin;%PATH%
set PKG_CONFIG_PATH=C:\gstreamer\1.0\mingw_x86\lib\pkgconfig;%PKG_CONFIG_PATH%
set PKG_CONFIG_PATH=C:\Downloads\taglib\lib\pkgconfig;%PKG_CONFIG_PATH%
set GST_PLUGIN_PATH=C:\gstreamer\1.0\mingw_x86\lib

cd C:\Downloads\nulloy
configure.bat
mingw32-make
copy /B /Y C:\gstreamer\1.0\mingw_x86\bin\*.dll .
del libstdc++-6.dll
copy /B /Y C:\Downloads\taglib\bin\libtag.dll .
windeployqt Nulloy.exe
Nulloy.exe
```
</details>

<details>
<summary>macOS</summary>

This fork builds on macOS with Qt 6 and the official GStreamer.framework; the
original Qt 5 / MacPorts / Homebrew GStreamer instructions no longer apply.
See [BUILD-macOS.md](BUILD-macOS.md) and the "Building" section at the top of
this file.
</details>

<details>
<summary>Linux</summary>

### Dependences

#### DEB-based distro

```sh
apt install g++ qttools5-dev qtscript5-dev qtbase5-private-dev libqt5x11extras5-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev zip libx11-dev libx11-xcb-dev libtag1-dev imagemagick librsvg2-bin libqt5svg5-dev
# install extra GStreamer plugins for more audio formats
apt install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
```

#### RPM-based distro

```sh
yum install gcc-c++ qt5-qtbase-devel qt5-qttools-devel qt5-qttools-static qt5-qtscript-devel qt5-qtbase-private-devel qt5-linguist gstreamer1-plugins-base-devel gstreamer1-devel zip libX11-devel libxcb-devel taglib-devel ImageMagick librsvg2 qt5-qtsvg-devel
# install extra GStreamer plugins for more audio formats
yum install gstreamer1-plugins-good gstreamer1-plugins-bad gstreamer1-plugins-ugly
```

### Build & Run Nulloy

```sh
cd nulloy.git
./configure
make
./nulloy
```
</details>

## License
[GPL3](/LICENSE.GPL3)
