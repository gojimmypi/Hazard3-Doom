#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File:        hazard3-doom-source-status.sh
# Path:        scripts/hazard3-doom-source-status.sh
#
# Project:     Hazard3-Doom
# Purpose:     Audit Hazard3-Doom and related fork and branch relationships
#              across configured repositories.
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
# File: scripts/hazard3-doom-source-status.sh


set -euo pipefail

# Hazard3 Doom repository/fork/branch status report.
#
# Usage:
#   ./scripts/hazard3-doom-source-status.sh [github-user]
#
# Example:
#   ./scripts/hazard3-doom-source-status.sh gojimmypi
#
# Default user: gojimmypi
#
# The current user's repository is listed first in each source family.
# Default branches are discovered from each remote's symbolic HEAD. The script
# never assumes main, master, stable, ulx-doom, or any other branch name.
#
# For every branch, the report includes:
#   - ahead/behind versus that repository's own default branch
#   - ahead/behind versus the canonical upstream repository's default branch
#   - most recent commit date, short SHA, and subject
#
# It also includes:
#   - default-to-default comparisons across all related repositories
#   - explicit project-integration branch comparisons
#   - same-named branch comparisons across all related repositories
#   - local submodule gitlink versus working-checkout diagnostics
#
# Requirements: Bash 4+, Git, and standard POSIX/GNU userland tools.
# No GitHub CLI, jq, API token, or local clone is required.

CURRENT_USER="${1:-gojimmypi}"
GITHUB_BASE_URL="${GITHUB_BASE_URL:-https://github.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_STATUS_LOG="${ROOT_DIR}/build/source_status.log"

# Keep this status report self-contained: create the output directory first,
# then send all subsequent stdout/stderr to both the caller and the log.
mkdir -p -- "$(dirname "${SOURCE_STATUS_LOG}")"
exec > >(tee "${SOURCE_STATUS_LOG}") 2>&1
printf "Saving git branch history to %s\n" "${SOURCE_STATUS_LOG}"

# Run shellcheck to ensure this is a good script.
# Specify the executable shell checker you want to use:
MY_SHELLCHECK="shellcheck"

# Check if the executable is available in the PATH
if command -v "$MY_SHELLCHECK" >/dev/null 2>&1; then
    # Run your command here
    shellcheck "$0" || exit 1
else
    echo "$MY_SHELLCHECK is not installed. Please install it if changes to this script have been made."
fi

require_tool() {
    local tool="$1"
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool not found: $tool" >&2
        exit 1
    fi
}

require_tool git
require_tool awk
require_tool sed
require_tool sort
require_tool tr
require_tool mktemp
require_tool date

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazard3-doom-source-status.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# Each entry is:
#   display-name|repo1|repo2|...|canonical-upstream-repo
#
# CURRENT_USER is first. The final repository is the canonical/original
# upstream used for the UP+A / UP-B comparison columns.
FAMILIES=(
    "Hazard3-Doom|${CURRENT_USER}/Hazard3-Doom|ulx3s/Hazard3-Doom"
    "doomgeneric|${CURRENT_USER}/doomgeneric|ulx3s/doomgeneric|ozkl/doomgeneric"
    "Hazard3|${CURRENT_USER}/Hazard3|ulx3s/Hazard3|Wren6991/Hazard3"
    "Hazard3-libfpga|${CURRENT_USER}/Hazard3-libfpga|ulx3s/Hazard3-libfpga|Wren6991/libfpga"
)

INTEGRATION_COMPARISONS=(
    "Hazard3|${CURRENT_USER}/Hazard3|ulx-doom-dev|ulx3s/Hazard3|ulx-doom"
    "Hazard3-libfpga|${CURRENT_USER}/Hazard3-libfpga|ulx-doom-dev|ulx3s/Hazard3-libfpga|ulx-doom"
)

declare -A DEFAULT_BRANCHES=()
declare -A REPO_FETCH_OK=()

repo_url() {
    local repo="$1"
    printf '%s/%s.git\n' "$GITHUB_BASE_URL" "$repo"
}

repo_owner() {
    local repo="$1"
    printf '%s\n' "${repo%%/*}"
}

discover_default_branch() {
    local repo="$1"
    local url
    url="$(repo_url "$repo")"

    git ls-remote --symref "$url" HEAD 2>/dev/null |
        awk '$1 == "ref:" { sub("refs/heads/", "", $2); print $2; exit }'
}

fetch_repo_branches() {
    local git_dir="$1"
    local repo="$2"
    local owner url

    owner="$(repo_owner "$repo")"
    url="$(repo_url "$repo")"

    # Repository names are the same within a family. Owner therefore provides
    # a unique namespace for all fetched branches in that family's bare repo.
    git --git-dir="$git_dir" fetch \
        --quiet \
        --no-tags \
        "$url" \
        "+refs/heads/*:refs/remotes/${owner}/*"
}

short_sha() {
    local git_dir="$1"
    local ref="$2"
    git --git-dir="$git_dir" rev-parse --short=10 "$ref"
}

commit_date() {
    local git_dir="$1"
    local ref="$2"
    git --git-dir="$git_dir" show -s --format='%cI' "$ref"
}

commit_epoch() {
    local git_dir="$1"
    local ref="$2"
    git --git-dir="$git_dir" show -s --format='%ct' "$ref"
}

commit_subject() {
    local git_dir="$1"
    local ref="$2"
    git --git-dir="$git_dir" show -s --format='%s' "$ref" | tr '\t' ' '
}

# Print: "ahead behind" for SUBJECT_REF relative to BASE_REF.
compare_refs() {
    local git_dir="$1"
    local subject_ref="$2"
    local base_ref="$3"
    local subject_only base_only

    if [[ "$subject_ref" == "$base_ref" ]]; then
        printf '0 0\n'
        return
    fi

    if ! git --git-dir="$git_dir" merge-base "$subject_ref" "$base_ref" >/dev/null 2>&1; then
        printf 'UNRELATED UNRELATED\n'
        return
    fi

    # subject...base:
    #   left  = commits only on subject => subject is ahead
    #   right = commits only on base    => subject is behind
    read -r subject_only base_only < <(
        git --git-dir="$git_dir" rev-list --left-right --count \
            "$subject_ref...$base_ref"
    )
    printf '%s %s\n' "$subject_only" "$base_only"
}

gitlink_sha() {
    local repo_dir="$1"
    local ref="$2"
    local path="$3"

    git -C "$repo_dir" ls-tree "$ref" -- "$path" 2>/dev/null |
        awk '$1 == "160000" { print $3; exit }'
}

checkout_state() {
    local repo_dir="$1"

    if [[ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]]; then
        printf 'DIRTY\n'
    else
        printf 'CLEAN\n'
    fi
}

checkout_branch() {
    local repo_dir="$1"
    local branch

    branch="$(git -C "$repo_dir" branch --show-current 2>/dev/null || true)"
    if [[ -n "$branch" ]]; then
        printf '%s\n' "$branch"
    else
        printf 'DETACHED\n'
    fi
}

print_rule() {
    printf '%*s\n' 146 '' | tr ' ' '='
}

print_subrule() {
    printf '%*s\n' 146 '' | tr ' ' '-'
}

printf 'Hazard3 Doom Source Code Status\n'
printf 'Current GitHub user: %s\n' "$CURRENT_USER"
printf 'Generated: %s\n' "$(date -Iseconds)"
printf '\nComparison columns:\n'
printf '  OWN+A / OWN-B = branch ahead/behind its own repository default branch\n'
printf '  UP+A  / UP-B  = branch ahead/behind the canonical upstream default branch\n'
printf '\nRules:\n'
printf '  - DEFAULT BRANCH is discovered from remote HEAD; main/master is never assumed.\n'
printf '  - Different branch names are not silently treated as equivalent.\n'
printf '  - UNRELATED means Git found no common merge base.\n\n'

for family_entry in "${FAMILIES[@]}"; do
    IFS='|' read -r -a fields <<< "$family_entry"
    family_name="${fields[0]}"
    repos=("${fields[@]:1}")
    canonical_repo="${repos[${#repos[@]} - 1]}"
    family_git_dir="$WORK_DIR/${family_name}.git"

    git init --bare --quiet "$family_git_dir"

    print_rule
    printf 'FAMILY: %s\n' "$family_name"
    printf 'CANONICAL UPSTREAM: %s\n' "$canonical_repo"
    print_rule

    # Discover every repository default and fetch every branch. Keep these two
    # operations independent so branch inventory can still work if symbolic
    # HEAD discovery fails for a repository.
    for repo in "${repos[@]}"; do
        default_branch="$(discover_default_branch "$repo" || true)"
        DEFAULT_BRANCHES["$repo"]="$default_branch"

        if fetch_repo_branches "$family_git_dir" "$repo"; then
            REPO_FETCH_OK["$repo"]=1
        else
            REPO_FETCH_OK["$repo"]=0
        fi
    done

    canonical_owner="$(repo_owner "$canonical_repo")"
    canonical_default="${DEFAULT_BRANCHES[$canonical_repo]}"
    canonical_default_ref=''

    if [[ -n "$canonical_default" && "${REPO_FETCH_OK[$canonical_repo]:-0}" == 1 ]]; then
        canonical_default_ref="refs/remotes/${canonical_owner}/${canonical_default}"
        printf '*** CANONICAL UPSTREAM DEFAULT BRANCH: %s ***\n' "$canonical_default"
    else
        printf '*** CANONICAL UPSTREAM DEFAULT BRANCH: UNKNOWN ***\n'
    fi

    # Repository-by-repository branch inventory.
    for repo in "${repos[@]}"; do
        owner="$(repo_owner "$repo")"
        default_branch="${DEFAULT_BRANCHES[$repo]}"

        printf '\nREPOSITORY: %s\n' "$repo"
        if [[ -n "$default_branch" ]]; then
            printf '*** DEFAULT BRANCH: %s ***\n' "$default_branch"
        else
            printf '*** DEFAULT BRANCH: UNKNOWN (could not read remote HEAD) ***\n'
        fi

        if [[ "${REPO_FETCH_OK[$repo]:-0}" != 1 ]]; then
            printf 'ERROR: unable to fetch repository branches.\n'
            continue
        fi

        default_ref=''
        if [[ -n "$default_branch" ]]; then
            default_ref="refs/remotes/${owner}/${default_branch}"
        fi

        print_subrule
        printf '%-38s %-7s %-7s %-7s %-7s %-25s %-10s %s\n' \
            'BRANCH' 'OWN+A' 'OWN-B' 'UP+A' 'UP-B' 'MOST RECENT COMMIT' 'SHA' 'SUBJECT'
        print_subrule

        mapfile -t branches < <(
            git --git-dir="$family_git_dir" for-each-ref \
                --format='%(refname:strip=3)' \
                "refs/remotes/${owner}/" |
                sort
        )

        # Default first; every other branch follows alphabetically.
        ordered_branches=()
        if [[ -n "$default_branch" ]]; then
            ordered_branches+=("$default_branch")
        fi
        for branch in "${branches[@]}"; do
            [[ -n "$default_branch" && "$branch" == "$default_branch" ]] && continue
            ordered_branches+=("$branch")
        done

        latest_epoch=0
        latest_date=''
        latest_branch=''

        for branch in "${ordered_branches[@]}"; do
            branch_ref="refs/remotes/${owner}/${branch}"
            if ! git --git-dir="$family_git_dir" rev-parse --verify --quiet "$branch_ref" >/dev/null; then
                continue
            fi

            if [[ -n "$default_ref" ]]; then
                read -r own_ahead own_behind < <(
                    compare_refs "$family_git_dir" "$branch_ref" "$default_ref"
                )
            else
                own_ahead='N/A'
                own_behind='N/A'
            fi

            if [[ -n "$canonical_default_ref" ]]; then
                read -r up_ahead up_behind < <(
                    compare_refs "$family_git_dir" "$branch_ref" "$canonical_default_ref"
                )
            else
                up_ahead='N/A'
                up_behind='N/A'
            fi

            date_value="$(commit_date "$family_git_dir" "$branch_ref")"
            epoch_value="$(commit_epoch "$family_git_dir" "$branch_ref")"
            sha_value="$(short_sha "$family_git_dir" "$branch_ref")"
            subject_value="$(commit_subject "$family_git_dir" "$branch_ref")"

            if ((epoch_value > latest_epoch)); then
                latest_epoch="$epoch_value"
                latest_date="$date_value"
                latest_branch="$branch"
            fi

            if [[ -n "$default_branch" && "$branch" == "$default_branch" ]]; then
                branch_label="${branch}  <<< DEFAULT >>>"
            else
                branch_label="$branch"
            fi

            printf '%-38s %-7s %-7s %-7s %-7s %-25s %-10s %s\n' \
                "$branch_label" \
                "$own_ahead" "$own_behind" \
                "$up_ahead" "$up_behind" \
                "$date_value" "$sha_value" "$subject_value"
        done

        if [[ -n "$latest_branch" ]]; then
            printf '\nRepository newest branch tip: %s @ %s\n' "$latest_branch" "$latest_date"
        fi
    done

    # Compare each repository's actual default against every other actual
    # default. This is deliberately allowed even when branch names differ.
    printf '\n'
    print_subrule
    printf 'DEFAULT-BRANCH COMPARISONS ACROSS %s REPOSITORIES\n' "$family_name"
    print_subrule

    default_comparison_count=0
    for ((i = 0; i < ${#repos[@]}; i++)); do
        left_repo="${repos[$i]}"
        left_default="${DEFAULT_BRANCHES[$left_repo]}"
        [[ "${REPO_FETCH_OK[$left_repo]:-0}" == 1 && -n "$left_default" ]] || continue
        left_owner="$(repo_owner "$left_repo")"
        left_ref="refs/remotes/${left_owner}/${left_default}"

        for ((j = i + 1; j < ${#repos[@]}; j++)); do
            right_repo="${repos[$j]}"
            right_default="${DEFAULT_BRANCHES[$right_repo]}"
            [[ "${REPO_FETCH_OK[$right_repo]:-0}" == 1 && -n "$right_default" ]] || continue
            right_owner="$(repo_owner "$right_repo")"
            right_ref="refs/remotes/${right_owner}/${right_default}"

            read -r ahead behind < <(
                compare_refs "$family_git_dir" "$left_ref" "$right_ref"
            )

            printf '%s:%s vs %s:%s -> AHEAD=%s BEHIND=%s\n' \
                "$left_repo" "$left_default" \
                "$right_repo" "$right_default" \
                "$ahead" "$behind"
            default_comparison_count=$((default_comparison_count + 1))
        done
    done

    if ((default_comparison_count == 0)); then
        printf '(No default-branch comparisons available.)\n'
    fi

    integration_entries=()
    for integration_entry in "${INTEGRATION_COMPARISONS[@]}"; do
        IFS='|' read -r integration_family _ <<< "$integration_entry"
        if [[ "$integration_family" == "$family_name" ]]; then
            integration_entries+=("$integration_entry")
        fi
    done

    if ((${#integration_entries[@]} > 0)); then
        printf '\n'
        print_subrule
        printf 'PROJECT-INTEGRATION BRANCH COMPARISONS ACROSS %s REPOSITORIES\n' "$family_name"
        print_subrule

        for integration_entry in "${integration_entries[@]}"; do
            IFS='|' read -r _ left_repo left_branch right_repo right_branch <<< "$integration_entry"
            left_owner="$(repo_owner "$left_repo")"
            right_owner="$(repo_owner "$right_repo")"
            left_ref="refs/remotes/${left_owner}/${left_branch}"
            right_ref="refs/remotes/${right_owner}/${right_branch}"

            if [[ "${REPO_FETCH_OK[$left_repo]:-0}" != 1 ||
                  "${REPO_FETCH_OK[$right_repo]:-0}" != 1 ]]; then
                printf '%s:%s vs %s:%s -> UNAVAILABLE (repository fetch failed)\n' \
                    "$left_repo" "$left_branch" "$right_repo" "$right_branch"
                continue
            fi

            if ! git --git-dir="$family_git_dir" rev-parse --verify --quiet "$left_ref" >/dev/null; then
                printf '%s:%s vs %s:%s -> UNAVAILABLE (left branch not found)\n' \
                    "$left_repo" "$left_branch" "$right_repo" "$right_branch"
                continue
            fi

            if ! git --git-dir="$family_git_dir" rev-parse --verify --quiet "$right_ref" >/dev/null; then
                printf '%s:%s vs %s:%s -> UNAVAILABLE (right branch not found)\n' \
                    "$left_repo" "$left_branch" "$right_repo" "$right_branch"
                continue
            fi

            read -r ahead behind < <(
                compare_refs "$family_git_dir" "$left_ref" "$right_ref"
            )

            printf '%s:%s vs %s:%s -> AHEAD=%s BEHIND=%s\n' \
                "$left_repo" "$left_branch" \
                "$right_repo" "$right_branch" \
                "$ahead" "$behind"
        done
    fi

    # Same-named branches across repositories. This section never assumes that
    # differently named branches such as master/stable/ulx-doom are equivalent.
    printf '\n'
    print_subrule
    printf 'SAME-NAMED BRANCH COMPARISONS ACROSS %s REPOSITORIES\n' "$family_name"
    print_subrule

    same_name_comparison_count=0
    for ((i = 0; i < ${#repos[@]}; i++)); do
        left_repo="${repos[$i]}"
        [[ "${REPO_FETCH_OK[$left_repo]:-0}" == 1 ]] || continue
        left_owner="$(repo_owner "$left_repo")"

        mapfile -t left_branches < <(
            git --git-dir="$family_git_dir" for-each-ref \
                --format='%(refname:strip=3)' \
                "refs/remotes/${left_owner}/" |
                sort
        )

        for ((j = i + 1; j < ${#repos[@]}; j++)); do
            right_repo="${repos[$j]}"
            [[ "${REPO_FETCH_OK[$right_repo]:-0}" == 1 ]] || continue
            right_owner="$(repo_owner "$right_repo")"

            for branch in "${left_branches[@]}"; do
                left_ref="refs/remotes/${left_owner}/${branch}"
                right_ref="refs/remotes/${right_owner}/${branch}"

                if ! git --git-dir="$family_git_dir" rev-parse --verify --quiet "$right_ref" >/dev/null; then
                    continue
                fi

                read -r ahead behind < <(
                    compare_refs "$family_git_dir" "$left_ref" "$right_ref"
                )

                printf '%s:%s vs %s:%s -> AHEAD=%s BEHIND=%s\n' \
                    "$left_repo" "$branch" \
                    "$right_repo" "$branch" \
                    "$ahead" "$behind"
                same_name_comparison_count=$((same_name_comparison_count + 1))
            done
        done
    done

    if ((same_name_comparison_count == 0)); then
        printf '(No same-named branches exist across these repositories.)\n'
    fi

    printf '\n'
done

print_rule
printf 'LOCAL SUBMODULE GITLINK AUDIT\n'
print_rule

HAZARD3_DIR="${ROOT_DIR}/third_party/Hazard3"
LIBFPGA_DIR="${HAZARD3_DIR}/example_soc/libfpga"

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    root_head="$(git -C "$ROOT_DIR" rev-parse HEAD)"
    root_branch="$(checkout_branch "$ROOT_DIR")"
    root_state="$(checkout_state "$ROOT_DIR")"
    printf 'Hazard3-Doom working checkout: %s (%s, %s)\n' "$root_head" "$root_branch" "$root_state"

    hazard3_recorded="$(gitlink_sha "$ROOT_DIR" HEAD third_party/Hazard3)"
    if [[ -n "$hazard3_recorded" ]]; then
        printf 'Hazard3-Doom recorded Hazard3: %s\n' "$hazard3_recorded"
    else
        printf 'Hazard3-Doom recorded Hazard3: UNAVAILABLE\n'
    fi

    if git -C "$HAZARD3_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        hazard3_working="$(git -C "$HAZARD3_DIR" rev-parse HEAD)"
        hazard3_branch="$(checkout_branch "$HAZARD3_DIR")"
        hazard3_state="$(checkout_state "$HAZARD3_DIR")"
        printf 'Hazard3 working checkout:       %s (%s, %s)\n' "$hazard3_working" "$hazard3_branch" "$hazard3_state"

        if [[ -n "$hazard3_recorded" && "$hazard3_recorded" == "$hazard3_working" ]]; then
            printf 'Hazard3 checkout vs parent gitlink: MATCH\n'
        elif [[ -n "$hazard3_recorded" ]]; then
            printf 'Hazard3 checkout vs parent gitlink: MISMATCH\n'
        else
            printf 'Hazard3 checkout vs parent gitlink: UNAVAILABLE\n'
        fi

        libfpga_recorded_working="$(gitlink_sha "$HAZARD3_DIR" HEAD example_soc/libfpga)"
        if [[ -n "$libfpga_recorded_working" ]]; then
            printf 'Hazard3 working HEAD recorded libfpga: %s\n' "$libfpga_recorded_working"
        else
            printf 'Hazard3 working HEAD recorded libfpga: UNAVAILABLE\n'
        fi

        libfpga_recorded_parent=''
        if [[ -n "$hazard3_recorded" ]] &&
           git -C "$HAZARD3_DIR" cat-file -e "${hazard3_recorded}^{commit}" 2>/dev/null; then
            libfpga_recorded_parent="$(gitlink_sha "$HAZARD3_DIR" "$hazard3_recorded" example_soc/libfpga)"
        fi
        if [[ -n "$libfpga_recorded_parent" ]]; then
            printf 'Parent-recorded Hazard3 expected libfpga: %s\n' "$libfpga_recorded_parent"
        else
            printf 'Parent-recorded Hazard3 expected libfpga: UNAVAILABLE\n'
        fi

        if git -C "$LIBFPGA_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            libfpga_working="$(git -C "$LIBFPGA_DIR" rev-parse HEAD)"
            libfpga_branch="$(checkout_branch "$LIBFPGA_DIR")"
            libfpga_state="$(checkout_state "$LIBFPGA_DIR")"
            printf 'libfpga working checkout:             %s (%s, %s)\n' "$libfpga_working" "$libfpga_branch" "$libfpga_state"

            if [[ -n "$libfpga_recorded_working" && "$libfpga_recorded_working" == "$libfpga_working" ]]; then
                printf 'libfpga checkout vs working Hazard3 gitlink: MATCH\n'
            elif [[ -n "$libfpga_recorded_working" ]]; then
                printf 'libfpga checkout vs working Hazard3 gitlink: MISMATCH\n'
            else
                printf 'libfpga checkout vs working Hazard3 gitlink: UNAVAILABLE\n'
            fi

            if [[ -n "$libfpga_recorded_parent" && "$libfpga_recorded_parent" == "$libfpga_working" ]]; then
                printf 'libfpga checkout vs parent-recorded chain: MATCH\n'
            elif [[ -n "$libfpga_recorded_parent" ]]; then
                printf 'libfpga checkout vs parent-recorded chain: MISMATCH\n'
            else
                printf 'libfpga checkout vs parent-recorded chain: UNAVAILABLE\n'
            fi
        else
            printf 'libfpga working checkout: UNAVAILABLE\n'
        fi
    else
        printf 'Hazard3 working checkout: UNAVAILABLE\n'
    fi
else
    printf 'Local Hazard3-Doom checkout: UNAVAILABLE\n'
fi
