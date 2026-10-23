#!/usr/bin/env bash
# Verify the known OSS CAD Suite 2026-07-20 tool builds for ULX5M-GS sweeps.
set -euo pipefail

expected_suite=2026-07-20
expected_yosys='Yosys 0.67+47 (git sha1 5f29546d8'
expected_nextpnr='nextpnr-0.10-95-gddc6c8c8'
nextpnr=${NEXTPNR:-nextpnr-himbaechel}

if [[ ${OSS_CAD_SUITE_VERSION:-$expected_suite} != "$expected_suite" ]]; then
    printf 'ERROR: ULX5M sweep requires OSS CAD Suite %s, not %s.\n' \
        "$expected_suite" "${OSS_CAD_SUITE_VERSION}" >&2
    exit 1
fi

yosys_version=$(yosys -V)
nextpnr_version=$("$nextpnr" --version 2>&1)
printf '%s\n%s\n' "$yosys_version" "$nextpnr_version"

if [[ $yosys_version != *"$expected_yosys"* ]]; then
    printf 'ERROR: unexpected Yosys build; expected %s.\n' "$expected_yosys" >&2
    exit 1
fi
if [[ $nextpnr_version != *"$expected_nextpnr"* ]]; then
    printf 'ERROR: unexpected nextpnr build; expected %s.\n' "$expected_nextpnr" >&2
    exit 1
fi
printf 'PASS: pinned Yosys and nextpnr versions match OSS CAD Suite %s.\n' "$expected_suite"
