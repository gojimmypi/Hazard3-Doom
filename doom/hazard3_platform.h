#ifndef HAZARD3_PLATFORM_H
#define HAZARD3_PLATFORM_H

#include <stddef.h>
#include <stdint.h>

#include "hazard3_monitor_services.h"

void hazard3_monitor_services_bind(const hazard3_monitor_services_t* services);
void hazard3_console_putc(uint8_t value);
void hazard3_console_puts(const char* text);
void hazard3_console_put_hex32(uint32_t value);
int hazard3_console_getc_nonblocking(uint8_t* value);
void hazard3_console_input_capture_begin(void);
void hazard3_console_input_capture_end(void);
uint32_t hazard3_console_input_capture_received(void);
uint32_t hazard3_console_input_capture_overflows(void);
uint32_t hazard3_ticks_ms(void);
void hazard3_sleep_ms(uint32_t milliseconds);
void hazard3_memory_barrier(void);
uint32_t hazard3_doom_image_base(void);
uint32_t hazard3_doom_image_limit(void);
uint32_t hazard3_video_base(void);
uint32_t hazard3_video_limit(void);
uint32_t hazard3_screen_base(void);
uint32_t hazard3_screen_bytes(void);
uint32_t hazard3_wad_base(void);
uint32_t hazard3_wad_limit(void);
uint32_t hazard3_wad_bytes(void);
const char* hazard3_wad_name(void);
void* hazard3_sbrk(ptrdiff_t increment);
void* hazard3_heap_alloc(uint32_t byte_count);
void hazard3_heap_reset(void);
int hazard3_heap_is_active(void);
uint32_t hazard3_heap_used(void);
uint32_t hazard3_heap_remaining(void);

#endif
