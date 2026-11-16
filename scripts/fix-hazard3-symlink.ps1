# -----------------------------------------------------------------------------
# File:        fix-hazard3-symlink.ps1
# Path:        scripts/fix-hazard3-symlink.ps1
#
# Project:     Hazard3-Doom
# Purpose:     Restore Hazard3 symlinks incorrectly reported as modified by Windows Git
#
# Copyright (c) 2026 gojimmypi
#
# Licensed under the Apache License, Version 2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# This software is provided under the terms of the applicable license.
# See LICENSES/Apache-2.0.txt for the complete license terms.
# See LICENSING.md for project licensing policy and scope.
# -----------------------------------------------------------------------------
#
# Restore the three CoreMark symlinks in the Hazard3 submodule using Windows Git.
# The script can be run from any directory. It does not change staged files.
#
# Run from Windows PowerShell at the repository root:
#   .\scripts\fix-hazard3-symlink.ps1
#
# The script also supports invocation by absolute path from any directory.
#
# This changes ONLY the working-tree copies of these three links. It does not
# unstage or modify the four staged FPGA source changes in Hazard3.
#
# If an error occurs: "fix-hazard3-symlink.ps1 is not digitally signed. You
#                      cannot run this script on the current system"
#
# run this:
#
#   Unblock-File .\scripts\fix-hazard3-symlink.ps1
#
# or
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\fix-hazard3-symlink.ps1

$ErrorActionPreference = 'Stop'

# This script lives in Hazard3-Doom/scripts, so its parent is the repo root.
# If it were two levels below the root, use '..\..' instead.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hazard3Dir = Join-Path $repoRoot 'third_party\Hazard3'

$files = @(
    'test/sim/coremark/dist/barebones/hazard3_csr.h'
    'test/sim/coremark/dist/barebones/init.S'
    'test/sim/coremark/dist/barebones/tb_cxxrtl_io.h'
)

# Git paths below are relative to the Hazard3 submodule, not the main repo.
Push-Location $hazard3Dir
try {
    git restore --worktree -- @files
    if ($LASTEXITCODE -ne 0) {
        throw "git restore failed (exit code $LASTEXITCODE)."
    }
    Write-Host 'Restored three Hazard3 CoreMark symlinks.'
}
finally {
    Pop-Location
}
