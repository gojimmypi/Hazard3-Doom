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
void hazard3_doom_input_reset(void);
int hazard3_doom_exit_requested(void);

#endif
