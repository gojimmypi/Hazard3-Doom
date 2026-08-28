/* -----------------------------------------------------------------------------
 * File:        sdram_exec_payload.S
 * Path:        doom/sdram_exec_payload.S
 *
 * Project:     Hazard3-Doom
 * Purpose:     Provide a relocatable RISC-V payload used to execute and stress-
 *              test code from SDRAM.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the Apache License, Version 2.0.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * This software is provided under the terms of the applicable license.
 * See LICENSES/Apache-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

.section .text.sdram_exec_payload, "ax", @progbits
.align 2
.option push
.option norvc

.global sdram_exec_payload_start
.global sdram_exec_payload_end
.type sdram_exec_payload_start, @function
/*
 * uint32_t payload(volatile uint32_t* scratch,
 *                  uint32_t iteration_count,
 *                  uint32_t seed,
 *                  uint32_t foreign_gp_base)
 *
 * This routine is copied byte-for-byte from internal SRAM to SDRAM and called
 * through a function pointer. It intentionally has no absolute addresses, no
 * external references, and no PC-relative data references, so relocating the
 * complete start/end range preserves all internal branch offsets.
 *
 * If foreign_gp_base is nonzero, install gp at the center of that 4 KiB
 * sacrificial window for the duration of the arithmetic
 * loop. This deliberately exposes timer/trap code that incorrectly assumes the
 * interrupted program is using the monitor's gp. The original gp is always
 * restored before returning to the monitor.
 */
sdram_exec_payload_start:
    addi sp, sp, -16
    sw gp, 12(sp)
    beqz a3, 1f
    li t3, 0x800
    add gp, a3, t3
1:
    mv t0, a2
    li t4, 0x9e3779b9
2:
    slli t1, t0, 13
    xor t0, t0, t1
    srli t1, t0, 17
    xor t0, t0, t1
    slli t1, t0, 5
    xor t0, t0, t1

    sw t0, 0(a0)
    lw t2, 0(a0)
    add t2, t2, t4
    xor t0, t0, t2

    addi a1, a1, -1
    bnez a1, 2b

    mv a0, t0
    lw gp, 12(sp)
    addi sp, sp, 16
    ret

sdram_exec_payload_end:
.size sdram_exec_payload_start, sdram_exec_payload_end - sdram_exec_payload_start
.option pop
