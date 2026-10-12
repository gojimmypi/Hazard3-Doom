# ulx5m-gs seed sweep summary

Apply updates to default GateMate seeds in `scripts/ecp5-board-defaults.sh`.

From: https://github.com/gojimmypi/Hazard3-Doom/actions/runs/38313653780/job/115036324942

Using Hazard3 [7743b30](https://github.com/gojimmypi/Hazard3/tree/7743b3089b1ded8b74d0d51e201b3554e310b5a3) WIP: 
Merge ULX3S GPIO/reset and ULX5M support into ulx-doom-dev

The paths recorded below are historical workflow metadata from that run.
Current scripts keep netlists, logs, and sweep results under top-level `build/`.

## Generatedulx5m-gs seed sweep summary

- Synthesis duration: 0:37 (37 seconds)
- Seeds expected: 260
- Routes completed: 249
- Timed-out seeds: 11
- TIMEOUT seed values: 8, 9, 13, 35, 41, 77, 99, 105, 145, 168, 203
- Timing-passing seeds: 178
- PASS seed values: 2, 3, 5, 6, 7, 11, 12, 15, 16, 17, 18, 19, 21, 22, 24, 25, 26, 28, 32, 33, 34, 37, 38, 39, 40, 42, 48, 49, 51, 52, 53, 59, 61, 63, 64, 65, 66, 67, 68, 69, 70, 72, 74, 76, 79, 83, 84, 85, 86, 90, 91, 92, 93, 95, 97, 98, 100, 101, 102, 104, 106, 107, 108, 111, 112, 113, 114, 115, 116, 117, 118, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 133, 134, 135, 138, 139, 140, 141, 142, 143, 144, 147, 148, 150, 151, 153, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 167, 169, 170, 171, 172, 173, 174, 175, 176, 178, 179, 180, 183, 185, 186, 187, 188, 190, 192, 193, 196, 199, 200, 201, 202, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 218, 220, 221, 222, 223, 224, 225, 227, 228, 230, 231, 233, 234, 235, 238, 239, 240, 243, 244, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 259, 260
- Best combined-margin PASS seed: 101
- Fastest timing-passing seed: 16
- Completed routes with timing failure: 71
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 12.00 MHz

## Per-clock closure

- clk_sys: 179/249

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 10
- max_parallel: 20
- netlist: build/ulx5m-gs/sweep-synth/fpga_ulx5m_gs.json
- nextpnr_extra_args: (none)
- placer: heap
- retain_bitstreams: false
- route_constraint: third_party/Hazard3/example_soc/synth/fpga_ulx5m_gs.ccf
- route_kill_after_seconds: 30
- route_oss_cad_suite_version: 2026-07-20
- route_timeout_seconds: 540
- router: router2
- router2_alt_weights: false
- seed_first: 1
- seed_kill_after_seconds: 30
- seed_last: 260
- seed_timeout_seconds: 600
- seeds_per_job: 2
- sweep_dir: build/ulx5m-gs-seed-sweep-beta0p6
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx5m-gs
- timing_constraint: third_party/Hazard3/example_soc/synth/fpga_ulx5m_gs.sdc
- tmg_ripup: false
- ulx3s_12f_memory_profile: 32m
- ulx3s_85f_extended_modes: 1
- ulx4m_litedram_cpu: serv
- ulx4m_sys_clk_mhz: 40
- ulx5m_heap_beta: 0.6
- ulx5m_sys_clk_mhz: 12

## Closest to full timing closure

| Seed | Result | clk_sys | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | :--- | ---: | ---: |
| 101 | PASS | 14.12 | clk_sys_mhz | 1.177x | 1:18 |
| 102 | PASS | 13.74 | clk_sys_mhz | 1.145x | 1:15 |
| 16 | PASS | 13.71 | clk_sys_mhz | 1.143x | 1:07 |
| 207 | PASS | 13.61 | clk_sys_mhz | 1.134x | 1:49 |
| 65 | PASS | 13.47 | clk_sys_mhz | 1.123x | 1:33 |
| 59 | PASS | 13.46 | clk_sys_mhz | 1.122x | 1:33 |
| 107 | PASS | 13.43 | clk_sys_mhz | 1.119x | 1:25 |
| 91 | PASS | 13.38 | clk_sys_mhz | 1.115x | 1:43 |
| 117 | PASS | 13.36 | clk_sys_mhz | 1.113x | 1:32 |
| 196 | PASS | 13.34 | clk_sys_mhz | 1.112x | 1:17 |
| 104 | PASS | 13.33 | clk_sys_mhz | 1.111x | 1:36 |
| 67 | PASS | 13.32 | clk_sys_mhz | 1.110x | 1:54 |
| 160 | PASS | 13.32 | clk_sys_mhz | 1.110x | 1:21 |
| 131 | PASS | 13.28 | clk_sys_mhz | 1.107x | 1:32 |
| 225 | PASS | 13.28 | clk_sys_mhz | 1.107x | 1:13 |
| 246 | PASS | 13.25 | clk_sys_mhz | 1.104x | 1:35 |
| 49 | PASS | 13.19 | clk_sys_mhz | 1.099x | 1:35 |
| 130 | PASS | 13.19 | clk_sys_mhz | 1.099x | 1:44 |
| 174 | PASS | 13.19 | clk_sys_mhz | 1.099x | 1:39 |
| 249 | PASS | 13.16 | clk_sys_mhz | 1.097x | 1:18 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | :--- | ---: | ---: |
| 101 | PASS | 14.12 | clk_sys_mhz | 1.177x | 1:18 |
| 102 | PASS | 13.74 | clk_sys_mhz | 1.145x | 1:15 |
| 16 | PASS | 13.71 | clk_sys_mhz | 1.143x | 1:07 |
| 207 | PASS | 13.61 | clk_sys_mhz | 1.134x | 1:49 |
| 65 | PASS | 13.47 | clk_sys_mhz | 1.123x | 1:33 |
| 59 | PASS | 13.46 | clk_sys_mhz | 1.122x | 1:33 |
| 107 | PASS | 13.43 | clk_sys_mhz | 1.119x | 1:25 |
| 91 | PASS | 13.38 | clk_sys_mhz | 1.115x | 1:43 |
| 117 | PASS | 13.36 | clk_sys_mhz | 1.113x | 1:32 |
| 196 | PASS | 13.34 | clk_sys_mhz | 1.112x | 1:17 |
| 104 | PASS | 13.33 | clk_sys_mhz | 1.111x | 1:36 |
| 67 | PASS | 13.32 | clk_sys_mhz | 1.110x | 1:54 |
| 160 | PASS | 13.32 | clk_sys_mhz | 1.110x | 1:21 |
| 131 | PASS | 13.28 | clk_sys_mhz | 1.107x | 1:32 |
| 225 | PASS | 13.28 | clk_sys_mhz | 1.107x | 1:13 |
| 246 | PASS | 13.25 | clk_sys_mhz | 1.104x | 1:35 |
| 49 | PASS | 13.19 | clk_sys_mhz | 1.099x | 1:35 |
| 130 | PASS | 13.19 | clk_sys_mhz | 1.099x | 1:44 |
| 174 | PASS | 13.19 | clk_sys_mhz | 1.099x | 1:39 |
| 249 | PASS | 13.16 | clk_sys_mhz | 1.097x | 1:18 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | :--- | ---: | ---: |
| 16 | PASS | 13.71 | clk_sys_mhz | 1.143x | 1:07 |
| 76 | PASS | 12.14 | clk_sys_mhz | 1.012x | 1:07 |
| 222 | PASS | 12.38 | clk_sys_mhz | 1.032x | 1:09 |
| 15 | PASS | 12.21 | clk_sys_mhz | 1.018x | 1:12 |
| 61 | PASS | 12.09 | clk_sys_mhz | 1.008x | 1:12 |
| 176 | PASS | 13.02 | clk_sys_mhz | 1.085x | 1:12 |
| 95 | PASS | 13.04 | clk_sys_mhz | 1.087x | 1:13 |
| 225 | PASS | 13.28 | clk_sys_mhz | 1.107x | 1:13 |
| 254 | PASS | 12.20 | clk_sys_mhz | 1.017x | 1:13 |
| 64 | PASS | 12.44 | clk_sys_mhz | 1.037x | 1:14 |
| 126 | PASS | 12.43 | clk_sys_mhz | 1.036x | 1:14 |
| 175 | PASS | 12.56 | clk_sys_mhz | 1.047x | 1:14 |
| 199 | PASS | 12.53 | clk_sys_mhz | 1.044x | 1:14 |
| 24 | PASS | 12.70 | clk_sys_mhz | 1.058x | 1:15 |
| 102 | PASS | 13.74 | clk_sys_mhz | 1.145x | 1:15 |
| 167 | PASS | 12.13 | clk_sys_mhz | 1.011x | 1:16 |
| 39 | PASS | 12.52 | clk_sys_mhz | 1.043x | 1:17 |
| 52 | PASS | 12.32 | clk_sys_mhz | 1.027x | 1:17 |
| 83 | PASS | 12.16 | clk_sys_mhz | 1.013x | 1:17 |
| 196 | PASS | 13.34 | clk_sys_mhz | 1.112x | 1:17 |

The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is
recomputed from the required clocks in the frozen sweep metadata.
