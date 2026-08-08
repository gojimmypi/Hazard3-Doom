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
