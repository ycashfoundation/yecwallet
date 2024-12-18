#-------------------------------------------------
#
# Project created by QtCreator 2018-10-05T09:54:45
#
#-------------------------------------------------

QT       += core gui network

CONFIG += precompile_header

PRECOMPILED_HEADER = src/precompiled.h

QT += widgets

TARGET = yecwallet

TEMPLATE = app

# The following define makes your compiler emit warnings if you use
# any feature of Qt which has been marked as deprecated (the exact warnings
# depend on your compiler). Please consult the documentation of the
# deprecated API in order to know how to port your code away from it.
DEFINES += \
    QT_DEPRECATED_WARNINGS

INCLUDEPATH  += src/3rdparty/
INCLUDEPATH  += src/

RESOURCES     = application.qrc

MOC_DIR = bin
OBJECTS_DIR = bin
UI_DIR = src

CONFIG += c++14

SOURCES += \
    src/main.cpp \
    src/mainwindow.cpp \
    src/balancestablemodel.cpp \
    src/3rdparty/qrcode/BitBuffer.cpp \
    src/3rdparty/qrcode/QrCode.cpp \
    src/3rdparty/qrcode/QrSegment.cpp \
    src/settings.cpp \
    src/sendtab.cpp \
    src/senttxstore.cpp \
    src/txtablemodel.cpp \
    src/turnstile.cpp \
    src/qrcodelabel.cpp \
    src/connection.cpp \
    src/fillediconlabel.cpp \
    src/addressbook.cpp \
    src/logger.cpp \
    src/addresscombo.cpp \
    src/validateaddress.cpp \
    src/requestdialog.cpp \
    src/memoedit.cpp \
    src/viewalladdresses.cpp \
    src/rescanprogress.cpp \
    src/datamodel.cpp \
    src/controller.cpp \
    src/zcashdrpc.cpp

HEADERS += \
    src/mainwindow.h \
    src/precompiled.h \
    src/balancestablemodel.h \
    src/3rdparty/qrcode/BitBuffer.hpp \
    src/3rdparty/qrcode/QrCode.hpp \
    src/3rdparty/qrcode/QrSegment.hpp \
    src/3rdparty/json/json.hpp \
    src/settings.h \
    src/txtablemodel.h \
    src/senttxstore.h \
    src/turnstile.h \
    src/qrcodelabel.h \
    src/connection.h \
    src/fillediconlabel.h \
    src/addressbook.h \
    src/logger.h \
    src/addresscombo.h \
    src/validateaddress.h \
    src/requestdialog.h \
    src/memoedit.h \
    src/viewalladdresses.h \
    src/rescanprogress.h \
    src/datamodel.h \
    src/controller.h \
    src/zcashdrpc.h 

FORMS += \
    src/mainwindow.ui \
    src/nullifiermigration.ui \
    src/rescandialog.ui \
    src/migration.ui \
    src/settings.ui \
    src/about.ui \
    src/confirm.ui \
    src/turnstile.ui \
    src/turnstileprogress.ui \
    src/privkey.ui \
    src/memodialog.ui \ 
    src/validateaddress.ui \
    src/viewalladdresses.ui \
    src/connection.ui \
    src/zboard.ui \
    src/addressbook.ui \
    src/createzcashconfdialog.ui \
    src/requestdialog.ui


TRANSLATIONS = res/zec_qt_wallet_es.ts \
               res/zec_qt_wallet_fr.ts \
               res/zec_qt_wallet_de.ts \
               res/zec_qt_wallet_pt.ts \
               res/zec_qt_wallet_it.ts \
               res/zec_qt_wallet_tr.ts \
               res/zec_qt_wallet_zh.ts \
               res/zec_qt_wallet_tr.ts 

include(singleapplication/singleapplication.pri)
DEFINES += QAPPLICATION_CLASS=QApplication

QMAKE_INFO_PLIST = res/Info.plist

unix: QMAKE_LFLAGS += -no-pie
CONFIG(release): QMAKE_LFLAGS += -s

win32: RC_ICONS = res/icon.ico
ICON = res/logo.icns

QMAKE_CLEAN += res/libsodium.a yecwallet

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

INCLUDEPATH += $$PWD/res
DEPENDPATH += $$PWD/res

DISTFILES +=
