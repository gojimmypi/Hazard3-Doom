#!/bin/bash
#
# Report failed quality checks with their actual diagnostics in the final
# GitHub Actions step and Job Summary. The individual checks write logs to
# QUALITY_LOG_DIR and use continue-on-error so every check can run.

set -euo pipefail

: "${QUALITY_LOG_DIR:?QUALITY_LOG_DIR is required}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"

status=0
failed_checks=()

escape_github_command()
{
    local value="$1"

    value="${value//'%'/'%25'}"
    value="${value//$'\r'/'%0D'}"
    value="${value//$'\n'/'%0A'}"
    printf '%s' "${value}"
}

first_actionable_line()
{
    local log="$1"
    local fallback="$2"
    local line=""

    if [[ -s "${log}" ]]; then
        line="$(grep -m1 '^Fix:' "${log}" || true)"
        if [[ -z "${line}" ]]; then
            line="$(grep -m1 -v '^[[:space:]]*$' "${log}" || true)"
        fi
    fi

    if [[ -z "${line}" ]]; then
        line="${fallback}"
    fi

    printf '%s' "${line}"
}

report_result()
{
    local name="$1"
    local outcome="$2"
    local log="$3"
    local guidance="$4"
    local annotation=""

    if [[ "${outcome}" == "success" ]]; then
        printf '[PASS] %s\n' "${name}"
        printf -- '- [PASS] %s\n' "${name}" >> "${GITHUB_STEP_SUMMARY}"
        return
    fi

    status=1
    failed_checks+=("${name}")

    printf '\n[FAIL] %s\n' "${name}"
    printf '%s\n' "${guidance}"

    if [[ -s "${log}" ]]; then
        printf '%s\n' '--- exact diagnostics ---'
        tail -n 120 "${log}"
        printf '%s\n' '--- end diagnostics ---'
    else
        printf 'No diagnostic log was produced at %s\n' "${log}"
    fi

    {
        printf -- '- [FAIL] **%s**\n' "${name}"
        printf '  - %s\n' "${guidance}"
        if [[ -s "${log}" ]]; then
            echo
            echo '  ```text'
            tail -n 120 "${log}" | sed 's/^/  /'
            echo '  ```'
        fi
    } >> "${GITHUB_STEP_SUMMARY}"

    annotation="$(first_actionable_line "${log}" "${guidance}")"
    annotation="$(escape_github_command "${annotation}")"
    echo "::error title=${name} failed::${annotation}"
}

{
    echo '## Quality check summary'
    echo
} >> "${GITHUB_STEP_SUMMARY}"

report_result \
    'Script-check dependency installation' \
    "${INSTALL_SCRIPT_CHECKS_OUTCOME:-skipped}" \
    "${QUALITY_LOG_DIR}/install-script-checks.log" \
    'ShellCheck could not be installed.'

report_result \
    'ShellCheck' \
    "${SHELLCHECK_OUTCOME:-skipped}" \
    "${QUALITY_LOG_DIR}/shellcheck.log" \
    'One or more shell scripts failed ShellCheck.'

report_result \
    'Executable permission check' \
    "${EXECUTABLE_PERMISSIONS_OUTCOME:-skipped}" \
    "${QUALITY_LOG_DIR}/executable-permissions.log" \
    'One or more tracked shell scripts do not have Git mode 100755.'

report_result \
    'Python syntax check' \
    "${PYTHON_SYNTAX_OUTCOME:-skipped}" \
    "${QUALITY_LOG_DIR}/python-syntax.log" \
    'Python syntax validation failed.'

report_result \
    'Host-tool tests' \
    "${HOST_TOOL_TESTS_OUTCOME:-skipped}" \
    "${QUALITY_LOG_DIR}/host-tool-tests.log" \
    'One or more host-tool unit tests failed.'

if (( status != 0 )); then
    printf '\nFailed quality checks:\n'
    printf '  - %s\n' "${failed_checks[@]}"
    printf '\nThe exact diagnostics and fixes are printed above and copied to the Job Summary.\n'
fi

exit "${status}"
