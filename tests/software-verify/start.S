/* -----------------------------------------------------------------------------
 * File:        start.S
 * Path:        tests/software-verify/start.S
 *
 * Project:     Hazard3-Doom
 * Purpose:     Provide the RISC-V startup entry point for the standalone software
 *              verification payload.
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

    .section .text.start, "ax", @progbits
    .align 2
    .globl _start
    .type _start, @function
_start:
    la      sp, __stack_top

    /* Keep the verifier deterministic: no timer or external interrupts. */
    csrci   mstatus, 8
    csrw    mie, zero

    la      t0, trap_entry
    csrw    mtvec, t0

    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    verify_main
3:
    wfi
    j       3b
    .size _start, .-_start

    .align 2
    .globl trap_entry
    .type trap_entry, @function
trap_entry:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    csrr    a0, mcause
    csrr    a1, mepc
    csrr    a2, mtval
    call    verify_trap
4:
    wfi
    j       4b
    .size trap_entry, .-trap_entry
