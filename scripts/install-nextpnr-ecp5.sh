#!/usr/bin/env bash
#
# Install the locally built nextpnr-ecp5 used by Hazard3-Doom timing tests.
#
# Expected build:
#   nextpnr-0.10-95-gddc6c8c8
#
# Default source:
#   <nextpnr-repo>/build-ecp5-ice40/nextpnr-ecp5
#
# Default destination:
#   /usr/local/bin/nextpnr-ecp5
#
# Usage:
#   ./scripts/install-nextpnr-ecp5.sh
#   ./scripts/install-nextpnr-ecp5.sh --dry-run
#   ./scripts/install-nextpnr-ecp5.sh --source /path/to/nextpnr-ecp5
#

set -euo pipefail

EXPECTED_VERSION="nextpnr-0.10-95-gddc6c8c8"
DESTINATION="/usr/local/bin/nextpnr-ecp5"
SOURCE=""
DRY_RUN=0

usage() {
    cat <<'USAGE'
Usage:
    install-nextpnr-ecp5.sh [options]

Options:
    --source PATH   Source nextpnr-ecp5 executable.
                    Default: build-ecp5-ice40/nextpnr-ecp5 in the
                    current nextpnr Git repository.
    --dry-run       Verify everything, but do not install.
    -h, --help      Show this help.
USAGE
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while (($# > 0)); do
    case "$1" in
        --source)
            (($# >= 2)) || die "--source requires a path"
            SOURCE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

if [[ -z "${SOURCE}" ]]; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" ||
        die "not inside the nextpnr Git repository; use --source PATH"

    SOURCE="${REPO_ROOT}/build-ecp5-ice40/nextpnr-ecp5"
fi

[[ -f "${SOURCE}" ]] || die "source binary not found: ${SOURCE}"
[[ -x "${SOURCE}" ]] || die "source binary is not executable: ${SOURCE}"

SOURCE_VERSION="$("${SOURCE}" --version 2>&1)"
printf 'Source:      %s\n' "${SOURCE}"
printf 'Version:     %s\n' "${SOURCE_VERSION}"
printf 'Destination: %s\n' "${DESTINATION}"

if [[ "${SOURCE_VERSION}" != *"${EXPECTED_VERSION}"* ]]; then
    die "expected ${EXPECTED_VERSION}, refusing to install"
fi

SOURCE_SHA256="$(sha256sum "${SOURCE}" | awk '{print $1}')"
printf 'SHA256:      %s\n' "${SOURCE_SHA256}"

if [[ -e "${DESTINATION}" ]]; then
    CURRENT_VERSION="$("${DESTINATION}" --version 2>&1 || true)"
    CURRENT_SHA256="$(sha256sum "${DESTINATION}" | awk '{print $1}')"

    printf '\nCurrently installed:\n'
    printf 'Version:     %s\n' "${CURRENT_VERSION}"
    printf 'SHA256:      %s\n' "${CURRENT_SHA256}"

    if [[ "${SOURCE_SHA256}" == "${CURRENT_SHA256}" ]]; then
        printf '\nAlready installed; no changes needed.\n'
        exit 0
    fi
fi

if ((DRY_RUN)); then
    printf '\nDry run complete; no files changed.\n'
    exit 0
fi

printf '\nInstalling...\n'
sudo install -m 0755 "${SOURCE}" "${DESTINATION}"

INSTALLED_VERSION="$("${DESTINATION}" --version 2>&1)"
INSTALLED_SHA256="$(sha256sum "${DESTINATION}" | awk '{print $1}')"

[[ "${INSTALLED_VERSION}" == *"${EXPECTED_VERSION}"* ]] ||
    die "installed binary does not report ${EXPECTED_VERSION}"

[[ "${INSTALLED_SHA256}" == "${SOURCE_SHA256}" ]] ||
    die "installed binary checksum does not match source"

printf '\nInstalled successfully:\n'
printf 'Version: %s\n' "${INSTALLED_VERSION}"
printf 'SHA256:  %s\n' "${INSTALLED_SHA256}"
printf '\nRun this in the current shell if needed:\n'
printf '    hash -r\n'
