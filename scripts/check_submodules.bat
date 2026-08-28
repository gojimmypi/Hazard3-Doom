@echo off
rem -----------------------------------------------------------------------------
rem File:        check_submodules.bat
rem Path:        scripts/check_submodules.bat
rem
rem Project:     Hazard3-Doom
rem Purpose:     Check local Git submodule commits and configured remote
rem              branches from Windows.
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

rem Check whether each Git submodule is:
rem   1. checked out at the commit expected by the parent repository, and
rem   2. current with its configured remote branch.
rem
rem Normally run from the repository root:
rem   scripts\check_submodules.bat
rem
rem The script also works when launched from the scripts directory.

rem Resolve the repository root from this script's location.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_HINT=%%~fI"

set "REPO_ROOT="
for /f "delims=" %%I in ('git -C "%REPO_HINT%" rev-parse --show-toplevel 2^>nul') do set "REPO_ROOT=%%I"

if not defined REPO_ROOT (
    echo ERROR: Could not locate the Git repository root.
    exit /b 2
)

pushd "%REPO_ROOT%" >nul || exit /b 2

if not exist ".gitmodules" (
    echo No .gitmodules file was found. This repository has no configured submodules.
    popd
    exit /b 0
)

set "PARENT_BRANCH="
for /f "delims=" %%I in ('git symbolic-ref --quiet --short HEAD 2^>nul') do set "PARENT_BRANCH=%%I"

set /a TOTAL=0
set /a CURRENT=0
set /a PROBLEMS=0
set /a WARNINGS=0

echo Repository: "%REPO_ROOT%"
echo Checking submodules against the parent repository and remote branches...

set "PARENT_REPO=."
for /f "tokens=1,*" %%A in ('git config -f .gitmodules --get-regexp "^submodule\..*\.path$" 2^>nul') do call :CheckSubmodule "%%A" "%%B"

if exist "third_party\Hazard3\.gitmodules" (
    set "PARENT_REPO=third_party\Hazard3"
    set "PARENT_BRANCH="
    for /f "delims=" %%I in ('git -C "!PARENT_REPO!" symbolic-ref --quiet --short HEAD 2^>nul') do set "PARENT_BRANCH=%%I"
    for /f "tokens=1,*" %%A in ('git -C "!PARENT_REPO!" config -f .gitmodules --get-regexp "^submodule\.example_soc/libfpga\.path$" 2^>nul') do call :CheckSubmodule "%%A" "%%B"
)

echo.
echo Checked: !TOTAL!  Current: !CURRENT!  Problems: !PROBLEMS!  Warnings: !WARNINGS!

popd

if not "!PROBLEMS!"=="0" exit /b 1
exit /b 0

:CheckSubmodule
set /a TOTAL+=1
set "SUB_PROBLEM=0"

set "KEY=%~1"
set "SUB_REL_PATH=%~2"
set "SUB_PATH=!SUB_REL_PATH!"
if /I not "!PARENT_REPO!"=="." set "SUB_PATH=!PARENT_REPO!\!SUB_REL_PATH!"
set "NAME=!KEY:submodule.=!"
set "NAME=!NAME:.path=!"

echo.
echo [!SUB_PATH!]

if not exist "!SUB_PATH!\.git" (
    echo   NOT INITIALIZED
    echo   Run: git -C "!PARENT_REPO!" submodule update --init --recursive --checkout -- "!SUB_REL_PATH!"
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

git -C "!SUB_PATH!" rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo   ERROR: The submodule working tree is not usable.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

set "BRANCH="
set "CONFIG_URL="
for /f "delims=" %%I in ('git -C "!PARENT_REPO!" config -f .gitmodules --get "submodule.!NAME!.branch" 2^>nul') do set "BRANCH=%%I"
for /f "delims=" %%I in ('git -C "!PARENT_REPO!" config -f .gitmodules --get "submodule.!NAME!.url" 2^>nul') do set "CONFIG_URL=%%I"

if not defined CONFIG_URL (
    echo   ERROR: No URL is configured for this submodule.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if "!BRANCH!"=="." (
    if defined PARENT_BRANCH (
        set "BRANCH=!PARENT_BRANCH!"
    ) else (
        echo   ERROR: branch=. is configured, but the parent repository has detached HEAD.
        set "SUB_PROBLEM=1"
        goto :FinishSubmodule
    )
)

set "REMOTE="
set "CONFIG_URL_COMPARE=!CONFIG_URL!"
if "!CONFIG_URL_COMPARE:~-1!"=="/" set "CONFIG_URL_COMPARE=!CONFIG_URL_COMPARE:~0,-1!"
if /I "!CONFIG_URL_COMPARE:~-4!"==".git" set "CONFIG_URL_COMPARE=!CONFIG_URL_COMPARE:~0,-4!"

for /f "delims=" %%R in ('git -C "!SUB_PATH!" remote 2^>nul') do (
    set "REMOTE_URL="
    for /f "delims=" %%U in ('git -C "!SUB_PATH!" remote get-url "%%R" 2^>nul') do set "REMOTE_URL=%%U"
    set "REMOTE_URL_COMPARE=!REMOTE_URL!"
    if "!REMOTE_URL_COMPARE:~-1!"=="/" set "REMOTE_URL_COMPARE=!REMOTE_URL_COMPARE:~0,-1!"
    if /I "!REMOTE_URL_COMPARE:~-4!"==".git" set "REMOTE_URL_COMPARE=!REMOTE_URL_COMPARE:~0,-4!"
    if /I "!REMOTE_URL_COMPARE!"=="!CONFIG_URL_COMPARE!" set "REMOTE=%%R"
)

if not defined REMOTE (
    echo   ERROR: No local remote matches the configured URL.
    echo   Configured URL: !CONFIG_URL!
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

git -C "!SUB_PATH!" fetch --quiet "!REMOTE!"
if errorlevel 1 (
    echo   ERROR: Could not fetch !REMOTE!.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if not defined BRANCH (
    git -C "!SUB_PATH!" remote set-head "!REMOTE!" --auto >nul 2>&1

    set "REMOTE_HEAD="
    for /f "delims=" %%I in ('git -C "!SUB_PATH!" symbolic-ref --quiet --short "refs/remotes/!REMOTE!/HEAD" 2^>nul') do set "REMOTE_HEAD=%%I"

    if not defined REMOTE_HEAD (
        echo   ERROR: No branch is configured and !REMOTE!/HEAD could not be determined.
        set "SUB_PROBLEM=1"
        goto :FinishSubmodule
    )

    for /f "tokens=1,* delims=/" %%A in ("!REMOTE_HEAD!") do set "BRANCH=%%B"
)

set "LOCAL_HASH="
set "REMOTE_HASH="
set "PARENT_HASH="
set "INDEX_HASH="

for /f "delims=" %%I in ('git -C "!SUB_PATH!" rev-parse HEAD 2^>nul') do set "LOCAL_HASH=%%I"
for /f "delims=" %%I in ('git -C "!SUB_PATH!" rev-parse "refs/remotes/!REMOTE!/!BRANCH!" 2^>nul') do set "REMOTE_HASH=%%I"
for /f "tokens=3" %%I in ('git -C "!PARENT_REPO!" ls-tree HEAD -- "!SUB_REL_PATH!" 2^>nul') do set "PARENT_HASH=%%I"
for /f "tokens=2" %%I in ('git -C "!PARENT_REPO!" ls-files -s -- "!SUB_REL_PATH!" 2^>nul') do set "INDEX_HASH=%%I"

if not defined LOCAL_HASH (
    echo   ERROR: Could not determine the checked-out commit.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if not defined REMOTE_HASH (
    echo   ERROR: Could not resolve !REMOTE!/!BRANCH!.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if not defined PARENT_HASH (
    echo   ERROR: The parent HEAD does not record this submodule path.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if not defined INDEX_HASH (
    echo   ERROR: The parent index does not record this submodule path.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

set "DIRTY="
for /f "delims=" %%I in ('git -C "!SUB_PATH!" status --porcelain 2^>nul') do set "DIRTY=1"

if defined DIRTY (
    echo   WARNING: The submodule has uncommitted changes.
    set /a WARNINGS+=1
)

rem First verify that the submodule checkout matches the parent index.
rem This prevents accidentally staging an unrelated checkout as the new pointer.
if /I not "!LOCAL_HASH!"=="!INDEX_HASH!" (
    set "SUB_PROBLEM=1"

    if /I "!INDEX_HASH!"=="!REMOTE_HASH!" (
        echo   OUT OF SYNC: checked out !LOCAL_HASH:~0,7!, but the parent expects !INDEX_HASH:~0,7!.
        echo   The parent already records the latest !REMOTE!/!BRANCH! commit.
        echo   Restore: git -C "!PARENT_REPO!" submodule update --init --recursive --checkout -- "!SUB_REL_PATH!"
    ) else if /I "!LOCAL_HASH!"=="!REMOTE_HASH!" (
        echo   UNRECORDED UPDATE: checked out latest !REMOTE!/!BRANCH! at !LOCAL_HASH:~0,7!,
        echo   but the parent index still records !INDEX_HASH:~0,7!.
        echo   Record:  git -C "!PARENT_REPO!" add "!SUB_REL_PATH!"
        echo   Restore: git -C "!PARENT_REPO!" submodule update --recursive --checkout -- "!SUB_REL_PATH!"
    ) else (
        echo   OUT OF SYNC: checked out !LOCAL_HASH:~0,7!, but the parent expects !INDEX_HASH:~0,7!.
        echo   Remote:  !REMOTE!/!BRANCH! is !REMOTE_HASH:~0,7!.
        echo   Restore: git -C "!PARENT_REPO!" submodule update --init --recursive --checkout -- "!SUB_REL_PATH!"
    )

    goto :FinishSubmodule
)

rem The checkout matches the index. Check whether the pointer is merely staged.
if /I not "!INDEX_HASH!"=="!PARENT_HASH!" (
    set "SUB_PROBLEM=1"

    if /I "!LOCAL_HASH!"=="!REMOTE_HASH!" (
        echo   STAGED UPDATE: !LOCAL_HASH:~0,7! matches !REMOTE!/!BRANCH!,
        echo   but parent HEAD still records !PARENT_HASH:~0,7!.
    ) else (
        echo   STAGED POINTER: the index records !INDEX_HASH:~0,7!,
        echo   parent HEAD records !PARENT_HASH:~0,7!, and !REMOTE!/!BRANCH! is !REMOTE_HASH:~0,7!.
    )

    echo   Commit the staged submodule pointer when ready.
    goto :FinishSubmodule
)

rem The checkout, index, and parent HEAD agree. Compare that commit to the remote.
if /I "!LOCAL_HASH!"=="!REMOTE_HASH!" (
    echo   CURRENT: !LOCAL_HASH:~0,7! matches parent HEAD and !REMOTE!/!BRANCH!.
    goto :FinishSubmodule
)

set "AHEAD_COUNT="
set "BEHIND_COUNT="
for /f "delims=" %%I in ('git -C "!SUB_PATH!" rev-list --count "!REMOTE_HASH!..!LOCAL_HASH!" 2^>nul') do set "AHEAD_COUNT=%%I"
for /f "delims=" %%I in ('git -C "!SUB_PATH!" rev-list --count "!LOCAL_HASH!..!REMOTE_HASH!" 2^>nul') do set "BEHIND_COUNT=%%I"

if not defined AHEAD_COUNT (
    echo   ERROR: Could not compare !LOCAL_HASH:~0,7! with !REMOTE!/!BRANCH!.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

set "SUB_PROBLEM=1"

if "!AHEAD_COUNT!"=="0" (
    echo   BEHIND: parent records !LOCAL_HASH:~0,7!; !REMOTE!/!BRANCH! is !REMOTE_HASH:~0,7!.
    echo   Missing commits: !BEHIND_COUNT!
    echo   Update: git -C "!SUB_PATH!" checkout "!REMOTE!/!BRANCH!"
    echo   Then:   git -C "!PARENT_REPO!" add "!SUB_REL_PATH!"
) else if "!BEHIND_COUNT!"=="0" (
    echo   AHEAD: parent records !LOCAL_HASH:~0,7!, which is !AHEAD_COUNT! commit^(s^) ahead of !REMOTE!/!BRANCH!.
) else (
    echo   DIVERGED: parent commit !LOCAL_HASH:~0,7! and !REMOTE!/!BRANCH! at !REMOTE_HASH:~0,7!
    echo   have !AHEAD_COUNT! local-only and !BEHIND_COUNT! remote-only commit^(s^).
)

:FinishSubmodule
if "!SUB_PROBLEM!"=="0" (
    set /a CURRENT+=1
) else (
    set /a PROBLEMS+=1
)

exit /b 0
