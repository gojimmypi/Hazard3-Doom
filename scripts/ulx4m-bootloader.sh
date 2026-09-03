#!/usr/bin/env bash
# Guided ULX4M-LD DFU bootloader build, SRAM validation, installation,
# recovery, cold-boot verification, and user-bitstream programming.
#
# This script is intentionally interactive around every hardware transition
# and destructive flash operation. It never uses fixed sleeps to guess when
# the user has completed a physical action.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

MODEL="ulx4m"
BOARD="ulx4m-v002"
DEVICE="um-85k"
IDCODE="0x01113043"
DFU_VID="0x1d50"
DFU_PID="0x614b"
DFU_MATCH="1d50:614b"
ALT5_SIZE=2097152
USER_BITSTREAM_ADDR="0x200000"

OPENFPGALOADER="${REPO_ROOT}/bin/openFPGALoader.exe"
DFU_UTIL="${REPO_ROOT}/bin/dfu-util.exe"

BOOTLOADER_PROJECT_DIR=""
BOOTLOADER_DEP_ROOT=""
BOOTLOADER_RULES_DIR=""
SESSION_DIR=""
SESSION_LOG=""
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
UPGRADE_SESSION_READY=0

usage()
{
    cat <<'USAGE'
Usage:
    scripts/ulx4m-bootloader.sh check
    scripts/ulx4m-bootloader.sh build
    scripts/ulx4m-bootloader.sh sram-test
    scripts/ulx4m-bootloader.sh install
    scripts/ulx4m-bootloader.sh cold-test
    scripts/ulx4m-bootloader.sh full
    scripts/ulx4m-bootloader.sh recover-install [emergency-sram.bit]
    scripts/ulx4m-bootloader.sh program-user [fpga_ulx4m_ld.bit]

Commands:
    check           Validate repository layout, source invariants, and tools.
    build           Build normal bootloader, SRAM test image, passthru image,
                    multiboot image, and exact 2 MiB alt-5 image.
    sram-test       Hardware-test PCB BTN3 normal DFU and PCB BTN2+BTN3
                    bootloader-upgrade DFU using the normal SRAM image.
    install         Load the normal SRAM image in PCB BTN2+BTN3 mode, back up
                    alt 5, write the exact 2 MiB normal bootloader image, and
                    read/compare it byte-for-byte. Does not power-cycle.
    cold-test       Run the three persistent cold-boot tests: no buttons,
                    PCB BTN3, and PCB BTN2+BTN3.
    full            Run check, build, SRAM tests, install, and cold tests.
    recover-install Load an already-built EMERGENCY_RESTORE2 SRAM image through
                    Tigard, back up alt 5, install the normal 2 MiB image, verify
                    readback, and run cold tests.
    program-user    Enter ordinary protected DFU with PCB BTN3 and program the
                    user bitstream through alt 0.

Environment overrides:
    ULX4M_BOOTLOADER_PROJECT_DIR
        Explicit bootloader project directory. Normally auto-detected.

    ULX4M_EMERGENCY_SRAM_IMAGE
        Default emergency SRAM image for recover-install.

    ULX4M_BOOTLOADER_SKIP_SHELLCHECK=1
        Skip the optional ShellCheck self-lint. bash -n still runs.

Recommended Hazard3-Doom vendored layout:
    Hazard3-Doom/
      bootloader/
        Makefile
        mk/
        cores/misc/
        cores/usb/
        data/
        fw/
        rtl/

The bootloader/Makefile in this layout sets ROOT to bootloader/ and uses the
vendored had2019 make rules and cores directly. A full upstream layout under
third_party/had2019-playground/projects/bootloader remains supported as a
development fallback.
USAGE
}

fail()
{
    printf 'ERROR: %s\n' "$*" >&2
    return 1
}

prompt_yes_no()
{
    local prompt="$1"
    local answer

    while true; do
        printf '\n%s [Y/N]: ' "${prompt}"
        IFS= read -r answer
        case "${answer}" in
        Y|y|YES|Yes|yes)
            return 0
            ;;
        N|n|NO|No|no)
            return 1
            ;;
        *)
            printf 'Please enter Y or N.\n'
            ;;
        esac
    done
}

require_continue()
{
    local prompt="$1"

    if ! prompt_yes_no "${prompt}"; then
        printf 'Aborted by user. No further steps will run.\n' >&2
        return 1
    fi
}

print_command()
{
    printf '+'
    printf ' %q' "$@"
    printf '\n'
}

run_command()
{
    print_command "$@"
    "$@"
}

require_command()
{
    local command_name="$1"
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "Required command not found on PATH: ${command_name}"
}

resolve_bootloader_project_dir()
{
    if [[ -n "${ULX4M_BOOTLOADER_PROJECT_DIR:-}" ]]; then
        BOOTLOADER_PROJECT_DIR="${ULX4M_BOOTLOADER_PROJECT_DIR}"
    elif [[ -f "${REPO_ROOT}/bootloader/Makefile" ]]; then
        BOOTLOADER_PROJECT_DIR="${REPO_ROOT}/bootloader"
    elif [[ -f "${REPO_ROOT}/third_party/had2019-playground/projects/bootloader/Makefile" ]]; then
        BOOTLOADER_PROJECT_DIR="${REPO_ROOT}/third_party/had2019-playground/projects/bootloader"
    elif [[ -f "${REPO_ROOT}/bootloader/projects/bootloader/Makefile" ]]; then
        BOOTLOADER_PROJECT_DIR="${REPO_ROOT}/bootloader/projects/bootloader"
    else
        fail "Could not find the ULX4M bootloader project. See --help for the supported layouts."
    fi

    BOOTLOADER_PROJECT_DIR="$(cd "${BOOTLOADER_PROJECT_DIR}" && pwd -P)"

    if [[ -d "${BOOTLOADER_PROJECT_DIR}/build" && -d "${BOOTLOADER_PROJECT_DIR}/mk" ]]; then
        fail "Both bootloader/build and bootloader/mk exist. Remove the legacy bootloader/build directory after completing the rename."
    fi

    if [[ -f "${BOOTLOADER_PROJECT_DIR}/mk/project-rules.mk" ]]; then
        BOOTLOADER_DEP_ROOT="${BOOTLOADER_PROJECT_DIR}"
        BOOTLOADER_RULES_DIR="mk"
    elif [[ -f "${BOOTLOADER_PROJECT_DIR}/build/project-rules.mk" ]]; then
        fail "Legacy bootloader/build make-rule directory found. Rename it to bootloader/mk and use the updated bootloader Makefile/core includes."
    else
        BOOTLOADER_DEP_ROOT="$(cd "${BOOTLOADER_PROJECT_DIR}/../.." && pwd -P)"
        BOOTLOADER_RULES_DIR="build"
    fi
}

check_source_invariants()
{
    local top_v="${BOOTLOADER_PROJECT_DIR}/rtl/top-ulx4m.v"
    local lpf="${BOOTLOADER_PROJECT_DIR}/data/top-ulx4m-v002.lpf"

    [[ -f "${top_v}" ]] || fail "Missing ${top_v}"
    [[ -f "${lpf}" ]] || fail "Missing ${lpf}"

    grep -Fq 'LOCATE COMP "btn[0]" SITE "E1"' "${lpf}" || \
        fail "Expected PCB BTN1 / btn[0] pin E1 is missing from LPF."
    grep -Fq 'LOCATE COMP "btn[1]" SITE "D2"' "${lpf}" || \
        fail "Expected PCB BTN2 / btn[1] pin D2 is missing from LPF."
    grep -Fq 'LOCATE COMP "btn[2]" SITE "F1"' "${lpf}" || \
        fail "Expected PCB BTN3 / btn[2] pin F1 is missing from LPF."

    grep -Eq 'IOBUF[[:space:]]+PORT "btn\[0\]" PULLMODE=DOWN' "${lpf}" || \
        fail "PCB BTN1 / btn[0] must use PULLMODE=DOWN."
    grep -Eq 'IOBUF[[:space:]]+PORT "btn\[1\]" PULLMODE=DOWN' "${lpf}" || \
        fail "PCB BTN2 / btn[1] must use PULLMODE=DOWN."
    grep -Eq 'IOBUF[[:space:]]+PORT "btn\[2\]" PULLMODE=DOWN' "${lpf}" || \
        fail "PCB BTN3 / btn[2] must use PULLMODE=DOWN."

    grep -Fq 'LOCATE COMP "usb_fpga_bd_dp" SITE "F4"' "${lpf}" || \
        fail "Expected usb_fpga_bd_dp pin F4 is missing from LPF."
    grep -Fq 'LOCATE COMP "usb_fpga_bd_dn" SITE "E3"' "${lpf}" || \
        fail "Expected usb_fpga_bd_dn pin E3 is missing from LPF."
    grep -Fq 'LOCATE COMP "usb_fpga_pu_dp" SITE "F5"' "${lpf}" || \
        fail "Expected usb_fpga_pu_dp pin F5 is missing from LPF."

    grep -Fq 'btn_remap_o[1]' "${top_v}" || \
        fail "Expected PCB BTN2 / btn[1] remapper input is missing."
    grep -Fq 'btn_remap_o[2]' "${top_v}" || \
        fail "Expected PCB BTN3 / btn[2] remapper input is missing."
    grep -Fq '.btn({sw,btn})' "${top_v}" || \
        fail "Expected eight-input soc_had_misc button connection is missing."
}

check_dependency_layout()
{
    local required_path
    local required_paths=(
        "${BOOTLOADER_DEP_ROOT}/${BOOTLOADER_RULES_DIR}/project-rules.mk"
        "${BOOTLOADER_DEP_ROOT}/${BOOTLOADER_RULES_DIR}/core-magic.mk"
        "${BOOTLOADER_DEP_ROOT}/${BOOTLOADER_RULES_DIR}/core-rules.mk"
        "${BOOTLOADER_DEP_ROOT}/${BOOTLOADER_RULES_DIR}/ulx3s-passthru-inc.mk"
        "${BOOTLOADER_DEP_ROOT}/cores/misc/core.mk"
        "${BOOTLOADER_DEP_ROOT}/cores/misc/rtl"
        "${BOOTLOADER_DEP_ROOT}/cores/usb/core.mk"
        "${BOOTLOADER_DEP_ROOT}/cores/usb/rtl"
        "${BOOTLOADER_DEP_ROOT}/cores/usb/data/usb_ep_status.hex"
        "${BOOTLOADER_DEP_ROOT}/cores/usb/utils/microcode.py"
    )

    for required_path in "${required_paths[@]}"; do
        if [[ ! -e "${required_path}" ]]; then
            cat >&2 <<EOF_DEP
ERROR: The bootloader dependency tree is incomplete.

Resolved bootloader project:
    ${BOOTLOADER_PROJECT_DIR}

Resolved bootloader dependency root:
    ${BOOTLOADER_DEP_ROOT}

Missing dependency:
    ${required_path}

For the supported self-contained Hazard3-Doom layout, vendor these upstream
had2019 directories below Hazard3-Doom/bootloader/:

    mk/
    cores/misc/
    cores/usb/

The upstream had2019 build/ directory is vendored as bootloader/mk/.
The bootloader project itself remains directly in Hazard3-Doom/bootloader/.
EOF_DEP
            return 1
        fi
    done
}

self_lint()
{
    bash -n "${BASH_SOURCE[0]}"

    if [[ "${ULX4M_BOOTLOADER_SKIP_SHELLCHECK:-0}" == "1" ]]; then
        printf 'ShellCheck self-lint: skipped by ULX4M_BOOTLOADER_SKIP_SHELLCHECK=1\n'
    elif command -v shellcheck >/dev/null 2>&1; then
        shellcheck "${BASH_SOURCE[0]}"
        printf 'ShellCheck self-lint: PASS\n'
    else
        printf 'ShellCheck self-lint: not available; continuing after bash -n PASS.\n'
    fi
}

setup_riscv_tool_shim()
{
    local tool
    local suffix
    local shim_dir="/tmp/had2019-riscv-tools"
    local found=0

    if command -v riscv-none-embed-gcc >/dev/null 2>&1; then
        printf 'RISC-V toolchain: riscv-none-embed-gcc already available.\n'
        return 0
    fi

    if ! compgen -G '/opt/riscv/bin/riscv32-unknown-elf-*' >/dev/null; then
        fail "Neither riscv-none-embed-* nor /opt/riscv/bin/riscv32-unknown-elf-* tools were found."
    fi

    mkdir -p "${shim_dir}"
    for tool in /opt/riscv/bin/riscv32-unknown-elf-*; do
        [[ -e "${tool}" ]] || continue
        suffix="${tool##*/riscv32-unknown-elf-}"
        ln -sf "${tool}" "${shim_dir}/riscv-none-embed-${suffix}"
        found=1
    done

    [[ "${found}" == "1" ]] || fail "Could not create RISC-V compatibility tool links."
    export PATH="${shim_dir}:${PATH}"
    printf 'RISC-V toolchain shim: %s\n' "${shim_dir}"
}

preflight()
{
    self_lint
    resolve_bootloader_project_dir
    check_dependency_layout
    check_source_invariants

    require_command make
    require_command yosys
    require_command nextpnr-ecp5
    require_command ecpbram
    require_command ecppack
    require_command ecpmulti
    require_command dd
    require_command sha256sum
    require_command cmp
    require_command stat
    require_command grep
    require_command tee
    require_command cp
    require_command realpath
    require_command tr
    require_command wslpath

    [[ -f "${OPENFPGALOADER}" ]] || fail "Missing ${OPENFPGALOADER}"
    [[ -f "${DFU_UTIL}" ]] || fail "Missing ${DFU_UTIL}"

    setup_riscv_tool_shim

    printf '\nPreflight PASS\n'
    printf '  Repository root:       %s\n' "${REPO_ROOT}"
    printf '  Bootloader dep root:   %s\n' "${BOOTLOADER_DEP_ROOT}"
    printf '  Bootloader rules dir:  %s\n' "${BOOTLOADER_RULES_DIR}"
    printf '  Bootloader project:    %s\n' "${BOOTLOADER_PROJECT_DIR}"
    printf '  FPGA IDCODE:           %s\n' "${IDCODE}"
    printf '  DFU VID:PID:           %s:%s\n' "${DFU_VID}" "${DFU_PID}"
    printf '  User bitstream start:  %s\n' "${USER_BITSTREAM_ADDR}"
}

start_session_log()
{
    if [[ -n "${SESSION_DIR}" ]]; then
        return 0
    fi

    SESSION_DIR="${BOOTLOADER_PROJECT_DIR}/artifacts/${RUN_ID}"
    SESSION_LOG="${SESSION_DIR}/session.log"
    mkdir -p "${SESSION_DIR}"
    : > "${SESSION_LOG}"
    exec > >(tee -a "${SESSION_LOG}") 2>&1

    printf 'Session artifacts: %s\n' "${SESSION_DIR}"
}

to_windows_path()
{
    local input_path="$1"
    wslpath -w "${input_path}" | tr -d '\r'
}

require_file()
{
    local file_path="$1"
    [[ -s "${file_path}" ]] || fail "Required file is missing or empty: ${file_path}"
}

require_size()
{
    local file_path="$1"
    local expected_size="$2"
    local actual_size

    actual_size="$(stat -c '%s' "${file_path}")"
    if [[ "${actual_size}" != "${expected_size}" ]]; then
        fail "Unexpected size for ${file_path}: ${actual_size}; expected ${expected_size}."
    fi
}

record_hashes()
{
    local output_file="${SESSION_DIR}/SHA256SUMS.txt"
    sha256sum "$@" | tee -a "${output_file}"
}

build_images()
{
    local build_dir="${BOOTLOADER_PROJECT_DIR}/build-tmp"
    local bootloader_bit="${build_dir}/bootloader.bit"
    local sram_bit="${build_dir}/bootloader-sram-ld-normal.bit"
    local passthru_bit="${build_dir}/passthru.bit"
    local multiboot_img="${build_dir}/multiboot-ulx4m-85f.img"
    local alt5_img="${build_dir}/bootloader-alt5-2m.img"

    start_session_log

    printf '\n=== Build normal ULX4M-LD bootloader ===\n'
    cd "${BOOTLOADER_PROJECT_DIR}"

    run_command make ROOT="${BOOTLOADER_DEP_ROOT}" MODEL="${MODEL}" BOARD="${BOARD}" DEVICE="${DEVICE}" clean
    run_command make ROOT="${BOOTLOADER_DEP_ROOT}" MODEL="${MODEL}" BOARD="${BOARD}" DEVICE="${DEVICE}"

    require_file "${bootloader_bit}"
    require_file "${build_dir}/bootloader-sw.config"

    require_continue "Check the normal bootloader build output above. Continue with SRAM-only repacking?"

    run_command ecppack \
        --compress \
        --idcode "${IDCODE}" \
        --input "${build_dir}/bootloader-sw.config" \
        --bit "${sram_bit}"

    require_file "${sram_bit}"

    run_command make ROOT="${BOOTLOADER_DEP_ROOT}" MODEL="${MODEL}" BOARD="${BOARD}" DEVICE="${DEVICE}" passthru
    require_file "${passthru_bit}"

    require_continue "Check the bootloader and passthru build output. Continue with the 85F multiboot image?"

    run_command ecpmulti \
        --input "${bootloader_bit}" \
        --address "${USER_BITSTREAM_ADDR}" \
        --input "${passthru_bit}" \
        --flashsize 128 \
        --input-idcode "${IDCODE}" \
        --output-idcode "${IDCODE}" \
        --output "${multiboot_img}"

    require_file "${multiboot_img}"

    run_command dd \
        if="${multiboot_img}" \
        of="${alt5_img}" \
        bs=2M \
        count=1

    require_size "${alt5_img}" "${ALT5_SIZE}"

    printf '\nBuild artifact sizes:\n'
    stat -c '%n: %s bytes' \
        "${bootloader_bit}" \
        "${sram_bit}" \
        "${passthru_bit}" \
        "${multiboot_img}" \
        "${alt5_img}"

    printf '\nBuild artifact SHA256 values:\n'
    record_hashes \
        "${bootloader_bit}" \
        "${sram_bit}" \
        "${passthru_bit}" \
        "${multiboot_img}" \
        "${alt5_img}"

    cp -f "${alt5_img}" "${SESSION_DIR}/bootloader-alt5-2m.img"

    require_continue "Check sizes and SHA256 values. Is the exact 2 MiB alt-5 image ready to continue?"
}

run_dfu_list()
{
    local output_file="$1"

    printf '\nDFU listing:\n'
    "${DFU_UTIL}" -l 2>&1 | tee "${output_file}"
}

require_dfu_alt()
{
    local output_file="$1"
    local alt="$2"

    grep -Eq "Found DFU: \[${DFU_MATCH}\].*alt=${alt}," "${output_file}" || \
        fail "Expected DFU alt ${alt} was not found."
}

verify_ordinary_dfu()
{
    local output_file="$1"
    local alt

    for alt in 0 1 2 3 4; do
        require_dfu_alt "${output_file}" "${alt}"
    done

    if grep -Eq "Found DFU: \[${DFU_MATCH}\].*alt=5," "${output_file}"; then
        fail "Alt 5 is visible in ordinary protected DFU mode; expected it to be hidden."
    fi

    printf 'DFU verification PASS: alt 0-4 visible; alt 5 hidden.\n'
}

verify_upgrade_dfu()
{
    local output_file="$1"
    local alt

    for alt in 0 1 2 3 4 5; do
        require_dfu_alt "${output_file}" "${alt}"
    done

    printf 'DFU verification PASS: alt 0-5 visible.\n'
}

load_normal_sram()
{
    local buttons="$1"
    local verification_mode="$2"
    local sram_bit="${BOOTLOADER_PROJECT_DIR}/build-tmp/bootloader-sram-ld-normal.bit"
    local sram_bit_win
    local list_file="${SESSION_DIR}/dfu-${verification_mode}.txt"

    require_file "${sram_bit}"
    sram_bit_win="$(to_windows_path "${sram_bit}")"

    require_continue "Hold ${buttons} now. Keep the button(s) held through JTAG loading and until USB has enumerated. Press Y when ready to load SRAM."

    cd "${REPO_ROOT}"
    run_command "${OPENFPGALOADER}" -c tigard "${sram_bit_win}"

    require_continue "Check openFPGALoader output. Keep ${buttons} held until USB enumeration is complete. Then release the button(s) and press Y to list DFU interfaces."

    run_dfu_list "${list_file}"

    case "${verification_mode}" in
    ordinary)
        verify_ordinary_dfu "${list_file}"
        ;;
    upgrade)
        verify_upgrade_dfu "${list_file}"
        UPGRADE_SESSION_READY=1
        ;;
    *)
        fail "Internal error: unknown DFU verification mode ${verification_mode}"
        ;;
    esac

    require_continue "Check the DFU listing and automatic verification above. Continue?"
}

sram_tests()
{
    start_session_log

    printf '\n=== SRAM hardware test 1: ordinary protected DFU ===\n'
    printf 'PCB button mapping: BTN3 is ordinary DFU entry.\n'
    load_normal_sram "PCB BTN3" ordinary

    printf '\n=== SRAM hardware test 2: bootloader upgrade DFU ===\n'
    printf 'PCB button mapping: BTN2+BTN3 exposes bootloader alt 5.\n'
    load_normal_sram "PCB BTN2 + PCB BTN3" upgrade
}

prepare_upgrade_session()
{
    if [[ "${UPGRADE_SESSION_READY}" == "1" ]]; then
        printf 'An upgrade-capable SRAM DFU session is already verified.\n'
        return 0
    fi

    printf '\n=== Prepare known-good normal SRAM bootloader for alt-5 update ===\n'
    load_normal_sram "PCB BTN2 + PCB BTN3" upgrade
}

backup_alt5()
{
    local backup_file="${SESSION_DIR}/bootloader-alt5-before-update.bin"
    local backup_win

    backup_win="$(to_windows_path "${backup_file}")"

    printf '\n=== Back up current persistent bootloader region ===\n'
    require_continue "Alt 5 must be visible. Press Y to read and preserve the current first 2 MiB before overwriting it."

    run_command "${DFU_UTIL}" \
        -d "${DFU_MATCH}" \
        -a 5 \
        -U "${backup_win}"

    require_size "${backup_file}" "${ALT5_SIZE}"
    stat -c '%n: %s bytes' "${backup_file}"
    record_hashes "${backup_file}"

    require_continue "Check the 2 MiB backup size and SHA256 above. Continue toward the alt-5 write?"
}

write_and_verify_alt5()
{
    local alt5_img="${BOOTLOADER_PROJECT_DIR}/build-tmp/bootloader-alt5-2m.img"
    local source_copy="${SESSION_DIR}/bootloader-alt5-2m.img"
    local readback_file="${SESSION_DIR}/bootloader-alt5-after-update.bin"
    local alt5_win
    local readback_win

    require_file "${alt5_img}"
    require_size "${alt5_img}" "${ALT5_SIZE}"

    cp -f "${alt5_img}" "${source_copy}"
    alt5_win="$(to_windows_path "${alt5_img}")"
    readback_win="$(to_windows_path "${readback_file}")"

    printf '\n=== DESTRUCTIVE STEP: write bootloader flash region through DFU alt 5 ===\n'
    printf 'Source image:\n'
    stat -c '%n: %s bytes' "${alt5_img}"
    record_hashes "${alt5_img}"

    require_continue "This will overwrite flash 0x000000-0x1FFFFF using alt 5. The running SRAM bootloader will perform the write. Press Y to write, N to abort."

    cd "${REPO_ROOT}"
    run_command "${DFU_UTIL}" \
        -d "${DFU_MATCH}" \
        -a 5 \
        -D "${alt5_win}"

    require_continue "Check that the download reached 100 percent and ended with status(0) / Done. Do NOT power-cycle. Press Y to read alt 5 back now."

    run_command "${DFU_UTIL}" \
        -d "${DFU_MATCH}" \
        -a 5 \
        -U "${readback_win}"

    require_size "${readback_file}" "${ALT5_SIZE}"

    printf '\nAlt-5 source and readback:\n'
    stat -c '%n: %s bytes' "${source_copy}" "${readback_file}"
    record_hashes "${source_copy}" "${readback_file}"

    if cmp -s "${source_copy}" "${readback_file}"; then
        printf 'PASS: alt5 readback is byte-for-byte identical.\n'
    else
        fail "Alt-5 readback differs from the source image. Do not power-cycle."
    fi

    require_continue "Byte-for-byte readback passed. Press Y only if you are ready to continue to cold-boot testing."
}

install_normal_bootloader()
{
    start_session_log
    prepare_upgrade_session
    backup_alt5
    write_and_verify_alt5
}

verify_no_dfu()
{
    local output_file="$1"

    if grep -Fq "Found DFU: [${DFU_MATCH}]" "${output_file}"; then
        fail "DFU is still present; expected the no-button boot to hand off to the user bitstream."
    fi

    printf 'No-button DFU check PASS: no %s device is listed.\n' "${DFU_MATCH}"
}

cold_tests()
{
    local no_button_file
    local ordinary_file
    local upgrade_file

    start_session_log
    no_button_file="${SESSION_DIR}/cold-no-buttons.txt"
    ordinary_file="${SESSION_DIR}/cold-pcb-btn3.txt"
    upgrade_file="${SESSION_DIR}/cold-pcb-btn2-btn3.txt"

    printf '\n=== Cold-boot test 1: no buttons ===\n'
    require_continue "Remove all board power/USB. Do not hold any button. Apply power normally. When the board has booted, press Y to check that DFU is absent."
    run_dfu_list "${no_button_file}"
    verify_no_dfu "${no_button_file}"
    require_continue "Confirm the expected user bitstream behavior is visible (for example LEDs/UART). Press Y for PASS, N to abort."

    printf '\n=== Cold-boot test 2: PCB BTN3 ordinary protected DFU ===\n'
    require_continue "Remove all board power/USB. Hold PCB BTN3, apply power, keep BTN3 held until USB enumerates, then release it. Press Y to list DFU interfaces."
    run_dfu_list "${ordinary_file}"
    verify_ordinary_dfu "${ordinary_file}"
    require_continue "Check the ordinary DFU listing: alt 0-4 visible and alt 5 hidden. Continue?"

    printf '\n=== Cold-boot test 3: PCB BTN2+BTN3 bootloader maintenance DFU ===\n'
    require_continue "Remove all board power/USB. Hold PCB BTN2+BTN3, apply power, keep both held until USB enumerates, then release them. Press Y to list DFU interfaces."
    run_dfu_list "${upgrade_file}"
    verify_upgrade_dfu "${upgrade_file}"
    require_continue "Check the maintenance DFU listing: alt 0-5 visible. Mark the persistent bootloader validation complete?"

    printf '\nPASS: all persistent cold-boot modes are validated.\n'
}

load_emergency_sram()
{
    local emergency_image="$1"
    local emergency_win
    local list_file="${SESSION_DIR}/dfu-emergency.txt"

    require_file "${emergency_image}"
    emergency_win="$(to_windows_path "${emergency_image}")"

    require_continue "Prepare Tigard JTAG: target power OFF, Vref 3.3 V, channel B/libusbK. No button is required for EMERGENCY_RESTORE2. Press Y to load the emergency SRAM image."

    cd "${REPO_ROOT}"
    run_command "${OPENFPGALOADER}" -c tigard "${emergency_win}"

    require_continue "Check openFPGALoader output. When USB has enumerated, press Y to list DFU interfaces."
    run_dfu_list "${list_file}"
    verify_upgrade_dfu "${list_file}"
    UPGRADE_SESSION_READY=1

    require_continue "Emergency SRAM DFU exposes alt 5. Continue with backup and normal bootloader installation?"
}

recover_install()
{
    local emergency_image="${1:-${ULX4M_EMERGENCY_SRAM_IMAGE:-${BOOTLOADER_PROJECT_DIR}/build-tmp/bootloader-sram-ld-upgrade.bit}}"

    start_session_log
    load_emergency_sram "${emergency_image}"
    backup_alt5
    write_and_verify_alt5
    cold_tests
}

program_user_bitstream()
{
    local default_user_bitstream="${REPO_ROOT}/third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.bit"
    local user_bitstream="${1:-${default_user_bitstream}}"
    local user_bitstream_abs
    local user_bitstream_win
    local list_file
    local post_file

    start_session_log

    [[ -f "${user_bitstream}" ]] || fail "User bitstream not found: ${user_bitstream}"
    user_bitstream_abs="$(realpath "${user_bitstream}")"
    require_file "${user_bitstream_abs}"
    user_bitstream_win="$(to_windows_path "${user_bitstream_abs}")"
    list_file="${SESSION_DIR}/program-user-before.txt"
    post_file="${SESSION_DIR}/program-user-after-cold-boot.txt"

    require_continue "Remove all board power/USB. Hold PCB BTN3, apply power, keep BTN3 held until USB enumerates, then release it. Press Y to verify ordinary DFU before programming alt 0."
    run_dfu_list "${list_file}"
    verify_ordinary_dfu "${list_file}"

    printf '\nUser bitstream to program:\n'
    stat -c '%n: %s bytes' "${user_bitstream_abs}"
    sha256sum "${user_bitstream_abs}"

    require_continue "Program this file to DFU alt 0 at flash address 0x200000?"

    cd "${REPO_ROOT}"
    run_command "${OPENFPGALOADER}" \
        --dfu \
        --vid "${DFU_VID}" \
        --pid "${DFU_PID}" \
        --altsetting 0 \
        "${user_bitstream_win}"

    require_continue "Check openFPGALoader DFU programming output. Remove all power, then cold-boot with NO buttons. Press Y when the user bitstream is running."
    run_dfu_list "${post_file}"
    verify_no_dfu "${post_file}"
    require_continue "Confirm expected user-bitstream LEDs/UART behavior. Press Y for PASS."

    printf 'PASS: user bitstream programming and no-button handoff verified.\n'
}

main()
{
    local command_name="${1:-}"

    if [[ -z "${command_name}" || "${command_name}" == "-h" || "${command_name}" == "--help" ]]; then
        usage
        return 0
    fi

    shift || true
    preflight

    case "${command_name}" in
    check)
        ;;
    build)
        build_images
        ;;
    sram-test)
        start_session_log
        sram_tests
        ;;
    install)
        start_session_log
        install_normal_bootloader
        ;;
    cold-test)
        start_session_log
        cold_tests
        ;;
    full)
        start_session_log
        build_images
        sram_tests
        install_normal_bootloader
        cold_tests
        ;;
    recover-install)
        start_session_log
        recover_install "${1:-}"
        ;;
    program-user)
        start_session_log
        program_user_bitstream "${1:-}"
        ;;
    *)
        usage >&2
        fail "Unknown command: ${command_name}"
        ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
