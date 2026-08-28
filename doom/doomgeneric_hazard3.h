/* -----------------------------------------------------------------------------
 * File:        doomgeneric_hazard3.h
 * Path:        doom/doomgeneric_hazard3.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Declare Hazard3-Doom DoomGeneric backend status, timing, and input
 *              interfaces.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the GNU General Public License, version 2 or later.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * This software is provided WITHOUT ANY WARRANTY.
 * See LICENSES/GPL-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

#ifndef DOOMGENERIC_HAZARD3_H
#define DOOMGENERIC_HAZARD3_H

#include <stdint.h>

#define HAZARD3_DOOM_IMAGE_BUILD_ID 0x44335235u
#define HAZARD3_DOOM_IMAGE_BUILD_NAME \
    "H3-Doom-Performance-R5-20260716"

uint32_t hazard3_doom_draw_frame_count(void);
uint32_t hazard3_doom_last_copy_cycles(void);
uint32_t hazard3_doom_last_present_cycles(void);
uint32_t hazard3_doom_copy_cycles_total(void);
uint32_t hazard3_doom_present_cycles_total(void);
void hazard3_doom_screen_snip_cache(void);
void hazard3_doom_input_reset(void);
int hazard3_doom_exit_requested(void);

#endif
