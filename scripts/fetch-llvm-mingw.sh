#!/usr/bin/env bash
# =============================================================================
# scripts/fetch-llvm-mingw.sh — Download and extract llvm-mingw toolchain
# =============================================================================
#
# Environment variables:
#   LLVM_MINGW_VERSION   Version tag (default: 20250114)
#   INSTALL_PREFIX       Where to extract (default: <project>/deps/llvm-mingw)
#   WORK_DIR             Download cache   (default: ~/.cache/yecwallet-build)
#
# Prints the toolchain root path to stdout on success so callers can capture it:
#   LLVM_MINGW_ROOT=$(bash scripts/fetch-llvm-mingw.sh)
# =============================================================================
set -euo pipefail

LLVM_MINGW_VERSION="${LLVM_MINGW_VERSION:-20250114}"
WORK_DIR="${WORK_DIR:-${HOME}/.cache/yecwallet-build}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PREFIX="${INSTALL_PREFIX:-${SCRIPT_DIR}/deps/llvm-mingw-${LLVM_MINGW_VERSION}}"

info() { echo "[llvm-mingw]  $*" >&2; }
die()  { echo "[llvm-mingw] ERROR: $*" >&2; exit 1; }

# Already extracted?
if [[ -x "${INSTALL_PREFIX}/bin/x86_64-w64-mingw32-clang" ]]; then
    echo "${INSTALL_PREFIX}"
    exit 0
fi

# Determine host triple for the prebuilt archive
OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" == "Linux" && "$ARCH" == "x86_64" ]]; then
    # Ubuntu 20.04 builds run on any modern Linux (glibc 2.31+)
    ARCHIVE="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-20.04-x86_64.tar.xz"
elif [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
    ARCHIVE="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-macos-universal.tar.xz"
elif [[ "$OS" == "Darwin" && "$ARCH" == "x86_64" ]]; then
    ARCHIVE="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-macos-universal.tar.xz"
else
    die "No prebuilt llvm-mingw archive for OS=$OS ARCH=$ARCH"
fi

URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/${ARCHIVE}"
TARBALL="${WORK_DIR}/${ARCHIVE}"

mkdir -p "${WORK_DIR}"

if [[ ! -f "${TARBALL}" ]]; then
    info "Downloading llvm-mingw ${LLVM_MINGW_VERSION}..."
    curl -L --progress-bar -o "${TARBALL}" "${URL}"
fi

info "Extracting llvm-mingw..."
# The archive extracts to a directory named llvm-mingw-<version>-ucrt-...,
# we rename it to our INSTALL_PREFIX for a stable path.
EXTRACT_DIR="${WORK_DIR}/llvm-mingw-extract-$$"
mkdir -p "${EXTRACT_DIR}"
tar -xf "${TARBALL}" -C "${EXTRACT_DIR}"
EXTRACTED="$(ls "${EXTRACT_DIR}")"
rm -rf "${INSTALL_PREFIX}"
mv "${EXTRACT_DIR}/${EXTRACTED}" "${INSTALL_PREFIX}"
rmdir "${EXTRACT_DIR}"

info "llvm-mingw installed at ${INSTALL_PREFIX}"
echo "${INSTALL_PREFIX}"
