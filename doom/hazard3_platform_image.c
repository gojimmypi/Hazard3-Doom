#include <stddef.h>
#include <stdint.h>

#include "hazard3_platform.h"

static const hazard3_monitor_services_t* monitor_services;

void hazard3_monitor_services_bind(const hazard3_monitor_services_t* services)
{
    monitor_services = services;
}

void hazard3_console_putc(uint8_t value)
{
    if (monitor_services != (const hazard3_monitor_services_t*)0 &&
        monitor_services->console_putc != (void (*)(uint8_t))0) {
        monitor_services->console_putc(value);
    }
}

void hazard3_console_puts(const char* text)
{
    if (monitor_services != (const hazard3_monitor_services_t*)0 &&
        monitor_services->console_puts != (void (*)(const char*))0) {
        monitor_services->console_puts(text);
    }
}

void hazard3_console_put_hex32(uint32_t value)
{
    if (monitor_services != (const hazard3_monitor_services_t*)0 &&
        monitor_services->console_put_hex32 != (void (*)(uint32_t))0) {
        monitor_services->console_put_hex32(value);
    }
}

int hazard3_console_getc_nonblocking(uint8_t* value)
{
    if (monitor_services == (const hazard3_monitor_services_t*)0 ||
        monitor_services->console_getc_nonblocking == (int (*)(uint8_t*))0) {
        return 0;
    }
    return monitor_services->console_getc_nonblocking(value);
}

uint32_t hazard3_ticks_ms(void)
{
    if (monitor_services == (const hazard3_monitor_services_t*)0 ||
        monitor_services->ticks_ms == (uint32_t (*)(void))0) {
        return 0u;
    }
    return monitor_services->ticks_ms();
}

void hazard3_sleep_ms(uint32_t milliseconds)
{
    if (monitor_services != (const hazard3_monitor_services_t*)0 &&
        monitor_services->sleep_ms != (void (*)(uint32_t))0) {
        monitor_services->sleep_ms(milliseconds);
    }
}

void hazard3_memory_barrier(void)
{
    if (monitor_services != (const hazard3_monitor_services_t*)0 &&
        monitor_services->memory_barrier != (void (*)(void))0) {
        monitor_services->memory_barrier();
    }
}

uint32_t hazard3_doom_image_base(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->image_base : 0u;
}

uint32_t hazard3_doom_image_limit(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->image_limit : 0u;
}

uint32_t hazard3_video_base(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->video_base : 0u;
}

uint32_t hazard3_video_limit(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->video_limit : 0u;
}

uint32_t hazard3_screen_base(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->screen_base : 0u;
}

uint32_t hazard3_screen_bytes(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->screen_bytes : 0u;
}

uint32_t hazard3_wad_base(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->wad_base : 0u;
}

uint32_t hazard3_wad_limit(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->wad_limit : 0u;
}

uint32_t hazard3_wad_bytes(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->wad_bytes : 0u;
}

const char* hazard3_wad_name(void)
{
    return monitor_services != (const hazard3_monitor_services_t*)0 ?
        monitor_services->wad_name : (const char*)0;
}

void* hazard3_sbrk(ptrdiff_t increment)
{
    if (monitor_services == (const hazard3_monitor_services_t*)0 ||
        monitor_services->sbrk == (void* (*)(ptrdiff_t))0) {
        return (void*)(intptr_t)-1;
    }
    return monitor_services->sbrk(increment);
}

void* hazard3_heap_alloc(uint32_t byte_count)
{
    uint32_t aligned_count;
    void* allocation;
    if (byte_count == 0u || byte_count > UINT32_MAX - 15u) {
        return (void*)0;
    }
    aligned_count = (byte_count + 15u) & ~15u;
    allocation = hazard3_sbrk((ptrdiff_t)aligned_count);
    return allocation == (void*)(intptr_t)-1 ? (void*)0 : allocation;
}

void hazard3_heap_reset(void)
{
}

int hazard3_heap_is_active(void)
{
    return hazard3_heap_used() != 0u;
}

uint32_t hazard3_heap_used(void)
{
    void* current_break;
    if (monitor_services == (const hazard3_monitor_services_t*)0) {
        return 0u;
    }
    current_break = hazard3_sbrk(0);
    if (current_break == (void*)(intptr_t)-1) {
        return 0u;
    }
    return (uint32_t)(uintptr_t)current_break - monitor_services->heap_base;
}

uint32_t hazard3_heap_remaining(void)
{
    if (monitor_services == (const hazard3_monitor_services_t*)0) {
        return 0u;
    }
    return monitor_services->heap_limit - monitor_services->heap_base -
        hazard3_heap_used();
}
