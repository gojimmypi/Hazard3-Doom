#!/usr/bin/env bash
# Rebuild or resume the validated ULX5M-GS BTN2 FWT3 configuration.
# Offline only: no JTAG, USB, persistent FPGA configuration, or flash writes.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$script_dir/.."

build_dir=build-ulx5m-gs
makefile=Makefile.ulx5m-gs
seed=147
json=$build_dir/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2.json
impl=$build_dir/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2.txt
bit=$build_dir/top_ulx5m_gs_flash_read-serv-dfu-hw-quad-btn2.bit
pnr_log=$build_dir/btn2-dfu-quad-serv-pnr.log
report=$build_dir/btn2-dfu-seed147-rebuild.txt
expected_json=6ecf4304157a35c1287872fbdd8967a3af5894bcacb8c6c8a1cd6013fd797979
reference_json=${ULX5M_BTN2_REFERENCE_JSON:-build-ulx5m-gs.bak/btn2-dfu-quad-seed-sweep-20261023T014803Z-14164/design.json}
compare_script=scripts/compare-ulx5m-btn2-netlists.py
expected_ccf=7389bcb6eb662c991ebe7847064ec0d516b0b3209f61e59dc1b488fea59e517e
expected_sdc=65d3d8e7e67a142c090209ebd2e8a724814497c0771607afff64808cecee3343
ccf=data/top-ulx5m-gs-flash-read.ccf
sdc=data/top-ulx5m-gs-flash-read.sdc

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

hash_of() {
    local digest
    digest=$(sha256sum -- "$1")
    printf '%s' "${digest%% *}"
}

if [[ -e $build_dir || -L $build_dir ]]; then
    [[ -d $build_dir && ! -L $build_dir ]] || fail "$build_dir is not a regular directory."
    [[ -s $json ]] || fail "$build_dir exists without the expected JSON. Preserve it before retrying."
    [[ ! -e $impl && ! -e $bit && ! -e $pnr_log ]] || fail 'Routing outputs already exist; refusing to replace an implementation.'
    resume=1
else
    resume=0
fi

for command in make gcc python3 iverilog vvp yosys nextpnr-himbaechel gmpack sha256sum git; do
    command -v "$command" >/dev/null 2>&1 || fail "Missing executable: $command"
done

[[ -s $ccf && -s $sdc ]] || fail 'Missing GateMate constraints.'
[[ -s $reference_json ]] || fail "Missing frozen sweep reference: $reference_json"
[[ $(hash_of "$reference_json") == "$expected_json" ]] || fail 'Frozen sweep reference SHA-256 does not match the verified 300-seed run.'
[[ -s $compare_script ]] || fail "Missing comparator: $compare_script"
[[ $(hash_of "$ccf") == "$expected_ccf" ]] || fail "CCF changed: $ccf. Seed 147 cannot be assumed reproducible."
[[ $(hash_of "$sdc") == "$expected_sdc" ]] || fail "SDC changed: $sdc. Seed 147 cannot be assumed reproducible."

printf 'ULX5M-GS BTN2 FWT3 clean rebuild, seed %d\n' "$seed"
printf 'Building only the validated original BTN2 variant; not the reset experiments.\n'
printf 'Offline build; no USB, JTAG, or flash operations.\n'
if (( resume )); then
    printf 'Resuming existing synthesis output: %s\n' "$json"
fi

# A fresh run executes tests. A resumed run reuses the previously tested build.
if (( ! resume )); then
    make -f "$makefile" \
        test-btn2-boot-mode \
        test-btn2-dfu-gate \
        test-flash-serv-ep0-trace \
        test-btn2-raw-read \
        test-flash-serv-ep0-ack \
        test-flash-serv-epbuf-tx \
        test-dfu-at25ql321-chain \
        test-dfu-hw-quad-arm
    python3 tests/test-ulx5m-serv-btn2-dfu-gate-guards.py
    python3 tests/test-ulx5m-serv-dfu-hw-quad-guards.py
fi

# Regenerate firmware, USB microcode, SERV verification stamp, and Yosys netlist.
# Compare before routing, because old routing seeds are netlist-specific.
make -f "$makefile" "$json"
[[ -s $json ]] || fail "Synthesis did not produce $json"

actual_json=$(hash_of "$json")
{
    printf 'ULX5M-GS BTN2 FWT3 clean rebuild\n'
    printf 'Seed: %s\n' "$seed"
    printf 'Expected JSON SHA-256: %s\n' "$expected_json"
    printf 'Actual JSON SHA-256:   %s\n' "$actual_json"
    printf 'Reference JSON: %s\n' "$reference_json"
    printf 'CCF SHA-256: %s\n' "$(hash_of "$ccf")"
    printf 'SDC SHA-256: %s\n' "$(hash_of "$sdc")"
    printf 'Git HEAD: %s\n' "$(git rev-parse HEAD 2>/dev/null || printf unknown)"
    yosys -V
    nextpnr-himbaechel --version
} > "$report"

if [[ $actual_json == "$expected_json" ]]; then
    printf 'MATCH: fresh JSON is byte-identical to the 300-seed sweep.\n' | tee -a "$report"
else
    printf 'JSON SHA-256 differs. Checking synthesized cell/port structure...\n' | tee -a "$report"
    if ! python3 "$compare_script" --require-identical-logic "$reference_json" "$json" \
        2>&1 | tee -a "$report"; then
        fail "Synthesized structure changed; refusing to route seed $seed. See $report"
    fi
    printf 'STRUCTURAL MATCH: connectivity/parameters/BRAM initialization match; JSON metadata differs.\n' | tee -a "$report"
    printf 'Timing may differ; fresh implementation must meet 48 MHz independently.\n' | tee -a "$report"
fi

# No implementation output may preexist this run: SERV_SEED=147 is not a
# Makefile dependency, so a stale .txt would otherwise bypass the new route.
if ! make -f "$makefile" btn2-dfu-quad-serv "SERV_SEED=$seed"; then
    if [[ -s $pnr_log ]]; then
        grep 'Max frequency for clock' "$pnr_log" | tail -1 | tee -a "$report" || true
    fi
    fail "Seed $seed place-and-route failed; review $pnr_log"
fi
[[ -s $impl && -s $bit && -s $pnr_log ]] || fail 'Missing implementation, bitstream, or timing report.'

timing_line=''
while IFS= read -r line; do
    if [[ $line == *'Max frequency for clock'* ]]; then
        timing_line=$line
    fi
done < "$pnr_log"

printf '%s\n' "$timing_line" | tee -a "$report"
[[ $timing_line == *'(PASS at 48.00 MHz)'* ]] || fail 'The final routed timing report does not show a 48 MHz PASS.'
{
    printf 'PASS: fresh routed implementation meets 48 MHz.\n'
    sha256sum -- "$json" "$impl" "$bit"
} | tee -a "$report"
printf 'SRAM-only bitstream: %s\n' "$bit"
printf 'Report: %s\n' "$report"
