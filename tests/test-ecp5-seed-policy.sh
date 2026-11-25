#!/usr/bin/env bash
# Local seed parsing and GitHub Actions matrix limits; no FPGA tools required.
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${TEST_DIR}/.." && pwd)"
# shellcheck source=scripts/sweep-ecp5-common.sh
source "${ROOT}/scripts/sweep-ecp5-common.sh"

usage()
{
    printf 'Test usage stub\n' >&2
}

assert_seed_list()
{
    local label="$1" expected_count="$2" expected_first="$3" expected_last="$4"
    local actual_count="${#SWEEP_SEEDS[@]}"
    if (( actual_count != expected_count )) ||
       [[ "${SWEEP_SEEDS[0]}" != "${expected_first}" ]] ||
       [[ "${SWEEP_SEEDS[actual_count-1]}" != "${expected_last}" ]]; then
        printf 'FAIL %s: got %s seeds, first=%s, last=%s\n' "${label}" \
            "${actual_count}" "${SWEEP_SEEDS[0]}" "${SWEEP_SEEDS[actual_count-1]}" >&2
        exit 1
    fi
    printf 'PASS: %s (%s seeds)\n' "${label}" "${actual_count}"
}

sweep_ecp5_parse_seeds usage 750-1300
assert_seed_list 'explicit range beyond 512' 551 750 1300

sweep_ecp5_parse_seeds usage 1-600,600-700 700,800
assert_seed_list 'duplicates across ranges' 701 1 800

sweep_ecp5_parse_seeds usage 2147483645-2147483647
assert_seed_list 'upper signed 32-bit boundary' 3 2147483645 2147483647

unset SWEEP_ALL_SEED_LAST || true
sweep_ecp5_parse_seeds usage --all
assert_seed_list 'default --all' 512 1 512
[[ "$(sweep_ecp5_results_filename '/tmp/check')" == '/tmp/check/results.csv' ]]

SWEEP_ALL_SEED_LAST=1024 sweep_ecp5_parse_seeds usage --all
assert_seed_list 'configurable --all' 1024 1 1024
[[ "$(sweep_ecp5_results_filename '/tmp/check')" == '/tmp/check/results.csv' ]]

SWEEP_ALL_SEED_LAST=100 sweep_ecp5_parse_seeds usage --all
assert_seed_list 'short --all' 100 1 100
[[ "$(sweep_ecp5_results_filename '/tmp/check')" == '/tmp/check/results.csv' ]]

for invalid in 0 9999999999 1-0 2147483648; do
    if (sweep_ecp5_parse_seeds usage "${invalid}") >/dev/null 2>&1; then
        printf 'FAIL: invalid seed accepted: %s\n' "${invalid}" >&2
        exit 1
    fi
    printf 'PASS: rejected invalid seed %s\n' "${invalid}"
done
if (SWEEP_ALL_SEED_LAST=2147483648 sweep_ecp5_parse_seeds usage --all) >/dev/null 2>&1; then
    printf 'FAIL: invalid SWEEP_ALL_SEED_LAST accepted\n' >&2
    exit 1
fi
printf 'PASS: rejected invalid --all limit\n'

MATRIX="${ROOT}/scripts/generate-ecp5-seed-matrix.py"
python3 - "${MATRIX}" <<'PY'
import json
import subprocess
import sys

script = sys.argv[1]

def matrix(first, last, per_job):
    result = subprocess.run(
        [sys.executable, script, '--first', str(first), '--last', str(last),
         '--per-job', str(per_job)], capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)['include']

groups = matrix(750, 1300, 3)
assert len(groups) == 184, len(groups)
assert groups[0]['seeds'] == '750 751 752'
assert groups[-1]['seeds'] == '1299 1300'
print('PASS: GitHub matrix accepts 551 seeds in 184 groups')

groups = matrix(1, 2304, 9)
assert len(groups) == 256, len(groups)
assert groups[-1]['seeds'].endswith('2304')
print('PASS: GitHub matrix accepts 2304 seeds in 256 groups')

failed = subprocess.run(
    [sys.executable, script, '--first', '1', '--last', '2305',
     '--per-job', '9'], capture_output=True, text=True
)
assert failed.returncode != 0
assert '256 matrix jobs' in failed.stderr, failed.stderr
print('PASS: GitHub matrix rejects more than 256 jobs')

groups = matrix(2147483645, 2147483647, 2)
assert len(groups) == 2
assert groups[-1]['seeds'] == '2147483647'
print('PASS: GitHub matrix allows maximum signed 32-bit seed')
PY

python3 - "${ROOT}/.github/workflows/ulx4m-ld-seed-sweep.yml" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap

workflow = Path(sys.argv[1]).read_text(encoding='utf-8')
start = workflow.index('              case "${route_status}" in\n')
end = workflow.index('\n              esac', start) + len('\n              esac')
route_case = textwrap.dedent(workflow[start:end])
script = '''#!/usr/bin/env bash
set -euo pipefail
seed=11
route_status="$1"
result="$2"
SWEEP_SEED_TIMEOUT_SECONDS=7600
overall_status=0
''' + route_case + '''
printf 'OVERALL_STATUS=%s\n' "${overall_status}"
'''

with tempfile.TemporaryDirectory() as temp:
    result_file = Path(temp) / 'result-seed-11.csv'
    cases = (
        (0, 'PASS', 0),
        (1, 'FAIL', 0),
        (1, 'TIMEOUT', 0),
        (1, 'PACK_ERROR', 1),
        (1, None, 1),
        (124, None, 0),
        (255, None, 1),
    )
    for route_exit, timing_status, expected_status in cases:
        if timing_status is None:
            result_file.unlink(missing_ok=True)
        else:
            result_file.write_text(f'11,50,25,125,4,{timing_status}\n')
        result = subprocess.run(
            ['bash', '-c', script, '--', str(route_exit), str(result_file)],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        assert f'OVERALL_STATUS={expected_status}' in result.stdout, (
            route_exit, timing_status, result.stdout, result.stderr
        )
        print(f'PASS: CI route exit {route_exit}, timing {timing_status} '
              f'=> group infra status {expected_status}')

for name in (
    'sweep-ulx3s-12f.sh', 'sweep-ulx3s-85f.sh',
    'sweep-ulx4m-ld.sh', 'sweep-ulx5m-gs.sh',
):
    sweep = (Path(sys.argv[1]).parents[2] / 'scripts' / name).read_text()
    assert 'if (( pass_count == 0 )); then' in sweep
    print(f'PASS: no-PASS exit code covered in {name}')
PY

printf 'All seed policy tests passed.\n'
