#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        test-scripts.sh
# Path:        scripts/test-scripts.sh
#
# Project:     Hazard3-Doom
# Purpose:     Run syntax, lint, smoke, and optional integration tests for
#              project scripts.
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

set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${REPO_ROOT}/build/script-tests"
PYTHON_CACHE_DIR="${TEST_DIR}/pycache"
COMMAND_LOG="${TEST_DIR}/last-command.log"
INTEGRATION_LOG_DIR="${TEST_DIR}/integration-logs"
INTEGRATION_STATE_BEFORE="${TEST_DIR}/tracked-state-before.txt"
INTEGRATION_STATE_AFTER="${TEST_DIR}/tracked-state-after.txt"

run_integration=0
dry_run=0

passed=0
failed=0
warned=0
skipped=0
LAST_COMMAND_STATUS=0

pass()
{
    printf 'PASS  %s\n' "$1"
    passed=$((passed + 1))
}

fail()
{
    printf 'FAIL  %s\n' "$1" >&2
    failed=$((failed + 1))
}

warn()
{
    printf 'WARN  %s\n' "$1" >&2
    warned=$((warned + 1))
}

skip()
{
    printf 'SKIP  %s\n' "$1"
    skipped=$((skipped + 1))
}

usage()
{
    cat <<EOF_USAGE
Usage: ${0##*/} [--integration] [--dry-run]

With no options, run syntax, lint, and safe smoke tests. The default run
first checks its host prerequisites with requirements-check.sh --test-scripts.
Integration mode uses the full development requirements check.

  --integration  Also run real builds and two-seed routed FPGA sweeps.
  --dry-run      With --integration, print long-running commands only.
  -h, --help     Show this help text.

Integration defaults:
  SCRIPT_TEST_ULX3S_85F_SEEDS="11 178"
  SCRIPT_TEST_ULX3S_12F_SEEDS="82 37"
  SCRIPT_TEST_ULX4M_LD_SEEDS="83 45"
  SCRIPT_TEST_SWEEP_JOBS=1
  SCRIPT_TEST_REQUIRE_TIMING_PASS=0

SCRIPT_TEST_SWEEP_SEEDS overrides all three target-specific seed lists.

All test logs and generated test artifacts are kept below build/script-tests/.
Normal board build and sweep artifacts remain below build/.
EOF_USAGE
}

parse_args()
{
    while (( $# > 0 )); do
        case "$1" in
        --integration)
            run_integration=1
            ;;
        --dry-run)
            dry_run=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        esac
        shift
    done

    if (( dry_run == 1 && run_integration == 0 )); then
        printf '%s\n' '--dry-run requires --integration.' >&2
        exit 2
    fi
}

run_quiet()
{
    local label="$1"

    shift
    if "$@" > "${COMMAND_LOG}" 2>&1; then
        pass "${label}"
    else
        fail "${label}"
        cat "${COMMAND_LOG}" >&2
    fi
}

check_requirements()
{
    local -a args=()

    if (( run_integration == 0 )); then
        args+=(--test-scripts)
    fi

    if "${SCRIPT_DIR}/requirements-check.sh" "${args[@]}" > "${COMMAND_LOG}" 2>&1; then
        if (( run_integration == 1 )); then
            pass 'requirements-check.sh: full development environment'
        else
            pass 'requirements-check.sh: test-scripts prerequisites'
        fi
        return 0
    fi

    fail 'requirements-check.sh: prerequisites'
    cat "${COMMAND_LOG}" >&2
    return 1
}

print_command()
{
    printf '      '
    printf '%q ' "$@"
    printf '\n'
}

run_logged()
{
    local label="$1"
    local log_name="$2"
    local status

    shift 2
    printf '\n== %s ==\n' "${label}"
    print_command "$@"

    if (( dry_run == 1 )); then
        LAST_COMMAND_STATUS=0
        skip "${label}: integration dry run"
        return
    fi

    mkdir -p "${INTEGRATION_LOG_DIR}"
    (
        cd -- "${REPO_ROOT}" || exit
        "$@"
    ) 2>&1 | tee "${INTEGRATION_LOG_DIR}/${log_name}.log"
    status="${PIPESTATUS[0]}"
    LAST_COMMAND_STATUS="${status}"

    if (( status == 0 )); then
        pass "${label}"
    else
        fail "${label}: exit ${status}; see build/script-tests/integration-logs/${log_name}.log"
    fi
}

check_sweep_timing()
{
    local label="$1"
    local results_file="$2"
    local pass_count

    if [[ ! -s "${results_file}" ]]; then
        fail "${label}: missing results file ${results_file#"${REPO_ROOT}/"}"
        return
    fi

    pass_count="$(awk -F, 'NR > 1 && $NF == "PASS" { count++ } END { print count + 0 }' \
        "${results_file}")"
    if (( pass_count > 0 )); then
        pass "${label}: ${pass_count} timing-passing seed(s)"
    elif [[ "${SCRIPT_TEST_REQUIRE_TIMING_PASS:-0}" == 1 ]]; then
        fail "${label}: routes completed, but no sampled seed closed timing"
    else
        warn "${label}: routes completed, but no sampled seed closed timing"
    fi
}

capture_tracked_state()
{
    local candidate
    local diff_hash
    local top
    local -a candidates=(
        "${REPO_ROOT}"
        "${REPO_ROOT}/third_party/doomgeneric"
        "${REPO_ROOT}/third_party/Hazard3"
        "${REPO_ROOT}/third_party/Hazard3/scripts"
        "${REPO_ROOT}/third_party/Hazard3/example_soc/libfpga"
    )
    local -A seen=()

    for candidate in "${candidates[@]}"; do
        [[ -d "${candidate}" ]] || continue
        top="$(git -C "${candidate}" rev-parse --show-toplevel 2>/dev/null)" || continue
        [[ -z "${seen[${top}]+x}" ]] || continue
        seen["${top}"]=1

        diff_hash="$(git -C "${top}" diff --binary HEAD | sha256sum | awk '{print $1}')"
        printf 'repository=%s\n' "${top#"${REPO_ROOT}"/}"
        printf 'head=%s\n' "$(git -C "${top}" rev-parse HEAD)"
        printf 'tracked_diff_sha256=%s\n' "${diff_hash}"
        git -C "${top}" status --porcelain=v1 --untracked-files=no
    done
}

verify_tracked_state()
{
    if (( dry_run == 1 )); then
        skip 'integration tracked-state check: integration dry run'
        return
    fi
    if ! git -C "${REPO_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
        skip 'integration tracked-state check: not inside a Git checkout'
        return
    fi

    capture_tracked_state > "${INTEGRATION_STATE_AFTER}"
    if cmp -s "${INTEGRATION_STATE_BEFORE}" "${INTEGRATION_STATE_AFTER}"; then
        pass 'integration builds: tracked checkout state unchanged'
    else
        fail 'integration builds: tracked checkout state changed'
        diff -u "${INTEGRATION_STATE_BEFORE}" "${INTEGRATION_STATE_AFTER}" >&2 || true
    fi
}

check_shell_scripts()
{
    local script
    local relative

    while IFS= read -r -d '' script; do
        relative="${script#"${REPO_ROOT}/"}"

        if bash -n "${script}" > "${COMMAND_LOG}" 2>&1; then
            pass "${relative}: bash syntax"
        else
            fail "${relative}: bash syntax"
            cat "${COMMAND_LOG}" >&2
        fi

        if (
            cd -- "${REPO_ROOT}"
            shellcheck -x "${relative}"
        ) > "${COMMAND_LOG}" 2>&1; then
            pass "${relative}: ShellCheck"
        else
            fail "${relative}: ShellCheck"
            cat "${COMMAND_LOG}" >&2
        fi
    done < <(
        find "${SCRIPT_DIR}" -maxdepth 1 -type f -name '*.sh' -print0 |
            LC_ALL=C sort -z
    )
}

check_python_scripts()
{
    local script
    local relative

    while IFS= read -r -d '' script; do
        relative="${script#"${REPO_ROOT}/"}"
        if PYTHONPYCACHEPREFIX="${PYTHON_CACHE_DIR}" \
            python3 -m py_compile "${script}" > "${COMMAND_LOG}" 2>&1; then
            pass "${relative}: Python compile"
        else
            fail "${relative}: Python compile"
            cat "${COMMAND_LOG}" >&2
        fi
    done < <(
        find "${SCRIPT_DIR}" -maxdepth 1 -type f -name '*.py' -print0 |
            LC_ALL=C sort -z
    )
}

check_powershell_scripts()
{
    local script
    local relative

    while IFS= read -r -d '' script; do
        relative="${script#"${REPO_ROOT}/"}"
        if ! command -v pwsh >/dev/null 2>&1; then
            skip "${relative}: PowerShell parser unavailable"
            continue
        fi

        # The single quotes intentionally protect PowerShell variables from Bash.
        # shellcheck disable=SC2016
        if pwsh -NoLogo -NoProfile -NonInteractive -Command '
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $args[0], [ref]$tokens, [ref]$errors) | Out-Null
            if ($errors.Count -ne 0) {
                $errors | ForEach-Object { [Console]::Error.WriteLine($_) }
                throw "PowerShell parse failed"
            }
        ' "${script}" > "${COMMAND_LOG}" 2>&1; then
            pass "${relative}: PowerShell syntax"
        else
            fail "${relative}: PowerShell syntax"
            cat "${COMMAND_LOG}" >&2
        fi
    done < <(
        find "${SCRIPT_DIR}" -maxdepth 1 -type f -name '*.ps1' -print0 |
            LC_ALL=C sort -z
    )
}

report_target_specific_scripts()
{
    local script
    local relative

    while IFS= read -r -d '' script; do
        relative="${script#"${REPO_ROOT}/"}"
        skip "${relative}: Windows command script requires Windows"
    done < <(
        find "${SCRIPT_DIR}" -maxdepth 1 -type f \
            \( -name '*.bat' -o -name '*.cmd' \) -print0 |
            LC_ALL=C sort -z
    )

    while IFS= read -r -d '' script; do
        relative="${script#"${REPO_ROOT}/"}"
        skip "${relative}: GDB command file requires a target session"
    done < <(
        find "${SCRIPT_DIR}" -type f -name '*.gdb' -print0 |
            LC_ALL=C sort -z
    )
}

check_seed_matrix()
{
    local actual
    local expected

    expected='{"include":[{"group":"01","seeds":"1 2 3 4"},{"group":"02","seeds":"5 6 7 8"},{"group":"03","seeds":"9 10"}]}'
    if actual="$(
        "${SCRIPT_DIR}/generate-ecp5-seed-matrix.py" \
            --first 1 --last 10 --per-job 4
    )" && [[ "${actual}" == "${expected}" ]]; then
        pass 'generate-ecp5-seed-matrix.py: grouped output'
    else
        fail 'generate-ecp5-seed-matrix.py: grouped output'
        printf '      expected: %s\n      actual:   %s\n' \
            "${expected}" "${actual:-<command failed>}" >&2
    fi

    if "${SCRIPT_DIR}/generate-ecp5-seed-matrix.py" \
        --first 10 --last 1 --per-job 4 > "${COMMAND_LOG}" 2>&1; then
        fail 'generate-ecp5-seed-matrix.py: rejects reversed range'
    else
        pass 'generate-ecp5-seed-matrix.py: rejects reversed range'
    fi
}

check_sweep_dispatcher()
{
    local target
    local netlist
    local sweep_dir

    run_quiet 'sweep-ecp5.sh: list targets' \
        "${SCRIPT_DIR}/sweep-ecp5.sh" --list-targets

    for target in ulx3s-85f ulx3s-12f ulx4m-ld-85f; do
        if netlist="$(
            "${SCRIPT_DIR}/sweep-ecp5.sh" --print-netlist "${target}"
        )" && [[ "${netlist}" == build/* ]]; then
            pass "sweep-ecp5.sh: ${target} netlist path"
        else
            fail "sweep-ecp5.sh: ${target} netlist path"
        fi

        if sweep_dir="$(
            "${SCRIPT_DIR}/sweep-ecp5.sh" --print-sweep-dir "${target}" |
                tail -n 1
        )" && [[ "${sweep_dir}" == build/* ]]; then
            pass "sweep-ecp5.sh: ${target} sweep path"
        else
            fail "sweep-ecp5.sh: ${target} sweep path"
        fi
    done
}

validate_integration_settings()
{
    local label
    local seed
    local -a seeds

    while (( $# > 0 )); do
        label="$1"
        read -r -a seeds <<< "$2"
        if (( ${#seeds[@]} == 0 )); then
            printf '%s must contain at least one seed.\n' "${label}" >&2
            return 1
        fi
        for seed in "${seeds[@]}"; do
            if [[ ! "${seed}" =~ ^[1-9][0-9]*$ ]] || (( seed > 260 )); then
                printf 'Invalid seed in %s: %s (expected 1 through 260).\n' \
                    "${label}" "${seed}" >&2
                return 1
            fi
        done
        shift 2
    done

    if [[ ! "${SCRIPT_TEST_SWEEP_JOBS:-1}" =~ ^[1-9][0-9]*$ ]]; then
        printf 'SCRIPT_TEST_SWEEP_JOBS must be a positive integer.\n' >&2
        return 1
    fi
    case "${SCRIPT_TEST_REQUIRE_TIMING_PASS:-0}" in
    0|1)
        ;;
    *)
        printf 'SCRIPT_TEST_REQUIRE_TIMING_PASS must be 0 or 1.\n' >&2
        return 1
        ;;
    esac
}

run_integration_tests()
{
    local jobs="${SCRIPT_TEST_SWEEP_JOBS:-1}"
    local shared_seeds="${SCRIPT_TEST_SWEEP_SEEDS:-}"
    local -a ulx3s_85f_seeds
    local -a ulx3s_12f_seeds
    local -a ulx4m_ld_seeds

    read -r -a ulx3s_85f_seeds <<< \
        "${SCRIPT_TEST_ULX3S_85F_SEEDS:-${shared_seeds:-11 178}}"
    read -r -a ulx3s_12f_seeds <<< \
        "${SCRIPT_TEST_ULX3S_12F_SEEDS:-${shared_seeds:-82 37}}"
    read -r -a ulx4m_ld_seeds <<< \
        "${SCRIPT_TEST_ULX4M_LD_SEEDS:-${shared_seeds:-83 45}}"

    printf '\nIntegration sample: parallel routes=%s\n' "${jobs}"
    printf '  ULX3S 85F seeds:  %s\n' "${ulx3s_85f_seeds[*]}"
    printf '  ULX3S 12F seeds:  %s\n' "${ulx3s_12f_seeds[*]}"
    printf '  ULX4M-LD seeds:   %s\n' "${ulx4m_ld_seeds[*]}"

    if (( dry_run == 0 )) && \
        git -C "${REPO_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
        capture_tracked_state > "${INTEGRATION_STATE_BEFORE}"
    fi

    run_logged 'full-clean.sh: cleanup preview' 'full-clean-dry-run' \
        "${SCRIPT_DIR}/full-clean.sh" --dry-run
    run_logged 'hazard3-submodule.sh: local source status' \
        'hazard3-submodule-status' \
        "${SCRIPT_DIR}/hazard3-submodule.sh" status
    run_logged 'hazard3-doom-source-status.sh: remote source audit' \
        'hazard3-doom-source-status' \
        "${SCRIPT_DIR}/hazard3-doom-source-status.sh"

    run_logged 'build-coremark.sh: baseline build' 'build-coremark' \
        env \
            HAZARD3_COREMARK_BUILD_DIR="${TEST_DIR}/coremark/baseline" \
            "${SCRIPT_DIR}/build-coremark.sh"
    run_logged 'peek-elf.sh: inspect CoreMark output' 'peek-elf' \
        "${SCRIPT_DIR}/peek-elf.sh" \
            "${TEST_DIR}/coremark/baseline/coremark-performance.map" \
            "${TEST_DIR}/coremark/baseline/coremark-performance.elf"
    run_logged 'build-doom-noncombat.sh: isolated Doom build' \
        'build-doom-noncombat' \
        env \
            HAZARD3_DOOM_NONCOMBAT_BUILD_DIR="${TEST_DIR}/doom-image-noncombat" \
            "${SCRIPT_DIR}/build-doom-noncombat.sh"

    run_logged 'build-ulx3s-doom.sh: complete ULX3S 85F build' \
        'build-ulx3s-doom' \
        env \
            FORCE_BITSTREAM_REBUILD=1 \
            HAZARD3_BUILD_DIR="${TEST_DIR}/ulx3s-85f/monitor" \
            HAZARD3_DOOM_BUILD_DIR="${TEST_DIR}/ulx3s-85f/doom-image" \
            "${SCRIPT_DIR}/build-ulx3s-doom.sh"
    if (( LAST_COMMAND_STATUS == 0 )); then
        run_logged 'sweep-ecp5.sh: ULX3S 85F routed sample' \
            'sweep-ulx3s-85f' \
            env SWEEP_JOBS="${jobs}" SWEEP_SKIP_SYNTH=1 \
                "${SCRIPT_DIR}/sweep-ecp5.sh" ulx3s-85f \
                "${ulx3s_85f_seeds[@]}"
        if (( dry_run == 0 && LAST_COMMAND_STATUS == 0 )); then
            check_sweep_timing 'ULX3S 85F routed sample' \
                "${REPO_ROOT}/build/ulx3s-seed-sweep/results-selected.csv"
        fi
    else
        skip 'sweep-ecp5.sh: ULX3S 85F build prerequisite failed'
    fi

    run_logged 'build-ulx3s-12f-doom.sh: complete ULX3S 12F build' \
        'build-ulx3s-12f-doom' \
        env \
            FORCE_BITSTREAM_REBUILD=1 \
            HAZARD3_BUILD_DIR="${TEST_DIR}/ulx3s-12f/monitor" \
            HAZARD3_DOOM_BUILD_DIR="${TEST_DIR}/ulx3s-12f/doom-image" \
            "${SCRIPT_DIR}/build-ulx3s-12f-doom.sh"
    if (( LAST_COMMAND_STATUS == 0 )); then
        run_logged 'sweep-ecp5.sh: ULX3S 12F routed sample' \
            'sweep-ulx3s-12f' \
            env SWEEP_JOBS="${jobs}" SWEEP_SKIP_SYNTH=1 \
                "${SCRIPT_DIR}/sweep-ecp5.sh" ulx3s-12f \
                "${ulx3s_12f_seeds[@]}"
        if (( dry_run == 0 && LAST_COMMAND_STATUS == 0 )); then
            check_sweep_timing 'ULX3S 12F routed sample' \
                "${REPO_ROOT}/build/ulx3s-12f-seed-sweep/32m/results-selected.csv"
        fi
    else
        skip 'sweep-ecp5.sh: ULX3S 12F build prerequisite failed'
    fi

    run_logged 'build-ulx4m-ld-doom.sh: complete ULX4M-LD build' \
        'build-ulx4m-ld-doom' \
        env \
            FORCE_BITSTREAM_REBUILD=1 \
            HAZARD3_BUILD_DIR="${TEST_DIR}/ulx4m-ld/monitor" \
            HAZARD3_DOOM_BUILD_DIR="${TEST_DIR}/ulx4m-ld/doom-image" \
            "${SCRIPT_DIR}/build-ulx4m-ld-doom.sh"
    if (( LAST_COMMAND_STATUS == 0 )); then
        run_logged 'sweep-ecp5.sh: ULX4M-LD routed sample' \
            'sweep-ulx4m-ld-85f' \
            env \
                SWEEP_JOBS="${jobs}" \
                SWEEP_SKIP_SYNTH=1 \
                SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT=30 \
                "${SCRIPT_DIR}/sweep-ecp5.sh" ulx4m-ld-85f \
                "${ulx4m_ld_seeds[@]}"
        if (( dry_run == 0 && LAST_COMMAND_STATUS == 0 )); then
            check_sweep_timing 'ULX4M-LD routed sample' \
                "${REPO_ROOT}/build/ulx4m-ld-seed-sweep/40mhz-serv-tw30/results-selected.csv"
        fi
    else
        skip 'sweep-ecp5.sh: ULX4M-LD build prerequisite failed'
    fi
    if [[ -f "${REPO_ROOT}/wads/DOOM1.WAD" && \
          -f "${REPO_ROOT}/wads/supercon10-friendly.wad" ]]; then
        run_logged 'build-supercon10-wad.py: sample WAD package' \
            'build-supercon10-wad' \
            "${SCRIPT_DIR}/build-supercon10-wad.py" \
                --output "${TEST_DIR}/SUPERCON10.WAD"
    else
        skip 'build-supercon10-wad.py: local DOOM1.WAD or Supercon PWAD unavailable'
    fi

    skip 'hardware programming and OpenOCD scripts: connected target required'
    skip 'UART and CoreMark run scripts: connected target and serial port required'
    skip 'setup, restore, and Git index scripts: intentionally mutating operations are excluded'
    skip 'Windows command scripts: native Windows environment required'

    verify_tracked_state
}

main()
{
    parse_args "$@"
    mkdir -p "${PYTHON_CACHE_DIR}"

    check_requirements || return 2

    check_shell_scripts
    check_python_scripts
    check_powershell_scripts
    report_target_specific_scripts
    check_seed_matrix
    check_sweep_dispatcher

    if git -C "${REPO_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
        run_quiet 'check-nettype.sh: project RTL policy' \
            "${SCRIPT_DIR}/check-nettype.sh"
        run_quiet 'inventory.sh: scripts inventory' \
            "${SCRIPT_DIR}/inventory.sh" --check scripts
    else
        skip 'check-nettype.sh: not inside a Git checkout'
        skip 'inventory.sh: not inside a Git checkout'
    fi

    if (( run_integration == 1 )); then
        shared_seeds="${SCRIPT_TEST_SWEEP_SEEDS:-}"
        if validate_integration_settings \
            SCRIPT_TEST_ULX3S_85F_SEEDS \
                "${SCRIPT_TEST_ULX3S_85F_SEEDS:-${shared_seeds:-11 178}}" \
            SCRIPT_TEST_ULX3S_12F_SEEDS \
                "${SCRIPT_TEST_ULX3S_12F_SEEDS:-${shared_seeds:-82 37}}" \
            SCRIPT_TEST_ULX4M_LD_SEEDS \
                "${SCRIPT_TEST_ULX4M_LD_SEEDS:-${shared_seeds:-83 45}}"; then
            run_integration_tests
        else
            fail 'integration settings'
        fi
    fi

    printf '\nSummary: %d passed, %d failed, %d warned, %d skipped\n' \
        "${passed}" "${failed}" "${warned}" "${skipped}"

    (( failed == 0 ))
}

main "$@"
