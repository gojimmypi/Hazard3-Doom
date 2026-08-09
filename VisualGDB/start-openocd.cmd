@echo off
setlocal EnableExtensions

rem This script is located in:
rem   Hazard3-Doom\VisualGDB
rem Therefore the repository root is one directory above it.

set "PORT=3333"
set "REPO=%~dp0.."

rem Set this to 0 after verifying startup so VisualGDB does not wait for a key.
set "PAUSE_BEFORE_EXIT=0"
if /i "%~1"=="--no-pause" set "PAUSE_BEFORE_EXIT=0"
if /i "%~1"=="/nopause" set "PAUSE_BEFORE_EXIT=0"

for %%I in ("%REPO%") do set "REPO=%%~fI"

set "OPENOCD=%REPO%\bin\openocd.exe"
set "OPENOCD_CFG=%REPO%\openocd\ulx3s-openocd-doom.cfg"

call :port_is_listening
if not errorlevel 1 (
    echo [OpenOCD] Port %PORT% is already listening.
    echo [OpenOCD] Reusing the existing OpenOCD instance.
    goto exit_ok
)

if not exist "%OPENOCD%" (
    echo ERROR: OpenOCD was not found:
    echo   %OPENOCD%
    goto exit_error
)

if not exist "%OPENOCD_CFG%" (
    echo ERROR: OpenOCD configuration was not found:
    echo   %OPENOCD_CFG%
    goto exit_error
)

echo [OpenOCD] Starting:
echo   "%OPENOCD%" -f "%OPENOCD_CFG%"

pushd "%REPO%"
if errorlevel 1 (
    echo ERROR: Could not change to the repository directory:
    echo   %REPO%
    goto exit_error
)

rem Open a separate console and keep it open if OpenOCD exits,
rem so startup errors remain visible.
start "Hazard3 OpenOCD" cmd.exe /d /k ""%OPENOCD%" -f "%OPENOCD_CFG%""

popd

rem Wait up to 15 seconds for OpenOCD to begin listening.
for /L %%N in (1,1,15) do (
    timeout /t 1 /nobreak >nul

    call :port_is_listening
    if not errorlevel 1 (
        echo [OpenOCD] Ready on port %PORT%.
        goto exit_ok
    )
)

echo ERROR: OpenOCD did not begin listening on port %PORT%.
echo Check the OpenOCD console for the actual error.
goto exit_error


:port_is_listening
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "if (Get-NetTCPConnection -State Listen -LocalPort %PORT% -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" ^
    >nul 2>&1

exit /b %ERRORLEVEL%


:exit_error
if "%PAUSE_BEFORE_EXIT%"=="1" (
    echo.
    pause
)
exit /b 1


:exit_ok
if "%PAUSE_BEFORE_EXIT%"=="1" (
    echo.
    pause
)
exit /b 0
