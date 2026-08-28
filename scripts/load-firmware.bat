@echo off
rem -----------------------------------------------------------------------------
rem File:        load-firmware.bat
rem Path:        scripts/load-firmware.bat
rem
rem Project:     Hazard3-Doom
rem Purpose:     Load and start the Hazard3 resident monitor through
rem              GDB/OpenOCD on Windows.
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

rem Resolve the repository root from this script's location.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

rem Allow GDB to be overridden by setting the GDB environment variable.
rem If the override is missing or invalid, use the repository-local GDB when present.
set "LOCAL_GDB=%ROOT_DIR%\bin\gdb\riscv-none-elf-gdb.exe"
if not defined GDB set "GDB=%LOCAL_GDB%"
if not exist "%GDB%" if exist "%LOCAL_GDB%" set "GDB=%LOCAL_GDB%"

rem Use the first argument as the ELF path, or use the default build output.
if "%~1"=="" (
    set "ELF=%ROOT_DIR%\build\hazard3-boot-monitor.elf"
) else (
    set "ELF=%~1"
)

if not exist "%GDB%" (
    >&2 echo Missing RISC-V GDB executable: %GDB%
    exit /b 1
)

if not exist "%ELF%" (
    >&2 echo Missing firmware ELF: %ELF%
    >&2 echo Expected the firmware at: %ROOT_DIR%\build\hazard3-boot-monitor.elf or specify the prebuilt image in ./bin/ directory.
    exit /b 1
)

rem OpenOCD must already be listening on localhost port 3333.
echo.
echo Running RISC-V GDB...
echo GDB: "%GDB%"
echo ELF: "%ELF%"
echo.

rem Merge GDB stderr into stdout so all GDB output is shown in the console.
"%GDB%" ^
    --batch ^
    "%ELF%" ^
    -ex "set confirm off" ^
    -ex "set pagination off" ^
    -ex "set remotetimeout 120" ^
    -ex "target extended-remote localhost:3333" ^
    -ex "monitor halt" ^
    -ex "load" ^
    -ex "compare-sections" ^
    -ex "set $pc = _start" ^
    -ex "monitor resume" ^
    -ex "disconnect" 2>&1

set "GDB_RESULT=%ERRORLEVEL%"
if not "%GDB_RESULT%"=="0" (
    >&2 echo.
    >&2 echo Firmware load failed.
    >&2 echo Make sure OpenOCD is running and listening on localhost:3333.
    >&2 echo Start OpenOCD in a dedicated windows, then run this script again.
    >&2 echo.
    pause
)

echo Done.
echo Check HDMI display for test pattern.
echo Connect to UART to upload Doom executable.

exit /b %GDB_RESULT%
