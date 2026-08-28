/* -----------------------------------------------------------------------------
 * File:        sdram_exec_test.h
 * Path:        doom/sdram_exec_test.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare resident monitor SDRAM execution-test interfaces and
 *              status reporting.
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

#ifndef SDRAM_EXEC_TEST_H
#define SDRAM_EXEC_TEST_H

#include <stdint.h>

int sdram_exec_test_run(void);
void sdram_exec_test_note_timer_pc(uint32_t mepc);

uint32_t sdram_exec_test_runs(void);
uint32_t sdram_exec_test_failures(void);
uint32_t sdram_exec_test_last_elapsed_ms(void);
uint32_t sdram_exec_test_last_timer_hits(void);
uint32_t sdram_exec_test_last_result(void);
uint32_t sdram_exec_test_last_expected(void);
uint32_t sdram_exec_test_payload_bytes(void);
int sdram_exec_test_last_passed(void);

#endif
