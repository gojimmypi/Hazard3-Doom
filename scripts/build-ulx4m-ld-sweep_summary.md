# ulx4m-ld-85f seed sweep

Apply updates to default ECP5 seeds in `scripts/ecp5-board-defaults.sh`.

From: https://github.com/gojimmypi/Hazard3-Doom/actions/runs/38184822196

Using Hazard3 [7743b30](https://github.com/gojimmypi/Hazard3/tree/7743b3089b1ded8b74d0d51e201b3554e310b5a3) WIP: 
Merge ULX3S GPIO/reset and ULX5M support into ulx-doom-dev

The paths recorded below are historical workflow metadata from that run.
Current scripts keep netlists, logs, and sweep results under top-level `build/`.

## Generated ulx4m-ld-85f seed sweep summary

- Synthesis duration: 1:10 (70 seconds)
- Seeds expected: 260
- Routes completed: 260
- Timed-out seeds: 0
- TIMEOUT seed values: none
- Timing-passing seeds: 101
- PASS seed values: 1, 2, 3, 7, 8, 18, 19, 25, 27, 30, 32, 33, 35, 38, 39, 40, 42, 43, 44, 45, 47, 51, 52, 53, 56, 58, 62, 65, 69, 73, 76, 77, 79, 89, 92, 93, 94, 97, 100, 101, 102, 103, 105, 110, 112, 117, 120, 125, 126, 129, 134, 135, 136, 142, 144, 149, 150, 153, 155, 157, 158, 159, 161, 162, 163, 164, 166, 169, 174, 178, 180, 182, 185, 186, 192, 194, 195, 196, 199, 200, 202, 209, 210, 212, 217, 218, 220, 221, 222, 223, 228, 231, 232, 237, 239, 243, 247, 250, 256, 257, 259
- Best combined-margin PASS seed: 89
- Fastest timing-passing seed: 97
- Completed routes with timing failure: 159
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 40.00 MHz
- LiteDRAM user: 60.01 MHz
- video pixel: 50.00 MHz
- TMDS x5: 250.00 MHz
- init_clk: 25.00 MHz

## Per-clock closure

- clk_sys: 106/260
- LiteDRAM user: 244/260
- video pixel: 260/260
- TMDS x5: 260/260
- init_clk: 260/260

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 30
- max_parallel: 20
- netlist: build/fpga_ulx4m_ld.json
- nextpnr_extra_args: (none)
- placer: heap
- retain_bitstreams: true
- route_constraint: third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.lpf
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
- sweep_dir: build/ulx4m-ld-seed-sweep/40mhz-serv-tw30
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx4m-ld-85f
- timing_constraint: (none)
- tmg_ripup: false
- ulx3s_12f_memory_profile: 32m
- ulx3s_85f_extended_modes: 1
- ulx4m_litedram_cpu: serv
- ulx4m_sys_clk_mhz: 40
- ulx5m_heap_beta: 0.6

## Closest to full timing closure

| Seed | Result | clk_sys | LiteDRAM user | video pixel | TMDS x5 | init_clk | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 89 | PASS | 43.09 | 69.40 | 71.80 | 310.37 | 272.11 | clk_sys_mhz | 1.077x | 2:52 |
| 157 | PASS | 42.38 | 67.08 | 68.83 | 364.56 | 293.94 | clk_sys_mhz | 1.060x | 2:29 |
| 56 | PASS | 42.14 | 64.08 | 68.94 | 333.78 | 310.85 | clk_sys_mhz | 1.054x | 3:49 |
| 159 | PASS | 42.04 | 65.82 | 59.09 | 295.33 | 350.02 | clk_sys_mhz | 1.051x | 4:49 |
| 182 | PASS | 41.98 | 63.72 | 66.17 | 323.31 | 291.38 | clk_sys_mhz | 1.050x | 2:45 |
| 228 | PASS | 41.96 | 62.84 | 58.24 | 280.90 | 282.41 | litedram_user_mhz | 1.047x | 3:22 |
| 32 | PASS | 41.63 | 65.36 | 71.64 | 290.36 | 290.70 | clk_sys_mhz | 1.041x | 3:24 |
| 221 | PASS | 41.62 | 63.97 | 57.82 | 310.17 | 366.03 | clk_sys_mhz | 1.040x | 3:52 |
| 97 | PASS | 41.61 | 65.66 | 67.77 | 350.88 | 277.09 | clk_sys_mhz | 1.040x | 2:04 |
| 256 | PASS | 41.57 | 63.97 | 60.92 | 326.90 | 290.19 | clk_sys_mhz | 1.039x | 3:03 |
| 27 | PASS | 41.52 | 63.28 | 67.44 | 307.88 | 273.22 | clk_sys_mhz | 1.038x | 3:45 |
| 161 | PASS | 41.45 | 63.81 | 69.20 | 285.96 | 356.00 | clk_sys_mhz | 1.036x | 3:32 |
| 30 | PASS | 41.39 | 65.28 | 68.70 | 333.78 | 361.79 | clk_sys_mhz | 1.035x | 3:48 |
| 79 | PASS | 41.34 | 65.26 | 70.47 | 327.87 | 300.21 | clk_sys_mhz | 1.034x | 3:22 |
| 162 | PASS | 41.33 | 64.17 | 60.56 | 316.76 | 296.56 | clk_sys_mhz | 1.033x | 3:09 |
| 202 | PASS | 41.30 | 66.81 | 66.24 | 288.27 | 299.22 | clk_sys_mhz | 1.032x | 3:22 |
| 40 | PASS | 41.29 | 62.72 | 67.54 | 283.93 | 351.00 | clk_sys_mhz | 1.032x | 3:07 |
| 102 | PASS | 41.23 | 64.31 | 59.91 | 262.33 | 278.63 | clk_sys_mhz | 1.031x | 2:37 |
| 120 | PASS | 41.23 | 65.46 | 66.95 | 295.51 | 278.86 | clk_sys_mhz | 1.031x | 2:39 |
| 155 | PASS | 41.23 | 66.93 | 62.68 | 323.52 | 333.56 | clk_sys_mhz | 1.031x | 2:49 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | LiteDRAM user | video pixel | TMDS x5 | init_clk | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 89 | PASS | 43.09 | 69.40 | 71.80 | 310.37 | 272.11 | clk_sys_mhz | 1.077x | 2:52 |
| 157 | PASS | 42.38 | 67.08 | 68.83 | 364.56 | 293.94 | clk_sys_mhz | 1.060x | 2:29 |
| 56 | PASS | 42.14 | 64.08 | 68.94 | 333.78 | 310.85 | clk_sys_mhz | 1.054x | 3:49 |
| 159 | PASS | 42.04 | 65.82 | 59.09 | 295.33 | 350.02 | clk_sys_mhz | 1.051x | 4:49 |
| 182 | PASS | 41.98 | 63.72 | 66.17 | 323.31 | 291.38 | clk_sys_mhz | 1.050x | 2:45 |
| 228 | PASS | 41.96 | 62.84 | 58.24 | 280.90 | 282.41 | litedram_user_mhz | 1.047x | 3:22 |
| 32 | PASS | 41.63 | 65.36 | 71.64 | 290.36 | 290.70 | clk_sys_mhz | 1.041x | 3:24 |
| 221 | PASS | 41.62 | 63.97 | 57.82 | 310.17 | 366.03 | clk_sys_mhz | 1.040x | 3:52 |
| 97 | PASS | 41.61 | 65.66 | 67.77 | 350.88 | 277.09 | clk_sys_mhz | 1.040x | 2:04 |
| 256 | PASS | 41.57 | 63.97 | 60.92 | 326.90 | 290.19 | clk_sys_mhz | 1.039x | 3:03 |
| 27 | PASS | 41.52 | 63.28 | 67.44 | 307.88 | 273.22 | clk_sys_mhz | 1.038x | 3:45 |
| 161 | PASS | 41.45 | 63.81 | 69.20 | 285.96 | 356.00 | clk_sys_mhz | 1.036x | 3:32 |
| 30 | PASS | 41.39 | 65.28 | 68.70 | 333.78 | 361.79 | clk_sys_mhz | 1.035x | 3:48 |
| 79 | PASS | 41.34 | 65.26 | 70.47 | 327.87 | 300.21 | clk_sys_mhz | 1.034x | 3:22 |
| 162 | PASS | 41.33 | 64.17 | 60.56 | 316.76 | 296.56 | clk_sys_mhz | 1.033x | 3:09 |
| 202 | PASS | 41.30 | 66.81 | 66.24 | 288.27 | 299.22 | clk_sys_mhz | 1.032x | 3:22 |
| 40 | PASS | 41.29 | 62.72 | 67.54 | 283.93 | 351.00 | clk_sys_mhz | 1.032x | 3:07 |
| 102 | PASS | 41.23 | 64.31 | 59.91 | 262.33 | 278.63 | clk_sys_mhz | 1.031x | 2:37 |
| 120 | PASS | 41.23 | 65.46 | 66.95 | 295.51 | 278.86 | clk_sys_mhz | 1.031x | 2:39 |
| 155 | PASS | 41.23 | 66.93 | 62.68 | 323.52 | 333.56 | clk_sys_mhz | 1.031x | 2:49 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | LiteDRAM user | video pixel | TMDS x5 | init_clk | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 97 | PASS | 41.61 | 65.66 | 67.77 | 350.88 | 277.09 | clk_sys_mhz | 1.040x | 2:04 |
| 112 | PASS | 40.80 | 62.35 | 58.38 | 307.98 | 293.17 | clk_sys_mhz | 1.020x | 2:10 |
| 25 | PASS | 40.40 | 66.78 | 61.70 | 327.44 | 344.95 | clk_sys_mhz | 1.010x | 2:18 |
| 62 | PASS | 40.63 | 66.25 | 70.98 | 328.84 | 287.85 | clk_sys_mhz | 1.016x | 2:24 |
| 19 | PASS | 40.11 | 64.21 | 70.15 | 316.56 | 287.85 | clk_sys_mhz | 1.003x | 2:25 |
| 52 | PASS | 40.86 | 67.60 | 71.56 | 333.11 | 338.29 | clk_sys_mhz | 1.022x | 2:26 |
| 51 | PASS | 40.03 | 66.51 | 74.14 | 335.57 | 356.13 | clk_sys_mhz | 1.001x | 2:27 |
| 157 | PASS | 42.38 | 67.08 | 68.83 | 364.56 | 293.94 | clk_sys_mhz | 1.060x | 2:29 |
| 125 | PASS | 41.67 | 61.57 | 64.30 | 306.28 | 301.66 | litedram_user_mhz | 1.026x | 2:34 |
| 194 | PASS | 40.20 | 64.43 | 64.86 | 304.88 | 345.90 | clk_sys_mhz | 1.005x | 2:35 |
| 102 | PASS | 41.23 | 64.31 | 59.91 | 262.33 | 278.63 | clk_sys_mhz | 1.031x | 2:37 |
| 120 | PASS | 41.23 | 65.46 | 66.95 | 295.51 | 278.86 | clk_sys_mhz | 1.031x | 2:39 |
| 45 | PASS | 40.56 | 64.64 | 61.09 | 279.56 | 263.92 | clk_sys_mhz | 1.014x | 2:43 |
| 1 | PASS | 42.37 | 61.69 | 72.56 | 313.09 | 292.40 | litedram_user_mhz | 1.028x | 2:45 |
| 53 | PASS | 40.33 | 69.55 | 69.01 | 300.03 | 256.28 | clk_sys_mhz | 1.008x | 2:45 |
| 158 | PASS | 40.67 | 63.20 | 71.28 | 319.28 | 335.46 | clk_sys_mhz | 1.017x | 2:45 |
| 182 | PASS | 41.98 | 63.72 | 66.17 | 323.31 | 291.38 | clk_sys_mhz | 1.050x | 2:45 |
| 212 | PASS | 40.85 | 66.82 | 59.00 | 324.25 | 258.13 | clk_sys_mhz | 1.021x | 2:45 |
| 73 | PASS | 41.08 | 64.25 | 63.19 | 338.29 | 288.77 | clk_sys_mhz | 1.027x | 2:46 |
| 94 | PASS | 41.04 | 63.73 | 72.68 | 326.48 | 292.83 | clk_sys_mhz | 1.026x | 2:47 |

The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is
recomputed from the required clocks in the frozen sweep metadata.