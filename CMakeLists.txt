cmake_minimum_required(VERSION 3.21)

# ── Version (single source of truth: src/version.h) ──────────────────────────
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/src/version.h" _ver_line
    REGEX "#define APP_VERSION")
string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${_ver_line}")
set(VERSION_MAJOR ${CMAKE_MATCH_1})
set(VERSION_MINOR ${CMAKE_MATCH_2})
set(VERSION_PATCH ${CMAKE_MATCH_3})

project(yecwallet VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}" LANGUAGES CXX)

# ── C++ standard ─────────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── Output directories ────────────────────────────────────────────────────────
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# ── OpenSSL (Linux static build) ─────────────────────────────────────────────
# Force CMake's FindOpenSSL to resolve to static .a files before Qt's
# WrapOpenSSL picks up the shared .so via find_package(Qt6 ...).
# Only needed on Linux; macOS uses SecureTransport, Windows uses SChannel.
if(UNIX AND NOT APPLE)
    set(OPENSSL_USE_STATIC_LIBS TRUE)
    find_package(OpenSSL REQUIRED)
endif()

# ── Qt ────────────────────────────────────────────────────────────────────────
# Point CMAKE_PREFIX_PATH to your static Qt install, e.g.:
#   cmake -DCMAKE_PREFIX_PATH=/opt/qt-static/6.8 ...
# or set QT_STATIC_ROOT env variable (build.sh does this automatically).
if(DEFINED ENV{QT_STATIC_ROOT} AND NOT CMAKE_PREFIX_PATH)
    set(CMAKE_PREFIX_PATH "$ENV{QT_STATIC_ROOT}")
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOUIC_SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/src")

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Network
    WebSockets
)

find_package(Qt6 OPTIONAL_COMPONENTS LinguistTools)

# Verify static Qt when requested
if(QT_STATIC)
    get_target_property(_qt_type Qt6::Core TYPE)
    if(NOT _qt_type STREQUAL "STATIC_LIBRARY")
        message(FATAL_ERROR
            "QT_STATIC=ON but found shared Qt at ${CMAKE_PREFIX_PATH}.\n"
            "Point CMAKE_PREFIX_PATH to a static Qt build.")
    endif()
endif()


# ── Sources ───────────────────────────────────────────────────────────────────
set(APP_SOURCES
    src/main.cpp
    src/mainwindow.cpp
    src/balancestablemodel.cpp
    src/settings.cpp
    src/sendtab.cpp
    src/senttxstore.cpp
    src/txtablemodel.cpp
    src/turnstile.cpp
    src/qrcodelabel.cpp
    src/connection.cpp
    src/fillediconlabel.cpp
    src/addressbook.cpp
    src/logger.cpp
    src/addresscombo.cpp
    src/validateaddress.cpp
    src/requestdialog.cpp
    src/memoedit.cpp
    src/viewalladdresses.cpp
    src/rescanprogress.cpp
    src/datamodel.cpp
    src/controller.cpp
    src/zcashdrpc.cpp
    # bundled 3rd-party (QR code)
    src/3rdparty/qrcode/BitBuffer.cpp
    src/3rdparty/qrcode/QrCode.cpp
    src/3rdparty/qrcode/QrSegment.cpp
    # SingleApplication
    singleapplication/singleapplication.cpp
    singleapplication/singleapplication_p.cpp
)

set(APP_HEADERS
    src/mainwindow.h
    src/precompiled.h
    src/balancestablemodel.h
    src/settings.h
    src/txtablemodel.h
    src/senttxstore.h
    src/turnstile.h
    src/qrcodelabel.h
    src/connection.h
    src/fillediconlabel.h
    src/addressbook.h
    src/logger.h
    src/addresscombo.h
    src/validateaddress.h
    src/requestdialog.h
    src/memoedit.h
    src/viewalladdresses.h
    src/rescanprogress.h
    src/datamodel.h
    src/controller.h
    src/zcashdrpc.h
    src/3rdparty/qrcode/BitBuffer.hpp
    src/3rdparty/qrcode/QrCode.hpp
    src/3rdparty/qrcode/QrSegment.hpp
    src/3rdparty/json/json.hpp
)

set(APP_FORMS
    src/mainwindow.ui
    src/nullifiermigration.ui
    src/rescandialog.ui
    src/migration.ui
    src/settings.ui
    src/about.ui
    src/confirm.ui
    src/turnstile.ui
    src/turnstileprogress.ui
    src/privkey.ui
    src/memodialog.ui
    src/validateaddress.ui
    src/viewalladdresses.ui
    src/connection.ui
    src/zboard.ui
    src/addressbook.ui
    src/createzcashconfdialog.ui
    src/requestdialog.ui
)

# ── Platform-specific extras ──────────────────────────────────────────────────
if(WIN32)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/src/scripts/zec-qt-wallet.rc.in"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/scripts/zec-qt-wallet.rc"
        @ONLY
    )
    set(APP_PLATFORM_EXTRAS src/scripts/zec-qt-wallet.rc)
elseif(APPLE)
    set(APP_PLATFORM_EXTRAS res/logo.icns)
    set_source_files_properties(res/logo.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources)
endif()

# ── Executable ───────────────────────────────────────────────────────────────
qt_add_executable(yecwallet
    ${APP_SOURCES}
    ${APP_HEADERS}
    ${APP_FORMS}
    ${APP_PLATFORM_EXTRAS}
    application.qrc
)

# ── Include paths ─────────────────────────────────────────────────────────────
target_include_directories(yecwallet PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/3rdparty"
    "${CMAKE_CURRENT_SOURCE_DIR}/singleapplication"

)

# ── Compile definitions ───────────────────────────────────────────────────────
target_compile_definitions(yecwallet PRIVATE
    QT_DEPRECATED_WARNINGS
    QAPPLICATION_CLASS=QApplication

)

# ── Precompiled header ────────────────────────────────────────────────────────
target_precompile_headers(yecwallet PRIVATE src/precompiled.h)

# ── Link libraries ────────────────────────────────────────────────────────────
target_link_libraries(yecwallet PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::WebSockets

)

# Platform-specific system libs required for static linking
if(WIN32)
    target_link_libraries(yecwallet PRIVATE
        advapi32 ws2_32 secur32 crypt32 iphlpapi userenv version winmm
    )
elseif(APPLE)
    find_library(CORE_FOUNDATION CoreFoundation REQUIRED)
    find_library(SECURITY_FRAMEWORK Security REQUIRED)
    find_library(APPKIT AppKit REQUIRED)
    find_library(SYSTEM_CONFIGURATION SystemConfiguration REQUIRED)
    target_link_libraries(yecwallet PRIVATE
        "${CORE_FOUNDATION}"
        "${SECURITY_FRAMEWORK}"
        "${APPKIT}"
        "${SYSTEM_CONFIGURATION}"
    )
elseif(UNIX)
    target_link_options(yecwallet PRIVATE -no-pie)
    target_link_libraries(yecwallet PRIVATE pthread dl)
endif()

# ── Static Qt platform plugin ─────────────────────────────────────────────────
# With a static Qt build the platform plugins are not loaded from disk at
# runtime; they must be linked into the binary and imported explicitly.
if(QT_STATIC)
    if(WIN32)
        target_link_libraries(yecwallet PRIVATE Qt6::QWindowsIntegrationPlugin)
        target_sources(yecwallet PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/import_plugins_windows.cpp)
    elseif(APPLE)
        target_link_libraries(yecwallet PRIVATE Qt6::QCocoaIntegrationPlugin)
        target_sources(yecwallet PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/import_plugins_macos.cpp)
    elseif(UNIX)
        if(TARGET Qt6::QXcbIntegrationPlugin)
            target_link_libraries(yecwallet PRIVATE
                Qt6::QXcbIntegrationPlugin
                Qt6::QTlsBackendOpenSSLPlugin
                Qt6::QTlsBackendOpenSSLPlugin_init
            )
            target_sources(yecwallet PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/import_plugins_linux.cpp)
        else()
            message(WARNING "QXcbIntegrationPlugin not found — falling back to offscreen plugin only.")
            target_sources(yecwallet PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cmake/import_plugins_linux_offscreen.cpp)
        endif()
    endif()
endif()

# OpenSSL must come after all Qt static plugins so the linker sees the TLS
# plugin's references to SSL symbols. --start-group/--end-group lets the linker
# make multiple passes over the group to resolve circular references between
# libqopensslbackend.a and libssl.a/libcrypto.a.
if(UNIX AND NOT APPLE)
    target_link_libraries(yecwallet PRIVATE
        -Wl,--start-group
        "${OPENSSL_SSL_LIBRARY}"
        "${OPENSSL_CRYPTO_LIBRARY}"
        -Wl,--end-group
    )
endif()

# Strip release binaries (matches original CONFIG(release) QMAKE_LFLAGS += -s)
if(CMAKE_BUILD_TYPE STREQUAL "Release" AND UNIX AND NOT APPLE)
    target_link_options(yecwallet PRIVATE -s)
endif()

# ── macOS bundle settings ────────────────────────────────────────────────────
if(APPLE)
    set_target_properties(yecwallet PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/res/Info.plist"
        MACOSX_BUNDLE_BUNDLE_NAME "yecwallet"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_GUI_IDENTIFIER "xyz.ycashfoundation.yecwallet"
        MACOSX_BUNDLE_ICON_FILE "logo.icns"
    )
endif()

# ── Windows RC ───────────────────────────────────────────────────────────────
if(WIN32)
    set_target_properties(yecwallet PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
endif()

# ── Translations ──────────────────────────────────────────────────────────────
if(Qt6LinguistTools_FOUND)
    qt_add_translations(yecwallet
        TS_FILES
            res/zec_qt_wallet_es.ts
            res/zec_qt_wallet_fr.ts
            res/zec_qt_wallet_de.ts
            res/zec_qt_wallet_pt.ts
            res/zec_qt_wallet_it.ts
            res/zec_qt_wallet_tr.ts
            res/zec_qt_wallet_zh.ts
        QM_FILES_OUTPUT_VARIABLE QM_FILES
    )
else()
    message(WARNING "Qt6LinguistTools not found — translations will not be compiled. "
                    "Add 'qttools' to -submodules in scripts/build-qt.sh and rebuild Qt.")
endif()

# ── Install rules ─────────────────────────────────────────────────────────────
if(UNIX AND NOT APPLE)
    install(TARGETS yecwallet RUNTIME DESTINATION bin)
elseif(APPLE)
    install(TARGETS yecwallet BUNDLE DESTINATION .)
elseif(WIN32)
    install(TARGETS yecwallet RUNTIME DESTINATION .)
endif()
