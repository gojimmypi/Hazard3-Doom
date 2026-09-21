/* -----------------------------------------------------------------------------
 * File:        bootstrap-12f.S
 * Path:        src/bootstrap-12f.S
 *
 * Project:     Hazard3-Doom
 * Purpose:     Provide a minimal UART-visible cold-boot stub for ULX3S 12F.
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

    .equ UART_BASE,          0x40004000
    .equ UART_CSR_ENABLE,    0x00000001
    .equ UART_DIV_X16_40MHZ, 694
    .equ UART_FSTAT_TX_FULL, 0x00000100

    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function
_start:
    li      t0, UART_BASE
    li      t1, UART_DIV_X16_40MHZ
    sw      t1, 4(t0)
    li      t1, UART_CSR_ENABLE
    sw      t1, 0(t0)

    la      t1, bootstrap_message
1:
    lbu     t2, 0(t1)
    beqz    t2, 3f
2:
    lw      t3, 8(t0)
    andi    t3, t3, UART_FSTAT_TX_FULL
    bnez    t3, 2b
    sw      t2, 12(t0)
    addi    t1, t1, 1
    j       1b

3:
    /* GDB/OpenOCD replaces this bootstrap by loading the full monitor to SDRAM. */
    j       3b
    .size _start, . - _start

    .section .rodata, "a", @progbits
bootstrap_message:
    .asciz "\r\nHazard3-Doom ULX3S 12F bootstrap\r\nUART: 115200 8N1\r\nFPGA configured; full monitor is SDRAM-resident.\r\nRun ./scripts/load-firmware-12f.sh from the repository root.\r\nWaiting for monitor load...\r\n"
