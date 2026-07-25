@echo off
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

for /f "tokens=1,*" %%A in ('git config -f .gitmodules --get-regexp "^submodule\..*\.path$" 2^>nul') do call :CheckSubmodule "%%A" "%%B"

echo.
echo Checked: !TOTAL!  Current: !CURRENT!  Problems: !PROBLEMS!  Warnings: !WARNINGS!

popd

if not "!PROBLEMS!"=="0" exit /b 1
exit /b 0

:CheckSubmodule
set /a TOTAL+=1
set "SUB_PROBLEM=0"

set "KEY=%~1"
set "SUB_PATH=%~2"
set "NAME=!KEY:submodule.=!"
set "NAME=!NAME:.path=!"

echo.
echo [!SUB_PATH!]

if not exist "!SUB_PATH!\.git" (
    echo   NOT INITIALIZED
    echo   Run: git submodule update --init --recursive --checkout -- "!SUB_PATH!"
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
for /f "delims=" %%I in ('git config -f .gitmodules --get "submodule.!NAME!.branch" 2^>nul') do set "BRANCH=%%I"

if "!BRANCH!"=="." (
    if defined PARENT_BRANCH (
        set "BRANCH=!PARENT_BRANCH!"
    ) else (
        echo   ERROR: branch=. is configured, but the parent repository has detached HEAD.
        set "SUB_PROBLEM=1"
        goto :FinishSubmodule
    )
)

git -C "!SUB_PATH!" fetch --quiet origin
if errorlevel 1 (
    echo   ERROR: Could not fetch origin.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if not defined BRANCH (
    git -C "!SUB_PATH!" remote set-head origin --auto >nul 2>&1

    set "REMOTE_HEAD="
    for /f "delims=" %%I in ('git -C "!SUB_PATH!" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2^>nul') do set "REMOTE_HEAD=%%I"

    if not defined REMOTE_HEAD (
        echo   ERROR: No branch is configured and origin/HEAD could not be determined.
        set "SUB_PROBLEM=1"
        goto :FinishSubmodule
    )

    set "BRANCH=!REMOTE_HEAD:origin/=!"
)

set "LOCAL_HASH="
set "REMOTE_HASH="
set "PARENT_HASH="
set "INDEX_HASH="

for /f "delims=" %%I in ('git -C "!SUB_PATH!" rev-parse HEAD 2^>nul') do set "LOCAL_HASH=%%I"
for /f "delims=" %%I in ('git -C "!SUB_PATH!" rev-parse "refs/remotes/origin/!BRANCH!" 2^>nul') do set "REMOTE_HASH=%%I"
for /f "tokens=3" %%I in ('git ls-tree HEAD -- "!SUB_PATH!" 2^>nul') do set "PARENT_HASH=%%I"
for /f "tokens=2" %%I in ('git ls-files -s -- "!SUB_PATH!" 2^>nul') do set "INDEX_HASH=%%I"

if not defined LOCAL_HASH (
    echo   ERROR: Could not determine the checked-out commit.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

if not defined REMOTE_HASH (
    echo   ERROR: Could not resolve origin/!BRANCH!.
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
        echo   The parent already records the latest origin/!BRANCH! commit.
        echo   Restore: git submodule update --init --recursive --checkout -- "!SUB_PATH!"
    ) else if /I "!LOCAL_HASH!"=="!REMOTE_HASH!" (
        echo   UNRECORDED UPDATE: checked out latest origin/!BRANCH! at !LOCAL_HASH:~0,7!,
        echo   but the parent index still records !INDEX_HASH:~0,7!.
        echo   Record:  git add "!SUB_PATH!"
        echo   Restore: git submodule update --recursive --checkout -- "!SUB_PATH!"
    ) else (
        echo   OUT OF SYNC: checked out !LOCAL_HASH:~0,7!, but the parent expects !INDEX_HASH:~0,7!.
        echo   Remote:  origin/!BRANCH! is !REMOTE_HASH:~0,7!.
        echo   Restore: git submodule update --init --recursive --checkout -- "!SUB_PATH!"
    )

    goto :FinishSubmodule
)

rem The checkout matches the index. Check whether the pointer is merely staged.
if /I not "!INDEX_HASH!"=="!PARENT_HASH!" (
    set "SUB_PROBLEM=1"

    if /I "!LOCAL_HASH!"=="!REMOTE_HASH!" (
        echo   STAGED UPDATE: !LOCAL_HASH:~0,7! matches origin/!BRANCH!,
        echo   but parent HEAD still records !PARENT_HASH:~0,7!.
    ) else (
        echo   STAGED POINTER: the index records !INDEX_HASH:~0,7!,
        echo   parent HEAD records !PARENT_HASH:~0,7!, and origin/!BRANCH! is !REMOTE_HASH:~0,7!.
    )

    echo   Commit the staged submodule pointer when ready.
    goto :FinishSubmodule
)

rem The checkout, index, and parent HEAD agree. Compare that commit to the remote.
if /I "!LOCAL_HASH!"=="!REMOTE_HASH!" (
    echo   CURRENT: !LOCAL_HASH:~0,7! matches parent HEAD and origin/!BRANCH!.
    goto :FinishSubmodule
)

set "AHEAD_COUNT="
set "BEHIND_COUNT="
for /f "tokens=1,2" %%I in ('git -C "!SUB_PATH!" rev-list --left-right --count "!LOCAL_HASH!...!REMOTE_HASH!" 2^>nul') do (
    set "AHEAD_COUNT=%%I"
    set "BEHIND_COUNT=%%J"
)

if not defined AHEAD_COUNT (
    echo   ERROR: Could not compare !LOCAL_HASH:~0,7! with origin/!BRANCH!.
    set "SUB_PROBLEM=1"
    goto :FinishSubmodule
)

set "SUB_PROBLEM=1"

if "!AHEAD_COUNT!"=="0" (
    echo   BEHIND: parent records !LOCAL_HASH:~0,7!; origin/!BRANCH! is !REMOTE_HASH:~0,7!.
    echo   Missing commits: !BEHIND_COUNT!
    echo   Update: git submodule update --remote --checkout -- "!SUB_PATH!"
    echo   Then:   git add "!SUB_PATH!"
) else if "!BEHIND_COUNT!"=="0" (
    echo   AHEAD: parent records !LOCAL_HASH:~0,7!, which is !AHEAD_COUNT! commit^(s^) ahead of origin/!BRANCH!.
) else (
    echo   DIVERGED: parent commit !LOCAL_HASH:~0,7! and origin/!BRANCH! at !REMOTE_HASH:~0,7!
    echo   have !AHEAD_COUNT! local-only and !BEHIND_COUNT! remote-only commit^(s^).
)

:FinishSubmodule
if "!SUB_PROBLEM!"=="0" (
    set /a CURRENT+=1
) else (
    set /a PROBLEMS+=1
)

exit /b 0
