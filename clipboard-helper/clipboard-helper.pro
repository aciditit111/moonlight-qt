QT += core gui network
CONFIG += c++17
CONFIG -= app_bundle

TARGET = moonlight-clipboard-helper
# PrimSec: Windows helper carries our product name (keep in sync with
# ClipboardHelperClient::findHelperExecutable and scripts/build-arch.bat).
win32 {
    TARGET = primsec-clipboard-helper
    QMAKE_TARGET_COMPANY = PrimSec
    QMAKE_TARGET_DESCRIPTION = PrimSec Clipboard Helper
    QMAKE_TARGET_PRODUCT = PrimSec
}
TEMPLATE = app

include(../globaldefs.pri)

INCLUDEPATH += $$PWD/../app

SOURCES += \
    main.cpp \
    ../app/streaming/clipboardipc.cpp \
    ../app/streaming/clipboardsync.cpp

macx:SOURCES += macos.mm

HEADERS += \
    ../app/streaming/clipboardipc.h \
    ../app/streaming/clipboardlogging.h \
    ../app/streaming/clipboardsync.h

unix:!macx {
    isEmpty(PREFIX) {
        PREFIX = /usr/local
    }
    isEmpty(BINDIR) {
        BINDIR = bin
    }

    target.path = $$PREFIX/$$BINDIR/
    INSTALLS += target
}
