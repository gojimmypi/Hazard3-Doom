@echo off
rem -----------------------------------------------------------------------------
rem File:        load-fpga-bitstream.bat
rem Path:        scripts/load-fpga-bitstream.bat
rem
rem Project:     Hazard3-Doom
rem Purpose:     Program a Hazard3-Doom FPGA bitstream from Windows using the
rem              configured loader.
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

setlocal EnableExtensions EnableDelayedExpansion

rem Resolve the repository root from this script's location.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

echo Repository root: "%ROOT_DIR%"

if exist "%ROOT_DIR%\build\hazard3-boot-monitor.bit" (
    set "SOURCE_BITSTREAM=%ROOT_DIR%\build\hazard3-boot-monitor.bit"

    echo.
    echo Using locally built FPGA bitstream:
    echo   "!SOURCE_BITSTREAM!"
    echo.
) else (
    if exist "%ROOT_DIR%\bin\fpga_ulx3s_hdmi_doom.bit" (
        set "SOURCE_BITSTREAM=%ROOT_DIR%\bin\fpga_ulx3s_hdmi_doom.bit"

        echo.
        echo WARNING: Using prebuilt FPGA bitstream:
        echo   "!SOURCE_BITSTREAM!"
        echo.
    ) else (
        >&2 echo.
        >&2 echo ERROR: No FPGA bitstream was found.
        >&2 echo.
        >&2 echo Checked:
        >&2 echo   "%ROOT_DIR%\build\hazard3-boot-monitor.bit"
        >&2 echo   "%ROOT_DIR%\bin\fpga_ulx3s_hdmi_doom.bit"
        >&2 echo.
        goto ERROR_EXIT
    )
)

if not exist "%ROOT_DIR%\bin\fujprog-v48-win64.exe" (
    >&2 echo.
    >&2 echo ERROR: fujprog was not found:
    >&2 echo   "%ROOT_DIR%\bin\fujprog-v48-win64.exe"
    >&2 echo.
    goto ERROR_EXIT
)

echo Loading FPGA bitstream:
echo   "!SOURCE_BITSTREAM!"
echo.

"%ROOT_DIR%\bin\fujprog-v48-win64.exe" "!SOURCE_BITSTREAM!"
set "FUJPROG_EXIT=!ERRORLEVEL!"

if not "!FUJPROG_EXIT!"=="0" (
    >&2 echo.
    >&2 echo ERROR: fujprog failed with exit code !FUJPROG_EXIT!.
    >&2 echo.
    >&2 echo Suggested resolution:
    >&2 echo   1. Confirm the ULX3S is powered and connected by USB.
    >&2 echo   2. Close OpenOCD, openFPGALoader, or other software using the FTDI interface.
    >&2 echo   3. Disconnect and reconnect the ULX3S USB cable, then try again.
    >&2 echo.
    exit /b !FUJPROG_EXIT!
)

echo.
echo Done.
exit /b 0

:ERROR_EXIT
exit /b 1
