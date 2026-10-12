# ulx3s-85f seed sweep summary

Apply updates to default ECP5 seeds in `scripts/ecp5-board-defaults.sh`.

From: https://github.com/gojimmypi/Hazard3-Doom/actions/runs/38148573801/job/114557646830

Using Hazard3 [7743b30](https://github.com/gojimmypi/Hazard3/tree/7743b3089b1ded8b74d0d51e201b3554e310b5a3) WIP: 
Merge ULX3S GPIO/reset and ULX5M support into ulx-doom-dev

The paths recorded below are historical workflow metadata from that run.
Current scripts keep netlists, logs, and sweep results under top-level `build/`.

## Generated ulx3s-85f seed sweep summary

- Synthesis duration: 1:13 (73 seconds)
- Seeds expected: 260
- Routes completed: 258
- Timed-out seeds: 2
- TIMEOUT seed values: 82, 139
- Timing-passing seeds: 106
- PASS seed values: 1, 2, 3, 6, 8, 14, 16, 17, 18, 22, 25, 27, 29, 35, 38, 41, 43, 44, 46, 51, 53, 54, 55, 60, 61, 65, 66, 72, 74, 78, 80, 81, 85, 86, 87, 90, 91, 94, 96, 99, 102, 103, 107, 108, 110, 111, 112, 115, 116, 117, 120, 123, 125, 127, 128, 131, 132, 133, 134, 135, 136, 137, 142, 145, 146, 147, 161, 163, 166, 167, 168, 169, 171, 172, 179, 181, 183, 184, 185, 189, 191, 193, 195, 199, 202, 207, 209, 210, 211, 212, 213, 214, 216, 218, 221, 223, 224, 227, 232, 233, 236, 240, 242, 248, 252, 256
- Best combined-margin PASS seed: 248
- Fastest timing-passing seed: 163
- Completed routes with timing failure: 152
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 50.00 MHz
- video pixel: 50.00 MHz
- TMDS x5: 250.00 MHz

## Per-clock closure

- clk_sys: 106/258
- video pixel: 258/258
- TMDS x5: 258/258

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 10
- max_parallel: 20
- netlist: build/fpga_ulx3s_85f.json
- nextpnr_extra_args: (none)
- placer: heap
- retain_bitstreams: false
- route_constraint: third_party/Hazard3/example_soc/synth/fpga_ulx3s.lpf
- route_kill_after_seconds: 30
- route_oss_cad_suite_version: 2026-07-20
- route_timeout_seconds: 7200
- router: router1
- router2_alt_weights: false
- seed_first: 1
- seed_kill_after_seconds: 30
- seed_last: 260
- seed_timeout_seconds: 7600
- seeds_per_job: 2
- sweep_dir: build/ulx3s-seed-sweep
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx3s-85f
- timing_constraint: (none)
- tmg_ripup: false
- ulx3s_12f_memory_profile: 32m
- ulx3s_85f_extended_modes: 1
- ulx4m_litedram_cpu: serv
- ulx4m_sys_clk_mhz: 40
- ulx5m_heap_beta: 0.6

## Closest to full timing closure

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 248 | PASS | 57.17 | 84.10 | 369.41 | clk_sys_mhz | 1.143x | 39:13 |
| 3 | PASS | 57.16 | 85.63 | 330.80 | clk_sys_mhz | 1.143x | 40:37 |
| 131 | PASS | 56.40 | 75.45 | 352.49 | clk_sys_mhz | 1.128x | 37:15 |
| 85 | PASS | 56.20 | 84.95 | 337.04 | clk_sys_mhz | 1.124x | 36:47 |
| 211 | PASS | 55.73 | 87.02 | 304.60 | clk_sys_mhz | 1.115x | 4:04 |
| 133 | PASS | 55.55 | 78.78 | 351.99 | clk_sys_mhz | 1.111x | 7:40 |
| 147 | PASS | 55.20 | 79.78 | 328.95 | clk_sys_mhz | 1.104x | 45:28 |
| 46 | PASS | 55.14 | 84.70 | 303.95 | clk_sys_mhz | 1.103x | 34:20 |
| 167 | PASS | 55.13 | 81.46 | 452.08 | clk_sys_mhz | 1.103x | 3:07 |
| 102 | PASS | 55.05 | 82.59 | 336.81 | clk_sys_mhz | 1.101x | 4:10 |
| 169 | PASS | 55.04 | 84.65 | 339.90 | clk_sys_mhz | 1.101x | 20:08 |
| 123 | PASS | 54.98 | 78.24 | 321.54 | clk_sys_mhz | 1.100x | 17:28 |
| 214 | PASS | 54.80 | 84.84 | 303.86 | clk_sys_mhz | 1.096x | 11:15 |
| 38 | PASS | 54.76 | 82.39 | 323.00 | clk_sys_mhz | 1.095x | 10:43 |
| 55 | PASS | 54.43 | 74.89 | 303.58 | clk_sys_mhz | 1.089x | 7:58 |
| 135 | PASS | 54.40 | 79.97 | 303.49 | clk_sys_mhz | 1.088x | 49:57 |
| 72 | PASS | 54.17 | 85.30 | 329.92 | clk_sys_mhz | 1.083x | 6:46 |
| 65 | PASS | 54.02 | 86.27 | 323.00 | clk_sys_mhz | 1.080x | 10:53 |
| 27 | PASS | 53.94 | 84.26 | 292.91 | clk_sys_mhz | 1.079x | 7:29 |
| 66 | PASS | 53.88 | 80.04 | 321.54 | clk_sys_mhz | 1.078x | 6:50 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 248 | PASS | 57.17 | 84.10 | 369.41 | clk_sys_mhz | 1.143x | 39:13 |
| 3 | PASS | 57.16 | 85.63 | 330.80 | clk_sys_mhz | 1.143x | 40:37 |
| 131 | PASS | 56.40 | 75.45 | 352.49 | clk_sys_mhz | 1.128x | 37:15 |
| 85 | PASS | 56.20 | 84.95 | 337.04 | clk_sys_mhz | 1.124x | 36:47 |
| 211 | PASS | 55.73 | 87.02 | 304.60 | clk_sys_mhz | 1.115x | 4:04 |
| 133 | PASS | 55.55 | 78.78 | 351.99 | clk_sys_mhz | 1.111x | 7:40 |
| 147 | PASS | 55.20 | 79.78 | 328.95 | clk_sys_mhz | 1.104x | 45:28 |
| 46 | PASS | 55.14 | 84.70 | 303.95 | clk_sys_mhz | 1.103x | 34:20 |
| 167 | PASS | 55.13 | 81.46 | 452.08 | clk_sys_mhz | 1.103x | 3:07 |
| 102 | PASS | 55.05 | 82.59 | 336.81 | clk_sys_mhz | 1.101x | 4:10 |
| 169 | PASS | 55.04 | 84.65 | 339.90 | clk_sys_mhz | 1.101x | 20:08 |
| 123 | PASS | 54.98 | 78.24 | 321.54 | clk_sys_mhz | 1.100x | 17:28 |
| 214 | PASS | 54.80 | 84.84 | 303.86 | clk_sys_mhz | 1.096x | 11:15 |
| 38 | PASS | 54.76 | 82.39 | 323.00 | clk_sys_mhz | 1.095x | 10:43 |
| 55 | PASS | 54.43 | 74.89 | 303.58 | clk_sys_mhz | 1.089x | 7:58 |
| 135 | PASS | 54.40 | 79.97 | 303.49 | clk_sys_mhz | 1.088x | 49:57 |
| 72 | PASS | 54.17 | 85.30 | 329.92 | clk_sys_mhz | 1.083x | 6:46 |
| 65 | PASS | 54.02 | 86.27 | 323.00 | clk_sys_mhz | 1.080x | 10:53 |
| 27 | PASS | 53.94 | 84.26 | 292.91 | clk_sys_mhz | 1.079x | 7:29 |
| 66 | PASS | 53.88 | 80.04 | 321.54 | clk_sys_mhz | 1.078x | 6:50 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 163 | PASS | 50.12 | 82.42 | 317.97 | clk_sys_mhz | 1.002x | 1:52 |
| 54 | PASS | 51.32 | 76.30 | 400.16 | clk_sys_mhz | 1.026x | 1:57 |
| 1 | PASS | 50.07 | 88.87 | 421.94 | clk_sys_mhz | 1.001x | 2:04 |
| 167 | PASS | 55.13 | 81.46 | 452.08 | clk_sys_mhz | 1.103x | 3:07 |
| 181 | PASS | 50.94 | 86.49 | 393.24 | clk_sys_mhz | 1.019x | 3:14 |
| 134 | PASS | 53.81 | 83.44 | 390.17 | clk_sys_mhz | 1.076x | 3:17 |
| 191 | PASS | 51.12 | 82.64 | 390.17 | clk_sys_mhz | 1.022x | 3:47 |
| 211 | PASS | 55.73 | 87.02 | 304.60 | clk_sys_mhz | 1.115x | 4:04 |
| 102 | PASS | 55.05 | 82.59 | 336.81 | clk_sys_mhz | 1.101x | 4:10 |
| 53 | PASS | 52.75 | 85.21 | 369.28 | clk_sys_mhz | 1.055x | 4:17 |
| 74 | PASS | 51.57 | 76.56 | 408.33 | clk_sys_mhz | 1.031x | 4:20 |
| 2 | PASS | 52.88 | 85.56 | 369.28 | clk_sys_mhz | 1.058x | 4:55 |
| 179 | PASS | 51.37 | 84.08 | 384.02 | clk_sys_mhz | 1.027x | 5:09 |
| 18 | PASS | 50.67 | 86.42 | 397.14 | clk_sys_mhz | 1.013x | 5:20 |
| 94 | PASS | 51.33 | 85.11 | 397.77 | clk_sys_mhz | 1.027x | 5:40 |
| 80 | PASS | 50.14 | 84.85 | 320.92 | clk_sys_mhz | 1.003x | 5:43 |
| 209 | PASS | 50.63 | 79.43 | 354.48 | clk_sys_mhz | 1.013x | 5:56 |
| 120 | PASS | 50.02 | 85.52 | 324.57 | clk_sys_mhz | 1.000x | 6:17 |
| 202 | PASS | 53.67 | 78.21 | 323.00 | clk_sys_mhz | 1.073x | 6:23 |
| 35 | PASS | 53.39 | 84.08 | 352.49 | clk_sys_mhz | 1.068x | 6:40 |

The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is
recomputed from the required clocks in the frozen sweep metadata.
