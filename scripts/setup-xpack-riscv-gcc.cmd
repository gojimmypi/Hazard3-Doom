@echo off
rem -----------------------------------------------------------------------------
rem File:        setup-xpack-riscv-gcc.cmd
rem Path:        scripts/setup-xpack-riscv-gcc.cmd
rem
rem Project:     Hazard3-Doom
rem Purpose:     Install and configure the xPack GNU RISC-V Embedded GCC
rem              toolchain for native Windows builds.
rem
rem Copyright (c) 2026 gojimmypi
rem
rem Licensed under the Apache License, Version 2.0.
rem
rem SPDX-License-Identifier: Apache-2.0
rem
rem This software is provided under the terms of the applicable license.
rem See LICENSES/Apache-2.0.txt for the complete license terms.
rem See LICENSING.md for project licensing policy and scope.
rem -----------------------------------------------------------------------------

setlocal EnableExtensions

rem Install xPack GNU RISC-V Embedded GCC into:
rem   <repo>\bin\riscv-gcc
rem
rem This script is expected to live in:
rem   <repo>\scripts\setup-xpack-riscv-gcc.cmd

set "XPACK_VERSION=15.2.0-1"
set "XPACK_ARCHIVE=xpack-riscv-none-elf-gcc-%XPACK_VERSION%-win32-x64.zip"
set "XPACK_URL=https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v%XPACK_VERSION%/%XPACK_ARCHIVE%"
set "XPACK_FOLDER=xpack-riscv-none-elf-gcc-%XPACK_VERSION%"

for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"
set "INSTALL_ROOT=%REPO_ROOT%\bin\riscv-gcc"
set "GCC_EXE=%INSTALL_ROOT%\bin\riscv-none-elf-gcc.exe"

set "WORK_ROOT=%TEMP%\Hazard3-Doom-xpack-%RANDOM%-%RANDOM%"
set "ZIP_PATH=%WORK_ROOT%\%XPACK_ARCHIVE%"
set "EXTRACT_ROOT=%WORK_ROOT%\extract"
set "EXTRACTED_FOLDER=%EXTRACT_ROOT%\%XPACK_FOLDER%"

if exist "%GCC_EXE%" (
    echo xPack RISC-V GCC is already installed:
    echo   %GCC_EXE%
    echo.
    "%GCC_EXE%" --version
    exit /b 0
)

if exist "%INSTALL_ROOT%" (
    echo ERROR: The destination already exists, but GCC was not found:
    echo   %INSTALL_ROOT%
    echo.
    echo Remove the incomplete directory, then run this script again:
    echo   rmdir /s /q "%INSTALL_ROOT%"
    exit /b 1
)

mkdir "%WORK_ROOT%"
if errorlevel 1 goto :fail

mkdir "%EXTRACT_ROOT%"
if errorlevel 1 goto :fail

echo Downloading:
echo   %XPACK_URL%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass ^
    -Command "$ErrorActionPreference = 'Stop'; Invoke-WebRequest -Uri '%XPACK_URL%' -OutFile '%ZIP_PATH%'"
if errorlevel 1 (
    echo ERROR: Download failed.
    goto :fail
)

if not exist "%ZIP_PATH%" (
    echo ERROR: The downloaded ZIP file was not created:
    echo   %ZIP_PATH%
    goto :fail
)

echo Extracting:
echo   %ZIP_PATH%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass ^
    -Command "$ErrorActionPreference = 'Stop'; Expand-Archive -LiteralPath '%ZIP_PATH%' -DestinationPath '%EXTRACT_ROOT%'"
if errorlevel 1 (
    echo ERROR: ZIP extraction failed.
    goto :fail
)

if not exist "%EXTRACTED_FOLDER%\bin\riscv-none-elf-gcc.exe" (
    echo ERROR: The expected compiler was not found after extraction:
    echo   %EXTRACTED_FOLDER%\bin\riscv-none-elf-gcc.exe
    goto :fail
)

if not exist "%REPO_ROOT%\bin" (
    mkdir "%REPO_ROOT%\bin"
    if errorlevel 1 goto :fail
)

mkdir "%INSTALL_ROOT%"
if errorlevel 1 (
    echo ERROR: Could not create the installation directory:
    echo   %INSTALL_ROOT%
    goto :fail
)

echo Installing to:
echo   %INSTALL_ROOT%
echo.

rem Robocopy return codes 0 through 7 indicate success.
robocopy "%EXTRACTED_FOLDER%" "%INSTALL_ROOT%" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS
set "ROBOCOPY_RESULT=%ERRORLEVEL%"

if %ROBOCOPY_RESULT% GEQ 8 (
    echo ERROR: Toolchain copy failed. Robocopy returned %ROBOCOPY_RESULT%.
    goto :fail_installed
)

if not exist "%GCC_EXE%" (
    echo ERROR: Installation completed, but the compiler was not found:
    echo   %GCC_EXE%
    goto :fail_installed
)

echo Verifying installation...
echo.

"%GCC_EXE%" --version
if errorlevel 1 (
    echo ERROR: The compiler did not run successfully.
    goto :fail_installed
)

echo.
echo xPack RISC-V GCC installed successfully:
echo   %INSTALL_ROOT%
echo.

rmdir /s /q "%WORK_ROOT%" >nul 2>&1
exit /b 0

:fail_installed
echo.
echo The incomplete installation directory was left in place for inspection:
echo   %INSTALL_ROOT%
echo.
echo Remove it before retrying:
echo   rmdir /s /q "%INSTALL_ROOT%"
rmdir /s /q "%WORK_ROOT%" >nul 2>&1
exit /b 1

:fail
rmdir /s /q "%WORK_ROOT%" >nul 2>&1
exit /b 1
