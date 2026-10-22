#!/usr/bin/env bash
# Offline ULX5M SERV regression suite, with optional native Windows USB tests.
# No JTAG programming, flash erase/write, or DFU download is performed.
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: ./scripts/test-ulx5m-serv.sh [options]

  --offline          Run hardware-free checks (default).
  --synth            Also synthesize the SERV GateMate netlist (no PnR).
  --all              Run offline tests followed by native Windows USB tests.
  --hardware-only    Only run native Windows USB tests (bitstream preloaded).
  --rounds N         Number of descriptor-test rounds (default: 32).
  --capture          Also read a previously frozen USB raw capture (no rearm).
  -h, --help         Show this help.

Offline tests require Python 3, GCC, Icarus Verilog, make, pinned SERV 1.4.0,
and a RISC-V GCC toolchain. The Makefile fetches SERV if it is absent.
Hardware tests require WSL with PowerShell interop, WinUSB/PyUSB, and
bin/libusb-1.0.dll. Run the PowerShell script directly on native Windows.
No hardware tests run unless --all or --hardware-only is supplied.
USAGE
}

mode=offline
synth=0
capture=0
rounds=32
while (( $# > 0 )); do
    case "$1" in
        --offline) mode=offline ;;
        --synth) synth=1 ;;
        --all) mode=all ;;
        --hardware-only) mode=hardware ;;
        --capture) capture=1 ;;
        --rounds)
            if (( $# < 2 )); then
                echo 'ERROR: --rounds requires a value.' >&2
                exit 2
            fi
            rounds=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unsupported argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
if [[ ! $rounds =~ ^[1-9][0-9]*$ ]]; then
    echo 'ERROR: --rounds must be a positive decimal integer.' >&2
    exit 2
fi
if (( synth )) && [[ $mode == hardware ]]; then
    echo 'ERROR: --synth and --hardware-only cannot be combined.' >&2
    exit 2
fi
if (( capture )) && [[ $mode == offline ]]; then
    echo 'ERROR: --capture requires --all or --hardware-only.' >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
boot_dir=$repo_dir/bootloader-serv
makefile=Makefile.ulx5m-gs
if [[ ! -f $boot_dir/$makefile ]]; then
    echo "ERROR: Missing bootloader-serv/$makefile in $repo_dir" >&2
    exit 1
fi
cd -- "$boot_dir"

passed=0
failed=0
run_test() {
    local name=$1
    shift
    printf '\n=== %s ===\n' "$name"
    if "$@"; then
        printf '[PASS] %s\n' "$name"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s\n' "$name" >&2
        failed=$((failed + 1))
    fi
}

test_memory_response() {
    mkdir -p build-ulx5m-gs
    iverilog -g2012 -s tb_soc_mem_response_reg \
        -o build-ulx5m-gs/response-test.vvp \
        rtl/soc_mem_response_reg.v tests/tb_soc_mem_response_reg.v &&
        vvp build-ulx5m-gs/response-test.vvp
}

run_offline() {
    local cmd
    for cmd in python3 make gcc git iverilog vvp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "ERROR: missing offline prerequisite: $cmd" >&2
            return 1
        fi
    done

    # Intentionally omit check-ulx5m-gs-flash-jedec.py: it references the
    # nonexistent flash-jedec Makefile target (a pre-existing mismatch).
    printf '[SKIP] Legacy JEDEC guard: no flash-jedec Makefile target.\n'
    run_test 'Python syntax' python3 -m compileall -q tests
    local checker
    for checker in \
        check-ulx5m-gs-port.py \
        check-ulx5m-gs-usb.py \
        check-ulx5m-gs-probe.py \
        check-ulx5m-gs-flash-read.py \
        check-ulx5m-gs-serv.py; do
        run_test "$checker" python3 "tests/$checker"
    done

    for checker in \
        capture-ulx5m-serv-ep0-raw.py \
        compare-ulx5m-serv-usb-link.py \
        check-ulx5m-serv-tx-waveform.py \
        check-ulx5m-serv-epbuf-tx.py; do
        run_test "$checker --selftest" python3 "tests/$checker" --selftest
    done
    run_test 'EP0 trace decoder' python3 tests/test-ulx5m-serv-ep0-trace-decoder.py
    run_test 'EP0 firmware diagnostics host test' python3 tests/test-ulx5m-serv-ep0-diag.py
    run_test 'DFU RAM staging state machine' make -f "$makefile" test-dfu-stage
    run_test 'DFU EP0 control-OUT integration' make -f "$makefile" test-dfu-ep0
    run_test 'DFU 2 MiB streaming state machine' make -f "$makefile" test-dfu-stream
    run_test 'DFU streaming EP0 integration' make -f "$makefile" test-dfu-stream-ep0
    run_test 'DFU streaming Windows host selftest' python3 tests/test-ulx5m-serv-dfu-stream-host.py
    run_test 'DFU streaming firmware dispatch' make -f "$makefile" test-dfu-stream-dispatch
    run_test 'AT25QL321 production SPI write protection' make -f "$makefile" test-at25ql321-protected
    run_test 'AT25QL321 SPI command emulator' make -f "$makefile" test-at25ql321-emulator
    run_test 'DFU to AT25QL321 SPI emulator' make -f "$makefile" test-dfu-at25ql321-chain
    run_test 'Flash programmer production protection' make -f "$makefile" test-flash-program-protected
    run_test 'Flash programmer 4 MiB chip emulator' make -f "$makefile" test-flash-program-emulator
    run_test 'DFU stream to flash emulator' make -f "$makefile" test-dfu-stream-program-emulator
    run_test 'DFU multiblock host selftest' python3 tests/test-ulx5m-serv-dfu-host.py
    run_test 'Flash layout policy' make -f "$makefile" test-flash-layout
    run_test 'Flash layout USB dispatch' make -f "$makefile" test-flash-layout-ep0
    run_test 'Flash layout diagnostic selftest' python3 tests/test-ulx5m-serv-flash-layout-host.py
    run_test 'USB copy ASan/UBSan regression' python3 tests/test-ulx5m-serv-usb-copy.py
    run_test 'Registered memory response' test_memory_response

    local target
    for target in \
        test-usb-probe-bus \
        test-flash-bram-pipe \
        test-flash-serv-bus \
        test-flash-serv-ep0-trace \
        test-flash-serv-ep0-ack \
        test-flash-serv-raw-capture \
        test-flash-serv-tx-packet \
        test-flash-serv-epbuf-tx \
        test-flash-serv-firmware; do
        run_test "$target" make -f "$makefile" "$target"
    done
    run_test 'Generate USB microcode' make -f "$makefile" build-ulx5m-gs/usb_trans_mc.hex
    run_test 'USB microcode timeout' python3 tests/test-ulx5m-serv-usb-timeout.py
    if (( synth )); then
        run_test 'SERV GateMate netlist synthesis' make -f "$makefile" \
            build-ulx5m-gs/top_ulx5m_gs_flash_read-serv.json
    fi
}

run_hardware() {
    local cmd=(powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass)
    local ps_script
    if ! command -v powershell.exe >/dev/null 2>&1 || \
       ! command -v wslpath >/dev/null 2>&1; then
        echo 'ERROR: Hardware mode must run in WSL with Windows interop enabled.' >&2
        echo '       Or run scripts/test-ulx5m-serv-hardware.ps1 in PowerShell.' >&2
        return 1
    fi
    ps_script=$(wslpath -w "$repo_dir/scripts/test-ulx5m-serv-hardware.ps1")
    cmd+=(-File "$ps_script" -Rounds "$rounds")
    if (( capture )); then
        cmd+=(-Capture)
    fi
    printf '\n=== Native Windows USB hardware tests ===\n'
    "${cmd[@]}"
}

if [[ $mode != hardware ]]; then
    if ! run_offline; then
        failed=$((failed + 1))
    fi
fi
if [[ $mode != offline ]]; then
    run_test 'Windows USB hardware suite' run_hardware
fi
printf '\n=== ULX5M SERV test summary: %d passed, %d failed ===\n' "$passed" "$failed"
if (( failed > 0 )); then
    exit 1
fi
