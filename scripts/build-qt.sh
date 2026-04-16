#!/usr/bin/env bash
# =============================================================================
# scripts/build-qt.sh — Fetch and statically build Qt 6 for one target
# =============================================================================
#
# Supported TARGET values:
#   linux-x86_64          Native Linux build (requires clang or gcc)
#   windows-x86_64        Cross-compile from Linux via llvm-mingw
#   macos-x86_64          Native macOS Intel build
#   macos-arm64           Native macOS Apple Silicon build
#   macos-universal       Fat binary (x86_64 + arm64) — macOS host only
#
# Required environment / arguments:
#   TARGET           One of the values above (or pass as first positional arg)
#   INSTALL_PREFIX   Where to install static Qt  (default: /opt/qt-static/$TARGET)
#   QT_VERSION       Qt version to build          (default: 6.5.8)
#   JOBS             Parallel make jobs            (default: nproc)
#
# For windows-x86_64:
#   LLVM_MINGW_ROOT  Path to llvm-mingw toolchain (required)
#
# Example — Linux:
#   TARGET=linux-x86_64 bash scripts/build-qt.sh
#
# Example — Windows cross-compile:
#   TARGET=windows-x86_64 LLVM_MINGW_ROOT=/opt/llvm-mingw bash scripts/build-qt.sh
#
# Example — macOS universal:
#   TARGET=macos-universal bash scripts/build-qt.sh
# =============================================================================
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET="${1:-${TARGET:-}}"
QT_VERSION="${QT_VERSION:-6.5.8}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)}"
INSTALL_PREFIX="${INSTALL_PREFIX:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/deps/qt-static/${TARGET}}"
WORK_DIR="${WORK_DIR:-${HOME}/.cache/yecwallet-build}"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()  { echo "[qt]  $*"; }
die()   { echo "[qt] ERROR: $*" >&2; exit 1; }
need()  { command -v "$1" >/dev/null 2>&1 || die "Required tool not found: $1"; }

[[ -z "$TARGET" ]] && die "TARGET not set. Pass it as the first argument or env var."

info "Target    : $TARGET"
info "Qt version: $QT_VERSION"
info "Install   : $INSTALL_PREFIX"
info "Jobs      : $JOBS"

# ── Parse minor/major for mirror URL ─────────────────────────────────────────
IFS='.' read -r QT_MAJOR QT_MINOR QT_PATCH <<< "$QT_VERSION"
QT_SHORT="${QT_MAJOR}.${QT_MINOR}"   # e.g. 6.8

# Qt sources are mirrored at download.qt.io
# Qt < 6.7 uses "qt-everywhere-opensource-src-X.Y.Z"; 6.7+ dropped "opensource-"
if [[ "${QT_MAJOR}" -gt 6 ]] || { [[ "${QT_MAJOR}" -eq 6 ]] && [[ "${QT_MINOR}" -ge 7 ]]; }; then
    QT_SRC_BASE="qt-everywhere-src-${QT_VERSION}"
    QT_SRC_URL="https://download.qt.io/official_releases/qt/${QT_SHORT}/${QT_VERSION}/single/${QT_SRC_BASE}.tar.xz"
else
    QT_SRC_BASE="qt-everywhere-opensource-src-${QT_VERSION}"
    QT_SRC_URL="https://download.qt.io/official_releases/qt/${QT_SHORT}/${QT_VERSION}/src/single/${QT_SRC_BASE}.tar.xz"
fi
# QT_SRC_URL="https://download.qt.io/official_releases/qt/${QT_SHORT}/${QT_VERSION}/src/single/${QT_SRC_BASE}.tar.xz"
QT_SRC_DIR="${WORK_DIR}/qt-everywhere-src-${QT_VERSION}"
QT_BUILD_DIR="${WORK_DIR}/qt-build-${TARGET}"
QT_TARBALL="${WORK_DIR}/${QT_SRC_BASE}.tar.xz"

mkdir -p "${WORK_DIR}"

# ── Download Qt sources ───────────────────────────────────────────────────────
if [[ ! -d "${QT_SRC_DIR}" ]]; then
    if [[ ! -f "${QT_TARBALL}" ]]; then
        info "Downloading Qt ${QT_VERSION} source from ${QT_SRC_URL} ..."
        need curl
        curl -L --progress-bar -o "${QT_TARBALL}" "${QT_SRC_URL}"
    fi
    info "Extracting Qt source..."
    tar -xf "${QT_TARBALL}" -C "${WORK_DIR}"
fi

# ── Build directory ───────────────────────────────────────────────────────────
rm -rf "${QT_BUILD_DIR}"
mkdir -p "${QT_BUILD_DIR}"
cd "${QT_BUILD_DIR}"

# ── Shared configure flags ────────────────────────────────────────────────────
# Only the modules actually used by yecwallet are enabled; everything else
# is skipped to keep build times short.
COMMON_FLAGS=(
    -prefix "${INSTALL_PREFIX}"
    -static
    -release
    -optimize-size
    -confirm-license
    -opensource
    -no-pch                              # PCH inside Qt slows cross-builds

    # Build only the modules yecwallet actually needs.
    # Everything not listed here is skipped automatically.
    -submodules qtbase,qtwebsockets,qttools,qttranslations

    # Skip heavy / unneeded submodules explicitly (belt-and-suspenders)
    -skip qtdeclarative
    -skip qtquick3d
    -skip qtmultimedia
    -skip qtlocation
    -skip qtsensors
    -skip qtwebengine
    -skip qtwebview
    -skip qt3d
    -skip qtcharts
    -skip qtdatavis3d
    -skip qtvirtualkeyboard
    -skip qtscxml
    -skip qtactiveqt
    -skip qtserialport
    -skip qtserialbus
    -skip qtbluetooth
    -skip qtnfc
    -skip qtpositioning
    -skip qtremoteobjects
    -skip qtcoap
    -skip qtmqtt
    -skip qtopcua

    # Disable individual qtbase features not needed by yecwallet
    -no-feature-dbus
    -no-feature-sql
    -no-feature-testlib
    -no-feature-concurrent
    -no-feature-accessibility
    -no-feature-vulkan
    -no-feature-glib
    -no-icu

)

# ── Platform-specific configure ───────────────────────────────────────────────
case "$TARGET" in
# ─────────────────────────────────────────────────────────── linux-x86_64 ────
linux-x86_64)
    need cmake
    need ninja
    EXTRA_FLAGS=(
        -platform linux-clang
        -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz
        -openssl-linked          # require OpenSSL; fails loudly if headers missing
    )
    # Locate static OpenSSL libs explicitly so Qt doesn't pick up the shared .so
    _SSL_A="$(find /usr/lib/x86_64-linux-gnu /usr/lib /usr/local/lib -name "libssl.a"    -print -quit 2>/dev/null)"
    _CRYPTO_A="$(find /usr/lib/x86_64-linux-gnu /usr/lib /usr/local/lib -name "libcrypto.a" -print -quit 2>/dev/null)"
    [[ -f "$_SSL_A" && -f "$_CRYPTO_A" ]] || die "Static OpenSSL .a files not found. Install libssl-dev."
    CMAKE_EXTRA=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_DISABLE_FIND_PACKAGE_WrapLibClang=ON
        -DQT_FEATURE_clang=OFF
        -DQT_FEATURE_clangcpp=OFF
        -DOPENSSL_USE_STATIC_LIBS=TRUE
        -DOPENSSL_SSL_LIBRARY="${_SSL_A}"
        -DOPENSSL_CRYPTO_LIBRARY="${_CRYPTO_A}"
    )
    "${QT_SRC_DIR}/configure" "${COMMON_FLAGS[@]}" "${EXTRA_FLAGS[@]}" -- "${CMAKE_EXTRA[@]}"
    cmake --build . --parallel "${JOBS}"
    cmake --install .
    ;;

# ──────────────────────────────────────────────────────── windows-x86_64 ────
windows-x86_64)
    [[ -z "${LLVM_MINGW_ROOT:-}" ]] && die "LLVM_MINGW_ROOT must be set for windows-x86_64 target."
    need cmake
    need ninja
    export PATH="${LLVM_MINGW_ROOT}/bin:${PATH}"
    TRIPLE="x86_64-w64-mingw32"

    # Qt cross-compilation requires a native (host) Qt build for moc/rcc/uic.
    # Default to the linux-x86_64 build produced by this same script.
    QT_HOST_PATH="${QT_HOST_PATH:-$(dirname "${INSTALL_PREFIX}")/linux-x86_64}"
    [[ -d "${QT_HOST_PATH}" ]] || die \
        "QT_HOST_PATH not found at ${QT_HOST_PATH}.\n" \
        "Build the linux-x86_64 target first:  bash build.sh linux-x86_64\n" \
        "Or set QT_HOST_PATH explicitly."

    EXTRA_FLAGS=(
        -xplatform win32-clang-g++
        -device-option CROSS_COMPILE="${TRIPLE}-"
        -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz
        -no-feature-dbus
        -no-opengl
        -no-openssl               # use Windows SChannel (built-in OS TLS); no OpenSSL dependency
    )
    CMAKE_EXTRA=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_C_COMPILER="${LLVM_MINGW_ROOT}/bin/${TRIPLE}-clang"
        -DCMAKE_CXX_COMPILER="${LLVM_MINGW_ROOT}/bin/${TRIPLE}-clang++"
        -DCMAKE_SYSTEM_NAME=Windows
        -DCMAKE_SYSTEM_PROCESSOR=x86_64
        -DQT_HOST_PATH="${QT_HOST_PATH}"
        -DQT_HOST_PATH_CMAKE_DIR="${QT_HOST_PATH}/lib/cmake"
        -DCMAKE_DISABLE_FIND_PACKAGE_WrapLibClang=ON
        -DQT_FEATURE_clang=OFF
        -DQT_FEATURE_clangcpp=OFF
    )
    "${QT_SRC_DIR}/configure" "${COMMON_FLAGS[@]}" "${EXTRA_FLAGS[@]}" -- "${CMAKE_EXTRA[@]}"
    cmake --build . --parallel "${JOBS}"
    cmake --install .
    ;;

# ───────────────────────────────────────────────────────── macos-x86_64 ─────
macos-x86_64)
    [[ "$(uname)" != "Darwin" ]] && die "macos-x86_64 must be built on a macOS host."
    need cmake
    need ninja
    HOST_ARCH="$(uname -m)"
    # Native build (x86_64 host) or cross build (arm64 host → x86_64 target)
    [[ "$HOST_ARCH" == "x86_64" ]] \
        && info "Native x86_64 build" \
        || info "Cross build: arm64 host → x86_64 target"
    EXTRA_FLAGS=(
        -platform macx-clang
        -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz
        -no-openssl -securetransport
    )
    CMAKE_EXTRA=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_OSX_ARCHITECTURES=x86_64
        -DQT_FORCE_WARN_APPLE_SDK_AND_XCODE_CHECK=ON
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
    )
    "${QT_SRC_DIR}/configure" "${COMMON_FLAGS[@]}" "${EXTRA_FLAGS[@]}" -- "${CMAKE_EXTRA[@]}"
    cmake --build . --parallel "${JOBS}"
    cmake --install .
    ;;

# ────────────────────────────────────────────────────────── macos-arm64 ─────
macos-arm64)
    [[ "$(uname)" != "Darwin" ]] && die "macos-arm64 must be built on a macOS host."
    need cmake
    need ninja
    HOST_ARCH="$(uname -m)"
    # Native build (arm64 host) or cross build (x86_64 host → arm64 target)
    [[ "$HOST_ARCH" == "arm64" ]] \
        && info "Native arm64 build" \
        || info "Cross build: x86_64 host → arm64 target"
    EXTRA_FLAGS=(
        -platform macx-clang
        -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz
        -no-openssl -securetransport
    )
    CMAKE_EXTRA=(
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_OSX_ARCHITECTURES=arm64
        -DQT_FORCE_WARN_APPLE_SDK_AND_XCODE_CHECK=ON
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
    )
    "${QT_SRC_DIR}/configure" "${COMMON_FLAGS[@]}" "${EXTRA_FLAGS[@]}" -- "${CMAKE_EXTRA[@]}"
    cmake --build . --parallel "${JOBS}"
    cmake --install .
    ;;

# ─────────────────────────────────────────────────────── macos-universal ────
macos-universal)
    [[ "$(uname)" != "Darwin" ]] && die "macos-universal must be built on a macOS host."
    need cmake
    need ninja
    info "Universal build (x86_64 + arm64) on $(uname -m) host"
    # Use Qt's native multi-arch support: pass both architectures in a single
    # configure run so Qt produces correct CMake config files for both slices.
    # The lipo-merge approach copies x86_64 cmake configs unchanged, which
    # causes CMake to fail when building a universal app binary.
    EXTRA_FLAGS=(
        -platform macx-clang
        -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz
        -no-openssl -securetransport
    )
    CMAKE_EXTRA=(
        -DCMAKE_BUILD_TYPE=Release
        "-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64"
        -DQT_FORCE_WARN_APPLE_SDK_AND_XCODE_CHECK=ON
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
    )
    "${QT_SRC_DIR}/configure" "${COMMON_FLAGS[@]}" "${EXTRA_FLAGS[@]}" -- "${CMAKE_EXTRA[@]}"
    cmake --build . --parallel "${JOBS}"
    cmake --install .
    info "Universal Qt installed at ${INSTALL_PREFIX}"
    ;;

*)
    die "Unknown TARGET '${TARGET}'. Valid values: linux-x86_64 windows-x86_64 macos-x86_64 macos-arm64 macos-universal"
    ;;
esac

info "Qt ${QT_VERSION} (${TARGET}) installed at ${INSTALL_PREFIX}"
