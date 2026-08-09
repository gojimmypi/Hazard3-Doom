@echo off
REM Starts a listening OpenOCD server using ulx3s-openocd.cfg
setlocal EnableExtensions

echo Starting OpenOCD for Doom...

rem Resolve the repository root from this script's location.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ROOT_DIR=%%~fI"


rem Use the first argument as the OpenOCD path, or use the prebuilt bin
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

set "OPENOCD_CONFIG=%ROOT_DIR%\openocd\ulx3s-openocd-doom.cfg"

if not exist "%OPENOCD_CONFIG%" (
    1>&2 echo ERROR: OpenOCD configuration not found:
    1>&2 echo   "%OPENOCD_CONFIG%"
    exit /b 1
)

echo OPENOCD_CONFIG=%OPENOCD_CONFIG%
"%OPENOCD%" -d2 -f "%OPENOCD_CONFIG%"
