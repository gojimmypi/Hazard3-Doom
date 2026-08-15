#!/bin/bash
set -euo pipefail

# File: scripts/hazard3-submodule.sh
#
# Temporarily test the reviewed Hazard3 ulx-doom-dev SD/SAO commit from a
# Hazard3-Doom develop checkout without changing .gitmodules.
#
# Usage:
#   ./scripts/hazard3-submodule.sh test
#   ./scripts/hazard3-submodule.sh status
#   ./scripts/hazard3-submodule.sh diff
#   ./scripts/hazard3-submodule.sh restore
#
# "restore" checks third_party/Hazard3 back out at the gitlink recorded by
# the current Hazard3-Doom HEAD. No state file is required.

TARGET_REPO="https://github.com/gojimmypi/Hazard3.git"
TARGET_BRANCH="ulx-doom-dev"
TARGET_COMMIT="736a74459b3f740c47803f20a62d820fcacbe5c3"
EXPECTED_SUPERPROJECT_BRANCH="develop"
SUBMODULE_PATH="third_party/Hazard3"

require_tool()
{
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required tool: $1" >&2
        exit 1
    }
}

find_root()
{
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if git -C "${script_dir}" rev-parse --show-toplevel >/dev/null 2>&1; then
        git -C "${script_dir}" rev-parse --show-toplevel
        return
    fi

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
        return
    fi

    echo "Run this script from inside a Hazard3-Doom checkout, or place it under that checkout." >&2
    exit 1
}

get_pinned_commit()
{
    local mode type commit path

    read -r mode type commit path < <(
        git -C "${ROOT_DIR}" ls-tree HEAD -- "${SUBMODULE_PATH}"
    )

    if [[ "${mode:-}" != "160000" || "${type:-}" != "commit" || -z "${commit:-}" ]]; then
        echo "${SUBMODULE_PATH} is not a submodule gitlink in Hazard3-Doom HEAD." >&2
        exit 1
    fi

    printf '%s\n' "${commit}"
}

check_branch()
{
    local branch

    branch="$(git -C "${ROOT_DIR}" branch --show-current)"
    if [[ "${branch}" != "${EXPECTED_SUPERPROJECT_BRANCH}" ]]; then
        echo "Refusing to change the test submodule while Hazard3-Doom is on '${branch}'." >&2
        echo "Expected branch: ${EXPECTED_SUPERPROJECT_BRANCH}" >&2
        exit 1
    fi
}

ensure_hazard3_initialized()
{
    if git -C "${HAZARD3_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return
    fi

    git -C "${ROOT_DIR}" submodule update --init -- "${SUBMODULE_PATH}"
}

check_hazard3_clean()
{
    local dirty

    dirty="$(git -C "${HAZARD3_ROOT}" status --porcelain --untracked-files=all --ignore-submodules=all)"
    if [[ -n "${dirty}" ]]; then
        echo "Refusing to change ${SUBMODULE_PATH}: its working tree has local changes:" >&2
        printf '%s\n' "${dirty}" >&2
        exit 1
    fi
}

check_nested_clean()
{
    local relpath="$1"
    local nested="${HAZARD3_ROOT}/${relpath}"
    local dirty

    if git -C "${nested}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        dirty="$(git -C "${nested}" status --porcelain --untracked-files=all)"
        if [[ -n "${dirty}" ]]; then
            echo "Refusing to update dirty nested Hazard3 submodule: ${relpath}" >&2
            printf '%s\n' "${dirty}" >&2
            exit 1
        fi
    fi
}

update_required_nested_submodules()
{
    git -C "${HAZARD3_ROOT}" submodule sync -- scripts example_soc/libfpga
    git -C "${HAZARD3_ROOT}" submodule update --init -- scripts example_soc/libfpga
}

show_status()
{
    local pinned current

    pinned="$(get_pinned_commit)"
    current="$(git -C "${HAZARD3_ROOT}" rev-parse HEAD)"

    printf 'Hazard3-Doom branch : %s\n' "$(git -C "${ROOT_DIR}" branch --show-current)"
    printf 'Pinned Hazard3      : %s\n' "${pinned}"
    printf 'Current Hazard3     : %s\n' "${current}"
    printf 'Reviewed test SHA   : %s\n' "${TARGET_COMMIT}"
    printf 'Reviewed source     : %s %s\n' "${TARGET_REPO}" "${TARGET_BRANCH}"

    if [[ "${current}" == "${pinned}" ]]; then
        echo "State                : restored to Hazard3-Doom gitlink"
    elif [[ "${current}" == "${TARGET_COMMIT}" ]]; then
        echo "State                : TEST commit active"
    else
        echo "State                : other Hazard3 commit active"
    fi

    echo
    git -C "${ROOT_DIR}" status --short -- "${SUBMODULE_PATH}"
}

show_diff()
{
    echo "Hazard3 working-tree status:"
    git -C "${HAZARD3_ROOT}" status --short

    echo
    echo "Hazard3 unstaged diff stat:"
    git -C "${HAZARD3_ROOT}" diff --stat --submodule=log

    echo
    echo "Hazard3 unstaged diff:"
    git -C "${HAZARD3_ROOT}" diff --submodule=log

    if ! git -C "${HAZARD3_ROOT}" diff --cached --quiet --ignore-submodules=none; then
        echo
        echo "Hazard3 staged diff stat:"
        git -C "${HAZARD3_ROOT}" diff --cached --stat --submodule=log

        echo
        echo "Hazard3 staged diff:"
        git -C "${HAZARD3_ROOT}" diff --cached --submodule=log
    fi
}

activate_test_commit()
{
    local pinned current fetched

    check_branch
    pinned="$(get_pinned_commit)"

    ensure_hazard3_initialized
    check_hazard3_clean
    check_nested_clean scripts
    check_nested_clean example_soc/libfpga

    current="$(git -C "${HAZARD3_ROOT}" rev-parse HEAD)"
    if [[ "${current}" != "${pinned}" && "${current}" != "${TARGET_COMMIT}" ]]; then
        echo "Refusing to replace unexpected Hazard3 checkout ${current}." >&2
        echo "Expected the develop gitlink ${pinned} or reviewed test SHA ${TARGET_COMMIT}." >&2
        exit 1
    fi

    echo "Fetching reviewed Hazard3 test branch..."
    git -C "${HAZARD3_ROOT}" fetch --no-tags "${TARGET_REPO}" \
        "refs/heads/${TARGET_BRANCH}"
    fetched="$(git -C "${HAZARD3_ROOT}" rev-parse FETCH_HEAD)"

    if [[ "${fetched}" != "${TARGET_COMMIT}" ]]; then
        echo "STOP: ${TARGET_BRANCH} has moved since this script was reviewed." >&2
        echo "Reviewed SHA : ${TARGET_COMMIT}" >&2
        echo "Current tip  : ${fetched}" >&2
        echo "Review the newer commit before changing TARGET_COMMIT." >&2
        exit 1
    fi

    git -C "${HAZARD3_ROOT}" checkout --detach "${TARGET_COMMIT}"
    update_required_nested_submodules

    echo
    echo "Temporary Hazard3 SD/SAO test commit is active:"
    git -C "${HAZARD3_ROOT}" log -1 --oneline --decorate
    echo
    echo "Hazard3-Doom now shows only the expected submodule-pointer difference:"
    git -C "${ROOT_DIR}" status --short -- "${SUBMODULE_PATH}"
    echo
    echo "Do not commit the submodule pointer for this temporary test."
    echo "Restore with: $0 restore"
}

restore_pinned_commit()
{
    local pinned current

    check_branch
    pinned="$(get_pinned_commit)"

    ensure_hazard3_initialized
    check_hazard3_clean
    check_nested_clean scripts
    check_nested_clean example_soc/libfpga

    current="$(git -C "${HAZARD3_ROOT}" rev-parse HEAD)"
    if [[ "${current}" != "${TARGET_COMMIT}" && "${current}" != "${pinned}" ]]; then
        echo "Refusing to overwrite unexpected Hazard3 checkout ${current}." >&2
        echo "Expected reviewed test SHA ${TARGET_COMMIT} or develop gitlink ${pinned}." >&2
        exit 1
    fi

    git -C "${HAZARD3_ROOT}" checkout --detach "${pinned}"
    update_required_nested_submodules

    echo
    echo "Hazard3 restored to the commit pinned by Hazard3-Doom HEAD:"
    git -C "${HAZARD3_ROOT}" log -1 --oneline --decorate
    echo
    git -C "${ROOT_DIR}" status --short -- "${SUBMODULE_PATH}"
}

usage()
{
    cat <<USAGE
Usage: $(basename "$0") {test|status|diff|restore}

  test     Temporarily check out reviewed ${TARGET_BRANCH} SHA ${TARGET_COMMIT}
  status   Show the Hazard3-Doom gitlink and current Hazard3 checkout
  diff     Show local changes inside the Hazard3 submodule (read-only)
  restore  Return Hazard3 to the gitlink recorded by Hazard3-Doom HEAD
USAGE
}

require_tool git
ROOT_DIR="$(find_root)"
HAZARD3_ROOT="${ROOT_DIR}/${SUBMODULE_PATH}"

case "${1:-}" in
    test)
        activate_test_commit
        ;;
    status)
        ensure_hazard3_initialized
        show_status
        ;;
    diff)
        ensure_hazard3_initialized
        show_diff
        ;;
    restore)
        restore_pinned_commit
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
