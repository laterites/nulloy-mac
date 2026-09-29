# Сборка Nulloy на macOS (Apple Silicon, Qt 6)

Нативная arm64-сборка с Qt 6. Система сборки — qmake (`./configure` +
`make`). `./macdeploy.sh` упаковывает внутрь `Nulloy Mac.app` Qt, TagLib и
GStreamer, так что готовое приложение работает на Mac без Homebrew.

## Что нужно для сборки

Системное: Xcode или Command Line Tools, `zip`, `iconutil`.

Пакеты Homebrew (только для сборки, пользователю приложения не нужны):

| Пакет         | Зачем                                                        |
|---------------|--------------------------------------------------------------|
| `qt`          | Qt 6: qmake, moc, lrelease, macdeployqt, фреймворки          |
| `taglib`      | чтение и запись тегов (плагин TagLib), копируется в бандл    |
| `pkgconf`     | `pkg-config` для поиска GStreamer и TagLib в `./configure`   |
| `imagemagick` | `convert`: иконки приложения из SVG                          |

```sh
brew install qt taglib pkgconf imagemagick
```

Qt 5 (`qt@5`) и `gstreamer` из Homebrew для сборки не нужны.

### GStreamer.framework

GStreamer берётся из официального фреймворка, не из Homebrew:
https://gstreamer.freedesktop.org/download/ → macOS, пакеты runtime и
development (universal). Проверено с версией 1.28.7.

Оба пакета ставятся в `/Library/Frameworks/GStreamer.framework`. Полный
development-пакет занимает 4,7 ГБ, для Nulloy хватает его компонента
«GStreamer 1.0 core» (≈ 2,3 ГБ, заголовки и `.pc`). Runtime занимает
682 МБ.

```sh
sudo installer -pkg gstreamer-1.0-1.28.7-universal.pkg -target /

# development: только компонент core
installer -showChoicesXML -pkg gstreamer-1.0-devel-1.28.7-universal.pkg \
          -target / > choices.plist
# в choices.plist снять выбор (attributeSetting = 0) со всех *-devel,
# кроме gstreamer-1.0-core-devel, затем:
sudo installer -pkg gstreamer-1.0-devel-1.28.7-universal.pkg \
     -applyChoiceChangesXML choices.plist -target /
```

`./configure` сам находит фреймворк. Другой путь можно указать через
`GSTREAMER_FRAMEWORK=/path/to/GStreamer.framework/Versions/1.0 ./configure`.
Если фреймворка нет, используется GStreamer, который найдёт `pkg-config`
(например, из Homebrew). Такая сборка работает, но `./macdeploy.sh` упаковать
её не сможет.

## Сборка

```sh
./configure
make -j8
./macdeploy.sh    # упаковать Qt, TagLib и GStreamer внутрь Nulloy Mac.app
open "Nulloy Mac.app"
```

Релизный архив:

```sh
ditto -c -k --keepParent "Nulloy Mac.app" Nulloy-Mac-<версия>-arm64.zip
```

`./configure` берёт `qmake` из `PATH`. Другой Qt можно указать явно:
`QMAKE=/opt/homebrew/opt/qt/bin/qmake ./configure`.

Если в дереве остались Makefile'ы от прошлой сборки (другая версия Qt,
другой GStreamer), сначала удалите их:

```sh
rm -rf tmp "Nulloy Mac.app" .qmake.stash Makefile src/Makefile \
       src/widgetCollection/Makefile src/plugins/*/Makefile
```

После каждого `make` нужно снова запускать `./macdeploy.sh`.

## Что делает macdeploy.sh

- **Qt:** `macdeployqt` копирует Qt 6 и его зависимости в
  `Contents/Frameworks`. Лишние Qt-плагины (qpdf, виртуальная клавиатура)
  удаляются.
- **TagLib:** `libtag` копируется в `Contents/Frameworks`, плагин ссылается
  на него через `@rpath`.
- **GStreamer:** плагины из списка `GST_PLUGINS` в начале скрипта,
  `gst-plugin-scanner` и все нужные им библиотеки копируются в
  `Contents/Frameworks/GStreamer` в той же структуре, что во фреймворке
  (`lib/`, `lib/gstreamer-1.0/`, `libexec/gstreamer-1.0/`). Отдельный каталог
  нужен потому, что у GStreamer своя GLib с теми же именами файлов, что у
  зависимостей Qt. Сейчас в списке:
  - ядро: `coreelements`, `typefindfunctions`, `playback`, `autodetect`;
  - вывод звука: `osxaudio`;
  - `audioconvert`, `audioresample`, `volume`;
  - парсеры и теги: `audioparsers`, `id3demux`, `apetag`;
  - форматы: `wavparse`, `aiff`, `flac`, `mpg123`, `ogg`, `vorbis`, `opus`,
    `opusparse`, `isomp4`, `wavpack`, `asf` (WMA);
  - `libav` (FFmpeg): ALAC и AAC в M4A, декодеры WMA, а также демультиплексоры
    и декодеры APE, TTA и Musepack.

  FFmpeg во фреймворке собран под LGPL-2.1-or-later (без GPL, version3 и
  nonfree): это видно по `avcodec_license()` и `avcodec_configuration()`.

  Чтобы добавить формат, допишите плагин в `GST_PLUGINS`. Зависимости скрипт
  найдёт сам.
- **Архитектура:** universal-бинарники урезаются до arm64.
- **Ссылки и подпись:** абсолютные rpath удаляются, каждый Mach-O
  подписывается ad-hoc.
- **Проверка:** в конце скрипт падает, если какой-то бинарник ссылается на
  библиотеки вне бандла, кроме `/usr/lib` и `/System`.

При запуске `main()` направляет GStreamer только на плагины и
`gst-plugin-scanner` внутри бандла. Реестр плагинов хранится в
`~/Library/Application Support/Nulloy/gstreamer-1.0.registry.bin`.
GStreamer из Homebrew, `/Library/Frameworks` и `~/.local` не используется.

## Имя и данные

Бандл называется `Nulloy Mac.app` (bundle identifier
`io.github.laterites.nulloy-mac`, имя в Dock и меню — «Nulloy Mac»), чтобы
macOS не путала его с оригинальным Nulloy. Исполняемый файл внутри по-прежнему
`Contents/MacOS/nulloy`. Имя бандла задаётся в `configure`
(`MAC_BUNDLE_NAME`), остальные ключи — в `src/platform/Info.plist.in`.
qmake не пересоздаёт `Contents/Info.plist` после правки шаблона: удалите
этот файл из бандла перед `make`.

Пользовательские данные (настройки, плейлист, кэш waveform, свои skins и
переводы) хранятся в `~/Library/Application Support/Nulloy`. Бандл во время
работы не изменяется.

## Когда разработка закончена

`Nulloy Mac.app` после `./macdeploy.sh` ни от чего из этого не зависит.
Инструменты сборки можно удалить:

```sh
brew uninstall imagemagick
brew autoremove --dry-run   # посмотреть, что будет удалено
brew autoremove
```

`brew autoremove` удаляет только пакеты, которые были установлены как
зависимости и больше никому не нужны. Если Nulloy больше не нужно
пересобирать, так же можно удалить `qt`, `taglib` и `pkgconf`. Проверьте
через `brew uses --installed <пакет>`, что они не нужны другим программам.

GStreamer.framework удаляется вручную:

```sh
sudo rm -rf /Library/Frameworks/GStreamer.framework
pkgutil --pkgs | grep org.freedesktop.gstreamer | xargs -n1 sudo pkgutil --forget
```
