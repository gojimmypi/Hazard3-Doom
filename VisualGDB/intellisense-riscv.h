/* -----------------------------------------------------------------------------
 * File:        intellisense-riscv.h
 * Path:        VisualGDB/intellisense-riscv.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     IntelliSense-only compatibility header for the Hazard3 RISC-V NMake wrapper.
 *
 *              This file is forced-included by Visual Studio IntelliSense only. The real
 *              firmware build is still performed by scripts/build-xpack.cmd with the xPack
 *              riscv-none-elf GCC toolchain and never consumes this file.
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

#pragma once

#include <stddef.h>
#include <stdint.h>

/* Preserve the target identity used by project source conditionals. */
#ifndef __riscv
#define __riscv 1
#endif
#ifndef __riscv_xlen
#define __riscv_xlen 32
#endif
#ifndef __riscv_float_abi_soft
#define __riscv_float_abi_soft 1
#endif
#ifndef __riscv_compressed
#define __riscv_compressed 1
#endif

/* Common GCC spelling accepted by the real compiler but not needed by VS. */
#ifndef __attribute__
#define __attribute__(x)
#endif
#ifndef __extension__
#define __extension__
#endif
#ifndef __builtin_expect
#define __builtin_expect(x, y) (x)
#endif
#ifndef __builtin_constant_p
#define __builtin_constant_p(x) 0
#endif
#ifndef __builtin_unreachable
#define __builtin_unreachable() ((void)0)
#endif

/*
 * MSVC IntelliSense does not understand GCC extended inline-assembly syntax:
 *
 *     __asm__ volatile ("..." ::: "memory");
 *
 * This header is never used by the real RISC-V build, so for IntelliSense
 * only, discard the __asm__ token and turn the following function-like
 * volatile(...) token sequence into a harmless no-op. Normal declarations
 * such as "volatile uint32_t" are unaffected because this macro expands only
 * when volatile is immediately followed by '('.
 */
#ifndef __GNUC__
#define __asm__
#define volatile(...) ((void)0)
#endif
