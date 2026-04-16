#!/usr/bin/env bash
# =============================================================================
# build.sh — Master build script for yecwallet
# =============================================================================
#
# SYNOPSIS
#   bash build.sh [OPTIONS] [TARGET]
#
# TARGET (default: auto-detect host)
#   linux-x86_64        Native Linux build
#   windows-x86_64      Cross-compile to Windows from Linux (llvm-mingw)
#   macos-x86_64        Native macOS Intel
#   macos-arm64         Native macOS Apple Silicon
#   macos-universal     Fat binary (x86_64 + arm64), macOS host only
#
# OPTIONS
#   --deps-only         Build Qt only; skip yecwallet compilation
#   --app-only          Skip dependency builds; only build yecwallet
#                       (assumes Qt is already installed)
#   --build-type TYPE   cmake build type: Release (default) | Debug | RelWithDebInfo
#   --qt-version VER    Qt version to fetch/build (default: 6.5.8)
#   --prefix DIR        Override install prefix for deps (./deps)
#   --jobs N            Parallel jobs              (default: nproc)
#   --package           Create distributable archive / .dmg / .zip after build
#   -h, --help          Show this help
#
# ENVIRONMENT VARIABLES (override defaults)
#   LLVM_MINGW_ROOT     Required for windows-x86_64 cross-compile
#   QT_STATIC_ROOT      Skip Qt build; point to an existing static Qt
#   WORK_DIR            Download/build cache dir (default: ~/.cache/yecwallet-build)
#
# PREREQUISITES
#   Linux  : cmake ninja-build clang libssl-dev  (apt install cmake ninja-build clang libssl-dev)
#   macOS  : brew install cmake ninja   (Xcode CLT required)
#   Windows: cross-compile from Linux with LLVM_MINGW_ROOT set
#
# EXAMPLES
#   # Full build on Linux (builds Qt, then yecwallet)
#   bash build.sh linux-x86_64
#
#   # Full cross-compile to Windows from Linux
#   LLVM_MINGW_ROOT=/opt/llvm-mingw bash build.sh windows-x86_64
#
#   # macOS universal binary
#   bash build.sh macos-universal
#
#   # Use a pre-built Qt, only compile the app
#   QT_STATIC_ROOT=/opt/myqt bash build.sh --app-only linux-x86_64
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET=""
BUILD_TYPE="Release"
QT_VERSION="${QT_VERSION:-6.5.8}"
LLVM_MINGW_VERSION="${LLVM_MINGW_VERSION:-20250114}"
DEPS_PREFIX="${DEPS_PREFIX:-${SCRIPT_DIR}/deps}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)}"
WORK_DIR="${WORK_DIR:-${HOME}/.cache/yecwallet-build}"
DEPS_ONLY=false
APP_ONLY=false
DO_PACKAGE=false
REBUILD_QT=false

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo ""; echo "━━━ $* ━━━"; }
step()    { echo "  » $*"; }
die()     { echo "ERROR: $*" >&2; exit 1; }
need()    { command -v "$1" >/dev/null 2>&1 || die "Required tool not found: $1. Please install it."; }

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --deps-only)       DEPS_ONLY=true ;;
        --app-only)        APP_ONLY=true ;;
        --rebuild-qt)      REBUILD_QT=true ;;
        --package)         DO_PACKAGE=true ;;
        --build-type)      BUILD_TYPE="$2"; shift ;;
        --qt-version)      QT_VERSION="$2"; shift ;;
        --prefix)          DEPS_PREFIX="$2"; shift ;;
        --jobs)            JOBS="$2"; shift ;;
        -h|--help)
            sed -n '/^# SYNOPSIS/,/^# ={10}/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        linux-x86_64|windows-x86_64|macos-x86_64|macos-arm64|macos-universal)
            TARGET="$1" ;;
        *)
            die "Unknown argument: $1" ;;
    esac
    shift
done

# ── Auto-detect target ────────────────────────────────────────────────────────
if [[ -z "$TARGET" ]]; then
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    if [[ "$OS" == "Linux"  && "$ARCH" == "x86_64" ]]; then TARGET="linux-x86_64"
    elif [[ "$OS" == "Darwin" && "$ARCH" == "x86_64" ]]; then TARGET="macos-x86_64"
    elif [[ "$OS" == "Darwin" && "$ARCH" == "arm64"  ]]; then TARGET="macos-arm64"
    else die "Cannot auto-detect target for OS=$OS ARCH=$ARCH. Pass TARGET explicitly."
    fi
    step "Auto-detected target: $TARGET"
fi

# ── Derived paths ─────────────────────────────────────────────────────────────
QT_STATIC_ROOT="${QT_STATIC_ROOT:-${DEPS_PREFIX}/qt-${QT_VERSION}/${TARGET}}"
BUILD_DIR="${SCRIPT_DIR}/build/${TARGET}"
ARTIFACTS_DIR="${SCRIPT_DIR}/artifacts"

APP_VERSION="$(sed -n 's/.*APP_VERSION "\([^"]*\)".*/\1/p' "${SCRIPT_DIR}/src/version.h" 2>/dev/null || echo "dev")"

export WORK_DIR

# ── Auto-fetch llvm-mingw for Windows cross-compile ───────────────────────────
if [[ "$TARGET" == "windows-x86_64" ]]; then
    if [[ -z "${LLVM_MINGW_ROOT:-}" ]]; then
        info "Fetching llvm-mingw ${LLVM_MINGW_VERSION}..."
        LLVM_MINGW_ROOT="$(
            LLVM_MINGW_VERSION="${LLVM_MINGW_VERSION}" \
            INSTALL_PREFIX="${DEPS_PREFIX}/llvm-mingw-${LLVM_MINGW_VERSION}" \
            WORK_DIR="${WORK_DIR}" \
                bash "${SCRIPT_DIR}/scripts/fetch-llvm-mingw.sh"
        )"
    fi
    [[ -x "${LLVM_MINGW_ROOT}/bin/x86_64-w64-mingw32-clang" ]] || \
        die "llvm-mingw not found at LLVM_MINGW_ROOT=${LLVM_MINGW_ROOT}"
    step "llvm-mingw: ${LLVM_MINGW_ROOT}"
fi
export LLVM_MINGW_ROOT="${LLVM_MINGW_ROOT:-}"

if [[ "$TARGET" == macos-* && "$(uname)" != "Darwin" ]]; then
    die "macOS targets must be built on a macOS host."
fi


echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              yecwallet build system                  ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Target       : %-35s  ║\n" "$TARGET"
printf "║  Build type   : %-35s  ║\n" "$BUILD_TYPE"
printf "║  Qt version   : %-35s  ║\n" "$QT_VERSION"
printf "║  App version  : %-35s  ║\n" "$APP_VERSION"
printf "║  Jobs         : %-35s  ║\n" "$JOBS"
printf "║  Qt root      : %-35s  ║\n" "$(basename "$QT_STATIC_ROOT")"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

need cmake

# ── Step 1: Build Qt ──────────────────────────────────────────────────────────
if ! $APP_ONLY; then
    if [[ ( -f "${QT_STATIC_ROOT}/bin/qmake" || -f "${QT_STATIC_ROOT}/bin/qt-cmake" ) ]] && ! $REBUILD_QT; then
        step "Qt already built at ${QT_STATIC_ROOT} — skipping."
    else
        $REBUILD_QT && rm -rf "${QT_STATIC_ROOT}" "${WORK_DIR}/qt-build-${TARGET}"
        info "Building Qt ${QT_VERSION} (static) for ${TARGET}"
        step "This will take 30-90 minutes on first run."
        TARGET="$TARGET" \
        QT_VERSION="$QT_VERSION" \
        INSTALL_PREFIX="$QT_STATIC_ROOT" \
        JOBS="$JOBS" \
        WORK_DIR="$WORK_DIR" \
        LLVM_MINGW_ROOT="${LLVM_MINGW_ROOT}" \
            bash "${SCRIPT_DIR}/scripts/build-qt.sh"
    fi
fi

$DEPS_ONLY && { step "Deps-only mode: done."; exit 0; }

# ── Step 2: Configure yecwallet ───────────────────────────────────────────────
info "Configuring yecwallet for ${TARGET}"

# Remove only the final executable so CMake re-links without wiping the build cache.
BIN_EARLY="${BUILD_DIR}/bin/yecwallet"
[[ "$TARGET" == "windows-x86_64" ]] && BIN_EARLY="${BIN_EARLY}.exe"
rm -f "${BIN_EARLY}"
mkdir -p "${BUILD_DIR}"

CMAKE_ARGS=(
    -S "${SCRIPT_DIR}"
    -B "${BUILD_DIR}"
    -G Ninja
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
    -DCMAKE_PREFIX_PATH="${QT_STATIC_ROOT}"
    -DQT_STATIC=ON
)

case "$TARGET" in
linux-x86_64)
    CMAKE_ARGS+=(
        -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cmake/toolchains/linux-x86_64.cmake"
    )
    ;;
windows-x86_64)
    CMAKE_ARGS+=(
        -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cmake/toolchains/windows-x86_64-llvm-mingw.cmake"
        -DLLVM_MINGW_ROOT="${LLVM_MINGW_ROOT}"
    )
    ;;
macos-x86_64|macos-arm64)
    CMAKE_ARGS+=(
        -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cmake/toolchains/macos-universal.cmake"
        # Override to single arch for non-universal builds
        -DCMAKE_OSX_ARCHITECTURES="${TARGET#macos-}"
    )
    ;;
macos-universal)
    CMAKE_ARGS+=(
        -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cmake/toolchains/macos-universal.cmake"
    )
    ;;
esac

need ninja
cmake "${CMAKE_ARGS[@]}"

# ── Step 3: Build ─────────────────────────────────────────────────────────────
info "Building yecwallet"
cmake --build "${BUILD_DIR}" --parallel "${JOBS}"

# ── Step 4: Verify static linkage ────────────────────────────────────────────
info "Verifying static linkage"
BIN="${BUILD_DIR}/bin/yecwallet"
[[ "$TARGET" == "windows-x86_64" ]] && BIN="${BIN}.exe"

if [[ "$TARGET" == "linux-x86_64" ]]; then
    if ldd "${BIN}" 2>/dev/null | grep -qi "qt"; then
        die "Qt appears to be dynamically linked! Check your Qt prefix."
    fi
    step "Qt is statically linked ✓"
    ldd "${BIN}" | grep -v "=>" || true
elif [[ "$TARGET" == macos-* ]]; then
    if otool -L "${BIN}" 2>/dev/null | grep -qi "Qt"; then
        die "Qt appears to be dynamically linked! Check your Qt prefix."
    fi
    step "Qt is statically linked ✓"
fi

# ── Step 5: Package ───────────────────────────────────────────────────────────
if $DO_PACKAGE; then
    info "Packaging"
    mkdir -p "${ARTIFACTS_DIR}"

    case "$TARGET" in
    linux-x86_64)
        PKG_DIR="${BUILD_DIR}/pkg/yecwallet-v${APP_VERSION}"
        mkdir -p "${PKG_DIR}"
        cp "${BIN}"             "${PKG_DIR}/"
        cp "${SCRIPT_DIR}/LICENSE" "${PKG_DIR}/"
        TARBALL="${ARTIFACTS_DIR}/linux-x86_64-yecwallet-v${APP_VERSION}.tar.gz"
        tar -czf "${TARBALL}" -C "${BUILD_DIR}/pkg" "yecwallet-v${APP_VERSION}"
        step "Package: ${TARBALL}"
        ;;
    windows-x86_64)
        PKG_DIR="${BUILD_DIR}/pkg/yecwallet-v${APP_VERSION}"
        mkdir -p "${PKG_DIR}"
        cp "${BIN}"             "${PKG_DIR}/"
        cp "${SCRIPT_DIR}/LICENSE" "${PKG_DIR}/"
        ZIPFILE="${ARTIFACTS_DIR}/windows-x86_64-yecwallet-v${APP_VERSION}.zip"
        (cd "${BUILD_DIR}/pkg" && zip -r "${ZIPFILE}" "yecwallet-v${APP_VERSION}")
        step "Package: ${ZIPFILE}"
        ;;
    macos-*|macos-universal)
        APP_BUNDLE="${BUILD_DIR}/bin/yecwallet.app"
        step "Running macdeployqt..."
        "${QT_STATIC_ROOT}/bin/macdeployqt" "${APP_BUNDLE}" -dmg
        DMG="${ARTIFACTS_DIR}/${TARGET}-yecwallet-v${APP_VERSION}.dmg"
        mv "${BUILD_DIR}/bin/yecwallet.dmg" "${DMG}"
        step "Package: ${DMG}"
        ;;
    esac
fi

info "Done"
echo "  Binary : ${BIN}"
[[ $DO_PACKAGE == true ]] && echo "  Artifacts: ${ARTIFACTS_DIR}/"
