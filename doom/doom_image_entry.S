.section .text.doom_entry, "ax"
.align 2
.global _doom_start
.type _doom_start, @function

_doom_start:
    /* Preserve the monitor return address and global pointer. */
    addi sp, sp, -16
    sw ra, 12(sp)
    sw gp, 8(sp)
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    call doom_image_main
    lw gp, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

.size _doom_start, . - _doom_start
