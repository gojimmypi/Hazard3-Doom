# Read-only ULX5M SERV USB tests. Run from native Windows PowerShell.
# Load the known-good SERV bitstream into FPGA SRAM manually before testing.
# Never invokes openFPGALoader, DFU download, or flash write/erase.
param(
    [ValidateRange(1, 1000000)][int]$Rounds = 32,
    [switch]$Capture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$boot = Join-Path $repo 'bootloader-serv'
$tests = Join-Path $boot 'tests'
$dll = Join-Path $repo 'bin\libusb-1.0.dll'
$output = Join-Path $boot 'build-ulx5m-gs\hardware'

if (-not (Test-Path $dll -PathType Leaf)) {
    throw "Missing $dll (required by the existing Windows PyUSB scripts)."
}
if (-not (Test-Path $tests -PathType Container)) {
    throw "Missing $tests"
}
$launcher = Get-Command py.exe -ErrorAction SilentlyContinue
$prefix = @()
if ($null -ne $launcher) {
    $python = $launcher.Source
    $prefix = @('-3')
} else {
    $launcher = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -eq $launcher) {
        throw 'Native Windows Python is missing (py.exe -3 or python.exe).'
    }
    $python = $launcher.Source
}

function Invoke-Python {
    param([string]$Title, [string[]]$Arguments)
    Write-Host "`n=== $Title ==="
    & $python @prefix @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Title failed (exit $LASTEXITCODE)"
    }
    Write-Host "[PASS] $Title"
}

# Do not silently use WSL Python; these scripts require native Windows USB.
# Windows PowerShell 5.1 can strip embedded quotes when forwarding Python -c.
# Use a quote-free Windows-only API check for reliable native invocation.
Invoke-Python 'Native Windows Python and PyUSB' @('-c', 'import sys, usb.core, usb.backend.libusb1; sys.getwindowsversion()')
New-Item -ItemType Directory -Force -Path $output | Out-Null
Push-Location $repo
$passed = 0
$failed = 0
try {
    $checks = @(
        @{Name='Read-only JEDEC and flash sample'; Args=@((Join-Path $tests 'read-ulx5m-flash.py'), '--offset', '0', '--length', '32')},
        @{Name='EP0 ACK and status diagnostics'; Args=@((Join-Path $tests 'diagnose-ulx5m-serv-ep0.py'), '--rounds', "$Rounds", '--delay-ms', '100')},
        @{Name='USB descriptor A/B measurements'; Args=@((Join-Path $tests 'compare-ulx5m-serv-usb-link.py'), '--tag', 'local-direct', '--rounds', "$Rounds", '--delay-ms', '100', '--output', (Join-Path $output 'descriptor-ab.csv'))},
        @{Name='USB descriptor stress'; Args=@((Join-Path $tests 'stress-ulx5m-serv-ep0.py'), '--runs', '2', '--rounds', "$Rounds", '--delay-ms', '100')}
    )
    if ($Capture) {
        # Requires an already frozen capture; intentionally does not rearm it.
        $checks += @{Name='Read frozen USB capture'; Args=@((Join-Path $tests 'capture-ulx5m-serv-ep0-raw.py'), '--dump', '--output', (Join-Path $output 'usb-raw'))}
    }
    foreach ($check in $checks) {
        try {
            Invoke-Python $check.Name $check.Args
            $passed++
        } catch {
            Write-Host "[FAIL] $($check.Name): $_"
            $failed++
        }
    }
} finally {
    Pop-Location
}
Write-Host "`n=== ULX5M USB hardware tests: $passed passed, $failed failed ==="
if ($failed -gt 0) {
    exit 1
}
