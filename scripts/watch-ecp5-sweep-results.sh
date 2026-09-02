#!/bin/bash
# -----------------------------------------------------------------------------
# File:        watch-ecp5-sweep-results.sh
# Path:        scripts/watch-ecp5-sweep-results.sh
#
# Project:     Hazard3-Doom
# Purpose:     Show timing-passing ECP5 seed results while CI routing continues.
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

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

usage()
{
    cat >&2 <<EOF_USAGE
Usage: $0 TARGET SEED_FIRST SEED_LAST SEEDS_PER_JOB

Environment required when watching GitHub Actions:
    GH_TOKEN or GITHUB_TOKEN
    GITHUB_API_URL
    GITHUB_REPOSITORY
    GITHUB_RUN_ID

The watcher polls completed per-group ECP5 sweep artifacts and prints a
consolidated list of timing-passing seeds while other route jobs continue.
EOF_USAGE
}

is_positive_integer()
{
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

# Run shellcheck to ensure this is a good script.
MY_SHELLCHECK="${MY_SHELLCHECK:-shellcheck}"
if command -v "${MY_SHELLCHECK}" >/dev/null 2>&1; then
    (
        cd -- "${REPO_ROOT}"
        "${MY_SHELLCHECK}" -x "scripts/$(basename -- "${BASH_SOURCE[0]}")"
    ) || exit 1
else
    echo "${MY_SHELLCHECK} is not installed. Please install it if changes to this script have been made."
fi

if (( $# != 4 )); then
    usage
    exit 1
fi

SWEEP_TARGET="$1"
SWEEP_SEED_FIRST="$2"
SWEEP_SEED_LAST="$3"
SWEEP_SEEDS_PER_JOB="$4"
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

if ! is_positive_integer "${SWEEP_SEED_FIRST}" ||
   ! is_positive_integer "${SWEEP_SEED_LAST}" ||
   ! is_positive_integer "${SWEEP_SEEDS_PER_JOB}"; then
    echo "Seed values and seeds-per-job must be positive integers." >&2
    exit 1
fi
if (( SWEEP_SEED_FIRST > SWEEP_SEED_LAST )); then
    echo "SEED_FIRST must be less than or equal to SEED_LAST." >&2
    exit 1
fi
if [[ -z "${GH_TOKEN}" ]]; then
    echo "GH_TOKEN or GITHUB_TOKEN is required." >&2
    exit 1
fi
: "${GITHUB_API_URL:?GITHUB_API_URL is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

for command_name in curl jq unzip sort paste wc find awk; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'Required command is not installed: %s\n' "${command_name}" >&2
        exit 1
    fi
done

expected_seeds=$((SWEEP_SEED_LAST - SWEEP_SEED_FIRST + 1))
expected_groups=$(((expected_seeds + SWEEP_SEEDS_PER_JOB - 1) / SWEEP_SEEDS_PER_JOB))
artifact_prefix="ecp5-sweep-seeds-"
artifact_suffix="-${GITHUB_RUN_ID}"
work_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ecp5-live-seed-results-${GITHUB_RUN_ID}"
mkdir -p "${work_dir}"

declare -A seen_artifacts=()
declare -A seed_status=()
declare -A seed_seconds=()
declare -A seed_exit=()
declare -A seed_clk_sys=()
declare -A seed_clk_video=()
declare -A seed_clk_tmds=()
declare -A seed_litedram_user=()
declare -A seed_init_clk=()

api_get()
{
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 3 \
        --retry-delay 5 \
        --retry-all-errors \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer ${GH_TOKEN}" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        "$1"
}

list_seed_artifacts()
{
    local page=1
    local response count

    while :; do
        response="$(
            api_get \
                "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/artifacts?per_page=100&page=${page}"
        )"
        count="$(jq ".artifacts | length" <<< "${response}")"
        jq -r \
            --arg prefix "${artifact_prefix}" \
            --arg suffix "${artifact_suffix}" \
            '.artifacts[] |
             select(.expired == false) |
             select(.name | startswith($prefix) and endswith($suffix)) |
             [.id, .name] | @tsv' \
            <<< "${response}"

        (( count < 100 )) && break
        page=$((page + 1))
    done
}

completed_route_jobs()
{
    local page=1
    local response count
    local job_prefix="${SWEEP_TARGET} seeds "

    while :; do
        response="$(
            api_get \
                "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs?filter=latest&per_page=100&page=${page}"
        )"
        count="$(jq ".jobs | length" <<< "${response}")"
        jq -r \
            --arg prefix "${job_prefix}" \
            '.jobs[] |
             select(.status == "completed") |
             select(.name | startswith($prefix)) |
             .name' \
            <<< "${response}"

        (( count < 100 )) && break
        page=$((page + 1))
    done | LC_ALL=C sort -u | wc -l
}

download_artifact()
{
    local artifact_id="$1"
    local artifact_name="$2"
    local zip_file="${work_dir}/${artifact_name}.zip"
    local extract_dir="${work_dir}/${artifact_name}"

    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"
    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 3 \
        --retry-delay 5 \
        --retry-all-errors \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer ${GH_TOKEN}" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/actions/artifacts/${artifact_id}/zip" \
        --output "${zip_file}"
    unzip -q -o "${zip_file}" -d "${extract_dir}"
    printf '%s\n' "${extract_dir}"
}

is_decimal()
{
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

load_seed_metrics()
{
    local extract_dir="$1"
    local seed="$2"
    local result
    local fields=()

    result="$(
        find "${extract_dir}" -maxdepth 2 -type f \
            -name "result-seed-${seed}.csv" -print -quit
    )"
    if [[ -z "${result}" ]]; then
        return 0
    fi

    IFS=, read -r -a fields < "${result}" || true
    case "${SWEEP_TARGET}" in
    ulx3s-85f|ulx3s-12f)
        seed_clk_sys["${seed}"]="${fields[1]:-NA}"
        seed_clk_video["${seed}"]="${fields[2]:-NA}"
        seed_clk_tmds["${seed}"]="${fields[3]:-NA}"
        ;;
    ulx4m-ld-85f)
        seed_clk_sys["${seed}"]="${fields[1]:-NA}"
        seed_litedram_user["${seed}"]="${fields[2]:-NA}"
        seed_clk_video["${seed}"]="${fields[3]:-NA}"
        seed_clk_tmds["${seed}"]="${fields[4]:-NA}"
        seed_init_clk["${seed}"]="${fields[5]:-NA}"
        ;;
    esac

    seed_clk_sys["${seed}"]="${seed_clk_sys[$seed]:-NA}"
    seed_clk_video["${seed}"]="${seed_clk_video[$seed]:-NA}"
    seed_clk_tmds["${seed}"]="${seed_clk_tmds[$seed]:-NA}"
    seed_litedram_user["${seed}"]="${seed_litedram_user[$seed]:-NA}"
    seed_init_clk["${seed}"]="${seed_init_clk[$seed]:-NA}"

    seed_clk_sys["${seed}"]="${seed_clk_sys[$seed]%$'\r'}"
    seed_clk_video["${seed}"]="${seed_clk_video[$seed]%$'\r'}"
    seed_clk_tmds["${seed}"]="${seed_clk_tmds[$seed]%$'\r'}"
    seed_litedram_user["${seed}"]="${seed_litedram_user[$seed]%$'\r'}"
    seed_init_clk["${seed}"]="${seed_init_clk[$seed]%$'\r'}"
}

seed_frequency_metrics()
{
    local seed="$1"

    case "${SWEEP_TARGET}" in
    ulx4m-ld-85f)
        printf 'sys=%s litedram_user=%s video=%s tmds=%s init=%s' \
            "${seed_clk_sys[$seed]:-NA}" \
            "${seed_litedram_user[$seed]:-NA}" \
            "${seed_clk_video[$seed]:-NA}" \
            "${seed_clk_tmds[$seed]:-NA}" \
            "${seed_init_clk[$seed]:-NA}"
        ;;
    *)
        printf 'sys=%s video=%s tmds=%s' \
            "${seed_clk_sys[$seed]:-NA}" \
            "${seed_clk_video[$seed]:-NA}" \
            "${seed_clk_tmds[$seed]:-NA}"
        ;;
    esac
}

best_pass_metric()
{
    local array_name="$1"
    local -n metric_values="${array_name}"
    local seed value best

    best="$(
        for seed in "${!metric_values[@]}"; do
            [[ "${seed_status[$seed]:-}" == "PASS" ]] || continue
            value="${metric_values[$seed]}"
            if is_decimal "${value}"; then
                printf '%s,%s\n' "${value}" "${seed}"
            fi
        done | awk -F, '
            BEGIN { have = 0 }
            !have || ($1 + 0) > best {
                have = 1
                best = $1 + 0
                value = $1
                seed = $2
            }
            END {
                if (have) {
                    printf "%s (seed %s)\n", value, seed
                }
            }'
    )"

    printf '%s\n' "${best:-none}"
}

print_route_duration_summary()
{
    local seed seconds
    local count=0 total=0 min_seconds=0 max_seconds=0
    local min_seed="" max_seed=""

    for seed in "${!seed_seconds[@]}"; do
        [[ "${seed_status[$seed]:-}" == "PASS" ]] || continue
        seconds="${seed_seconds[$seed]}"
        [[ "${seconds}" =~ ^[0-9]+$ ]] || continue

        if (( count == 0 || seconds < min_seconds )); then
            min_seconds="${seconds}"
            min_seed="${seed}"
        fi
        if (( count == 0 || seconds > max_seconds )); then
            max_seconds="${seconds}"
            max_seed="${seed}"
        fi
        total=$((total + seconds))
        count=$((count + 1))
    done

    if (( count == 0 )); then
        printf 'PASS route duration: no timing-passing seeds yet\n'
        return
    fi

    printf 'PASS route duration: avg=%ss | fastest=%ss (seed %s) | slowest=%ss (seed %s)\n' \
        "$((total / count))" "${min_seconds}" "${min_seed}" \
        "${max_seconds}" "${max_seed}"
}

print_best_frequency_summary()
{
    local best_sys best_video best_tmds best_litedram best_init

    if (( $(count_status PASS) == 0 )); then
        printf 'Best PASS max MHz: no timing-passing seeds yet\n'
        return
    fi

    best_sys="$(best_pass_metric seed_clk_sys)"
    best_video="$(best_pass_metric seed_clk_video)"
    best_tmds="$(best_pass_metric seed_clk_tmds)"

    if [[ "${SWEEP_TARGET}" == "ulx4m-ld-85f" ]]; then
        best_litedram="$(best_pass_metric seed_litedram_user)"
        best_init="$(best_pass_metric seed_init_clk)"
        printf 'Best PASS max MHz: sys=%s | litedram_user=%s | video=%s\n' \
            "${best_sys}" "${best_litedram}" "${best_video}"
        printf '                   tmds=%s | init=%s\n' \
            "${best_tmds}" "${best_init}"
    else
        printf 'Best PASS max MHz: sys=%s | video=%s | tmds=%s\n' \
            "${best_sys}" "${best_video}" "${best_tmds}"
    fi
}

sorted_seeds_for_status()
{
    local wanted_status="$1"
    local seed

    for seed in "${!seed_status[@]}"; do
        case "${wanted_status}" in
        PASS|FAIL)
            if [[ "${seed_status[$seed]}" == "${wanted_status}" ]]; then
                printf '%s\n' "${seed}"
            fi
            ;;
        TIMEOUT)
            if [[ "${seed_status[$seed]}" == *TIMEOUT* ]]; then
                printf '%s\n' "${seed}"
            fi
            ;;
        ERROR)
            case "${seed_status[$seed]}" in
            PASS|FAIL|*TIMEOUT*)
                ;;
            *)
                printf '%s\n' "${seed}"
                ;;
            esac
            ;;
        esac
    done | sort -n
}

joined_seeds_for_status()
{
    local value

    value="$(sorted_seeds_for_status "$1" | paste -sd" " -)"
    printf '%s\n' "${value:-none}"
}

count_status()
{
    sorted_seeds_for_status "$1" | wc -l
}

print_consolidated()
{
    local completed_groups="$1"
    local completed_jobs="$2"
    local pass_seeds timeout_seeds error_seeds
    local pass_count timeout_count fail_count error_count

    pass_seeds="$(joined_seeds_for_status PASS)"
    timeout_seeds="$(joined_seeds_for_status TIMEOUT)"
    error_seeds="$(joined_seeds_for_status ERROR)"
    pass_count="$(count_status PASS)"
    timeout_count="$(count_status TIMEOUT)"
    fail_count="$(count_status FAIL)"
    error_count="$(count_status ERROR)"

    printf '\n%s\n' '------------------------------------------------------------'
    printf 'LIVE TIMING RESULTS\n'
    printf 'Timing-passing seeds: %s\n' "${pass_seeds}"
    printf 'Progress: %s/%s seeds | %s/%s groups | %s/%s jobs\n' \
        "${#seed_status[@]}" "${expected_seeds}" \
        "${completed_groups}" "${expected_groups}" \
        "${completed_jobs}" "${expected_groups}"
    printf 'Status: PASS=%s FAIL=%s TIMEOUT=%s OTHER=%s\n' \
        "${pass_count}" "${fail_count}" "${timeout_count}" "${error_count}"
    print_route_duration_summary
    print_best_frequency_summary
    printf 'Timeout seeds: %s\n' "${timeout_seeds}"
    printf 'Other/problem seeds: %s\n' "${error_seeds}"
    printf '%s\n' '------------------------------------------------------------'
}

printf 'Watching %s seeds %s-%s.\n' \
    "${SWEEP_TARGET}" "${SWEEP_SEED_FIRST}" "${SWEEP_SEED_LAST}"
case "${SWEEP_TARGET}" in
ulx3s-85f)
    printf 'Timing targets: sys=50.00 MHz | video=50.00 MHz | tmds=250.00 MHz\n'
    ;;
ulx3s-12f)
    printf 'Timing targets: sys=40.00 MHz | video=50.00 MHz | tmds=250.00 MHz\n'
    ;;
ulx4m-ld-85f)
    printf 'Timing targets: sys=%s.00 MHz | litedram_user=60.01 MHz | video=50.00 MHz | tmds=250.00 MHz | init=25.00 MHz\n' \
        "${HAZARD3_ULX4M_SYS_CLK_MHZ:-40}"
    ;;
esac
printf 'Expected seed groups: %s (%s seed(s) per job).\n' \
    "${expected_groups}" "${SWEEP_SEEDS_PER_JOB}"
printf 'Newly uploaded seed artifacts will be reported here while routing continues.\n'

poll_count=0
all_jobs_complete_polls=0
while :; do
    new_artifacts=0
    while IFS=$'\t' read -r artifact_id artifact_name; do
        [[ -n "${artifact_id}" ]] || continue
        [[ -z "${seen_artifacts[${artifact_name}]+x}" ]] || continue

        if ! extract_dir="$(download_artifact "${artifact_id}" "${artifact_name}")"; then
            printf 'Artifact %s is visible but not downloadable yet; retrying later.\n' \
                "${artifact_name}" >&2
            continue
        fi

        status_file="$(
            find "${extract_dir}" -maxdepth 2 -type f \
                -name 'group-status-*.csv' -print -quit
        )"
        if [[ -z "${status_file}" ]]; then
            printf 'Artifact %s has no group-status CSV; retrying later.\n' \
                "${artifact_name}" >&2
            continue
        fi

        group_seeds=()
        group_passes=()
        while IFS=, read -r seed status seconds route_exit; do
            [[ "${seed}" != "seed" ]] || continue
            [[ -n "${seed}" ]] || continue
            status="${status%$'\r'}"
            seconds="${seconds%$'\r'}"
            route_exit="${route_exit%$'\r'}"
            seed_status["${seed}"]="${status}"
            seed_seconds["${seed}"]="${seconds}"
            seed_exit["${seed}"]="${route_exit}"
            seed_clk_sys["${seed}"]="NA"
            seed_clk_video["${seed}"]="NA"
            seed_clk_tmds["${seed}"]="NA"
            seed_litedram_user["${seed}"]="NA"
            seed_init_clk["${seed}"]="NA"
            group_seeds+=("${seed}")
            if [[ "${status}" == "PASS" ]]; then
                group_passes+=("${seed}")
            fi
        done < "${status_file}"

        for seed in "${group_seeds[@]}"; do
            load_seed_metrics "${extract_dir}" "${seed}"
        done

        seen_artifacts["${artifact_name}"]=1
        new_artifacts=$((new_artifacts + 1))
        group="${artifact_name#"${artifact_prefix}"}"
        group="${group%"${artifact_suffix}"}"
        printf '\n[%s UTC] seed group %s reported: %s\n' \
            "$(date -u +%H:%M:%S)" "${group}" "${group_seeds[*]:-none}"
        printf 'PASS in this group: %s\n' "${group_passes[*]:-none}"
        if (( ${#group_passes[@]} > 0 )); then
            printf '>>> NEW TIMING PASS: %s <<<\n' "${group_passes[*]}"
        fi
        for seed in "${group_seeds[@]}"; do
            printf '  seed %-3s %-18s %ss (exit %s) | max MHz: %s\n' \
                "${seed}" "${seed_status[$seed]}" \
                "${seed_seconds[$seed]}" "${seed_exit[$seed]}" \
                "$(seed_frequency_metrics "${seed}")"
        done
    done < <(list_seed_artifacts)

    artifact_groups="${#seen_artifacts[@]}"
    route_jobs_done="$(completed_route_jobs)"

    if (( new_artifacts > 0 )); then
        print_consolidated "${artifact_groups}" "${route_jobs_done}"
    fi

    if (( artifact_groups >= expected_groups )); then
        printf '\nAll expected seed-group artifacts have been received.\n'
        print_consolidated "${artifact_groups}" "${route_jobs_done}"
        break
    fi

    if (( route_jobs_done >= expected_groups )); then
        all_jobs_complete_polls=$((all_jobs_complete_polls + 1))
        if (( all_jobs_complete_polls >= 2 )); then
            printf '\n::warning::All route jobs completed, but only %s of %s seed-group artifacts were received.\n' \
                "${artifact_groups}" "${expected_groups}"
            print_consolidated "${artifact_groups}" "${route_jobs_done}"
            break
        fi
    else
        all_jobs_complete_polls=0
    fi

    poll_count=$((poll_count + 1))
    if (( poll_count % 5 == 0 )); then
        printf '[%s UTC] waiting: artifact groups %s/%s, route jobs completed %s/%s\n' \
            "$(date -u +%H:%M:%S)" \
            "${artifact_groups}" "${expected_groups}" \
            "${route_jobs_done}" "${expected_groups}"
    fi
    sleep 60
done

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    pass_seeds="$(joined_seeds_for_status PASS)"
    timeout_seeds="$(joined_seeds_for_status TIMEOUT)"
    {
        printf '### Live %s timing results\n\n' "${SWEEP_TARGET}"
        printf '**Timing-passing seeds:** %s\n\n' "${pass_seeds}"
        printf '**Timed-out seeds:** %s\n\n' "${timeout_seeds}"
        print_route_duration_summary
        print_best_frequency_summary
        printf '\nReceived %s of %s expected seed results.\n' \
            "${#seed_status[@]}" "${expected_seeds}"
    } >> "${GITHUB_STEP_SUMMARY}"
fi
