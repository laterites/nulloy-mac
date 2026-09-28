# Сборка Nulloy на macOS (Apple Silicon, Qt 6)

Нативная arm64-сборка с Qt 6 из Homebrew. Система сборки — qmake
(`./configure` + `make`), Qt упаковывается внутрь `nulloy.app`.

## Что нужно

Системное (не из Homebrew): Xcode или Command Line Tools, `zip`, `iconutil`.

Пакеты Homebrew:

| Пакет         | Зачем                                                        | Нужен для работы `nulloy.app`? |
|---------------|--------------------------------------------------------------|--------------------------------|
| `qt`          | Qt 6: qmake, moc, lrelease, macdeployqt, фреймворки          | нет, после `./macdeploy.sh` Qt лежит в бандле |
| `gstreamer`   | воспроизведение и построение waveform (плагин GStreamer)     | **да**, грузится из Homebrew   |
| `taglib`      | чтение и запись тегов (плагин TagLib)                        | **да**, грузится из Homebrew   |
| `pkgconf`     | `pkg-config` для поиска gstreamer и taglib в `./configure`   | нет                            |
| `imagemagick` | `convert`: иконки приложения из SVG при сборке               | нет                            |

```sh
brew install qt gstreamer taglib pkgconf imagemagick
```

Qt 5 (`qt@5`) для сборки не нужен.

## Сборка

```sh
./configure
make -j8
./macdeploy.sh    # упаковать Qt внутрь nulloy.app
open nulloy.app
```

`./configure` берёт `qmake` из `PATH`. Другой Qt можно указать явно:
`QMAKE=/opt/homebrew/opt/qt/bin/qmake ./configure`.

Если в дереве остались Makefile'ы от сборки с другой версией Qt, сначала
удалите их, иначе `make` соберёт проект старым Qt:

```sh
rm -rf tmp nulloy.app .qmake.stash Makefile src/Makefile \
       src/widgetCollection/Makefile src/plugins/*/Makefile
```

`./macdeploy.sh` копирует в бандл Qt и его зависимости. GStreamer и TagLib
в бандл намеренно не попадают: GStreamer загружает свои плагины из
Homebrew, и вторая копия libgstreamer внутри бандла конфликтовала бы с ними.
После каждого `make` скрипт нужно запускать заново.

Пользовательские данные (настройки, плейлист, кэш waveform, свои skins и
переводы) хранятся в `~/Library/Application Support/Nulloy`, бандл во время
работы не изменяется.

## Когда разработка закончена

Пакеты, нужные только для сборки, можно удалить. `nulloy.app` продолжит
работать, если он упакован через `./macdeploy.sh`.

```sh
brew uninstall imagemagick
brew autoremove --dry-run   # посмотреть, что будет удалено
brew autoremove
```

`brew autoremove` удаляет только пакеты, которые были установлены как
зависимости и больше никому не нужны. `pkgconf` и `taglib` — зависимости
`gstreamer`, поэтому они останутся. Чтобы `taglib` не пропал, если
когда-нибудь удалить `gstreamer`, пометьте его как установленный явно:
`brew install taglib`.

`qt` тоже нужен только для сборки. Удалять его стоит, только если вы не
собираетесь пересобирать Nulloy: `brew uninstall qt && brew autoremove`.

Не удаляйте `gstreamer` и `taglib`: без них не будет звука и тегов.
