# ulx3s-12f seed sweep summary

- Synthesis duration: 0:49 (49 seconds)
- Seeds expected: 260
- Routes completed: 260
- Timed-out seeds: 0
- TIMEOUT seed values: none
- Timing-passing seeds: 139
- PASS seed values: 1, 4, 5, 6, 7, 8, 9, 10, 12, 18, 20, 22, 23, 24, 25, 27, 28, 29, 30, 33, 34, 35, 36, 37, 38, 40, 42, 45, 46, 48, 49, 52, 53, 54, 55, 56, 57, 59, 60, 62, 63, 64, 65, 66, 67, 68, 69, 74, 75, 76, 77, 80, 82, 87, 88, 90, 91, 92, 100, 101, 103, 104, 106, 107, 109, 110, 112, 114, 115, 118, 121, 125, 126, 127, 129, 130, 133, 134, 135, 136, 139, 140, 141, 144, 146, 150, 151, 154, 156, 158, 160, 162, 163, 165, 166, 168, 171, 172, 173, 174, 176, 177, 180, 181, 182, 183, 184, 187, 189, 192, 194, 196, 203, 204, 207, 211, 212, 213, 215, 219, 222, 225, 226, 230, 231, 235, 237, 238, 241, 243, 245, 246, 249, 250, 251, 252, 255, 258, 260
- Best combined-margin PASS seed: 82
- Fastest timing-passing seed: 37
- Completed routes with timing failure: 121
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 40.00 MHz
- video pixel: 50.00 MHz
- TMDS x5: 250.00 MHz

## Per-clock closure

- clk_sys: 159/260
- video pixel: 260/260
- TMDS x5: 232/260

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 10
- max_parallel: 20
- netlist: third_party/Hazard3/example_soc/synth/fpga_ulx3s_12f.json
- nextpnr_extra_args: (none)
- placer: heap
- retain_bitstreams: false
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
- sweep_dir: build/ulx3s-12f-seed-sweep/32m
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx3s-12f
- tmg_ripup: false
- ulx3s_12f_memory_profile: 32m
- ulx3s_85f_extended_modes: 1
- ulx4m_litedram_cpu: serv
- ulx4m_sys_clk_mhz: 40

## Closest to full timing closure

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 82 | PASS | 42.70 | 90.96 | 285.06 | clk_sys_mhz | 1.067x | 1:14 |
| 141 | PASS | 42.48 | 90.52 | 271.59 | clk_sys_mhz | 1.062x | 1:22 |
| 243 | PASS | 42.44 | 91.90 | 278.40 | clk_sys_mhz | 1.061x | 1:33 |
| 1 | PASS | 42.43 | 93.07 | 271.67 | clk_sys_mhz | 1.061x | 1:08 |
| 4 | PASS | 42.31 | 94.27 | 295.60 | clk_sys_mhz | 1.058x | 1:07 |
| 76 | PASS | 42.34 | 94.51 | 264.41 | clk_tmds_mhz | 1.058x | 1:15 |
| 91 | PASS | 42.27 | 94.36 | 271.22 | clk_sys_mhz | 1.057x | 1:08 |
| 154 | PASS | 42.19 | 91.55 | 316.56 | clk_sys_mhz | 1.055x | 0:59 |
| 158 | PASS | 42.14 | 94.94 | 279.41 | clk_sys_mhz | 1.054x | 1:07 |
| 126 | PASS | 42.08 | 95.27 | 279.17 | clk_sys_mhz | 1.052x | 1:00 |
| 110 | PASS | 42.02 | 88.90 | 278.47 | clk_sys_mhz | 1.050x | 1:07 |
| 90 | PASS | 41.98 | 88.90 | 275.63 | clk_sys_mhz | 1.050x | 1:01 |
| 192 | PASS | 41.92 | 90.10 | 277.09 | clk_sys_mhz | 1.048x | 1:05 |
| 9 | PASS | 41.76 | 92.49 | 278.63 | clk_sys_mhz | 1.044x | 1:05 |
| 28 | PASS | 42.10 | 93.01 | 260.55 | clk_tmds_mhz | 1.042x | 1:24 |
| 92 | PASS | 41.68 | 95.98 | 273.75 | clk_sys_mhz | 1.042x | 1:06 |
| 140 | PASS | 41.68 | 88.04 | 281.21 | clk_sys_mhz | 1.042x | 1:09 |
| 55 | PASS | 41.66 | 95.30 | 284.33 | clk_sys_mhz | 1.042x | 1:10 |
| 57 | PASS | 41.66 | 91.20 | 273.45 | clk_sys_mhz | 1.042x | 1:18 |
| 63 | PASS | 41.64 | 93.67 | 264.13 | clk_sys_mhz | 1.041x | 1:05 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 82 | PASS | 42.70 | 90.96 | 285.06 | clk_sys_mhz | 1.067x | 1:14 |
| 141 | PASS | 42.48 | 90.52 | 271.59 | clk_sys_mhz | 1.062x | 1:22 |
| 243 | PASS | 42.44 | 91.90 | 278.40 | clk_sys_mhz | 1.061x | 1:33 |
| 1 | PASS | 42.43 | 93.07 | 271.67 | clk_sys_mhz | 1.061x | 1:08 |
| 4 | PASS | 42.31 | 94.27 | 295.60 | clk_sys_mhz | 1.058x | 1:07 |
| 76 | PASS | 42.34 | 94.51 | 264.41 | clk_tmds_mhz | 1.058x | 1:15 |
| 91 | PASS | 42.27 | 94.36 | 271.22 | clk_sys_mhz | 1.057x | 1:08 |
| 154 | PASS | 42.19 | 91.55 | 316.56 | clk_sys_mhz | 1.055x | 0:59 |
| 158 | PASS | 42.14 | 94.94 | 279.41 | clk_sys_mhz | 1.054x | 1:07 |
| 126 | PASS | 42.08 | 95.27 | 279.17 | clk_sys_mhz | 1.052x | 1:00 |
| 110 | PASS | 42.02 | 88.90 | 278.47 | clk_sys_mhz | 1.050x | 1:07 |
| 90 | PASS | 41.98 | 88.90 | 275.63 | clk_sys_mhz | 1.050x | 1:01 |
| 192 | PASS | 41.92 | 90.10 | 277.09 | clk_sys_mhz | 1.048x | 1:05 |
| 9 | PASS | 41.76 | 92.49 | 278.63 | clk_sys_mhz | 1.044x | 1:05 |
| 28 | PASS | 42.10 | 93.01 | 260.55 | clk_tmds_mhz | 1.042x | 1:24 |
| 92 | PASS | 41.68 | 95.98 | 273.75 | clk_sys_mhz | 1.042x | 1:06 |
| 140 | PASS | 41.68 | 88.04 | 281.21 | clk_sys_mhz | 1.042x | 1:09 |
| 55 | PASS | 41.66 | 95.30 | 284.33 | clk_sys_mhz | 1.042x | 1:10 |
| 57 | PASS | 41.66 | 91.20 | 273.45 | clk_sys_mhz | 1.042x | 1:18 |
| 63 | PASS | 41.64 | 93.67 | 264.13 | clk_sys_mhz | 1.041x | 1:05 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 37 | PASS | 40.80 | 92.87 | 256.81 | clk_sys_mhz | 1.020x | 0:39 |
| 246 | PASS | 40.09 | 93.05 | 271.96 | clk_sys_mhz | 1.002x | 0:40 |
| 238 | PASS | 40.60 | 96.01 | 272.70 | clk_sys_mhz | 1.015x | 0:43 |
| 151 | PASS | 41.34 | 93.45 | 278.55 | clk_sys_mhz | 1.034x | 0:44 |
| 237 | PASS | 40.14 | 91.58 | 278.40 | clk_sys_mhz | 1.004x | 0:45 |
| 38 | PASS | 41.48 | 93.68 | 259.88 | clk_sys_mhz | 1.037x | 0:46 |
| 249 | PASS | 40.37 | 94.74 | 273.45 | clk_sys_mhz | 1.009x | 0:46 |
| 203 | PASS | 40.47 | 94.66 | 306.75 | clk_sys_mhz | 1.012x | 0:47 |
| 204 | PASS | 40.88 | 87.15 | 264.83 | clk_sys_mhz | 1.022x | 0:48 |
| 250 | PASS | 41.43 | 93.26 | 271.08 | clk_sys_mhz | 1.036x | 0:49 |
| 29 | PASS | 40.38 | 97.27 | 267.59 | clk_sys_mhz | 1.010x | 0:52 |
| 245 | PASS | 40.40 | 93.84 | 304.97 | clk_sys_mhz | 1.010x | 0:52 |
| 67 | PASS | 41.19 | 95.17 | 279.80 | clk_sys_mhz | 1.030x | 0:53 |
| 10 | PASS | 41.03 | 95.18 | 257.93 | clk_sys_mhz | 1.026x | 0:55 |
| 150 | PASS | 40.82 | 82.75 | 279.25 | clk_sys_mhz | 1.020x | 0:55 |
| 160 | PASS | 40.50 | 88.72 | 275.41 | clk_sys_mhz | 1.012x | 0:55 |
| 172 | PASS | 41.19 | 98.76 | 277.01 | clk_sys_mhz | 1.030x | 0:55 |
| 163 | PASS | 40.15 | 93.96 | 270.42 | clk_sys_mhz | 1.004x | 0:56 |
| 176 | PASS | 41.18 | 89.62 | 256.74 | clk_tmds_mhz | 1.027x | 0:56 |
| 68 | PASS | 40.85 | 95.00 | 257.14 | clk_sys_mhz | 1.021x | 0:57 |

The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is
recomputed from the required clocks in the frozen sweep metadata.