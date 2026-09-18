@echo off
rem -----------------------------------------------------------------------------
rem File:        start-openocd.bat
rem Path:        scripts/start-openocd.bat
rem
rem Project:     Hazard3-Doom
rem Purpose:     Start OpenOCD on Windows with the selected Hazard3-Doom board
rem              configuration.
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

set "BOARD=ulx3s-85f"
set "BOARD_WAS_DEFAULT=1"

if "%~1"=="" goto args_parsed
if /I "%~1"=="-h" goto usage_ok
if /I "%~1"=="--help" goto usage_ok
if /I "%~1"=="ulx3s-85f" goto board_selected
if /I "%~1"=="ulx3s-12f" goto board_selected
if /I "%~1"=="ulx3s" goto board_selected
if /I "%~1"=="ulx3s-doom" goto board_selected
if /I "%~1"=="ulx4m" goto board_selected
if /I "%~1"=="ulx4m-ld" goto board_selected
if /I "%~1"=="ulx4m-tigard" goto board_selected
if /I "%~1"=="ulx4m-ld-tigard" goto board_selected
if /I "%~1"=="icebreaker" goto board_selected
set "ARG1=%~1"
if "%ARG1:~0,1%"=="-" goto unknown_option
goto args_parsed

:board_selected
set "BOARD=%~1"
set "BOARD_WAS_DEFAULT=0"
shift

:args_parsed
if not "%~2"=="" goto too_many_args

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"

if "%~1"=="" (
    set "OPENOCD=%ROOT_DIR%\bin\openocd.exe"
) else (
    set "OPENOCD=%~1"
)

if not exist "%OPENOCD%" (
    1>&2 echo ERROR: OpenOCD executable not found:
    1>&2 echo   "%OPENOCD%"
    exit /b 1
)

if /I "%BOARD%"=="ulx3s-85f" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx3s-85f-openocd.cfg"
if /I "%BOARD%"=="ulx3s-12f" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx3s-12f-openocd.cfg"
if /I "%BOARD%"=="ulx3s" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx3s-openocd.cfg"
if /I "%BOARD%"=="ulx3s-doom" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx3s-openocd-doom.cfg"
if /I "%BOARD%"=="ulx4m" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx4m-openocd.cfg"
if /I "%BOARD%"=="ulx4m-ld" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx4m-openocd.cfg"
if /I "%BOARD%"=="ulx4m-tigard" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx4m-openocd-tigard.cfg"
if /I "%BOARD%"=="ulx4m-ld-tigard" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx4m-openocd-tigard.cfg"
if /I "%BOARD%"=="icebreaker" set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\icebreaker-openocd.cfg"

if not exist "%OPENOCD_CONFIG%" (
    1>&2 echo ERROR: OpenOCD configuration not found:
    1>&2 echo   "%OPENOCD_CONFIG%"
    exit /b 1
)

echo Repository root:
echo   %ROOT_DIR%
echo.
call :print_target_summary
echo.
echo OpenOCD executable:
echo   %OPENOCD%
echo.
echo OpenOCD version:
"%OPENOCD%" --version 2>&1
echo.
echo Using config:
echo   %OPENOCD_CONFIG%
echo.
echo Starting OpenOCD...
echo.

"%OPENOCD%" -d2 -f "%OPENOCD_CONFIG%"
exit /b %ERRORLEVEL%

:print_target_summary
set "DEFAULT_NOTE="
if "%BOARD_WAS_DEFAULT%"=="1" set "DEFAULT_NOTE= (default)"
echo Target selection:
echo   Selector:       %BOARD%%DEFAULT_NOTE%
if /I "%BOARD%"=="ulx3s-85f" goto summary_ulx3s_85f
if /I "%BOARD%"=="ulx3s-12f" goto summary_ulx3s_12f
if /I "%BOARD%"=="ulx3s" goto summary_ulx3s_compat
if /I "%BOARD%"=="ulx3s-doom" goto summary_ulx3s_compat
if /I "%BOARD%"=="ulx4m" goto summary_ulx4m
if /I "%BOARD%"=="ulx4m-ld" goto summary_ulx4m
if /I "%BOARD%"=="ulx4m-tigard" goto summary_ulx4m_tigard
if /I "%BOARD%"=="ulx4m-ld-tigard" goto summary_ulx4m_tigard
if /I "%BOARD%"=="icebreaker" goto summary_icebreaker
exit /b 0

:summary_ulx3s_85f
echo   Board:          ULX3S 85F
echo   FPGA:           LFE5U-85F
echo   JTAG IDCODE:    0x41113043
echo   GDB server:     localhost:3333
echo   Adapter:        onboard FT231X, ft232r bit-bang JTAG
echo   Adapter speed:  1000 kHz OpenOCD setting
echo.
echo Memory map:
echo   Internal SRAM:  0x00000000-0x0001ffff  128 KiB
echo     monitor/stack: 0x00000000-0x0000ffff
echo     Doom screen:  0x00010000-0x0001f9ff
echo     OpenOCD work: 0x0001fa00-0x0001ffff  0x600 bytes
echo   SDRAM:          0x20000000-0x23ffffff  64 MiB
echo     Doom image:   0x20100000-0x203fffff
echo     Doom heap:    0x20400000-0x22bfffff
echo     IWAD:         0x22c00000-0x23bfffff
echo     video:        0x23c00000-0x23ffffff
echo.
echo OpenOCD checksum work area:
echo   0x0001fa00 size 0x600, backup enabled.
echo   GDB compare-sections can use the target-side CRC helper.
exit /b 0

:summary_ulx3s_12f
echo   Board:          ULX3S 12F
echo   FPGA:           LFE5U-12F
echo   JTAG IDCODE:    0x21111043
echo   GDB server:     localhost:3333
echo   Adapter:        onboard FT231X, ft232r bit-bang JTAG
echo   Adapter speed:  1000 kHz OpenOCD setting
echo.
echo Memory map:
echo   Bootstrap SRAM: 0x00000000-0x000003ff  1 KiB
echo   SDRAM:          0x20000000-0x21ffffff  32 MiB
echo     monitor load: 0x20000040
echo     Doom image:   0x20100000-0x203fffff
echo     Doom heap:    0x20400000-0x20ffffff
echo     IWAD:         0x21000000-0x21bfffff
echo     video:        0x21c00000-0x21ffffff
echo.
echo OpenOCD checksum work area:
echo   none - the 85F internal-SRAM work area is not valid on the 12F.
echo   compare-sections falls back to direct target reads.
echo   OpenOCD may print a working-memory warning during that fallback.
exit /b 0

:summary_ulx3s_compat
echo   Board:          ULX3S compatibility auto-detect
echo   FPGA IDCODEs:   0x21111043 (12F), 0x41113043 (85F)
echo   GDB server:     localhost:3333
echo   Adapter:        onboard FT231X, ft232r bit-bang JTAG
echo   Adapter speed:  1000 kHz OpenOCD setting
echo.
echo Memory/work-area policy:
echo   No fixed work area is configured because the 12F and 85F
echo   internal-memory layouts differ. Use ulx3s-85f or ulx3s-12f
echo   when the exact board is known.
exit /b 0

:summary_ulx4m
echo   Board:          ULX4M-LD
echo   GDB server:     localhost:3333
echo   Config:         ULX4M onboard debug path
exit /b 0

:summary_ulx4m_tigard
echo   Board:          ULX4M-LD
echo   GDB server:     localhost:3333
echo   Config:         external Tigard JTAG
exit /b 0

:summary_icebreaker
echo   Board:          iCEBreaker
echo   GDB server:     localhost:3333
exit /b 0

:unknown_option
1>&2 echo ERROR: Unknown option: %~1
1>&2 echo.
call :usage 1>&2
exit /b 2

:too_many_args
1>&2 echo ERROR: Expected at most BOARD and OPENOCD arguments.
1>&2 echo.
call :usage 1>&2
exit /b 2

:usage_ok
call :usage
exit /b 0

:usage
echo Usage:
echo   scripts\start-openocd.bat [BOARD] [OPENOCD]
echo   scripts\start-openocd.bat [OPENOCD]
echo   scripts\start-openocd.bat -h ^| --help
echo.
echo Start the Hazard3-Doom OpenOCD server for BOARD.
echo The default board is ulx3s-85f.
echo.
echo Arguments:
echo   BOARD      Optional board/configuration selector:
echo                ulx3s-85f      openocd\ulx3s-85f-openocd.cfg (default)
echo                ulx3s-12f      openocd\ulx3s-12f-openocd.cfg
echo                ulx3s          openocd\ulx3s-openocd.cfg
echo                               compatibility auto-detect; no fixed work area
echo                ulx3s-doom     openocd\ulx3s-openocd-doom.cfg
echo                               compatibility auto-detect; no fixed work area
echo                ulx4m          openocd\ulx4m-openocd.cfg
echo                ulx4m-tigard   openocd\ulx4m-openocd-tigard.cfg
echo                icebreaker     openocd\icebreaker-openocd.cfg
echo              ulx4m-ld and ulx4m-ld-tigard are accepted aliases.
echo   OPENOCD    Optional OpenOCD executable path. Default: bin\openocd.exe
echo.
echo Options:
echo   -h, --help Show this help and exit.
echo.
echo Examples:
echo   scripts\start-openocd.bat
echo   scripts\start-openocd.bat ulx3s-85f
echo   scripts\start-openocd.bat ulx3s-12f
echo   scripts\start-openocd.bat ulx4m
echo   scripts\start-openocd.bat C:\tools\openocd.exe
echo   scripts\start-openocd.bat ulx3s-85f C:\tools\openocd.exe
exit /b 0
