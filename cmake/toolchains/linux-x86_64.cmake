# Toolchain file for native Linux x86_64 builds.
# Usually not required (CMake auto-detects the host), but provided for
# consistency when the build.sh script drives all platforms uniformly.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Default to clang if available, fall back to gcc
find_program(CLANG_C   clang)
find_program(CLANG_CXX clang++)
if(CLANG_C AND CLANG_CXX)
    set(CMAKE_C_COMPILER   "${CLANG_C}")
    set(CMAKE_CXX_COMPILER "${CLANG_CXX}")
endif()
