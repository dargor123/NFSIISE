@echo off
setlocal EnableDelayedExpansion

rem ---------------------------------------------
rem WINDOWS ONLY BUILD SCRIPT
rem ---------------------------------------------

rem -- READ CAREFULLY THE INSTRUCTIONS BELOW BEFORE FIRST RUN --

rem 1. Download MINGW32 with LLVM/Clang/LLD/LLDB from
rem https://github.com/brechtsanders/winlibs_mingw/releases/tag/16.2.0posix-23.1.3-14.0.0-ucrt-r3

rem 2. Download SDL2 Devel MINGW from:
rem https://github.com/libsdl-org/SDL/releases/tag/release-2.32.10

rem 3. Download YASM WIN32 from:
rem https://github.com/yasm/yasm/releases/tag/v1.3.0

rem 4. Download Byteswap header from:
rem https://github.com/icecoobe/sbc-windows/blob/master/byteswap.h

rem 5. Edit these paths to match yours:
set "MINGW32_DIR=C:\Work\Programs\mingw32"
set "SDL2_DIR=C:\Work\Programs\SDL2-2.32.10"
set "YASM_DIR=C:\Work\Programs\yasm"
set "BYTESWAP_H_DIR=C:\Work\Programs\byteswap_h"

rem -- BUILD OPTIONS (EDIT BY YOUR PREFERENCE) --

rem asm = build using the assembly implementation (Asm/NFS2SE.asm); builds faster and produces a smaller binary
rem cpp = build using the C++ implementation (Cpp/NFS2SE.cpp); builds slower and produces a larger binary
set "COMPILE_MODE=asm"

rem debug = debug build with a console window for viewing logs
rem release = release build without a console window
set "BUILD_TYPE=debug"

rem -- BUILD LOGIC (DO NOT EDIT UNLESS YOU KNOW WHAT YOU'RE DOING) --

set "CPU_FLAGS=-m32"
set "CPP_LTO=-flto"
set "FLAGS=-O3 -DNDEBUG"
set "OPENGL_DEFINE="
set "OPENGL_LIBS=-lopengl32"

set "MINGW32_LIB_DIR=%MINGW32_DIR%\i686-w64-mingw32\lib"
set "CCACHE_EXE=%MINGW32_DIR%\bin\ccache.exe"
set "WINDRES_EXE=%MINGW32_DIR%\bin\windres.exe"
set "CLANG_EXE=%MINGW32_DIR%\bin\clang.exe"
set "LD_EXE=%MINGW32_DIR%\bin\ld.exe"

set "SDL2_LIB_DIR=%SDL2_DIR%\i686-w64-mingw32\lib"
set "SDL2_INCLUDE_DIR=%SDL2_DIR%\i686-w64-mingw32\include"
set "SDL2_DLL=%SDL2_DIR%\i686-w64-mingw32\bin\SDL2.dll"

set "YASM_EXE=%YASM_DIR%\yasm-1.3.0-win32.exe"

if /I "%COMPILE_MODE%"=="asm" (
    set "NFS_CPP="
) else if /I "%COMPILE_MODE%"=="cpp" (
    set "NFS_CPP=-DNFS_CPP"
) else (
    echo ERROR: Invalid COMPILE_MODE "%COMPILE_MODE%". Expected "asm" or "cpp".
    exit /b 1
)

if /I "%BUILD_TYPE%"=="debug" (
    set "WIN_SUBSYSTEM=console"
    set "DEBUG_ASM=-g dwarf2"
    set "EXTRA_FLAGS=-g"
    set "STRIP="
) else if /I "%BUILD_TYPE%"=="release" (
    set "WIN_SUBSYSTEM=windows"
    set "DEBUG_ASM="
    set "EXTRA_FLAGS=-O2"
    set "STRIP=-s"
) else (
    echo ERROR: Invalid BUILD_TYPE "%BUILD_TYPE%". Expected "debug" or "release".
    exit /b 1
)

echo ----------------------------
echo Compile mode: %COMPILE_MODE%
echo Build type: %BUILD_TYPE%
echo ----------------------------

cd /d "%~dp0src" || exit /b 1

echo Compiling Windows resources...
%CCACHE_EXE% %WINDRES_EXE% Windows/nfs2se.rc icon.o
if errorlevel 1 exit /b 1
echo OK!

echo Compiling C code...
for %%F in ("*.c") do (
    echo %%F
    %CCACHE_EXE% %CLANG_EXE% -c -std=gnu89 ^
        -Wno-incompatible-function-pointer-types ^
        -Wno-int-conversion -Wall ^
        %CPU_FLAGS% %EXTRA_FLAGS% %FLAGS% ^
        %OPENGL_DEFINE% %NFS_CPP% ^
        -I"%SDL2_INCLUDE_DIR%" "%%F" -o "%%~nF.o"
    if errorlevel 1 exit /b 1
)
echo OK!

if /I "%COMPILE_MODE%"=="asm" (
    echo Compiling ASM code...
    %CCACHE_EXE% %YASM_EXE% -f win32 ^
        Asm/NFS2SE.asm -o NFS2SE.o ^
        %DEBUG_ASM% --prefix=_
) else (
    echo Compiling C++ code...
    %CCACHE_EXE% %CLANG_EXE% -c -std=c++14 ^
        %CPU_FLAGS% %CPP_LTO% %FLAGS% ^
        -Wno-c++11-narrowing -Wextra ^
        Cpp/NFS2SE.cpp -o NFS2SE.o ^
        -fno-rtti -fno-exceptions ^
        -I%BYTESWAP_H_DIR% ^
        -D__BYTE_ORDER=1 ^
        -D__LITTLE_ENDIAN=1 ^
        -D__WORDSIZE=32
)
if errorlevel 1 exit /b 1
echo OK!

echo Linking...
set "O_FILES="
for %%F in ("*.o") do (
    if exist "%%~fF" set "O_FILES=!O_FILES! "%%~fF""
)
if /I "%COMPILE_MODE%"=="asm" (
    %LD_EXE% --enable-stdcall-fixup ^
        -o "../Need For Speed II SE/nfs2se.exe" !O_FILES! ^
        -L%MINGW32_LIB_DIR% -L%SDL2_LIB_DIR% ^
        %OPENGL_LIBS% -lSDL2 -lws2_32 -lwinmm -lmsvcrt -lkernel32 ^
        -subsystem=%WIN_SUBSYSTEM% ^
        %STRIP% ^
        -e _start
) else (
    %CLANG_EXE% -fuse-ld=lld ^
        -o "../Need For Speed II SE/nfs2se.exe" ^
        %CPU_FLAGS% %CPP_LTO% !O_FILES! ^
        -L%SDL2_LIB_DIR% ^
        %OPENGL_LIBS% -lSDL2 -lSDL2main -lws2_32 -lwinmm -lm ^
        -Wl,-subsystem,%WIN_SUBSYSTEM% ^
        %STRIP%
)
if errorlevel 1 exit /b 1
echo OK!

echo Copying SDL2.dll...
copy /y "%SDL2_DLL%" "..\Need For Speed II SE\SDL2.dll" >nul
if errorlevel 1 exit /b 1
echo OK!

exit /b 0
