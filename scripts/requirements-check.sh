#!/bin/bash

# Check a machine for the Hazard3-Doom development requirements.
#
# This script is non-destructive: it does not install packages or change
# configuration. Required items affect the exit status; optional items do not.
#
# Linux and WSL are intentionally handled differently:
#   * Native Linux requires native Linux tools.
#   * WSL may use selected Windows executables already shipped in bin/ when
#     Windows interop is enabled. These are useful for programming/debugging,
#     but they do not replace the native Linux/WSL build toolchain.
#   * bin/riscv-gcc is an optional, ignored xPack installation for native
#     Windows builds. It does not satisfy the normal Bash build requirement.

set -u
set -o pipefail

CHECK_PROFILE="full"
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
IS_WSL=0
WSL_INTEROP_AVAILABLE=0
WSL_VERSION=0
REPO_ON_WINDOWS_FS=0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." 2>/dev/null && pwd)" || REPO_ROOT=""
fi
BIN_DIR="${REPO_ROOT:+${REPO_ROOT}/bin}"

usage()
{
    cat <<EOF_USAGE
Usage: ${0##*/} [--test-scripts]

With no options, check the full Hazard3-Doom development environment.

  --test-scripts  Check only prerequisites needed by scripts/test-scripts.sh.
  -h, --help      Show this help text.
EOF_USAGE
}

parse_args()
{
    while (( $# > 0 )); do
        case "$1" in
        --test-scripts)
            CHECK_PROFILE="test-scripts"
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
}

section()
{
    printf '\n=== %s ===\n' "$1"
}

info()
{
    printf '[INFO] %s\n' "$1"
}

pass()
{
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '[PASS] %s\n' "$1"
}

warn()
{
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '[WARN] %s\n' "$1"
}

fail()
{
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[FAIL] %s\n' "$1" >&2
}

finish()
{
    section "Summary"
    printf 'Pass: %d\n' "${PASS_COUNT}"
    printf 'Warn: %d\n' "${WARN_COUNT}"
    printf 'Fail: %d\n' "${FAIL_COUNT}"

    if (( FAIL_COUNT > 0 )); then
        if [[ "${CHECK_PROFILE}" == "test-scripts" ]]; then
            printf '\nRESULT: FAIL - test-scripts prerequisites are missing.\n' >&2
        else
            printf '\nRESULT: FAIL - this machine is missing one or more required items.\n' >&2
        fi
        exit 1
    fi

    if [[ "${CHECK_PROFILE}" == "test-scripts" ]]; then
        printf '\nRESULT: PASS - test-scripts prerequisites were found.\n'
    else
        printf '\nRESULT: PASS - all required items were found.\n'
    fi
    exit 0
}

check_tool()
{
    local level="$1"
    local command_name="$2"
    local description="$3"
    local install_hint="$4"
    shift 4

    local path=""
    local output=""

    if path="$(command -v "${command_name}" 2>/dev/null)"; then
        if (( $# > 0 )); then
            output="$("${path}" "$@" 2>&1 || true)"
            output="$(normalize_first_line "${output}")"
            if [[ "${command_name}" == "iverilog" ]]; then
                output="${output% ()}"
            fi
        fi

        if [[ -n "${output}" ]]; then
            pass "${description}: ${output} (${path})"
        else
            pass "${description}: ${path}"
        fi
        return 0
    fi

    if [[ "${level}" == "required" ]]; then
        fail "Missing required tool: ${command_name} (${description})"
    else
        warn "Missing optional tool: ${command_name} (${description})"
    fi

    if [[ -n "${install_hint}" ]]; then
        printf '       Install: %s\n' "${install_hint}"
    fi

    return 0
}

check_python_module()
{
    local level="$1"
    local module_name="$2"
    local description="$3"
    local install_hint="$4"
    local version=""

    command -v python3 >/dev/null 2>&1 || return 0

    if version="$(python3 - "${module_name}" 2>/dev/null <<'PY'
import importlib
import sys

module = importlib.import_module(sys.argv[1])
print(getattr(module, "__version__", getattr(module, "VERSION", "")))
PY
    )"; then
        if [[ -n "${version}" ]]; then
            pass "${description}: ${version}"
        else
            pass "${description}"
        fi
        return 0
    fi

    if [[ "${level}" == "required" ]]; then
        fail "Missing required Python module: ${description}"
    else
        warn "Missing optional Python module: ${description}"
    fi

    if [[ -n "${install_hint}" ]]; then
        printf '       Install: %s\n' "${install_hint}"
    fi
}

resolve_executable()
{
    local executable="$1"

    if [[ "${executable}" == */* ]]; then
        [[ -x "${executable}" ]] || return 1
        printf '%s' "${executable}"
    else
        command -v "${executable}" 2>/dev/null
    fi
}

normalize_first_line()
{
    local output="$1"

    # Windows executables launched through WSL commonly emit CRLF. Strip CR
    # before selecting the first line so captured version text cannot rewrite
    # the beginning of the status line when printed by a Linux terminal.
    output="${output//$'\r'/}"
    output="${output%%$'\n'*}"
    printf '%s' "${output}"
}

version_ge()
{
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

check_cmake()
{
    local path=""
    local output=""
    local version=""

    if ! path="$(command -v cmake 2>/dev/null)"; then
        fail "Missing required tool: cmake (CMake 3.28 or newer)"
        printf '%s\n' '       Install: ./scripts/install-cmake.sh'
        return 0
    fi

    output="$("${path}" --version 2>&1 || true)"
    output="$(normalize_first_line "${output}")"

    if [[ "${output}" =~ ^cmake[[:space:]]version[[:space:]]([0-9]+(\.[0-9]+)+) ]]; then
        version="${BASH_REMATCH[1]}"
    fi

    if [[ -z "${version}" ]]; then
        fail "Could not determine CMake version from: ${output:-no output}"
        printf '%s\n' '       Install: ./scripts/install-cmake.sh'
        return 0
    fi

    if version_ge "${version}" "3.28"; then
        pass "CMake: ${output} (${path})"
    else
        fail "CMake 3.28 or newer is required for the reference Yosys 0.67 build; found ${version} (${path})"
        printf '%s\n' '       Install/update: ./scripts/install-cmake.sh'
    fi
}

detect_environment()
{
    local kernel_release=""
    local fs_type=""

    kernel_release="$(uname -r 2>/dev/null || true)"

    if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
        [[ "${kernel_release,,}" == *microsoft* ]]; then
        IS_WSL=1
    fi

    if (( IS_WSL == 1 )); then
        if [[ "${kernel_release,,}" == *wsl2* ]] ||
            grep -qi 'wsl2' /proc/version 2>/dev/null; then
            WSL_VERSION=2
        else
            WSL_VERSION=1
        fi

        if [[ -n "${WSL_INTEROP:-}" ]] ||
            [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]] ||
            command -v cmd.exe >/dev/null 2>&1; then
            WSL_INTEROP_AVAILABLE=1
        fi

        if [[ -n "${REPO_ROOT}" ]]; then
            fs_type="$(stat -f -c '%T' "${REPO_ROOT}" 2>/dev/null || true)"
            case "${REPO_ROOT}" in
            /mnt/[a-zA-Z]|/mnt/[a-zA-Z]/*)
                REPO_ON_WINDOWS_FS=1
                ;;
            esac
            case "${fs_type}" in
            9p|drvfs)
                REPO_ON_WINDOWS_FS=1
                ;;
            esac
        fi
    fi
}

windows_bundle_usable()
{
    (( IS_WSL == 1 )) || return 1
    (( WSL_INTEROP_AVAILABLE == 1 )) || return 1
    (( REPO_ON_WINDOWS_FS == 1 )) || return 1
    [[ -n "${BIN_DIR}" && -d "${BIN_DIR}" ]]
}

check_tool_with_wsl_bundle()
{
    local command_name="$1"
    local bundle_relative="$2"
    local description="$3"
    local install_hint="$4"
    shift 4

    local path=""
    local bundle_path="${BIN_DIR:+${BIN_DIR}/${bundle_relative}}"
    local output=""

    if path="$(command -v "${command_name}" 2>/dev/null)"; then
        if (( $# > 0 )); then
            output="$("${path}" "$@" 2>&1 || true)"
            output="$(normalize_first_line "${output}")"
        fi
        if [[ -n "${output}" ]]; then
            pass "${description}: ${output} (${path})"
        else
            pass "${description}: ${path}"
        fi
        return 0
    fi

    if windows_bundle_usable && [[ -f "${bundle_path}" ]]; then
        pass "${description}: bundled Windows tool ${bundle_path}"
        return 0
    fi

    warn "Missing optional tool: ${command_name} (${description})"
    if [[ -n "${install_hint}" ]]; then
        printf '       Install native Linux tool: %s\n' "${install_hint}"
    fi
    if (( IS_WSL == 1 )); then
        if [[ -f "${bundle_path}" ]]; then
            printf '       Bundled Windows tool exists but is not counted as usable here: %s\n' \
                "${bundle_path}"
            if (( WSL_INTEROP_AVAILABLE == 0 )); then
                printf '%s\n' '       Reason: WSL Windows interop was not detected.'
            elif (( REPO_ON_WINDOWS_FS == 0 )); then
                printf '%s\n' \
                    '       Reason: repository is not on a Windows-mounted filesystem.'
            fi
        else
            printf '       WSL alternative when present: %s\n' "${bundle_path}"
        fi
    fi
}

find_riscv_prefix()
{
    local candidate=""
    local gcc_path=""
    local home_dir="${HOME:-}"

    if [[ -n "${TOOLCHAIN_PREFIX:-}" ]]; then
        if resolve_executable "${TOOLCHAIN_PREFIX}gcc" >/dev/null 2>&1; then
            printf '%s' "${TOOLCHAIN_PREFIX}"
            return 0
        fi
        return 1
    fi

    for candidate in \
        /opt/riscv/bin/riscv32-unknown-elf- \
        riscv-none-elf- \
        riscv32-unknown-elf- \
        riscv64-unknown-elf-
    do
        if resolve_executable "${candidate}gcc" >/dev/null 2>&1; then
            printf '%s' "${candidate}"
            return 0
        fi
    done

    if [[ -n "${home_dir}" ]]; then
        for gcc_path in \
            "${home_dir}"/.local/xPacks/riscv-none-elf-gcc/*/bin/riscv-none-elf-gcc
        do
            if [[ -x "${gcc_path}" ]]; then
                printf '%s' "${gcc_path%gcc}"
                return 0
            fi
        done
    fi

    return 1
}

check_riscv_tool()
{
    local level="$1"
    local prefix="$2"
    local suffix="$3"
    local executable="${prefix}${suffix}"
    local path=""
    local output=""

    if path="$(resolve_executable "${executable}")"; then
        if [[ "${suffix}" == "gcc" ]]; then
            output="$("${path}" --version 2>&1 || true)"
            output="$(normalize_first_line "${output}")"
            pass "RISC-V ${suffix}: ${output} (${path})"
        else
            pass "RISC-V ${suffix}: ${path}"
        fi
        return 0
    fi

    if [[ "${level}" == "required" ]]; then
        fail "Missing required RISC-V tool: ${executable}"
    else
        warn "Missing optional RISC-V tool: ${executable}"
    fi
}

check_riscv_isa()
{
    local prefix="$1"
    local cc_path=""
    local output=""

    if ! cc_path="$(resolve_executable "${prefix}gcc")"; then
        return 0
    fi

    if output="$({
        printf '%s\n' 'int hazard3_requirements_check;' |
            "${cc_path}" \
                -march=rv32imc_zicsr_zifencei_zba_zbb_zbs \
                -mabi=ilp32 \
                -ffreestanding \
                -x c \
                -c \
                -o /dev/null \
                -
    } 2>&1)"; then
        pass "RISC-V compiler accepts the Hazard3 RV32 ISA/ABI options"
        return 0
    fi

    fail "RISC-V compiler does not accept the Hazard3 RV32 ISA/ABI options"
    if [[ -n "${output}" ]]; then
        while IFS= read -r line; do
            printf '       %s\n' "${line}" >&2
        done <<< "${output}"
    fi
}

check_windows_xpack()
{
    local gcc_path="${BIN_DIR:+${BIN_DIR}/riscv-gcc/bin/riscv-none-elf-gcc.exe}"
    local output=""

    [[ -n "${BIN_DIR}" ]] || return 0

    if [[ ! -f "${gcc_path}" ]]; then
        info "Optional native-Windows xPack RISC-V GCC is not installed under bin/riscv-gcc."
        info "Install it only for native Windows builds; it is ignored by Git."
        return 0
    fi

    if windows_bundle_usable; then
        if output="$("${gcc_path}" --version 2>&1)"; then
            output="$(normalize_first_line "${output}")"
            pass "Optional native-Windows xPack RISC-V GCC: ${output} (${gcc_path})"
        else
            warn "Native-Windows xPack RISC-V GCC exists but could not be executed from WSL"
            printf '       Path: %s\n' "${gcc_path}"
        fi
    else
        info "Optional native-Windows xPack RISC-V GCC is installed: ${gcc_path}"
    fi

    info "bin/riscv-gcc is for the native Windows build path and does not satisfy scripts/build.sh on Linux/WSL."
}

check_bin_inventory()
{
    local manifest="${BIN_DIR:+${BIN_DIR}/INVENTORY.sha256}"

    [[ -n "${BIN_DIR}" && -d "${BIN_DIR}" ]] || return 0

    if [[ -f "${manifest}" ]] && command -v sha256sum >/dev/null 2>&1; then
        if (cd -- "${BIN_DIR}" && sha256sum -c INVENTORY.sha256 >/dev/null 2>&1); then
            pass "Tracked bin/ package checksums match INVENTORY.sha256"
        else
            warn "One or more tracked bin/ package checksums do not match INVENTORY.sha256"
            printf '%s\n' '       Verify with: (cd bin && sha256sum -c INVENTORY.sha256)'
        fi
    else
        info "bin/ checksum inventory is unavailable; skipping bundled-file verification."
    fi
}

parse_args "$@"
detect_environment

section "Environment"
if (( IS_WSL == 1 )); then
    printf 'Environment: WSL%d (%s)\n' \
        "${WSL_VERSION}" "${WSL_DISTRO_NAME:-distribution name unavailable}"
    if (( WSL_VERSION == 1 )); then
        info "WSL1 detected; Linux USB tool presence does not by itself prove direct device access."
    else
        info "WSL2 detected; USB/programmer device access may require host-to-WSL passthrough."
    fi

    if (( WSL_INTEROP_AVAILABLE == 1 )); then
        pass "WSL Windows interop is available"
    else
        warn "WSL Windows interop was not detected; bundled bin/*.exe tools cannot be used from this shell"
    fi

    if (( REPO_ON_WINDOWS_FS == 1 )); then
        pass "Repository is on a Windows-mounted filesystem: ${REPO_ROOT}"
        info "Bundled Windows programming/debug tools under bin/ may be used from WSL."
    else
        info "Repository is not on a Windows-mounted filesystem: ${REPO_ROOT:-unknown}"
        info "Native Linux tools will be preferred; bundled Windows tools are not counted as WSL fallbacks."
    fi
else
    printf '%s\n' 'Environment: native Linux'
    info "Windows executables under bin/ are not counted as Linux requirements."
fi

section "Host"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'OS: %s\n' "${PRETTY_NAME:-${NAME:-unknown}}"
else
    printf 'OS: %s\n' "$(uname -s)"
fi
printf 'Architecture: %s\n' "$(uname -m)"
printf 'Kernel: %s\n' "$(uname -r)"
printf 'Repository: %s\n' "${REPO_ROOT:-not detected}"

if (( BASH_VERSINFO[0] >= 4 )); then
    pass "Bash ${BASH_VERSION}"
else
    fail "Bash 4 or newer is required; found ${BASH_VERSION}"
fi

section "Required host tools"
printf 'Profile: %s\n' "${CHECK_PROFILE}"
check_tool required git        "Git"               "sudo apt-get install git" --version
check_tool required python3    "Python 3"          "sudo apt-get install python3" --version
check_tool required shellcheck "ShellCheck"        "sudo apt-get install shellcheck" --version
check_tool required grep       "Host utility grep" "sudo apt-get install grep" --version
check_tool required awk        "Host utility awk"  "sudo apt-get install gawk" --version
for tool in cat cmp diff find mkdir sha256sum sort tail tee; do
    check_tool required "${tool}" "Host utility ${tool}" "sudo apt-get install coreutils"
done

if [[ "${CHECK_PROFILE}" == "full" ]]; then
    check_tool required make "GNU Make" $'sudo apt-get install make\n       Also installed automatically by: ./scripts/install-nextpnr-ecp5.sh' --version
    check_cmake
    for tool in env install stat; do
        check_tool required "${tool}" "Host utility ${tool}" "sudo apt-get install coreutils"
    done
else
    finish
fi

section "Python"
if command -v python3 >/dev/null 2>&1; then
    if python3 -m pip --version >/dev/null 2>&1; then
        pass "pip: $(python3 -m pip --version 2>&1)"
    else
        warn "pip is unavailable"
        printf '%s\n' '       Install: sudo apt-get install python3-pip'
    fi

    if python3 -c 'import venv' >/dev/null 2>&1; then
        pass "Python venv module"
    else
        warn "Python venv module is unavailable"
        printf '%s\n' '       Install: sudo apt-get install python3-venv'
    fi
fi

check_python_module required serial "pyserial" "sudo apt-get install python3-serial"

section "RISC-V bare-metal toolchain"
RISCV_PREFIX=""
if RISCV_PREFIX="$(find_riscv_prefix)"; then
    pass "Native Linux/WSL RISC-V toolchain prefix: ${RISCV_PREFIX}"
    if [[ -z "${TOOLCHAIN_PREFIX:-}" && "${RISCV_PREFIX}" == */.local/xPacks/* ]]; then
        info "Linux xPack RISC-V toolchain was found outside PATH."
        printf '       Use: TOOLCHAIN_PREFIX=%q ./scripts/build.sh\n' "${RISCV_PREFIX}"
    fi
    for tool in gcc objcopy objdump size ar nm; do
        check_riscv_tool required "${RISCV_PREFIX}" "${tool}"
    done
    check_riscv_tool optional "${RISCV_PREFIX}" readelf
    if resolve_executable "${RISCV_PREFIX}gdb" >/dev/null 2>&1; then
        check_riscv_tool optional "${RISCV_PREFIX}" gdb
    elif windows_bundle_usable && \
        [[ -f "${BIN_DIR}/gdb/riscv-none-elf-gdb.exe" ]]; then
        pass "RISC-V GDB: bundled Windows tool ${BIN_DIR}/gdb/riscv-none-elf-gdb.exe"
    else
        warn "RISC-V GDB is unavailable; source-level JTAG debugging will be limited"
    fi
    check_riscv_isa "${RISCV_PREFIX}"
else
    fail "No supported native Linux/WSL RISC-V bare-metal GCC toolchain was found"
    if [[ -n "${TOOLCHAIN_PREFIX:-}" ]]; then
        printf '       TOOLCHAIN_PREFIX was set but unusable: %s\n' "${TOOLCHAIN_PREFIX}"
    fi
    printf '%s\n' \
        '       Project reference: /opt/riscv/bin/riscv32-unknown-elf-' \
        '       Linux xPack installations commonly use: riscv-none-elf-' \
        '         use: ./scripts/install-riscv-toolchain.sh' \
        '       Ubuntu alternative: sudo apt-get install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf'
fi

section "Repository Windows tool bundle"
if [[ -n "${BIN_DIR}" && -d "${BIN_DIR}" ]]; then
    info "Repository bin directory: ${BIN_DIR}"
    check_bin_inventory
    check_windows_xpack
else
    info "Repository bin/ directory was not found."
fi

section "ECP5 FPGA build tools"
check_tool required yosys        "Yosys synthesis"                  "./scripts/install-yosys.sh" --version
check_tool required nextpnr-ecp5 "nextpnr ECP5 place-and-route"     "./scripts/install-nextpnr-ecp5.sh" --version
check_tool required ecppack      "Project Trellis bitstream packer" "./scripts/install-nextpnr-ecp5.sh" --version
printf '%s\n' \
    'INFO: Record Yosys and nextpnr versions for release builds.' \
    '      Routing seeds are tool-version-specific; package presence alone does' \
    '      not prove equivalence with a previously qualified release toolchain.'

section "Hardware programming and debug"
if (( IS_WSL == 1 )); then
    info "Installed tools are checked here; physical USB/JTAG/serial device accessibility is not."
fi
check_tool_with_wsl_bundle openocd \
    "openocd.exe" \
    "OpenOCD JTAG debugger" \
    "sudo apt-get install openocd" \
    --version
check_tool_with_wsl_bundle dfu-util \
    "dfu-util.exe" \
    "DFU utility" \
    "sudo apt-get install dfu-util" \
    --version
check_tool_with_wsl_bundle openFPGALoader \
    "openFPGALoader.exe" \
    "openFPGALoader" \
    "sudo apt-get install openfpgaloader" \
    --version
check_tool_with_wsl_bundle fujprog \
    "fujprog-v48-win64.exe" \
    "ULX3S fujprog" \
    "build from https://github.com/kost/fujprog"
check_tool optional lsusb "USB device listing" "sudo apt-get install usbutils"

if (( IS_WSL == 1 )); then
    check_tool optional wslpath "WSL path conversion" "installed with WSL"
fi

if command -v id >/dev/null 2>&1; then
    if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx dialout; then
        pass "Current user belongs to dialout group"
    elif (( IS_WSL == 1 )); then
        info "Current user is not in dialout; WSL serial access may instead use Windows COM-port integration."
    else
        warn "Current user is not in the dialout group; serial access may need permissions"
        printf '%s\n' "       Typical fix: sudo usermod -aG dialout \"\$USER\"; then log out and back in."
    fi
fi

section "Development, simulation, and documentation"
check_tool optional gcc        "Host C compiler"   "sudo apt-get install build-essential" --version
check_tool optional g++        "Host C++ compiler" "sudo apt-get install build-essential" --version
check_tool optional ninja      "Ninja"             "sudo apt-get install ninja-build" --version
check_tool optional iverilog   "Icarus Verilog"    "sudo apt-get install iverilog" -V
check_tool optional verilator  "Verilator"         "sudo apt-get install verilator" --version
check_tool optional clang-tidy "clang-tidy"        "sudo apt-get install clang-tidy" --version
check_tool optional timeout    "timeout for timing sweeps" "sudo apt-get install coreutils"
check_tool optional nproc      "nproc for parallel builds" "sudo apt-get install coreutils"
check_tool optional curl       "curl for setup/download helpers" "sudo apt-get install curl" --version
check_tool optional wget       "wget for setup/download helpers" "sudo apt-get install wget" --version
check_tool optional tar        "tar archive utility" "sudo apt-get install tar" --version
check_tool optional unzip      "ZIP extraction utility" "sudo apt-get install unzip" -v
check_tool optional zip        "ZIP creation utility" "sudo apt-get install zip" -v
check_python_module optional sphinx "Sphinx" \
    "python3 -m pip install -r docs/requirements.txt"

section "Git configuration"
if command -v git >/dev/null 2>&1; then
    GIT_AUTOCRLF="$(git config --global --get core.autocrlf 2>/dev/null || true)"
    case "${GIT_AUTOCRLF}" in
    true)
        warn "Git core.autocrlf=true can convert Bash scripts to CRLF"
        printf '%s\n' '       Prefer core.autocrlf=input or leave it unset on Linux/WSL.'
        ;;
    input|false)
        pass "Git core.autocrlf=${GIT_AUTOCRLF}"
        ;;
    "")
        pass "Git core.autocrlf is unset"
        ;;
    *)
        warn "Unexpected Git core.autocrlf value: ${GIT_AUTOCRLF}"
        ;;
    esac
else
    warn "Git configuration checks skipped because Git is unavailable"
fi

if command -v git >/dev/null 2>&1 &&
    git -C "${REPO_ROOT:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Repository: %s\n' "${REPO_ROOT}"
    git remote --verbose

    if [[ "$(git -C "${REPO_ROOT}" config --get core.symlinks 2>/dev/null || true)" == "false" ]]; then
        warn "Git core.symlinks=false; tracked symlinks may appear as type changes"
    else
        pass "Git symlink handling is not explicitly disabled"
    fi

    if (( IS_WSL == 1 && REPO_ON_WINDOWS_FS == 1 )); then
        info "WSL checkout is on a Windows filesystem; preserve Git symlink and LF behavior carefully."
    fi

    if [[ -f "${REPO_ROOT}/.gitmodules" ]]; then
        SUBMODULE_STATUS="$(git -C "${REPO_ROOT}" submodule status --recursive 2>/dev/null || true)"
        if grep -q '^-' <<< "${SUBMODULE_STATUS}"; then
            fail "One or more Git submodules are not initialized"
            printf '%s\n' '       Run: git submodule sync --recursive'
            printf '%s\n' '       Run: git submodule update --init --recursive'
        elif grep -q '^U' <<< "${SUBMODULE_STATUS}"; then
            fail "One or more Git submodules have merge conflicts"
        elif [[ -n "${SUBMODULE_STATUS}" ]]; then
            pass "Git submodules are initialized"
            if grep -q '^+' <<< "${SUBMODULE_STATUS}"; then
                warn "One or more submodules differ from the recorded gitlinks"
            fi
        fi
    fi
fi

finish
