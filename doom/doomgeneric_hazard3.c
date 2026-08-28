/* -----------------------------------------------------------------------------
 * File:        doomgeneric_hazard3.c
 * Path:        doom/doomgeneric_hazard3.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement the DoomGeneric video, palette, timing, and input
 *              backend for Hazard3-Doom.
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

#include <stdint.h>

#include "doomgeneric.h"
#include "doomgeneric_hazard3.h"
#include "doomkeys.h"
#include "hazard3_platform.h"
#include "hazard3_video.h"
#include "i_video.h"

#ifndef CMAP256
#error "The Hazard3 HDMI path requires Doomgeneric CMAP256 output"
#endif

#define HAZARD3_VIDEO_WORDS (HAZARD3_VIDEO_FRAMEBUFFER_BYTES / 4u)
#define HAZARD3_VIDEO_PRESENT_TIMEOUT_MS 1000u
#define HAZARD3_UART_KEY_HOLD_MS 120u
#define HAZARD3_ESCAPE_SEQUENCE_TIMEOUT_MS 40u
#define HAZARD3_SCREEN_SNIP_CAPABILITY_REQUEST 0x1cu
#define HAZARD3_SCREEN_SNIP_CAPABILITY_ACK 0x06u
#define HAZARD3_SCREEN_SNIP_REQUEST 0x1du
#define HAZARD3_SCREEN_SNIP_HEADER_STANDARD \
    "\r\nH3SNIP1 320 200 1024 600 IDX8 256 64000\r\n"
#define HAZARD3_SCREEN_SNIP_HEADER_HIGH \
    "\r\nH3SNIP1 400 240 1024 600 IDX8 256 96000\r\n"

static uint32_t draw_frame_count;
static uint32_t back_buffer_index;
static uint32_t palette_bank_valid_mask;
static int video_available;
static int direct_video_available;
static int video_failure_reported;
static uint32_t copy_cycles_total;
static uint32_t present_cycles_total;
static uint32_t last_copy_cycles;
static uint32_t last_present_cycles;

// UART terminals do not provide key-up events. Each recognized character
// holds the corresponding Doom key for a short real-time interval. This makes
// one character visible even during long render loops and lets auto-repeat
// continuous movement without overflowing the two-byte hardware FIFO.
static int key_release_pending;
static unsigned char key_release_code;
static uint32_t key_release_deadline_ms;
static int stop_input_scan;
static int exit_requested;
static int input_activity_reported;
static uint8_t escape_sequence_state;
static uint32_t escape_sequence_deadline_ms;
static uint8_t deferred_character;
static int deferred_character_valid;
static int screen_snip_requested;

static uint32_t read_cycle_counter(void)
{
    uint32_t cycles;
    __asm__ volatile ("csrr %0, cycle" : "=r" (cycles));
    return cycles;
}

static uint8_t color_to_rgb332(const struct color* color)
{
    return (uint8_t)((color->r & 0xe0u)
        | ((color->g >> 3) & 0x1cu)
        | (color->b >> 6));
}

static void upload_palette(uint32_t buffer_index)
{
    HAZARD3_VIDEO_PALETTE_INDEX = (buffer_index & 1u) << 8;
    for (uint32_t i = 0u; i < 256u; ++i) {
        HAZARD3_VIDEO_PALETTE_DATA = color_to_rgb332(&colors[i]);
    }
    palette_bank_valid_mask |= 1u << buffer_index;
}

static int wait_for_video_idle(void)
{
    uint32_t start_ticks = hazard3_ticks_ms();

    while ((HAZARD3_VIDEO_STATUS &
        HAZARD3_VIDEO_STATUS_PRESENT_PENDING) != 0u) {
        if (hazard3_ticks_ms() - start_ticks >=
            HAZARD3_VIDEO_PRESENT_TIMEOUT_MS) {
            return 0;
        }
    }
    return 1;
}

static int wait_for_dma_complete(uint32_t present_count_before)
{
    uint32_t start_ticks = hazard3_ticks_ms();

    for (;;) {
        uint32_t status = HAZARD3_VIDEO_STATUS;
        if (HAZARD3_VIDEO_PRESENT_COUNT != present_count_before &&
            (status & HAZARD3_VIDEO_STATUS_DMA_BUSY) == 0u) {
            return 1;
        }

        if (hazard3_ticks_ms() - start_ticks >=
            HAZARD3_VIDEO_PRESENT_TIMEOUT_MS) {
            return 0;
        }
    }
}

/* GCC 12.2.0 used by the Hazard3 toolchain can ICE when it turns a bit-11
 * test into a direct 0x800 mask. Keep this helper out of line and make the
 * shifted value volatile so GCC must perform the shift before testing bit 0. */
static __attribute__((noinline)) int video_high_resolution_supported(uint32_t status)
{
    volatile uint32_t shifted_status = status >> 11u;

    return (shifted_status & 1u) != 0u;
}

void DG_Init(void)
{
    uint32_t video_base = hazard3_video_base();
    uint32_t video_limit = hazard3_video_limit();
    uint32_t status = HAZARD3_VIDEO_STATUS;
    uint32_t front_buffer =
        (status & HAZARD3_VIDEO_STATUS_FRONT_BUFFER) != 0u ? 1u : 0u;
    uint32_t internal_buffer =
        (status & HAZARD3_VIDEO_STATUS_INTERNAL_BUFFER) != 0u ? 1u : 0u;

    draw_frame_count = 0u;
    palette_bank_valid_mask = 0u;
    video_failure_reported = 0;
    copy_cycles_total = 0u;
    present_cycles_total = 0u;
    last_copy_cycles = 0u;
    last_present_cycles = 0u;
    screen_snip_requested = 0;
    direct_video_available =
        (status & HAZARD3_VIDEO_STATUS_DIRECT_SUPPORTED) != 0u;
    back_buffer_index = (direct_video_available
        ? internal_buffer : front_buffer) ^ 1u;
    video_available = video_base == HAZARD3_VIDEO_FRAMEBUFFER0_BASE
        && video_limit >= video_base
        && video_limit - video_base >= HAZARD3_VIDEO_MINIMUM_RESERVE_BYTES
        && (status & HAZARD3_VIDEO_STATUS_SDRAM_READY) != 0u
        && (HAZARD3_VIDEO_HIGH_RES_ENABLED == 0u ||
            video_high_resolution_supported(status));

    hazard3_console_puts(
        direct_video_available
            ? "Doom platform: indexed renderer + direct block-RAM HDMI initialized\r\n"
            : "Doom platform: indexed renderer + SDRAM scanout HDMI initialized\r\n");
#ifdef HAZARD3_VIDEO_HIGH_RES
    hazard3_console_puts(
        "  renderer: 320x200; HDMI source: 400x240 EXPERIMENTAL\r\n");
#else
    hazard3_console_puts("  renderer/HDMI source: 320x200 standard\r\n");
#endif
    hazard3_console_puts(
        direct_video_available
            ? "  presentation path: direct APB-to-EBR\r\n"
            : "  presentation path: SDRAM staging / hardware scanout\r\n");
    if (!video_available) {
        hazard3_console_puts("Doom HDMI performance interface: FAIL\r\n");
    }
}

#ifdef HAZARD3_VIDEO_HIGH_RES
static uint32_t pack_indexed_pixels(
    uint8_t p0,
    uint8_t p1,
    uint8_t p2,
    uint8_t p3)
{
    return (uint32_t)p0 | ((uint32_t)p1 << 8) |
        ((uint32_t)p2 << 16) | ((uint32_t)p3 << 24);
}
#endif

static void screen_snip_put_word(uint32_t pixels)
{
    hazard3_console_putc((uint8_t)pixels);
    hazard3_console_putc((uint8_t)(pixels >> 8));
    hazard3_console_putc((uint8_t)(pixels >> 16));
    hazard3_console_putc((uint8_t)(pixels >> 24));
}

static void screen_snip_send(const uint32_t* source_words)
{
    if (source_words == (const uint32_t*)0) {
        return;
    }

#ifdef HAZARD3_VIDEO_HIGH_RES
    hazard3_console_puts(HAZARD3_SCREEN_SNIP_HEADER_HIGH);
#else
    hazard3_console_puts(HAZARD3_SCREEN_SNIP_HEADER_STANDARD);
#endif

    for (uint32_t i = 0u; i < 256u; ++i) {
        hazard3_console_putc(color_to_rgb332(&colors[i]));
    }

#ifdef HAZARD3_VIDEO_HIGH_RES
    const uint8_t* source_pixels = (const uint8_t*)source_words;
    uint32_t source_y;

    for (source_y = 0u; source_y < HAZARD3_VIDEO_STANDARD_HEIGHT; ++source_y) {
        const uint8_t* source_row = source_pixels +
            source_y * HAZARD3_VIDEO_STANDARD_WIDTH;
        uint32_t repeat_count = source_y % 5u == 0u ? 2u : 1u;
        uint32_t repeat;

        for (repeat = 0u; repeat < repeat_count; ++repeat) {
            uint32_t source_x;

            for (source_x = 0u;
                 source_x < HAZARD3_VIDEO_STANDARD_WIDTH;
                 source_x += 16u) {
                const uint8_t* p = source_row + source_x;

                screen_snip_put_word(pack_indexed_pixels(
                    p[0], p[0], p[1], p[2]));
                screen_snip_put_word(pack_indexed_pixels(
                    p[3], p[4], p[4], p[5]));
                screen_snip_put_word(pack_indexed_pixels(
                    p[6], p[7], p[8], p[8]));
                screen_snip_put_word(pack_indexed_pixels(
                    p[9], p[10], p[11], p[12]));
                screen_snip_put_word(pack_indexed_pixels(
                    p[12], p[13], p[14], p[15]));
            }
        }
    }
#else
    for (uint32_t i = 0u; i < HAZARD3_VIDEO_WORDS; ++i) {
        screen_snip_put_word(source_words[i]);
    }
#endif
}

void hazard3_doom_screen_snip_cache(void)
{
    const uint32_t* source_words = (const uint32_t*)DG_ScreenBuffer;
    volatile hazard3_screen_snip_cache_t* cache =
        (volatile hazard3_screen_snip_cache_t*)(uintptr_t)
            HAZARD3_SCREEN_SNIP_CACHE_BASE;

    if (source_words == (const uint32_t*)0) {
        return;
    }

    cache->magic = 0u;
    cache->magic_inverse = 0u;
    hazard3_memory_barrier();
    cache->version = HAZARD3_SCREEN_SNIP_CACHE_VERSION;
#ifdef HAZARD3_VIDEO_HIGH_RES
    cache->source_width = HAZARD3_VIDEO_HIGH_WIDTH;
    cache->source_height = HAZARD3_VIDEO_HIGH_HEIGHT;
    cache->pixel_bytes = HAZARD3_VIDEO_HIGH_BYTES;
#else
    cache->source_width = HAZARD3_VIDEO_STANDARD_WIDTH;
    cache->source_height = HAZARD3_VIDEO_STANDARD_HEIGHT;
    cache->pixel_bytes = HAZARD3_VIDEO_STANDARD_BYTES;
#endif
    cache->palette_bytes = HAZARD3_SCREEN_SNIP_PALETTE_BYTES;
    cache->reserved = 0u;

    for (uint32_t i = 0u; i < HAZARD3_SCREEN_SNIP_PALETTE_BYTES; ++i) {
        cache->palette[i] = color_to_rgb332(&colors[i]);
    }

#ifdef HAZARD3_VIDEO_HIGH_RES
    {
        const uint8_t* source_pixels = (const uint8_t*)source_words;
        uint32_t destination = 0u;

        for (uint32_t source_y = 0u;
             source_y < HAZARD3_VIDEO_STANDARD_HEIGHT;
             ++source_y) {
            const uint8_t* source_row = source_pixels +
                source_y * HAZARD3_VIDEO_STANDARD_WIDTH;
            uint32_t repeat_count = source_y % 5u == 0u ? 2u : 1u;

            for (uint32_t repeat = 0u; repeat < repeat_count; ++repeat) {
                for (uint32_t source_x = 0u;
                     source_x < HAZARD3_VIDEO_STANDARD_WIDTH;
                     source_x += 16u) {
                    const uint8_t* p = source_row + source_x;
                    static const uint8_t map[20] = {
                        0u, 0u, 1u, 2u, 3u, 4u, 4u, 5u, 6u, 7u,
                        8u, 8u, 9u, 10u, 11u, 12u, 12u, 13u, 14u, 15u
                    };

                    for (uint32_t i = 0u; i < 20u; ++i) {
                        cache->pixels[destination++] = p[map[i]];
                    }
                }
            }
        }
    }
#else
    {
        const uint8_t* source_pixels = (const uint8_t*)source_words;

        for (uint32_t i = 0u; i < HAZARD3_VIDEO_STANDARD_BYTES; ++i) {
            cache->pixels[i] = source_pixels[i];
        }
    }
#endif

    hazard3_memory_barrier();
    cache->magic_inverse = ~HAZARD3_SCREEN_SNIP_CACHE_MAGIC;
    hazard3_memory_barrier();
    cache->magic = HAZARD3_SCREEN_SNIP_CACHE_MAGIC;
    hazard3_memory_barrier();
}

static void copy_frame_direct(const uint32_t* source_words)
{
    HAZARD3_VIDEO_DIRECT_ADDRESS = hazard3_video_direct_halfword_base(
        back_buffer_index, HAZARD3_VIDEO_HIGH_RES_ENABLED != 0u);

#ifdef HAZARD3_VIDEO_HIGH_RES
    /*
     * Doom itself remains a 320x200 renderer. Four source pixels expand to
     * five HDMI-source pixels; five source rows expand to six output rows.
     * Processing 16 source pixels at once produces five aligned 32-bit writes.
     */
    const uint8_t* source_pixels = (const uint8_t*)source_words;
    uint32_t source_y;

    for (source_y = 0u; source_y < HAZARD3_VIDEO_STANDARD_HEIGHT; ++source_y) {
        const uint8_t* source_row = source_pixels +
            source_y * HAZARD3_VIDEO_STANDARD_WIDTH;
        uint32_t repeat_count = source_y % 5u == 0u ? 2u : 1u;
        uint32_t repeat;

        for (repeat = 0u; repeat < repeat_count; ++repeat) {
            uint32_t source_x;

            for (source_x = 0u;
                 source_x < HAZARD3_VIDEO_STANDARD_WIDTH;
                 source_x += 16u) {
                const uint8_t* p = source_row + source_x;

                HAZARD3_VIDEO_DIRECT_DATA = pack_indexed_pixels(
                    p[0], p[0], p[1], p[2]);
                HAZARD3_VIDEO_DIRECT_DATA = pack_indexed_pixels(
                    p[3], p[4], p[4], p[5]);
                HAZARD3_VIDEO_DIRECT_DATA = pack_indexed_pixels(
                    p[6], p[7], p[8], p[8]);
                HAZARD3_VIDEO_DIRECT_DATA = pack_indexed_pixels(
                    p[9], p[10], p[11], p[12]);
                HAZARD3_VIDEO_DIRECT_DATA = pack_indexed_pixels(
                    p[12], p[13], p[14], p[15]);
            }
        }
    }
#else
    for (uint32_t i = 0u; i < HAZARD3_VIDEO_WORDS; i += 8u) {
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 0u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 1u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 2u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 3u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 4u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 5u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 6u];
        HAZARD3_VIDEO_DIRECT_DATA = source_words[i + 7u];
    }
#endif
}

static void copy_frame_legacy(
    volatile uint32_t* destination_words,
    const uint32_t* source_words)
{
#ifdef HAZARD3_VIDEO_HIGH_RES
    const uint8_t* source_pixels = (const uint8_t*)source_words;
    uint32_t destination_y = 0u;
    uint32_t source_y;

    for (source_y = 0u; source_y < HAZARD3_VIDEO_STANDARD_HEIGHT; ++source_y) {
        const uint8_t* source_row = source_pixels +
            source_y * HAZARD3_VIDEO_STANDARD_WIDTH;
        uint32_t repeat_count = source_y % 5u == 0u ? 2u : 1u;
        uint32_t repeat;

        for (repeat = 0u; repeat < repeat_count; ++repeat) {
            volatile uint32_t* destination_row = destination_words +
                destination_y * (HAZARD3_VIDEO_HIGH_WIDTH / 4u);
            uint32_t source_x;
            uint32_t destination_word = 0u;

            for (source_x = 0u;
                 source_x < HAZARD3_VIDEO_STANDARD_WIDTH;
                 source_x += 16u) {
                const uint8_t* p = source_row + source_x;

                destination_row[destination_word++] = pack_indexed_pixels(
                    p[0], p[0], p[1], p[2]);
                destination_row[destination_word++] = pack_indexed_pixels(
                    p[3], p[4], p[4], p[5]);
                destination_row[destination_word++] = pack_indexed_pixels(
                    p[6], p[7], p[8], p[8]);
                destination_row[destination_word++] = pack_indexed_pixels(
                    p[9], p[10], p[11], p[12]);
                destination_row[destination_word++] = pack_indexed_pixels(
                    p[12], p[13], p[14], p[15]);
            }
            ++destination_y;
        }
    }
#else
    for (uint32_t i = 0u; i < HAZARD3_VIDEO_WORDS; i += 8u) {
        destination_words[i + 0u] = source_words[i + 0u];
        destination_words[i + 1u] = source_words[i + 1u];
        destination_words[i + 2u] = source_words[i + 2u];
        destination_words[i + 3u] = source_words[i + 3u];
        destination_words[i + 4u] = source_words[i + 4u];
        destination_words[i + 5u] = source_words[i + 5u];
        destination_words[i + 6u] = source_words[i + 6u];
        destination_words[i + 7u] = source_words[i + 7u];
    }
#endif
}

void DG_DrawFrame(void)
{
    const uint32_t* source_words = (const uint32_t*)DG_ScreenBuffer;

    if (video_available && source_words != (const uint32_t*)0) {
        uint32_t present_count_before;
        uint32_t copy_start;
        uint32_t present_start;

        // The direct path writes the inactive displayed bank. Wait until the
        // prior vertical-blank swap is complete before reusing that bank.
        if (direct_video_available && !wait_for_video_idle()) {
            video_available = 0;
        }

        copy_start = read_cycle_counter();
        if (video_available) {
            if (direct_video_available) {
                copy_frame_direct(source_words);
            } else {
                volatile uint32_t* destination_words =
                    hazard3_video_framebuffer_words(back_buffer_index);
                copy_frame_legacy(destination_words, source_words);
                hazard3_memory_barrier();
            }
        }
        last_copy_cycles = read_cycle_counter() - copy_start;
        copy_cycles_total += last_copy_cycles;

        present_start = read_cycle_counter();
        if (video_available && !direct_video_available &&
            !wait_for_video_idle()) {
            video_available = 0;
        }

        // Palette RAM is indexed by displayed-buffer number. Do not overwrite a
        // bank until the preceding swap has completed.
        if (video_available) {
            if (palette_changed) {
                palette_bank_valid_mask = 0u;
                palette_changed = false;
            }
            if ((palette_bank_valid_mask & (1u << back_buffer_index)) == 0u) {
                upload_palette(back_buffer_index);
            }

            present_count_before = HAZARD3_VIDEO_PRESENT_COUNT;
            HAZARD3_VIDEO_CONTROL = HAZARD3_VIDEO_CONTROL_INDEXED
                | (back_buffer_index != 0u
                    ? HAZARD3_VIDEO_CONTROL_BUFFER1 : 0u)
                | (direct_video_available
                    ? HAZARD3_VIDEO_CONTROL_DIRECT : 0u)
                | HAZARD3_VIDEO_MODE_CONTROL
                | HAZARD3_VIDEO_CONTROL_PRESENT;

            // Direct presentation only queues a vertical-blank bank swap.
            // Legacy presentation waits for SDRAM-to-block-RAM DMA completion.
            if (wait_for_dma_complete(present_count_before)) {
                last_present_cycles = read_cycle_counter() - present_start;
                present_cycles_total += last_present_cycles;
                back_buffer_index ^= 1u;
            } else {
                video_available = 0;
            }
        }

        if (!video_available && !video_failure_reported) {
            hazard3_console_puts(
                "Doom HDMI present timeout; continuing headless\r\n");
            video_failure_reported = 1;
        }
    }

    if (screen_snip_requested && source_words != (const uint32_t*)0) {
        screen_snip_requested = 0;
        screen_snip_send(source_words);
    }

    ++draw_frame_count;
    if (draw_frame_count == 1u) {
        hazard3_console_puts(
            video_available
                ? (direct_video_available
                    ? "Doom renderer: first direct block-RAM frame queued\r\n"
                    : "Doom renderer: first SDRAM scanout frame queued\r\n")
                : "Doom renderer: first headless frame completed\r\n");
    }
}

void DG_SleepMs(uint32_t milliseconds)
{
    hazard3_sleep_ms(milliseconds);
}

uint32_t DG_GetTicksMs(void)
{
    return hazard3_ticks_ms();
}

static int uart_character_to_doom_key(uint8_t character, unsigned char* key)
{
    switch (character) {
    case 'w':
    case 'W':
        *key = KEY_UPARROW;
        return 1;

    case 's':
    case 'S':
        *key = KEY_DOWNARROW;
        return 1;

    case 'a':
    case 'A':
        *key = KEY_LEFTARROW;
        return 1;

    case 'd':
    case 'D':
        *key = KEY_RIGHTARROW;
        return 1;

    case 'z':
    case 'Z':
        *key = KEY_STRAFE_L;
        return 1;

    case 'c':
    case 'C':
        *key = KEY_STRAFE_R;
        return 1;

    case 'f':
    case 'F':
    case ' ':
        *key = KEY_FIRE;
        return 1;

    case 'e':
    case 'E':
        *key = KEY_USE;
        return 1;

    case 'm':
    case 'M':
    case '\t':
        *key = KEY_TAB;
        return 1;

    case 'p':
    case 'P':
        *key = KEY_PAUSE;
        return 1;

    case '\r':
    case '\n':
        *key = KEY_ENTER;
        return 1;

    case 0x1bu:
        *key = KEY_ESCAPE;
        return 1;

    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
        *key = character;
        return 1;

    default:
        return 0;
    }
}

static int emit_key_down(
    int* pressed,
    unsigned char* key,
    unsigned char key_code,
    uint8_t source_character)
{
    *pressed = 1;
    *key = key_code;
    key_release_code = key_code;
    key_release_deadline_ms =
        hazard3_ticks_ms() + HAZARD3_UART_KEY_HOLD_MS;
    key_release_pending = 1;
    stop_input_scan = 1;

    if (!input_activity_reported) {
        hazard3_console_puts(
            "Doom UART input: ACTIVE first_character=");
        hazard3_console_put_hex32(source_character);
        hazard3_console_puts("\r\n");
        input_activity_reported = 1;
    }

    return 1;
}

static int decode_escape_sequence(
    uint8_t character,
    unsigned char* key)
{
    if (escape_sequence_state == 1u) {
        if (character == '[' || character == 'O') {
            escape_sequence_state = 2u;
            escape_sequence_deadline_ms =
                hazard3_ticks_ms() +
                HAZARD3_ESCAPE_SEQUENCE_TIMEOUT_MS;
            return 0;
        }

        deferred_character = character;
        deferred_character_valid = 1;
        escape_sequence_state = 0u;
        *key = KEY_ESCAPE;
        return 1;
    }

    if (escape_sequence_state == 2u) {
        escape_sequence_state = 0u;
        switch (character) {
        case 'A':
            *key = KEY_UPARROW;
            return 1;
        case 'B':
            *key = KEY_DOWNARROW;
            return 1;
        case 'C':
            *key = KEY_RIGHTARROW;
            return 1;
        case 'D':
            *key = KEY_LEFTARROW;
            return 1;
        default:
            return 0;
        }
    }

    return 0;
}

int DG_GetKey(int* pressed, unsigned char* key)
{
    uint8_t character;

    if (pressed == (int*)0 || key == (unsigned char*)0) {
        return 0;
    }

    if (stop_input_scan) {
        stop_input_scan = 0;
        return 0;
    }

    if (key_release_pending) {
        if ((int32_t)(hazard3_ticks_ms() -
            key_release_deadline_ms) < 0) {
            return 0;
        }

        *pressed = 0;
        *key = key_release_code;
        key_release_pending = 0;
        return 1;
    }

    if (escape_sequence_state != 0u &&
        (int32_t)(hazard3_ticks_ms() -
            escape_sequence_deadline_ms) >= 0) {
        escape_sequence_state = 0u;
        return emit_key_down(
            pressed, key, KEY_ESCAPE, 0x1bu);
    }

    // Consume a bounded number of ignored terminal characters per tick. ANSI
    // arrow sequences are decoded as one Doom key instead of interpreting
    // their leading escape byte as a menu command.
    for (uint32_t ignored = 0u; ignored < 4u; ++ignored) {
        if (deferred_character_valid) {
            character = deferred_character;
            deferred_character_valid = 0;
        } else if (!hazard3_console_getc_nonblocking(&character)) {
            return 0;
        }

        if (character == HAZARD3_SCREEN_SNIP_CAPABILITY_REQUEST) {
            hazard3_console_putc(HAZARD3_SCREEN_SNIP_CAPABILITY_ACK);
            return 0;
        }

        if (character == HAZARD3_SCREEN_SNIP_REQUEST) {
            screen_snip_requested = 1;
            return 0;
        }

        if (escape_sequence_state != 0u) {
            if (decode_escape_sequence(character, key)) {
                return emit_key_down(
                    pressed, key, *key, character);
            }
            continue;
        }

        if (character == 0x18u) {
            // Ctrl-X exits the SDRAM Doom image and returns to the monitor.
            exit_requested = 1;
            return 0;
        }

        if (character == 0x1bu) {
            escape_sequence_state = 1u;
            escape_sequence_deadline_ms =
                hazard3_ticks_ms() +
                HAZARD3_ESCAPE_SEQUENCE_TIMEOUT_MS;
            continue;
        }

        if (uart_character_to_doom_key(character, key)) {
            return emit_key_down(
                pressed, key, *key, character);
        }
    }

    return 0;
}

void DG_SetWindowTitle(const char* title)
{
    hazard3_console_puts("Doom title: ");
    hazard3_console_puts(title != (const char*)0 ? title : "(null)");
    hazard3_console_puts("\r\n");
}

uint32_t hazard3_doom_draw_frame_count(void)
{
    return draw_frame_count;
}

uint32_t hazard3_doom_last_copy_cycles(void)
{
    return last_copy_cycles;
}

uint32_t hazard3_doom_last_present_cycles(void)
{
    return last_present_cycles;
}

uint32_t hazard3_doom_copy_cycles_total(void)
{
    return copy_cycles_total;
}

uint32_t hazard3_doom_present_cycles_total(void)
{
    return present_cycles_total;
}

void hazard3_doom_input_reset(void)
{
    key_release_pending = 0;
    key_release_code = 0u;
    key_release_deadline_ms = 0u;
    stop_input_scan = 0;
    exit_requested = 0;
    input_activity_reported = 0;
    escape_sequence_state = 0u;
    escape_sequence_deadline_ms = 0u;
    deferred_character = 0u;
    deferred_character_valid = 0;
    screen_snip_requested = 0;
}

int hazard3_doom_exit_requested(void)
{
    return exit_requested;
}
