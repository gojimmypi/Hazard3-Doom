/* -----------------------------------------------------------------------------
 * File:        doom_port_smoke.h
 * Path:        doom/doom_port_smoke.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare resident monitor Doom port smoke-test interfaces and
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

#ifndef DOOM_PORT_SMOKE_H
#define DOOM_PORT_SMOKE_H

#include <stdint.h>

int doom_port_smoke_run(void);
uint32_t doom_port_smoke_runs(void);
uint32_t doom_port_smoke_failures(void);
uint32_t doom_port_smoke_last_elapsed_ms(void);
uint32_t doom_port_smoke_last_heap_used(void);
int doom_port_smoke_last_passed(void);

#endif
