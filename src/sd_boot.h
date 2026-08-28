/* -----------------------------------------------------------------------------
 * File:        sd_boot.h
 * Path:        src/sd_boot.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare the resident monitor SD boot interface and status
 *              reporting.
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

#ifndef HAZARD3_SD_BOOT_H
#define HAZARD3_SD_BOOT_H

int hazard3_sd_boot(int launch_after_load);
void hazard3_sd_boot_print_status(void);

#endif
