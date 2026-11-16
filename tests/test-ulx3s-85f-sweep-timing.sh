#!/usr/bin/env bash
# Regression test for the ULX3S-85F routed-sweep timing PASS decision.
# Uses mocked nextpnr/ecppack. No FPGA tools or hardware are required.
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd -- "${TEST_DIR}/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "${TEMP_ROOT}"' EXIT

mkdir -p "${TEMP_ROOT}/scripts" "${TEMP_ROOT}/build/ulx3s-85f" \
    "${TEMP_ROOT}/third_party/Hazard3/example_soc/synth" "${TEMP_ROOT}/fake-bin"
cp "${SOURCE_ROOT}/scripts/sweep-ulx3s-85f.sh" \
   "${SOURCE_ROOT}/scripts/sweep-ecp5-common.sh" \
   "${SOURCE_ROOT}/scripts/ecp5-board-defaults.sh" \
   "${SOURCE_ROOT}/scripts/inventory.sh" "${TEMP_ROOT}/scripts/"
touch "${TEMP_ROOT}/third_party/Hazard3/example_soc/synth/fpga_ulx3s.lpf"
printf 'mock netlist\n' > "${TEMP_ROOT}/build/fpga_ulx3s_85f.json"
printf 'mock synthesis\n' > "${TEMP_ROOT}/build/fpga_ulx3s_85f.synth.log"

# These stamps match the 50 MHz defaults checked by SWEEP_SKIP_SYNTH=1.
printf '50\n' > "${TEMP_ROOT}/build/ulx3s-85f/monitor-sys-clk-mhz"
for entry in \
    'video-profile:vga640-standard' \
    'sys-clk-mhz:50' \
    'registered-read-hits:1' \
    'sram-write-buffer:1' \
    'sram-dual-port-rw:0' \
    'cache-tag-pipeline:0' \
    'tag-ram-mode:0' \
    'cache-addr-pipeline:0'; do
    printf '%s\n' "${entry#*:}" > "${TEMP_ROOT}/build/fpga_ulx3s_85f.${entry%%:*}"
done

cat > "${TEMP_ROOT}/fake-bin/nextpnr-ecp5" <<'MOCK_NEXT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == '--version' ]]; then
    printf 'mock nextpnr 1.0\n'
    exit 0
fi
while (( $# )); do
    case "$1" in
    --log) log="$2"; shift 2 ;;
    --textcfg) config="$2"; shift 2 ;;
    --seed) seed="$2"; shift 2 ;;
    *) shift ;;
    esac
done
source_log="${MOCK_LOG}"
if [[ -n "${MOCK_LOG_SEED_DIR:-}" ]]; then
    source_log="${MOCK_LOG_SEED_DIR}/${seed}.log"
fi
cp "${source_log}" "${log}"
printf 'mock configuration\n' > "${config}"
MOCK_NEXT
cat > "${TEMP_ROOT}/fake-bin/ecppack" <<'MOCK_PACK'
#!/usr/bin/env bash
set -euo pipefail
printf 'mock bitstream\n' > "${*: -1}"
MOCK_PACK
chmod +x "${TEMP_ROOT}/fake-bin/nextpnr-ecp5" "${TEMP_ROOT}/fake-bin/ecppack"
export PATH="${TEMP_ROOT}/fake-bin:${PATH}"
export HAZARD3_ULX3S_85F_SYS_CLK_MHZ=50 SWEEP_SKIP_SYNTH=1 SWEEP_JOBS=1
export MOCK_LOG="${TEMP_ROOT}/mock-nextpnr.log"

run_case()
{
    local label="$1" sys_mhz="$2" video_mhz="$3" tmds_mhz="$4"
    local sys_status="$5" expected="$6"
    local results actual

    cat > "${MOCK_LOG}" <<EOF_LOG
Info: Max frequency for clock '\$glbnet\$clk_sys': ${sys_mhz} MHz (${sys_status} at 25.00 MHz)
Info: Max frequency for clock '\$glbnet\$clk_video_pix': ${video_mhz} MHz (PASS at 25.00 MHz)
Info: Max frequency for clock '\$glbnet\$clk_tmds_x5': ${tmds_mhz} MHz (PASS at 125.00 MHz)
EOF_LOG
    local route_exit expected_exit
    if bash "${TEMP_ROOT}/scripts/sweep-ulx3s-85f.sh" 11 \
        > "${TEMP_ROOT}/sweep-output.log" 2>&1; then
        route_exit=0
    else
        route_exit=$?
    fi
    expected_exit=1
    if [[ "${expected}" == "PASS" ]]; then
        expected_exit=0
    fi
    if (( route_exit != expected_exit )); then
        printf 'FAIL %s: expected sweep exit %s, got %s\n' \
            "${label}" "${expected_exit}" "${route_exit}" >&2
        cat "${TEMP_ROOT}/sweep-output.log" >&2
        exit 1
    fi

    results="$(find "${TEMP_ROOT}/build" -name 'result-seed-11.csv' -print -quit)"
    actual="$(awk -F, '{ print $6 }' "${results}")"
    if [[ "${actual}" != "${expected}" ]]; then
        printf 'FAIL %s: expected %s, got %s\n' "${label}" "${expected}" "${actual}" >&2
        cat "${TEMP_ROOT}/sweep-output.log" >&2
        exit 1
    fi
    printf 'PASS test: %s => %s (exit %s)\n' "${label}" "${actual}" "${route_exit}"
}

run_case 'false PASS: 32.05 MHz vs physical 50 MHz' 32.05 44.67 203.38 PASS FAIL
run_case 'system below target' 49.99 44.67 203.38 PASS FAIL
run_case 'video below target' 55.00 24.99 203.38 PASS FAIL
run_case 'TMDS below target' 55.00 44.67 124.99 PASS FAIL
run_case 'nextpnr FAIL remains FAIL' 55.00 44.67 203.38 FAIL FAIL
run_case 'physical target exactly met' 50.00 25.00 125.00 PASS PASS
run_case 'all physical targets exceeded' 55.00 44.67 203.38 PASS PASS

SWEEP_SYS_TARGET_MHZ=30.00 run_case 'lower override cannot bypass physical 50' 32.05 44.67 203.38 PASS FAIL
SWEEP_SYS_TARGET_MHZ=60.00 run_case 'higher override must be met' 55.00 44.67 203.38 PASS FAIL
SWEEP_VIDEO_TARGET_MHZ=45.00 run_case 'higher video override must be met' 55.00 44.67 203.38 PASS FAIL
SWEEP_TMDS_TARGET_MHZ=205.00 run_case 'higher TMDS override must be met' 55.00 44.67 203.38 PASS FAIL
run_case 'malformed clock fails closed' unavailable 44.67 203.38 PASS FAIL
# A failing seed must not reject a sweep that also contains a passing seed.
mkdir -p "${TEMP_ROOT}/seed-logs"
cat > "${TEMP_ROOT}/seed-logs/11.log" <<'PASS_LOG'
Info: Max frequency for clock '$glbnet$clk_sys': 50.00 MHz (PASS at 25.00 MHz)
Info: Max frequency for clock '$glbnet$clk_video_pix': 25.00 MHz (PASS at 25.00 MHz)
Info: Max frequency for clock '$glbnet$clk_tmds_x5': 125.00 MHz (PASS at 125.00 MHz)
PASS_LOG
cat > "${TEMP_ROOT}/seed-logs/12.log" <<'FAIL_LOG'
Info: Max frequency for clock '$glbnet$clk_sys': 32.05 MHz (PASS at 25.00 MHz)
Info: Max frequency for clock '$glbnet$clk_video_pix': 25.00 MHz (PASS at 25.00 MHz)
Info: Max frequency for clock '$glbnet$clk_tmds_x5': 125.00 MHz (PASS at 125.00 MHz)
FAIL_LOG
if ! MOCK_LOG_SEED_DIR="${TEMP_ROOT}/seed-logs" \
    bash "${TEMP_ROOT}/scripts/sweep-ulx3s-85f.sh" 11 12 \
        > "${TEMP_ROOT}/sweep-mixed-output.log" 2>&1; then
    printf 'FAIL: mixed passing/failing sweep returned nonzero\n' >&2
    cat "${TEMP_ROOT}/sweep-mixed-output.log" >&2
    exit 1
fi
mixed_results="$(find "${TEMP_ROOT}/build" -name 'results-selected.csv' -print -quit)"
[[ "$(awk -F, 'NR>1 && $6=="PASS" {n++} END {print n+0}' "${mixed_results}")" == 1 ]]
[[ "$(awk -F, 'NR>1 && $6=="FAIL" {n++} END {print n+0}' "${mixed_results}")" == 1 ]]
printf 'PASS test: mixed sweep (one PASS, one FAIL) => exit 0\n'

printf 'All ULX3S-85F timing verdict regression tests passed.\n'
