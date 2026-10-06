@echo off
setlocal EnableExtensions

rem This script is located in:
rem   Hazard3-Doom\VisualGDB
rem Therefore the repository root is one directory above it.

set "PORT=3333"
set "REPO=%~dp0.."

rem Normal/manual mode starts OpenOCD in a separate console when needed and
rem returns after port 3333 is ready.
rem
rem --server is for VisualGDB's GDBServerCommand. In that mode this script
rem represents the real server lifetime: it runs a new OpenOCD in the foreground
rem or, if OpenOCD is already running, waits for that actual process to exit.
set "PAUSE_BEFORE_EXIT=0"
set "SERVER_MODE=0"
for %%A in (%*) do (
    if /i "%%~A"=="--no-pause" set "PAUSE_BEFORE_EXIT=0"
    if /i "%%~A"=="/nopause" set "PAUSE_BEFORE_EXIT=0"
    if /i "%%~A"=="--server" set "SERVER_MODE=1"
)

for %%I in ("%REPO%") do set "REPO=%%~fI"

set "OPENOCD=%REPO%\bin\openocd.exe"
set "OPENOCD_CFG=%REPO%\openocd\ulx4m-openocd-tigard.cfg"

call :openocd_status
set "OPENOCD_STATUS=%ERRORLEVEL%"

if "%OPENOCD_STATUS%"=="2" (
    echo ERROR: Port %PORT% is already in use by a process other than OpenOCD.
    goto exit_error
)

if "%SERVER_MODE%"=="1" (
    if "%OPENOCD_STATUS%"=="0" goto server_reuse
    goto server_start
)

if "%OPENOCD_STATUS%"=="0" (
    echo [OpenOCD] OpenOCD is already listening on port %PORT%.
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

goto manual_start

:server_reuse
echo [OpenOCD] OpenOCD is already listening on port %PORT%.
echo [OpenOCD] Reusing the existing OpenOCD instance.
rem Emit the same readiness text as OpenOCD so VisualGDB can recognize the stub.
echo Info : Listening on port %PORT% for gdb connections
rem Stay tied to the real OpenOCD process lifetime, not an artificial sleep loop.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$c = Get-NetTCPConnection -State Listen -LocalPort %PORT% -ErrorAction Stop | Select-Object -First 1; $p = Get-Process -Id $c.OwningProcess -ErrorAction Stop; if ($p.ProcessName -ine 'openocd') { exit 2 }; Wait-Process -Id $p.Id"
exit /b %ERRORLEVEL%


:server_start
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

echo [OpenOCD] Starting under VisualGDB:
echo   "%OPENOCD%" -d2 -f "%OPENOCD_CFG%"

pushd "%REPO%"
if errorlevel 1 (
    echo ERROR: Could not change to the repository directory:
    echo   %REPO%
    goto exit_error
)

"%OPENOCD%" -d2 -f "%OPENOCD_CFG%"
set "OPENOCD_EXIT=%ERRORLEVEL%"

popd
exit /b %OPENOCD_EXIT%


:manual_start
echo [OpenOCD] Starting:
echo   "%OPENOCD%" -d2 -f "%OPENOCD_CFG%"

pushd "%REPO%"
if errorlevel 1 (
    echo ERROR: Could not change to the repository directory:
    echo   %REPO%
    goto exit_error
)

rem Open a separate console and keep it open if OpenOCD exits,
rem so startup errors remain visible.
start "Hazard3 OpenOCD" cmd.exe /d /k ""%OPENOCD%" -d2 -f "%OPENOCD_CFG%""

popd

rem Wait up to 15 seconds for OpenOCD to begin listening.
rem Do not use TIMEOUT here: VisualGDB launches this script with redirected
rem standard input, and Windows TIMEOUT exits immediately in that environment.
call :wait_for_openocd
set "OPENOCD_STATUS=%ERRORLEVEL%"
if "%OPENOCD_STATUS%"=="0" (
    echo [OpenOCD] Ready on port %PORT%.
    goto exit_ok
)
if "%OPENOCD_STATUS%"=="2" (
    echo ERROR: Port %PORT% became occupied by a process other than OpenOCD.
    goto exit_error
)

echo ERROR: OpenOCD did not begin listening on port %PORT% within 15 seconds.
echo Check the OpenOCD console for the actual error.
goto exit_error


:wait_for_openocd
rem Return 0 when OpenOCD owns the listening port, 1 on timeout,
rem or 2 if another process owns the port. PowerShell Start-Sleep works
rem correctly even when VisualGDB redirects this script's standard input.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$deadline = (Get-Date).AddSeconds(15); while ((Get-Date) -lt $deadline) { $c = Get-NetTCPConnection -State Listen -LocalPort %PORT% -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { try { $p = Get-Process -Id $c.OwningProcess -ErrorAction Stop; if ($p.ProcessName -ieq 'openocd') { exit 0 } else { exit 2 } } catch { exit 2 } }; Start-Sleep -Milliseconds 250 }; exit 1" ^
    >nul 2>&1

exit /b %ERRORLEVEL%


:openocd_status
rem Return 0 if OpenOCD owns the listening port, 1 if the port is unused,
rem or 2 if another process owns the port.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$c = Get-NetTCPConnection -State Listen -LocalPort %PORT% -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not $c) { exit 1 }; try { $p = Get-Process -Id $c.OwningProcess -ErrorAction Stop; if ($p.ProcessName -ieq 'openocd') { exit 0 } else { exit 2 } } catch { exit 2 }" ^
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
