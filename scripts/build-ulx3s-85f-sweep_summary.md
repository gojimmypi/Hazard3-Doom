# ulx3s-85f seed sweep summary

From: https://github.com/gojimmypi/Hazard3-Doom/actions/runs/33443050599/job/99745412024

- Synthesis duration: 1:01 (61 seconds)
- Seeds expected: 260
- Routes completed: 256
- Timed-out seeds: 4
- TIMEOUT seed values: 66, 149, 212, 252
- Timing-passing seeds: 46
- PASS seed values: 11, 16, 19, 34, 35, 40, 41, 43, 49, 51, 54, 57, 60, 62, 63, 68, 81, 91, 103, 114, 116, 120, 121, 136, 140, 141, 144, 146, 147, 150, 153, 158, 176, 182, 193, 202, 206, 217, 227, 231, 248, 249, 256, 257, 258, 260
- Best combined-margin PASS seed: 150
- Fastest timing-passing seed: 147
- Completed routes with timing failure: 210
- Route/tool failures: 0
- Missing seed results: 0

## Required clocks

- clk_sys: 50.00 MHz
- video pixel: 50.00 MHz
- TMDS x5: 250.00 MHz

## Per-clock closure

- clk_sys: 47/256
- video pixel: 256/256
- TMDS x5: 256/256

## Workflow configuration

- heap_critexp: 2
- heap_timingweight: 10
- max_parallel: 20
- netlist: third_party/Hazard3/example_soc/synth/fpga_ulx3s.json
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
- sweep_dir: build/ulx3s-seed-sweep
- synth_oss_cad_suite_version: 2026-07-20
- target: ulx3s-85f
- tmg_ripup: false
- ulx3s_12f_memory_profile: 32m
- ulx3s_85f_extended_modes: 1
- ulx4m_litedram_cpu: serv
- ulx4m_sys_clk_mhz: 40

## Closest to full timing closure

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 150 | PASS | 53.35 | 78.85 | 375.09 | clk_sys_mhz | 1.067x | 55:05 |
| 257 | PASS | 52.82 | 69.45 | 303.58 | clk_sys_mhz | 1.056x | 25:08 |
| 40 | PASS | 52.79 | 74.31 | 323.00 | clk_sys_mhz | 1.056x | 45:14 |
| 231 | PASS | 52.53 | 80.37 | 342.11 | clk_sys_mhz | 1.051x | 16:46 |
| 103 | PASS | 52.30 | 76.41 | 320.31 | clk_sys_mhz | 1.046x | 1:06:57 |
| 11 | PASS | 52.24 | 72.96 | 342.47 | clk_sys_mhz | 1.045x | 3:53 |
| 217 | PASS | 52.06 | 71.85 | 333.00 | clk_sys_mhz | 1.041x | 8:14 |
| 136 | PASS | 52.00 | 72.33 | 303.58 | clk_sys_mhz | 1.040x | 17:32 |
| 62 | PASS | 51.89 | 74.59 | 366.57 | clk_sys_mhz | 1.038x | 1:31:07 |
| 146 | PASS | 51.89 | 82.57 | 371.33 | clk_sys_mhz | 1.038x | 39:42 |
| 202 | PASS | 51.86 | 78.28 | 362.45 | clk_sys_mhz | 1.037x | 11:20 |
| 121 | PASS | 51.79 | 76.82 | 285.55 | clk_sys_mhz | 1.036x | 6:53 |
| 158 | PASS | 51.78 | 73.64 | 281.29 | clk_sys_mhz | 1.036x | 12:12 |
| 116 | PASS | 51.66 | 86.37 | 378.36 | clk_sys_mhz | 1.033x | 3:03 |
| 176 | PASS | 51.57 | 74.16 | 324.57 | clk_sys_mhz | 1.031x | 13:57 |
| 120 | PASS | 51.56 | 81.57 | 378.64 | clk_sys_mhz | 1.031x | 3:40 |
| 68 | PASS | 51.46 | 72.24 | 303.95 | clk_sys_mhz | 1.029x | 15:48 |
| 258 | PASS | 51.31 | 79.77 | 352.49 | clk_sys_mhz | 1.026x | 15:37 |
| 19 | PASS | 51.27 | 81.07 | 370.78 | clk_sys_mhz | 1.025x | 4:14 |
| 182 | PASS | 51.17 | 71.13 | 311.72 | clk_sys_mhz | 1.023x | 5:58 |

## Timing-passing seeds by combined margin

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 150 | PASS | 53.35 | 78.85 | 375.09 | clk_sys_mhz | 1.067x | 55:05 |
| 257 | PASS | 52.82 | 69.45 | 303.58 | clk_sys_mhz | 1.056x | 25:08 |
| 40 | PASS | 52.79 | 74.31 | 323.00 | clk_sys_mhz | 1.056x | 45:14 |
| 231 | PASS | 52.53 | 80.37 | 342.11 | clk_sys_mhz | 1.051x | 16:46 |
| 103 | PASS | 52.30 | 76.41 | 320.31 | clk_sys_mhz | 1.046x | 1:06:57 |
| 11 | PASS | 52.24 | 72.96 | 342.47 | clk_sys_mhz | 1.045x | 3:53 |
| 217 | PASS | 52.06 | 71.85 | 333.00 | clk_sys_mhz | 1.041x | 8:14 |
| 136 | PASS | 52.00 | 72.33 | 303.58 | clk_sys_mhz | 1.040x | 17:32 |
| 62 | PASS | 51.89 | 74.59 | 366.57 | clk_sys_mhz | 1.038x | 1:31:07 |
| 146 | PASS | 51.89 | 82.57 | 371.33 | clk_sys_mhz | 1.038x | 39:42 |
| 202 | PASS | 51.86 | 78.28 | 362.45 | clk_sys_mhz | 1.037x | 11:20 |
| 121 | PASS | 51.79 | 76.82 | 285.55 | clk_sys_mhz | 1.036x | 6:53 |
| 158 | PASS | 51.78 | 73.64 | 281.29 | clk_sys_mhz | 1.036x | 12:12 |
| 116 | PASS | 51.66 | 86.37 | 378.36 | clk_sys_mhz | 1.033x | 3:03 |
| 176 | PASS | 51.57 | 74.16 | 324.57 | clk_sys_mhz | 1.031x | 13:57 |
| 120 | PASS | 51.56 | 81.57 | 378.64 | clk_sys_mhz | 1.031x | 3:40 |
| 68 | PASS | 51.46 | 72.24 | 303.95 | clk_sys_mhz | 1.029x | 15:48 |
| 258 | PASS | 51.31 | 79.77 | 352.49 | clk_sys_mhz | 1.026x | 15:37 |
| 19 | PASS | 51.27 | 81.07 | 370.78 | clk_sys_mhz | 1.025x | 4:14 |
| 182 | PASS | 51.17 | 71.13 | 311.72 | clk_sys_mhz | 1.023x | 5:58 |

## Fastest timing-passing seeds

| Seed | Result | clk_sys | video pixel | TMDS x5 | Limiting | Worst ratio | Route time |
| ---: | :---: | ---: | ---: | ---: | :--- | ---: | ---: |
| 147 | PASS | 50.24 | 79.67 | 400.16 | clk_sys_mhz | 1.005x | 2:49 |
| 116 | PASS | 51.66 | 86.37 | 378.36 | clk_sys_mhz | 1.033x | 3:03 |
| 120 | PASS | 51.56 | 81.57 | 378.64 | clk_sys_mhz | 1.031x | 3:40 |
| 11 | PASS | 52.24 | 72.96 | 342.47 | clk_sys_mhz | 1.045x | 3:53 |
| 19 | PASS | 51.27 | 81.07 | 370.78 | clk_sys_mhz | 1.025x | 4:14 |
| 193 | PASS | 50.25 | 87.25 | 378.36 | clk_sys_mhz | 1.005x | 4:56 |
| 256 | PASS | 50.02 | 82.97 | 392.93 | clk_sys_mhz | 1.000x | 4:56 |
| 140 | PASS | 50.84 | 71.42 | 320.92 | clk_sys_mhz | 1.017x | 5:12 |
| 16 | PASS | 50.60 | 71.97 | 291.04 | clk_sys_mhz | 1.012x | 5:28 |
| 91 | PASS | 50.65 | 84.18 | 388.80 | clk_sys_mhz | 1.013x | 5:43 |
| 182 | PASS | 51.17 | 71.13 | 311.72 | clk_sys_mhz | 1.023x | 5:58 |
| 121 | PASS | 51.79 | 76.82 | 285.55 | clk_sys_mhz | 1.036x | 6:53 |
| 217 | PASS | 52.06 | 71.85 | 333.00 | clk_sys_mhz | 1.041x | 8:14 |
| 248 | PASS | 50.79 | 84.22 | 320.92 | clk_sys_mhz | 1.016x | 8:33 |
| 144 | PASS | 50.07 | 80.48 | 381.53 | clk_sys_mhz | 1.001x | 8:40 |
| 49 | PASS | 50.05 | 73.31 | 352.49 | clk_sys_mhz | 1.001x | 9:42 |
| 35 | PASS | 51.06 | 78.76 | 344.71 | clk_sys_mhz | 1.021x | 9:44 |
| 202 | PASS | 51.86 | 78.28 | 362.45 | clk_sys_mhz | 1.037x | 11:20 |
| 158 | PASS | 51.78 | 73.64 | 281.29 | clk_sys_mhz | 1.036x | 12:12 |
| 176 | PASS | 51.57 | 74.16 | 324.57 | clk_sys_mhz | 1.031x | 13:57 |

The complete per-seed data is in `summary.csv`. Timing PASS/FAIL is
recomputed from the required clocks in the frozen sweep metadata.