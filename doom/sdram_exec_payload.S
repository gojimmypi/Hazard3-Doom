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
 *                  uint32_t seed)
 *
 * This routine is copied byte-for-byte from internal SRAM to SDRAM and called
 * through a function pointer. It intentionally has no absolute addresses, no
 * external references, and no PC-relative data references, so relocating the
 * complete start/end range preserves all internal branch offsets.
 */
sdram_exec_payload_start:
    mv t0, a2
    li t4, 0x9e3779b9

1:
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
    bnez a1, 1b

    mv a0, t0
    ret

sdram_exec_payload_end:
.size sdram_exec_payload_start, sdram_exec_payload_end - sdram_exec_payload_start
.option pop
