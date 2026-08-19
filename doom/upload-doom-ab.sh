#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 {320x200|400x240} SERIAL_PORT" >&2
    echo "Example: $0 400x240 /dev/ttyS7" >&2
    exit 2
fi

resolution="$1"
port="$2"

case "${resolution}" in
320x200|400x240)
    ;;
*)
    echo "Unsupported resolution: ${resolution}" >&2
    exit 2
    ;;
esac

image="${ROOT_DIR}/build/doom-ab/${resolution}/hazard3-doom.h3d"
if [[ ! -f "${image}" ]]; then
    echo "Missing A/B image: ${image}" >&2
    echo "Build it first with: ./doom/build-doom-ab.sh ${resolution}" >&2
    exit 1
fi

exec "${SCRIPT_DIR}/upload-doom-image.py" "${image}" --port "${port}"
