/* -----------------------------------------------------------------------------
 * File:        doom_image_entry.S
 * Path:        doom/doom_image_entry.S
 *
 * Project:     Hazard3-Doom
 * Purpose:     Provide the RISC-V entry point that transfers monitor services
 *              into the Doom image runtime.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the GNU General Public License, version 2 or later.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * This software is provided WITHOUT ANY WARRANTY.
 * See LICENSES/GPL-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

.section .bss.doom_entry, "aw", @nobits
.align 2
.type doom_monitor_frame_sp, @object
doom_monitor_frame_sp:
    .word 0
.size doom_monitor_frame_sp, . - doom_monitor_frame_sp

.section .text.doom_entry, "ax"
.align 2
.global _doom_start
.type _doom_start, @function

_doom_start:
    /*
     * Preserve the complete monitor-side callee-saved register set. A normal
     * C return would restore these registers one frame at a time, but
     * hazard3_image_exit deliberately skips every active Doom frame.
     */
    addi sp, sp, -64
    sw ra, 60(sp)
    sw gp, 56(sp)
    sw s0, 52(sp)
    sw s1, 48(sp)
    sw s2, 44(sp)
    sw s3, 40(sp)
    sw s4, 36(sp)
    sw s5, 32(sp)
    sw s6, 28(sp)
    sw s7, 24(sp)
    sw s8, 20(sp)
    sw s9, 16(sp)
    sw s10, 12(sp)
    sw s11, 8(sp)

    /* Remember this exact frame so a fatal Doom exit can return to monitor. */
    .option push
    .option norelax
    la t0, doom_monitor_frame_sp
    .option pop
    sw sp, 0(t0)

    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    call doom_image_main

    /* Normal return: disarm fatal-exit recovery before restoring the monitor. */
    .option push
    .option norelax
    la t0, doom_monitor_frame_sp
    .option pop
    sw zero, 0(t0)
    lw s11, 8(sp)
    lw s10, 12(sp)
    lw s9, 16(sp)
    lw s8, 20(sp)
    lw s7, 24(sp)
    lw s6, 28(sp)
    lw s5, 32(sp)
    lw s4, 36(sp)
    lw s3, 40(sp)
    lw s2, 44(sp)
    lw s1, 48(sp)
    lw s0, 52(sp)
    lw gp, 56(sp)
    lw ra, 60(sp)
    addi sp, sp, 64
    ret

.size _doom_start, . - _doom_start

/*
 * Non-local fatal exit for the Doom image.
 *
 * a0 already contains the Doom exit status. Restore the exact monitor frame
 * saved by _doom_start and return directly to doom_image_loader_launch().
 * This deliberately avoids libc non-local-jump state and does not unwind Doom's
 * C stack, so it must restore every monitor-side callee-saved register itself.
 * If called before _doom_start arms the saved frame, park safely.
 */
.align 2
.global hazard3_image_exit
.type hazard3_image_exit, @function
hazard3_image_exit:
    .option push
    .option norelax
    la t0, doom_monitor_frame_sp
    .option pop
    lw t1, 0(t0)
    beqz t1, .Ldoom_exit_park
    sw zero, 0(t0)
    mv sp, t1
    lw s11, 8(sp)
    lw s10, 12(sp)
    lw s9, 16(sp)
    lw s8, 20(sp)
    lw s7, 24(sp)
    lw s6, 28(sp)
    lw s5, 32(sp)
    lw s4, 36(sp)
    lw s3, 40(sp)
    lw s2, 44(sp)
    lw s1, 48(sp)
    lw s0, 52(sp)
    lw gp, 56(sp)
    lw ra, 60(sp)
    addi sp, sp, 64
    ret

.Ldoom_exit_park:
    wfi
    j .Ldoom_exit_park

.size hazard3_image_exit, . - hazard3_image_exit
