.section .vectors, "ax"
.global _start
.type _start, @function

_start:
    csrci mstatus, 8
    csrw mie, zero

    // Hazard3 resets mcycle/minstret inhibited to save power. Enable both
    // counters before CoreMark starts; the benchmark uses mcycle for timing.
    csrci mcountinhibit, 0x5

    la sp, __stack_top

    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b

2:
    call main
3:
    j 3b
.size _start, . - _start

.section .coremark_diag.text, "ax"
.align 2
.global coremark_probe_trap
.type coremark_probe_trap, @function

// Temporary exception handler used only while portable_init probes optional
// CSRs. Interrupts remain disabled. An illegal CSR access is skipped and
// recorded; any unexpected trap stops here rather than masking a real fault.
coremark_probe_trap:
    addi sp, sp, -8
    sw t0, 0(sp)
    sw t1, 4(sp)

    csrr t0, mcause
    li t1, 2
    bne t0, t1, 4f

    la t0, coremark_probe_faulted
    li t1, 1
    sw t1, 0(t0)
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    lw t0, 0(sp)
    lw t1, 4(sp)
    addi sp, sp, 8
    mret
4:
    j 4b
.size coremark_probe_trap, . - coremark_probe_trap
