# ulx3s-12f seed sweep summary

Apply updates to default ECP5 seeds in `scripts/ecp5-board-defaults.sh`.

From https://github.com/gojimmypi/Hazard3-Doom/actions/runs/38201459493/job/114659796436

Using Hazard3 [7743b30](https://github.com/gojimmypi/Hazard3/tree/7743b3089b1ded8b74d0d51e201b3554e310b5a3) WIP: 
Merge ULX3S GPIO/reset and ULX5M support into ulx-doom-dev

The paths recorded below are historical workflow metadata from that run.
Current scripts keep netlists, logs, and sweep results under top-level `build/`.

## Generated ulx3s-12f seed sweep summary

- Synthesis duration: 0:56 (56 seconds)
- Seeds expected: 260
- Routes completed: 260
- Timed-out seeds: 0
- TIMEOUT seed values: none
- Timing-passing seeds: 222
- PASS seed values: 2, 3, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 31, 32, 33, 35, 36, 37, 38, 39, 40, 42, 43, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 55, 56, 57, 58, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 105, 106, 107, 109, 110, 111, 112, 113, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 155, 157, 158, 159, 160, 161, 162, 163, 164, 166, 167, 168, 169, 170, 171, 172, 175, 176, 177, 178, 179, 180, 181, 182, 184, 186, 187, 189, 190, 191, 193, 195, 196, 197, 198, 199, 200, 201, 202, 204, 205, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 221, 222, 225, 226, 227, 228, 229, 230, 231, 232, 234, 235, 236, 237, 239, 240, 241, 242, 243, 244, 245, 248, 249, 250, 251, 252, 253, 255, 256, 257, 258, 259, 260
- Best combined-margin PASS seed: 151
- Fastest timing-passing seed: 239
- Completed routes with timing failure: 38
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 40.00 MHz
- video pixel: 50.00 MHz
- TMDS x5: 250.00 MHz

## Per-clock closure

- clk_sys: 243/260
- video pixel: 260/260
- TMDS x5: 238/260

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 10
- max_parallel: 20
- netlist: build/fpga_ulx3s_12f.json
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
- sweep_dir: build/ulx3s-12f-seed-sweep/32m
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx3s-12f
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
| 151 | PASS | 42.96 | 99.58 | 290.95 | clk_sys_mhz | 1.074x | 1:08 |
| 225 | PASS | 42.81 | 90.78 | 292.31 | clk_sys_mhz | 1.070x | 1:05 |
| 242 | PASS | 42.69 | 96.53 | 284.90 | clk_sys_mhz | 1.067x | 1:06 |
| 89 | PASS | 42.68 | 95.43 | 300.21 | clk_sys_mhz | 1.067x | 0:59 |
| 54 | PASS | 42.66 | 93.55 | 276.24 | clk_sys_mhz | 1.067x | 1:16 |
| 22 | PASS | 42.64 | 93.23 | 301.39 | clk_sys_mhz | 1.066x | 1:17 |
| 83 | PASS | 42.63 | 92.83 | 323.73 | clk_sys_mhz | 1.066x | 1:01 |
| 248 | PASS | 42.59 | 90.16 | 302.11 | clk_sys_mhz | 1.065x | 1:04 |
| 40 | PASS | 42.58 | 96.21 | 318.57 | clk_sys_mhz | 1.065x | 1:09 |
| 257 | PASS | 42.57 | 96.02 | 302.57 | clk_sys_mhz | 1.064x | 1:09 |
| 134 | PASS | 42.54 | 95.17 | 270.64 | clk_sys_mhz | 1.063x | 1:08 |
| 138 | PASS | 42.54 | 94.87 | 284.01 | clk_sys_mhz | 1.063x | 1:02 |
| 191 | PASS | 42.54 | 84.90 | 297.80 | clk_sys_mhz | 1.063x | 1:11 |
| 13 | PASS | 42.52 | 95.48 | 293.17 | clk_sys_mhz | 1.063x | 1:03 |
| 222 | PASS | 42.49 | 93.51 | 307.03 | clk_sys_mhz | 1.062x | 1:03 |
| 167 | PASS | 42.47 | 89.32 | 298.24 | clk_sys_mhz | 1.062x | 0:59 |
| 81 | PASS | 42.39 | 94.68 | 301.20 | clk_sys_mhz | 1.060x | 0:58 |
| 190 | PASS | 42.35 | 95.30 | 275.18 | clk_sys_mhz | 1.059x | 1:01 |
| 169 | PASS | 42.32 | 90.61 | 278.16 | clk_sys_mhz | 1.058x | 0:53 |
| 45 | PASS | 42.30 | 89.35 | 272.63 | clk_sys_mhz | 1.058x | 1:06 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 151 | PASS | 42.96 | 99.58 | 290.95 | clk_sys_mhz | 1.074x | 1:08 |
| 225 | PASS | 42.81 | 90.78 | 292.31 | clk_sys_mhz | 1.070x | 1:05 |
| 242 | PASS | 42.69 | 96.53 | 284.90 | clk_sys_mhz | 1.067x | 1:06 |
| 89 | PASS | 42.68 | 95.43 | 300.21 | clk_sys_mhz | 1.067x | 0:59 |
| 54 | PASS | 42.66 | 93.55 | 276.24 | clk_sys_mhz | 1.067x | 1:16 |
| 22 | PASS | 42.64 | 93.23 | 301.39 | clk_sys_mhz | 1.066x | 1:17 |
| 83 | PASS | 42.63 | 92.83 | 323.73 | clk_sys_mhz | 1.066x | 1:01 |
| 248 | PASS | 42.59 | 90.16 | 302.11 | clk_sys_mhz | 1.065x | 1:04 |
| 40 | PASS | 42.58 | 96.21 | 318.57 | clk_sys_mhz | 1.065x | 1:09 |
| 257 | PASS | 42.57 | 96.02 | 302.57 | clk_sys_mhz | 1.064x | 1:09 |
| 134 | PASS | 42.54 | 95.17 | 270.64 | clk_sys_mhz | 1.063x | 1:08 |
| 138 | PASS | 42.54 | 94.87 | 284.01 | clk_sys_mhz | 1.063x | 1:02 |
| 191 | PASS | 42.54 | 84.90 | 297.80 | clk_sys_mhz | 1.063x | 1:11 |
| 13 | PASS | 42.52 | 95.48 | 293.17 | clk_sys_mhz | 1.063x | 1:03 |
| 222 | PASS | 42.49 | 93.51 | 307.03 | clk_sys_mhz | 1.062x | 1:03 |
| 167 | PASS | 42.47 | 89.32 | 298.24 | clk_sys_mhz | 1.062x | 0:59 |
| 81 | PASS | 42.39 | 94.68 | 301.20 | clk_sys_mhz | 1.060x | 0:58 |
| 190 | PASS | 42.35 | 95.30 | 275.18 | clk_sys_mhz | 1.059x | 1:01 |
| 169 | PASS | 42.32 | 90.61 | 278.16 | clk_sys_mhz | 1.058x | 0:53 |
| 45 | PASS | 42.30 | 89.35 | 272.63 | clk_sys_mhz | 1.058x | 1:06 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 239 | PASS | 43.37 | 90.42 | 255.17 | clk_tmds_mhz | 1.021x | 0:37 |
| 240 | PASS | 40.21 | 94.58 | 303.49 | clk_sys_mhz | 1.005x | 0:38 |
| 12 | PASS | 40.89 | 89.42 | 273.67 | clk_sys_mhz | 1.022x | 0:39 |
| 3 | PASS | 42.22 | 92.52 | 325.84 | clk_sys_mhz | 1.056x | 0:40 |
| 153 | PASS | 41.38 | 93.67 | 293.77 | clk_sys_mhz | 1.034x | 0:42 |
| 11 | PASS | 40.36 | 96.38 | 299.76 | clk_sys_mhz | 1.009x | 0:44 |
| 62 | PASS | 40.58 | 92.36 | 301.48 | clk_sys_mhz | 1.014x | 0:44 |
| 78 | PASS | 40.30 | 92.77 | 290.53 | clk_sys_mhz | 1.008x | 0:46 |
| 107 | PASS | 40.86 | 93.18 | 298.15 | clk_sys_mhz | 1.022x | 0:47 |
| 50 | PASS | 42.14 | 90.49 | 318.57 | clk_sys_mhz | 1.054x | 0:48 |
| 228 | PASS | 42.30 | 87.92 | 312.99 | clk_sys_mhz | 1.058x | 0:48 |
| 61 | PASS | 41.03 | 98.88 | 299.94 | clk_sys_mhz | 1.026x | 0:51 |
| 98 | PASS | 40.80 | 91.89 | 304.60 | clk_sys_mhz | 1.020x | 0:51 |
| 227 | PASS | 42.08 | 89.46 | 320.31 | clk_sys_mhz | 1.052x | 0:51 |
| 26 | PASS | 40.13 | 90.83 | 280.11 | clk_sys_mhz | 1.003x | 0:52 |
| 111 | PASS | 42.24 | 89.95 | 289.10 | clk_sys_mhz | 1.056x | 0:52 |
| 136 | PASS | 40.94 | 94.01 | 331.35 | clk_sys_mhz | 1.024x | 0:52 |
| 182 | PASS | 42.47 | 88.64 | 262.05 | clk_tmds_mhz | 1.048x | 0:52 |
| 100 | PASS | 41.69 | 92.40 | 254.52 | clk_tmds_mhz | 1.018x | 0:53 |
| 129 | PASS | 40.73 | 95.45 | 298.69 | clk_sys_mhz | 1.018x | 0:53 |

The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is
recomputed from the required clocks in the frozen sweep metadata.
