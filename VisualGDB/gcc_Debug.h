/* -----------------------------------------------------------------------------
 * File:        gcc_Debug.h
 * Path:        VisualGDB/gcc_Debug.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     IntelliSense-only compatibility header for the Hazard3 RISC-V NMake wrapper.
 *
 *              This file is only used by Coding Assistance tools
 *              DO NOT INCLUDE THIS FILE FROM YOUR ACTUAL SOURCE FILES.
 *              This file lists the preprocessor macros extracted from your GCC.
 *              It is needed for Coding Assistance tools to parse other header files correctly.
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

#if defined(_MSC_VER) || defined (__SYSPROGS_CODESENSE__)
#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Wreserved-id-macro"
#endif
#pragma clang diagnostic pop
