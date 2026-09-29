TARGET = plugin_gstreamer
unix:TARGET = plugin_gstreamer
win32:TARGET = PluginGStreamer

include($$SRC_DIR/plugins/plugin.pri)

CONFIG += link_pkgconfig
PKGCONFIG += gstreamer-1.0 gstreamer-pbutils-1.0

HEADERS += $$files(*.h)
SOURCES += $$files(*.cpp)

gstreamer-tagreader {
    DEFINES += _N_GSTREAMER_TAGREADER_PLUGIN_
} else {
    HEADERS -= tagReaderGstreamer.h
    SOURCES -= tagReaderGstreamer.cpp
}


# GStreamer bundled by macdeploy.sh. Must be the only bundle rpath: Frameworks/
# holds another libglib (Qt's dependency) that GStreamer must not pick up.
mac:QMAKE_LFLAGS += -Wl,-rpath,@loader_path/../../Frameworks/GStreamer/lib
