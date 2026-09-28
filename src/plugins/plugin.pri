TEMPLATE = lib
CONFIG += plugin
greaterThan(QT_MAJOR_VERSION, 5) {
    QT += core5compat
    # Q_ENUM_NS in global.h needs the N namespace meta-object inside each plugin
    HEADERS += $$SRC_DIR/global.h
}

INCLUDEPATH += $$SRC_DIR $$SRC_DIR/interfaces $$SRC_DIR/plugins

HEADERS += common.h
SOURCES += $$SRC_DIR/common.cpp $$SRC_DIR/plugins/abstractWaveformBuilder.cpp $$SRC_DIR/waveformPeaks.cpp

win32:DESTDIR = $$PROJECT_DIR/Plugins

unix:!mac {
    DESTDIR = $$PROJECT_DIR/plugins
    target.path = $$PREFIX/$$LIBDIR/$$APP_NAME/plugins
    INSTALLS += target
}

mac {
    xcode_override.name = "CONFIGURATION_BUILD_DIR"
    xcode_override.value = $$TMP_DIR/$$join(MAC_BUNDLE_NAME, " ").app/Contents/MacOS/plugins
    QMAKE_MAC_XCODE_SETTINGS += xcode_override
    DESTDIR = $$PROJECT_DIR/$$join(MAC_BUNDLE_NAME, " ").app/Contents/MacOS/plugins
}
