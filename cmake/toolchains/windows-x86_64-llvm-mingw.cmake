# Toolchain file for cross-compiling to Windows x86_64 from Linux
# using llvm-mingw (https://github.com/mstorsjo/llvm-mingw).
#
# Usage:
#   cmake -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/windows-x86_64-llvm-mingw.cmake \
#         -DCMAKE_PREFIX_PATH=/opt/qt-static/windows-x86_64 \
#         -DSODIUM_ROOT=/opt/sodium/windows-x86_64 \
#         -B build-windows ..
#
# The LLVM_MINGW_ROOT environment variable (or cmake cache variable) must
# point to the extracted llvm-mingw toolchain directory, e.g.
#   /opt/llvm-mingw-20241119-ucrt-ubuntu-20.04-x86_64

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Locate toolchain root
if(DEFINED ENV{LLVM_MINGW_ROOT} AND NOT LLVM_MINGW_ROOT)
    set(LLVM_MINGW_ROOT "$ENV{LLVM_MINGW_ROOT}")
endif()
if(NOT LLVM_MINGW_ROOT)
    message(FATAL_ERROR "Set LLVM_MINGW_ROOT to the llvm-mingw install directory.")
endif()

set(TRIPLE x86_64-w64-mingw32)
set(CMAKE_C_COMPILER   "${LLVM_MINGW_ROOT}/bin/${TRIPLE}-clang")
set(CMAKE_CXX_COMPILER "${LLVM_MINGW_ROOT}/bin/${TRIPLE}-clang++")
set(CMAKE_RC_COMPILER  "${LLVM_MINGW_ROOT}/bin/${TRIPLE}-windres")
set(CMAKE_AR           "${LLVM_MINGW_ROOT}/bin/llvm-ar")
set(CMAKE_RANLIB       "${LLVM_MINGW_ROOT}/bin/llvm-ranlib")
set(CMAKE_LINKER       "${LLVM_MINGW_ROOT}/bin/lld")

# Static runtime — avoids shipping MSVCRT DLLs
set(CMAKE_EXE_LINKER_FLAGS_INIT    "-static -static-libgcc -static-libstdc++")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-static -static-libgcc -static-libstdc++")

# Search only in the sysroot and explicitly listed prefixes, not in the host system.
# CMAKE_PREFIX_PATH entries are appended to CMAKE_FIND_ROOT_PATH so that
# find_package(Qt6) and find_library(sodium) resolve against the cross-built deps.
set(CMAKE_FIND_ROOT_PATH "${LLVM_MINGW_ROOT}/${TRIPLE}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Allow CMAKE_PREFIX_PATH to extend the find root so callers can do:
#   cmake -DCMAKE_PREFIX_PATH=".../deps/qt-6.8.3/windows-x86_64"
# without having to override the find modes.
list(APPEND CMAKE_FIND_ROOT_PATH ${CMAKE_PREFIX_PATH})
