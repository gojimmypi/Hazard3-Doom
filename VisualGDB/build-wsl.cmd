@echo off
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
wsl.exe --cd "%ROOT%" --exec /bin/bash ./scripts/build.sh
exit /b %ERRORLEVEL%

:clean
wsl.exe --cd "%ROOT%" --exec /bin/bash -c "rm -f -- ./build/hazard3-test.elf ./build/hazard3-test.map"
exit /b %ERRORLEVEL%

:rebuild
call :clean
if errorlevel 1 exit /b %ERRORLEVEL%
goto build
