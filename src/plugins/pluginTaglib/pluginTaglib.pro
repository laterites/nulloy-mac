unix:TARGET = plugin_taglib
win32:TARGET = PluginTagLib

!mac:QMAKE_CXXFLAGS += -std=c++0x

include(../plugin.pri)

CONFIG += link_pkgconfig
PKGCONFIG += taglib

HEADERS += $$files(*.h)
SOURCES += $$files(*.cpp)


# TagLib bundled into Frameworks/ by macdeploy.sh
mac:QMAKE_LFLAGS += -Wl,-rpath,@loader_path/../../Frameworks
