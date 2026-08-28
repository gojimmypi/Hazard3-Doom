@echo off
REM -----------------------------------------------------------------------------
REM File:        build-wsl.cmd
REM Path:        VisualGDB/build-wsl.cmd
REM
REM Project:     Hazard3-Doom
REM Purpose:     Dispatch build, clean, and rebuild actions from Windows and
REM              VisualGDB into the repository's WSL build scripts.
REM
REM Copyright (c) 2026 gojimmypi
REM
REM Licensed under the Apache License, Version 2.0.
REM
REM SPDX-License-Identifier: Apache-2.0
REM
REM This software is provided under the terms of the applicable license.
REM See LICENSES/Apache-2.0.txt for the complete license terms.
REM See LICENSING.md for project licensing policy and scope.
REM -----------------------------------------------------------------------------

setlocal EnableExtensions DisableDelayedExpansion

set "ACTION=%~1"
if not defined ACTION set "ACTION=build"

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

where wsl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: wsl.exe was not found. Install or enable WSL first. 1>&2
    exit /b 1
)

if not exist "%ROOT%\scripts\build.sh" (
    echo ERROR: "%ROOT%\scripts\build.sh" was not found. 1>&2
    exit /b 1
)

if /i "%ACTION%"=="build" goto build
if /i "%ACTION%"=="clean" goto clean
if /i "%ACTION%"=="rebuild" goto rebuild

echo ERROR: Unknown action "%ACTION%". Use build, clean, or rebuild. 1>&2
exit /b 2

:build
call :enter_root
if errorlevel 1 exit /b %ERRORLEVEL%
wsl.exe --exec /bin/bash ./scripts/build.sh
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%

:clean
call :enter_root
if errorlevel 1 exit /b %ERRORLEVEL%
wsl.exe --exec /bin/bash -c "rm -f -- ./build/hazard3-boot-monitor.elf ./build/hazard3-boot-monitor.map"
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%

:rebuild
call :clean
if errorlevel 1 exit /b %ERRORLEVEL%
goto build

:enter_root
pushd "%ROOT%" >nul
if errorlevel 1 (
    echo ERROR: Could not change to repository root "%ROOT%". 1>&2
    exit /b 1
)
exit /b 0
