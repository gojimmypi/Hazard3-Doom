#!/bin/bash

# Check a machine for the Hazard3-Doom development requirements.
#
# This script is non-destructive: it does not install packages or change
# configuration. Required items affect the exit status; optional items do not.

set -u
set -o pipefail

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

section()
{
    printf '\n=== %s ===\n' "$1"
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
            output="${output%%$'\n'*}"
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

find_riscv_prefix()
{
    local candidate=""
    local gcc_path=""
    local home_dir="${HOME:-}"

    if [[ -n "${TOOLCHAIN_PREFIX:-}" ]]; then
        printf '%s' "${TOOLCHAIN_PREFIX}"
        return 0
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
            output="${output%%$'\n'*}"
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

    if output="$(
        printf '%s\n' 'int hazard3_requirements_check;' | \
            "${cc_path}" \
                -march=rv32imc_zicsr_zifencei_zba_zbb_zbs \
                -mabi=ilp32 \
                -ffreestanding \
                -x c \
                -c \
                -o /dev/null \
                - \
                2>&1
    )"; then
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

if (( BASH_VERSINFO[0] >= 4 )); then
    pass "Bash ${BASH_VERSION}"
else
    fail "Bash 4 or newer is required; found ${BASH_VERSION}"
fi

section "Required host tools"
check_tool required git "Git" "sudo apt-get install git" --version
check_tool required make "GNU Make" "sudo apt-get install make" --version
check_tool required python3 "Python 3" "sudo apt-get install python3" --version
check_tool required shellcheck "ShellCheck" "sudo apt-get install shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "$0"; then
        pass "This requirements script passes ShellCheck"
    else
        fail "This requirements script failed ShellCheck"
    fi
fi
check_tool required grep "Host utility grep" "sudo apt-get install grep"
check_tool required awk "Host utility awk" "sudo apt-get install gawk"
for tool in stat install sha256sum; do
    check_tool required "${tool}" "Host utility ${tool}" "sudo apt-get install coreutils"
done

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
    pass "RISC-V toolchain prefix: ${RISCV_PREFIX}"
    if [[ -z "${TOOLCHAIN_PREFIX:-}" && "${RISCV_PREFIX}" == */.local/xPacks/* ]]; then
        warn "xPack RISC-V toolchain was found outside the normal command-prefix search"
        printf '       Use: TOOLCHAIN_PREFIX=%q ./scripts/build.sh\n' "${RISCV_PREFIX}"
    fi
    for tool in gcc objcopy objdump size ar nm; do
        check_riscv_tool required "${RISCV_PREFIX}" "${tool}"
    done
    check_riscv_tool optional "${RISCV_PREFIX}" readelf
    check_riscv_tool optional "${RISCV_PREFIX}" gdb
    check_riscv_isa "${RISCV_PREFIX}"
else
    fail "No supported RISC-V bare-metal GCC toolchain was found"
    printf '%s\n' \
        '       Set TOOLCHAIN_PREFIX to the prefix used by your installation.' \
        '       Project reference: /opt/riscv/bin/riscv32-unknown-elf-' \
        '       xPack installations commonly use: riscv-none-elf-'
fi

section "ECP5 FPGA build tools"
check_tool required yosys "Yosys synthesis" "sudo apt-get install yosys" --version
check_tool required nextpnr-ecp5 "nextpnr ECP5 place-and-route" \
    "sudo apt-get install nextpnr-ecp5" --version
check_tool required ecppack "Project Trellis bitstream packer" \
    "sudo apt-get install fpga-trellis"
printf '%s\n' \
    'INFO: Record Yosys and nextpnr versions for release builds.' \
    '      Routing seeds are tool-version-specific; package presence alone does' \
    '      not prove equivalence with a previously qualified release toolchain.'

section "Hardware programming and debug"
check_tool optional openocd "OpenOCD JTAG debugger" "sudo apt-get install openocd" --version
check_tool optional dfu-util "DFU utility" "sudo apt-get install dfu-util" --version
check_tool optional openFPGALoader "openFPGALoader" \
    "sudo apt-get install openfpgaloader" --version
check_tool optional fujprog "ULX3S fujprog" ""
check_tool optional lsusb "USB device listing" "sudo apt-get install usbutils"

if command -v id >/dev/null 2>&1; then
    if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx dialout; then
        pass "Current user belongs to dialout group"
    else
        warn "Current user is not in the dialout group; serial access may need permissions"
    fi
fi

section "Development, simulation, and documentation"
check_tool optional gcc "Host C compiler" "sudo apt-get install build-essential" --version
check_tool optional g++ "Host C++ compiler" "sudo apt-get install build-essential" --version
check_tool optional cmake "CMake" "sudo apt-get install cmake" --version
check_tool optional ninja "Ninja" "sudo apt-get install ninja-build" --version
check_tool optional iverilog "Icarus Verilog" "sudo apt-get install iverilog" -V
check_tool optional verilator "Verilator" "sudo apt-get install verilator" --version
check_tool optional clang-tidy "clang-tidy" "sudo apt-get install clang-tidy" --version
check_tool optional timeout "timeout for timing sweeps" "sudo apt-get install coreutils"
check_tool optional nproc "nproc for parallel builds" "sudo apt-get install coreutils"
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

if command -v git >/dev/null 2>&1 && \
    git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    printf 'Repository: %s\n' "${REPO_ROOT}"

    if [[ "$(git config --get core.symlinks 2>/dev/null || true)" == "false" ]]; then
        warn "Git core.symlinks=false; tracked symlinks may appear as type changes"
    else
        pass "Git symlink handling is not explicitly disabled"
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

section "Summary"
printf 'Pass: %d\n' "${PASS_COUNT}"
printf 'Warn: %d\n' "${WARN_COUNT}"
printf 'Fail: %d\n' "${FAIL_COUNT}"

if (( FAIL_COUNT > 0 )); then
    printf '\nRESULT: FAIL - this machine is missing one or more required items.\n' >&2
    exit 1
fi

printf '\nRESULT: PASS - all required items were found.\n'
