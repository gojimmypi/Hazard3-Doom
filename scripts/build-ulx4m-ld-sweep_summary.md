# ulx4m-ld-85f seed sweep summary

From: https://github.com/gojimmypi/Hazard3-Doom/actions/runs/33827152284/job/100892326473

- Synthesis duration: 1:16 (76 seconds)
- Seeds expected: 260
- Routes completed: 260
- Timed-out seeds: 0
- TIMEOUT seed values: none
- Timing-passing seeds: 167
- PASS seed values: 2, 4, 5, 6, 8, 9, 10, 11, 13, 14, 16, 19, 21, 23, 24, 25, 28, 29, 30, 31, 33, 35, 41, 42, 43, 44, 45, 46, 47, 48, 49, 51, 53, 54, 57, 58, 61, 62, 66, 67, 68, 69, 71, 72, 73, 74, 75, 79, 80, 81, 82, 83, 84, 85, 86, 88, 89, 90, 91, 92, 93, 95, 96, 97, 99, 106, 107, 109, 110, 111, 112, 113, 114, 115, 117, 118, 120, 122, 123, 124, 126, 127, 130, 132, 133, 134, 135, 137, 139, 140, 142, 147, 148, 149, 150, 153, 154, 155, 156, 157, 158, 159, 161, 162, 166, 167, 168, 169, 170, 171, 174, 175, 176, 177, 179, 181, 182, 183, 184, 185, 186, 187, 188, 189, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 203, 206, 208, 209, 210, 212, 214, 215, 216, 218, 219, 220, 224, 226, 227, 228, 232, 233, 235, 236, 237, 238, 239, 242, 245, 246, 248, 250, 252, 253, 254, 258, 260
- Best combined-margin PASS seed: 45
- Fastest timing-passing seed: 49
- Completed routes with timing failure: 93
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 40.00 MHz
- LiteDRAM user: 60.01 MHz
- video pixel: 50.00 MHz
- TMDS x5: 250.00 MHz
- init_clk: 25.00 MHz

## Per-clock closure

- clk_sys: 172/260
- LiteDRAM user: 249/260
- video pixel: 260/260
- TMDS x5: 260/260
- init_clk: 260/260

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 30
- max_parallel: 20
- netlist: third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.json
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
- sweep_dir: third_party/Hazard3/example_soc/synth/routing-sweep/ulx4m-ld-40mhz-serv-tw30
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx4m-ld-85f
- tmg_ripup: false
- ulx3s_12f_memory_profile: 32m
- ulx3s_85f_extended_modes: 1
- ulx4m_litedram_cpu: serv
- ulx4m_sys_clk_mhz: 40

## Closest to full timing closure

| Seed | Result | clk_sys | LiteDRAM user | video pixel | TMDS x5 | init_clk | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 45 | PASS | 44.31 | 65.90 | 69.19 | 335.57 | 288.60 | litedram_user_mhz | 1.098x | 5:17 |
| 83 | PASS | 43.63 | 67.51 | 70.90 | 332.01 | 351.12 | clk_sys_mhz | 1.091x | 2:26 |
| 75 | PASS | 43.43 | 67.79 | 71.94 | 306.00 | 297.89 | clk_sys_mhz | 1.086x | 2:50 |
| 239 | PASS | 43.18 | 66.54 | 60.40 | 305.72 | 336.47 | clk_sys_mhz | 1.079x | 2:54 |
| 92 | PASS | 43.16 | 67.63 | 64.13 | 346.74 | 273.37 | clk_sys_mhz | 1.079x | 3:05 |
| 170 | PASS | 43.15 | 69.04 | 70.27 | 320.31 | 328.95 | clk_sys_mhz | 1.079x | 3:34 |
| 74 | PASS | 43.06 | 69.84 | 66.05 | 312.99 | 338.64 | clk_sys_mhz | 1.077x | 2:48 |
| 62 | PASS | 43.05 | 65.18 | 64.28 | 303.58 | 280.03 | clk_sys_mhz | 1.076x | 2:32 |
| 66 | PASS | 42.83 | 71.28 | 63.71 | 291.97 | 265.53 | clk_sys_mhz | 1.071x | 3:28 |
| 142 | PASS | 42.79 | 67.77 | 72.37 | 269.69 | 293.69 | clk_sys_mhz | 1.070x | 2:32 |
| 16 | PASS | 42.76 | 65.61 | 61.33 | 313.77 | 281.45 | clk_sys_mhz | 1.069x | 3:22 |
| 58 | PASS | 42.71 | 69.18 | 70.14 | 333.44 | 343.17 | clk_sys_mhz | 1.068x | 2:29 |
| 216 | PASS | 42.74 | 64.07 | 61.02 | 333.44 | 344.12 | litedram_user_mhz | 1.068x | 3:21 |
| 186 | PASS | 42.70 | 65.54 | 60.31 | 321.34 | 286.29 | clk_sys_mhz | 1.067x | 3:03 |
| 46 | PASS | 42.69 | 68.08 | 68.22 | 308.74 | 270.12 | clk_sys_mhz | 1.067x | 3:32 |
| 210 | PASS | 42.67 | 66.64 | 61.33 | 340.25 | 279.72 | clk_sys_mhz | 1.067x | 5:19 |
| 215 | PASS | 42.67 | 69.41 | 68.84 | 356.13 | 310.95 | clk_sys_mhz | 1.067x | 4:25 |
| 132 | PASS | 42.66 | 67.99 | 66.72 | 315.06 | 306.84 | clk_sys_mhz | 1.067x | 2:56 |
| 183 | PASS | 42.73 | 63.89 | 68.80 | 349.53 | 356.38 | litedram_user_mhz | 1.065x | 4:45 |
| 219 | PASS | 42.54 | 64.12 | 73.49 | 370.23 | 329.16 | clk_sys_mhz | 1.063x | 3:00 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | LiteDRAM user | video pixel | TMDS x5 | init_clk | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 45 | PASS | 44.31 | 65.90 | 69.19 | 335.57 | 288.60 | litedram_user_mhz | 1.098x | 5:17 |
| 83 | PASS | 43.63 | 67.51 | 70.90 | 332.01 | 351.12 | clk_sys_mhz | 1.091x | 2:26 |
| 75 | PASS | 43.43 | 67.79 | 71.94 | 306.00 | 297.89 | clk_sys_mhz | 1.086x | 2:50 |
| 239 | PASS | 43.18 | 66.54 | 60.40 | 305.72 | 336.47 | clk_sys_mhz | 1.079x | 2:54 |
| 92 | PASS | 43.16 | 67.63 | 64.13 | 346.74 | 273.37 | clk_sys_mhz | 1.079x | 3:05 |
| 170 | PASS | 43.15 | 69.04 | 70.27 | 320.31 | 328.95 | clk_sys_mhz | 1.079x | 3:34 |
| 74 | PASS | 43.06 | 69.84 | 66.05 | 312.99 | 338.64 | clk_sys_mhz | 1.077x | 2:48 |
| 62 | PASS | 43.05 | 65.18 | 64.28 | 303.58 | 280.03 | clk_sys_mhz | 1.076x | 2:32 |
| 66 | PASS | 42.83 | 71.28 | 63.71 | 291.97 | 265.53 | clk_sys_mhz | 1.071x | 3:28 |
| 142 | PASS | 42.79 | 67.77 | 72.37 | 269.69 | 293.69 | clk_sys_mhz | 1.070x | 2:32 |
| 16 | PASS | 42.76 | 65.61 | 61.33 | 313.77 | 281.45 | clk_sys_mhz | 1.069x | 3:22 |
| 58 | PASS | 42.71 | 69.18 | 70.14 | 333.44 | 343.17 | clk_sys_mhz | 1.068x | 2:29 |
| 216 | PASS | 42.74 | 64.07 | 61.02 | 333.44 | 344.12 | litedram_user_mhz | 1.068x | 3:21 |
| 186 | PASS | 42.70 | 65.54 | 60.31 | 321.34 | 286.29 | clk_sys_mhz | 1.067x | 3:03 |
| 46 | PASS | 42.69 | 68.08 | 68.22 | 308.74 | 270.12 | clk_sys_mhz | 1.067x | 3:32 |
| 210 | PASS | 42.67 | 66.64 | 61.33 | 340.25 | 279.72 | clk_sys_mhz | 1.067x | 5:19 |
| 215 | PASS | 42.67 | 69.41 | 68.84 | 356.13 | 310.95 | clk_sys_mhz | 1.067x | 4:25 |
| 132 | PASS | 42.66 | 67.99 | 66.72 | 315.06 | 306.84 | clk_sys_mhz | 1.067x | 2:56 |
| 183 | PASS | 42.73 | 63.89 | 68.80 | 349.53 | 356.38 | litedram_user_mhz | 1.065x | 4:45 |
| 219 | PASS | 42.54 | 64.12 | 73.49 | 370.23 | 329.16 | clk_sys_mhz | 1.063x | 3:00 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | LiteDRAM user | video pixel | TMDS x5 | init_clk | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 49 | PASS | 42.12 | 61.78 | 57.74 | 301.93 | 285.39 | litedram_user_mhz | 1.029x | 1:59 |
| 6 | PASS | 40.65 | 61.92 | 66.93 | 307.22 | 333.11 | clk_sys_mhz | 1.016x | 2:11 |
| 11 | PASS | 43.86 | 63.30 | 57.86 | 292.48 | 283.85 | litedram_user_mhz | 1.055x | 2:15 |
| 5 | PASS | 41.28 | 69.53 | 71.07 | 284.41 | 280.35 | clk_sys_mhz | 1.032x | 2:20 |
| 107 | PASS | 41.03 | 67.06 | 60.96 | 296.12 | 321.44 | clk_sys_mhz | 1.026x | 2:20 |
| 235 | PASS | 40.77 | 69.39 | 71.05 | 300.48 | 303.49 | clk_sys_mhz | 1.019x | 2:20 |
| 236 | PASS | 41.69 | 60.88 | 58.98 | 298.42 | 292.91 | litedram_user_mhz | 1.014x | 2:20 |
| 83 | PASS | 43.63 | 67.51 | 70.90 | 332.01 | 351.12 | clk_sys_mhz | 1.091x | 2:26 |
| 58 | PASS | 42.71 | 69.18 | 70.14 | 333.44 | 343.17 | clk_sys_mhz | 1.068x | 2:29 |
| 61 | PASS | 42.27 | 65.49 | 70.01 | 343.64 | 300.75 | clk_sys_mhz | 1.057x | 2:30 |
| 162 | PASS | 42.32 | 64.87 | 68.74 | 305.53 | 299.49 | clk_sys_mhz | 1.058x | 2:30 |
| 62 | PASS | 43.05 | 65.18 | 64.28 | 303.58 | 280.03 | clk_sys_mhz | 1.076x | 2:32 |
| 142 | PASS | 42.79 | 67.77 | 72.37 | 269.69 | 293.69 | clk_sys_mhz | 1.070x | 2:32 |
| 57 | PASS | 41.15 | 67.35 | 58.58 | 313.97 | 274.27 | clk_sys_mhz | 1.029x | 2:33 |
| 8 | PASS | 42.30 | 65.69 | 65.73 | 280.03 | 281.06 | clk_sys_mhz | 1.058x | 2:34 |
| 252 | PASS | 43.42 | 62.70 | 71.32 | 333.78 | 360.62 | litedram_user_mhz | 1.045x | 2:34 |
| 134 | PASS | 41.69 | 61.91 | 71.74 | 308.26 | 321.96 | litedram_user_mhz | 1.032x | 2:36 |
| 156 | PASS | 42.57 | 60.85 | 71.26 | 308.07 | 353.86 | litedram_user_mhz | 1.014x | 2:38 |
| 126 | PASS | 41.22 | 64.17 | 60.29 | 312.40 | 321.23 | clk_sys_mhz | 1.030x | 2:39 |
| 159 | PASS | 41.26 | 65.31 | 58.10 | 307.50 | 255.95 | clk_sys_mhz | 1.032x | 2:39 |
