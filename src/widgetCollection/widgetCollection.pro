TEMPLATE = lib
TARGET = widget_collection
DESTDIR = $$PWD

CONFIG += static

include(widgetCollection.pri)

greaterThan(QT_MAJOR_VERSION, 5) {
    # skin forms are loaded via a QUiLoader subclass, no Designer plugin needed
    QT += gui widgets svgwidgets
    HEADERS -= widgetCollection.h
    SOURCES -= widgetCollection.cpp
} else {
    QT += designer gui
    CONFIG += plugin
}
INCLUDEPATH += $$SRC_DIR/platform/
