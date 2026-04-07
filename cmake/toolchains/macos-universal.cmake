# Toolchain file for building a macOS universal binary (x86_64 + arm64).
#
# Must be used on a macOS host with Xcode / Command Line Tools installed.
#
# Usage (native macOS build):
#   cmake -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/macos-universal.cmake \
#         -DCMAKE_PREFIX_PATH=/opt/qt-static/macos-universal \
#         -DSODIUM_ROOT=/opt/sodium/macos-universal \
#         -B build-macos ..
#
# Qt itself must be built for both architectures (build-qt.sh handles this).
# libsodium must also be lipo'd into a fat library (build-sodium.sh handles this).

set(CMAKE_SYSTEM_NAME Darwin)

set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING "Build universal binary")
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
