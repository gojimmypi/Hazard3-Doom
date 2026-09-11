#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: test-readthedocs.sh
# Path: scripts/test-readthedocs.sh
#
# Project: Hazard3-Doom
# Purpose: Test the Sphinx / Read the Docs documentation locally.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

set -Eeuo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"
readonly SCRIPT_DIR

REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
readonly REPO_ROOT
readonly DOCS_DIR="${REPO_ROOT}/docs"
readonly REQUIREMENTS_FILE="${DOCS_DIR}/requirements.txt"
readonly RTD_CONFIG="${REPO_ROOT}/.readthedocs.yaml"
readonly BUILD_ROOT="${REPO_ROOT}/build/readthedocs"

# Sphinx 9 requires Python 3.12+. Python 3.10 can still provide a very useful
# local preflight build with the newest Sphinx branch that supports it.
readonly PY310_SPHINX_VERSION="8.1.3"

LANGUAGE="all"
RUN_LINKCHECK=0
CLEAN_OUTPUT=0
RECREATE_VENV=0
REQUIRE_RTD_PYTHON=0

usage() {
    cat <<'EOF'
Usage:
  ./scripts/test-readthedocs.sh [options]

Build the Hazard3-Doom Sphinx documentation locally and fail on warnings.

Options:
  --language LANG       Build en, fr, hr, or all (default: all)
  --linkcheck           Also check external links after the HTML build
  --clean               Remove previous HTML, doctrees, and linkcheck output
  --recreate-venv       Recreate the local documentation virtual environment
  --require-rtd-python  Require the exact Python version from .readthedocs.yaml
  -h, --help            Show this help

Examples:
  ./scripts/test-readthedocs.sh
  ./scripts/test-readthedocs.sh --language en
  ./scripts/test-readthedocs.sh --clean
  ./scripts/test-readthedocs.sh --language en --linkcheck
  ./scripts/test-readthedocs.sh --require-rtd-python

Normal mode is intended as a fast local preflight check. If the local Python
is older than the Read the Docs Python version, the script uses a compatible
Sphinx release while preserving the rest of docs/requirements.txt.

Use --require-rtd-python when exact Read the Docs interpreter/package parity
is required.

Output:
  build/readthedocs/html/<language>/
  build/readthedocs/linkcheck/<language>/
EOF
}

die() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

info() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

pass() {
    printf '[PASS] %s\n' "$*"
}

while (($# > 0)); do
    case "$1" in
        --language)
            (($# >= 2)) || die "--language requires an argument"
            LANGUAGE="$2"
            shift 2
            ;;
        --linkcheck)
            RUN_LINKCHECK=1
            shift
            ;;
        --clean)
            CLEAN_OUTPUT=1
            shift
            ;;
        --recreate-venv)
            RECREATE_VENV=1
            shift
            ;;
        --require-rtd-python)
            REQUIRE_RTD_PYTHON=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

case "${LANGUAGE}" in
    en|fr|hr|all)
        ;;
    *)
        die "Unsupported language '${LANGUAGE}'. Use en, fr, hr, or all."
        ;;
esac

[[ -f "${RTD_CONFIG}" ]] ||
    die "Missing Read the Docs configuration: ${RTD_CONFIG}"
[[ -f "${DOCS_DIR}/conf.py" ]] ||
    die "Missing Sphinx configuration: ${DOCS_DIR}/conf.py"
[[ -f "${REQUIREMENTS_FILE}" ]] ||
    die "Missing documentation requirements: ${REQUIREMENTS_FILE}"

RTD_PYTHON="$(
    awk '
        /^[[:space:]]*tools:[[:space:]]*$/ {
            in_tools = 1
            next
        }
        in_tools && /^[^[:space:]]/ {
            in_tools = 0
        }
        in_tools && /^[[:space:]]*python:[[:space:]]*/ {
            line = $0
            sub(/^[[:space:]]*python:[[:space:]]*/, "", line)
            gsub(/["'\'']/, "", line)
            sub(/[[:space:]]*#.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            print line
            exit
        }
    ' "${RTD_CONFIG}"
)"

[[ -n "${RTD_PYTHON}" ]] ||
    die "Could not determine build.tools.python from ${RTD_CONFIG}"

readonly RTD_PYTHON

if command -v "python${RTD_PYTHON}" >/dev/null 2>&1; then
    PYTHON="$(command -v "python${RTD_PYTHON}")"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
    PYTHON="$(command -v python)"
else
    die "Python 3 is required."
fi
readonly PYTHON

LOCAL_PYTHON="$(
    "${PYTHON}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
)"
readonly LOCAL_PYTHON

if ((REQUIRE_RTD_PYTHON)) && [[ "${LOCAL_PYTHON}" != "${RTD_PYTHON}" ]]; then
    die "Read the Docs uses Python ${RTD_PYTHON}; local Python is ${LOCAL_PYTHON}."
fi

readonly VENV_DIR="${BUILD_ROOT}/.venv-python${LOCAL_PYTHON}"
readonly VENV_PYTHON="${VENV_DIR}/bin/python"
readonly SPHINX_BUILD="${VENV_DIR}/bin/sphinx-build"
readonly COMPAT_REQUIREMENTS="${BUILD_ROOT}/requirements-python${LOCAL_PYTHON}.txt"
readonly REQUIREMENTS_STAMP="${BUILD_ROOT}/.requirements-python${LOCAL_PYTHON}.sha256"

mkdir -p "${BUILD_ROOT}"

if ((RECREATE_VENV)); then
    info "Removing local documentation virtual environment"
    rm -rf -- "${VENV_DIR}"
    rm -f -- "${REQUIREMENTS_STAMP}"
fi

if ((CLEAN_OUTPUT)); then
    info "Removing previous documentation build output"
    rm -rf -- \
        "${BUILD_ROOT}/html" \
        "${BUILD_ROOT}/doctrees" \
        "${BUILD_ROOT}/linkcheck"
fi

if [[ ! -x "${VENV_PYTHON}" ]]; then
    info "Creating Python ${LOCAL_PYTHON} virtual environment: ${VENV_DIR}"

    if ! "${PYTHON}" -m venv "${VENV_DIR}"; then
        die "Could not create the virtual environment. On Ubuntu, install python${LOCAL_PYTHON}-venv."
    fi
fi

EFFECTIVE_REQUIREMENTS="${REQUIREMENTS_FILE}"
BUILD_MODE="Read the Docs parity"

if [[ "${LOCAL_PYTHON}" != "${RTD_PYTHON}" ]]; then
    BUILD_MODE="local compatibility"
    warn "Local Python is ${LOCAL_PYTHON}; Read the Docs uses Python ${RTD_PYTHON}."
    warn "Using local compatibility mode for fast Sphinx/RST validation."

    case "${LOCAL_PYTHON}" in
        3.10|3.11)
            awk -v sphinx_version="${PY310_SPHINX_VERSION}" '
                BEGIN {
                    replaced = 0
                }
                /^[[:space:]]*[Ss]phinx([<>=!~].*)?[[:space:]]*$/ {
                    print "Sphinx==" sphinx_version
                    replaced = 1
                    next
                }
                {
                    print
                }
                END {
                    if (!replaced) {
                        print "Sphinx==" sphinx_version
                    }
                }
            ' "${REQUIREMENTS_FILE}" >"${COMPAT_REQUIREMENTS}"

            EFFECTIVE_REQUIREMENTS="${COMPAT_REQUIREMENTS}"
            ;;
        *)
            die "No compatibility Sphinx version is configured for Python ${LOCAL_PYTHON}."
            ;;
    esac
fi

readonly EFFECTIVE_REQUIREMENTS
readonly BUILD_MODE

requirements_hash="$(
    "${VENV_PYTHON}" - "${EFFECTIVE_REQUIREMENTS}" <<'PY'
import hashlib
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
print(hashlib.sha256(path.read_bytes()).hexdigest())
PY
)"

installed_hash=""
if [[ -f "${REQUIREMENTS_STAMP}" ]]; then
    installed_hash="$(<"${REQUIREMENTS_STAMP}")"
fi

if [[ "${requirements_hash}" != "${installed_hash}" ]] ||
    [[ ! -x "${SPHINX_BUILD}" ]]; then
    info "Installing documentation requirements"
    "${VENV_PYTHON}" -m pip install \
        --disable-pip-version-check \
        -r "${EFFECTIVE_REQUIREMENTS}"
    printf '%s\n' "${requirements_hash}" >"${REQUIREMENTS_STAMP}"
else
    pass "Documentation requirements are already installed"
fi

actual_python="$(
    "${VENV_PYTHON}" -c 'import platform; print(platform.python_version())'
)"
actual_sphinx="$("${VENV_PYTHON}" -m sphinx --version)"

info "Build mode: ${BUILD_MODE}"
info "Read the Docs Python: ${RTD_PYTHON}"
info "Local Python: ${actual_python}"
info "Sphinx: ${actual_sphinx}"

if [[ "${BUILD_MODE}" == "local compatibility" ]]; then
    warn "This catches normal RST, reference, directive, image, and Sphinx warning failures."
    warn "It is not a byte-for-byte reproduction of the hosted Sphinx 9 build."
fi

git_identifier="$(
    git -C "${REPO_ROOT}" symbolic-ref --quiet --short HEAD 2>/dev/null ||
        git -C "${REPO_ROOT}" rev-parse --short HEAD
)"
readonly git_identifier

if [[ "${LANGUAGE}" == "all" ]]; then
    languages=(en fr hr)
else
    languages=("${LANGUAGE}")
fi
readonly languages

build_language() {
    local lang="$1"
    local output_dir="${BUILD_ROOT}/html/${lang}"
    local doctree_dir="${BUILD_ROOT}/doctrees/${lang}"

    printf '\n=== Read the Docs HTML build: %s ===\n' "${lang}"

    rm -rf -- "${output_dir}" "${doctree_dir}"
    mkdir -p "${output_dir}" "${doctree_dir}"

    READTHEDOCS=True \
    READTHEDOCS_LANGUAGE="${lang}" \
    READTHEDOCS_VERSION="${READTHEDOCS_VERSION:-latest}" \
    READTHEDOCS_GIT_IDENTIFIER="${READTHEDOCS_GIT_IDENTIFIER:-${git_identifier}}" \
    READTHEDOCS_CANONICAL_URL="${READTHEDOCS_CANONICAL_URL:-https://hazard3-doom.readthedocs.io/${lang}/latest/}" \
        "${SPHINX_BUILD}" \
        -T \
        -E \
        -W \
        --keep-going \
        -b html \
        -d "${doctree_dir}" \
        "${DOCS_DIR}" \
        "${output_dir}"

    pass "HTML build: ${lang}"
    info "Open: ${output_dir}/index.html"
}

linkcheck_language() {
    local lang="$1"
    local output_dir="${BUILD_ROOT}/linkcheck/${lang}"
    local doctree_dir="${BUILD_ROOT}/doctrees/linkcheck-${lang}"

    printf '\n=== External link check: %s ===\n' "${lang}"

    rm -rf -- "${output_dir}" "${doctree_dir}"
    mkdir -p "${output_dir}" "${doctree_dir}"

    READTHEDOCS=True \
    READTHEDOCS_LANGUAGE="${lang}" \
    READTHEDOCS_VERSION="${READTHEDOCS_VERSION:-latest}" \
    READTHEDOCS_GIT_IDENTIFIER="${READTHEDOCS_GIT_IDENTIFIER:-${git_identifier}}" \
    READTHEDOCS_CANONICAL_URL="${READTHEDOCS_CANONICAL_URL:-https://hazard3-doom.readthedocs.io/${lang}/latest/}" \
        "${SPHINX_BUILD}" \
        -T \
        -E \
        -W \
        --keep-going \
        -b linkcheck \
        -d "${doctree_dir}" \
        "${DOCS_DIR}" \
        "${output_dir}"

    pass "External link check: ${lang}"
}

printf '=== Local Read the Docs test ===\n'
printf 'Repository: %s\n' "${REPO_ROOT}"
printf 'Configuration: %s\n' "${RTD_CONFIG}"
printf 'Requirements: %s\n' "${EFFECTIVE_REQUIREMENTS}"
printf 'Git identifier: %s\n' "${git_identifier}"

for lang in "${languages[@]}"; do
    build_language "${lang}"
done

if ((RUN_LINKCHECK)); then
    for lang in "${languages[@]}"; do
        linkcheck_language "${lang}"
    done
fi

printf '\n'
pass "Local Read the Docs test completed successfully"
