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
    /* Preserve the monitor return address and global pointer. */
    addi sp, sp, -16
    sw ra, 12(sp)
    sw gp, 8(sp)

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
    lw gp, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

.size _doom_start, . - _doom_start

/*
 * Non-local fatal exit for the Doom image.
 *
 * a0 already contains the Doom exit status. Restore the exact monitor frame
 * saved by _doom_start and return directly to doom_image_loader_launch().
 * This deliberately avoids libc non-local-jump state and does not unwind Doom's C
 * stack. If called before _doom_start arms the saved frame, park safely.
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
    lw gp, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

.Ldoom_exit_park:
    wfi
    j .Ldoom_exit_park

.size hazard3_image_exit, . - hazard3_image_exit
