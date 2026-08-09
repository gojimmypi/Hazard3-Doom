@echo off
setlocal EnableExtensions

rem Native Windows build for the Hazard3 resident monitor.
rem
rem Usage:
rem   build-xpack.cmd [build^|clean^|rebuild] [64m^|32m] [50000000^|25000000]
rem
rem Defaults:
rem   build 64m 50000000
rem
rem Required toolchain:
rem   <repo>\bin\riscv-gcc\bin\riscv-none-elf-gcc.exe

set "ACTION=%~1"
if not defined ACTION set "ACTION=build"

set "MEMORY_PROFILE=%~2"
if not defined MEMORY_PROFILE set "MEMORY_PROFILE=64m"

set "SYSTEM_CLOCK_HZ=%~3"
if not defined SYSTEM_CLOCK_HZ set "SYSTEM_CLOCK_HZ=50000000"

for %%I in ("%~dp0..") do set "ROOT_DIR=%%~fI"

set "SRC_DIR=%ROOT_DIR%\src"
set "DOOM_DIR=%ROOT_DIR%\doom"
set "BUILD_DIR=%ROOT_DIR%\build"
set "TOOLCHAIN_ROOT=%ROOT_DIR%\bin\riscv-gcc"
set "TOOLCHAIN_BIN=%TOOLCHAIN_ROOT%\bin"

set "CC=%TOOLCHAIN_BIN%\riscv-none-elf-gcc.exe"
set "SIZE=%TOOLCHAIN_BIN%\riscv-none-elf-size.exe"
set "OUTPUT_ELF=%BUILD_DIR%\hazard3-test.elf"
set "OUTPUT_MAP=%BUILD_DIR%\hazard3-test.map"

if /i "%ACTION%"=="build" goto :validate
if /i "%ACTION%"=="clean" goto :clean_only
if /i "%ACTION%"=="rebuild" goto :rebuild

echo ERROR: Unsupported action "%ACTION%".
echo Usage: %~nx0 [build^|clean^|rebuild] [64m^|32m] [50000000^|25000000]
exit /b 2

:validate
set "MEMORY_FLAGS="
if /i "%MEMORY_PROFILE%"=="64m" goto :memory_ok
if /i "%MEMORY_PROFILE%"=="32m" (
    set "MEMORY_FLAGS=-DHAZARD3_SDRAM_32MB"
    goto :memory_ok
)

echo ERROR: Unsupported memory profile "%MEMORY_PROFILE%".
echo Use 64m or 32m.
exit /b 2

:memory_ok
if "%SYSTEM_CLOCK_HZ%"=="50000000" goto :clock_ok
if "%SYSTEM_CLOCK_HZ%"=="25000000" goto :clock_ok

echo ERROR: Unsupported system clock "%SYSTEM_CLOCK_HZ%".
echo Use 50000000 or 25000000.
exit /b 2

:clock_ok
call :require_toolchain
if errorlevel 1 exit /b 1

call :require_file "%SRC_DIR%\start.S"
if errorlevel 1 exit /b 1

call :require_file "%SRC_DIR%\main.c"
if errorlevel 1 exit /b 1

call :require_file "%SRC_DIR%\link.ld"
if errorlevel 1 exit /b 1

call :require_file "%DOOM_DIR%\doom_image_loader.c"
if errorlevel 1 exit /b 1

call :require_file "%DOOM_DIR%\doom_wad_loader.c"
if errorlevel 1 exit /b 1

call :require_file "%DOOM_DIR%\doom_port_smoke.c"
if errorlevel 1 exit /b 1

call :require_file "%DOOM_DIR%\sdram_exec_test.c"
if errorlevel 1 exit /b 1

call :require_file "%DOOM_DIR%\sdram_exec_payload.S"
if errorlevel 1 exit /b 1

if not exist "%BUILD_DIR%" (
    mkdir "%BUILD_DIR%"
    if errorlevel 1 (
        echo ERROR: Could not create the build directory:
        echo   %BUILD_DIR%
        exit /b 1
    )
)

echo Hazard3 native Windows build
echo   compiler:       %CC%
echo   SDRAM profile:  %MEMORY_PROFILE%
echo   system clock:   %SYSTEM_CLOCK_HZ% Hz
echo   monitor output: %OUTPUT_ELF%
echo.

pushd "%ROOT_DIR%"
if errorlevel 1 (
    echo ERROR: Could not enter the repository directory:
    echo   %ROOT_DIR%
    exit /b 1
)

"%CC%" ^
    -march=rv32imc_zicsr_zifencei_zba_zbb_zbs ^
    -mabi=ilp32 ^
    -O2 ^
    -fomit-frame-pointer ^
    -g3 ^
    -ffreestanding ^
    -fno-builtin ^
    -nostdlib ^
    -nostartfiles ^
    -Wl,-T,"%SRC_DIR%\link.ld" ^
    -Wl,-Map,"%OUTPUT_MAP%" ^
    -I"%ROOT_DIR%" ^
    -I"%DOOM_DIR%" ^
    %MEMORY_FLAGS% ^
    -DHAZARD3_SYS_CLK_HZ=%SYSTEM_CLOCK_HZ%u ^
    "%SRC_DIR%\start.S" ^
    "%SRC_DIR%\main.c" ^
    "%DOOM_DIR%\doom_image_loader.c" ^
    "%DOOM_DIR%\doom_wad_loader.c" ^
    "%DOOM_DIR%\doom_port_smoke.c" ^
    "%DOOM_DIR%\sdram_exec_test.c" ^
    "%DOOM_DIR%\sdram_exec_payload.S" ^
    -o "%OUTPUT_ELF%"

set "BUILD_RESULT=%ERRORLEVEL%"
popd

if not "%BUILD_RESULT%"=="0" (
    echo.
    echo ERROR: xPack RISC-V GCC returned exit code %BUILD_RESULT%.
    exit /b %BUILD_RESULT%
)

if not exist "%OUTPUT_ELF%" (
    echo ERROR: GCC returned success, but the ELF was not created:
    echo   %OUTPUT_ELF%
    exit /b 1
)

echo.
if exist "%SIZE%" (
    "%SIZE%" "%OUTPUT_ELF%"
    echo.
)

echo Build complete:
echo   %OUTPUT_ELF%
echo   %OUTPUT_MAP%
exit /b 0

:rebuild
call :clean
if errorlevel 1 exit /b 1
set "ACTION=build"
goto :validate

:clean_only
call :clean
exit /b %ERRORLEVEL%

:clean
echo Cleaning native monitor outputs...
if exist "%OUTPUT_ELF%" del /f /q "%OUTPUT_ELF%"
if exist "%OUTPUT_MAP%" del /f /q "%OUTPUT_MAP%"

if exist "%OUTPUT_ELF%" (
    echo ERROR: Could not remove:
    echo   %OUTPUT_ELF%
    exit /b 1
)

if exist "%OUTPUT_MAP%" (
    echo ERROR: Could not remove:
    echo   %OUTPUT_MAP%
    exit /b 1
)

echo Clean complete.
exit /b 0

:require_toolchain
if not exist "%TOOLCHAIN_ROOT%\" goto :toolchain_missing
if not exist "%CC%" goto :toolchain_incomplete

"%CC%" --version >nul 2>&1
if errorlevel 1 goto :toolchain_unusable
exit /b 0

:toolchain_missing
echo.
echo ERROR: Hazard3-Doom RISC-V toolchain is not installed.
echo.
echo Expected compiler:
echo   %CC%
echo.
echo Install the pinned xPack RISC-V GCC toolchain from the repository root:
echo.
echo   scripts\setup-xpack-riscv-gcc.cmd
echo.
echo Then rebuild the project in Visual Studio.
echo The toolchain will be installed locally under:
echo   %TOOLCHAIN_ROOT%
echo.
exit /b 1

:toolchain_incomplete
echo.
echo ERROR: Hazard3-Doom RISC-V toolchain installation is incomplete.
echo.
echo Toolchain directory exists, but the compiler is missing:
echo   %CC%
echo.
echo Remove or rename this directory:
echo   %TOOLCHAIN_ROOT%
echo.
echo Then reinstall from the repository root with:
echo   scripts\setup-xpack-riscv-gcc.cmd
echo.
exit /b 1

:toolchain_unusable
echo.
echo ERROR: Hazard3-Doom RISC-V compiler was found, but could not run.
echo.
echo Compiler:
echo   %CC%
echo.
echo Run this command from a Command Prompt for the detailed error:
echo   "%CC%" --version
echo.
echo If the installation is damaged, remove or rename:
echo   %TOOLCHAIN_ROOT%
echo and reinstall with:
echo   scripts\setup-xpack-riscv-gcc.cmd
echo.
exit /b 1

:require_file
if exist "%~1" exit /b 0

echo ERROR: Missing required file:
echo   %~1
exit /b 1
