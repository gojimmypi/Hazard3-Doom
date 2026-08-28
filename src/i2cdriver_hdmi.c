/* -----------------------------------------------------------------------------
 * File:        i2cdriver_hdmi.c
 * Path:        src/i2cdriver_hdmi.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement the I2CDriver-inspired interactive HDMI user interface
 *              over the Hazard3 SAO bus.
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

/*
 * Hazard3-Doom I2CDriver-style HDMI user interface.
 *
 * The interaction model is inspired by James Bowman's I2CDriver firmware
 * (firmware/main.fs and its display/capture helpers), licensed BSD-3-Clause.
 * See docs/i2cdriver-BSD-3-Clause.txt and docs/I2CDRIVER_HDMI.md.
 *
 * This implementation deliberately reuses the existing Hazard3 SAO APB I2C
 * controller instead of bit-banging I2C in C. The waveform shown on HDMI is a
 * logical trace of transactions initiated by this application. Passive bus
 * capture of unrelated traffic requires a hardware capture FIFO and is not
 * represented as sampled electrical data here.
 */
#include "i2cdriver_hdmi.h"

#include <stddef.h>
#include <stdint.h>

#include "doom/hazard3_memory_map.h"
#include "doom/hazard3_platform.h"
#include "doom/hazard3_sao.h"
#include "doom/hazard3_video.h"

#ifndef HAZARD3_SYS_CLK_HZ
#define HAZARD3_SYS_CLK_HZ 50000000u
#endif

/* The compatibility UI uses the original 320x200 EBR layout. The optional
 * 400x240 mode is retained for comparison. The preferred high-quality GUI
 * mode is 512x300 packed 4-bpp in the uncached video workbuffer. Presentation
 * copies it into the existing EBR frame banks, where the FPGA scales it
 * exactly 2x to the 1024x600 HDMI panel. */
#define UI_WIDTH                 HAZARD3_VIDEO_STANDARD_WIDTH
#define UI_HEIGHT                HAZARD3_VIDEO_STANDARD_HEIGHT
#define UI_PIXELS                (UI_WIDTH * UI_HEIGHT)
#define UI_WORDS                 (UI_PIXELS / 4u)
#define UI_HIGH_WIDTH            HAZARD3_VIDEO_HIGH_WIDTH
#define UI_HIGH_HEIGHT           HAZARD3_VIDEO_HIGH_HEIGHT
#define UI_HIGH_PIXELS           (UI_HIGH_WIDTH * UI_HIGH_HEIGHT)
#define UI_HIGH_WORDS            (UI_HIGH_PIXELS / 4u)
#define UI_GUI_WIDTH             HAZARD3_VIDEO_GUI_WIDTH
#define UI_GUI_HEIGHT            HAZARD3_VIDEO_GUI_HEIGHT
#define UI_GUI_PIXELS            (UI_GUI_WIDTH * UI_GUI_HEIGHT)
#define UI_GUI_BYTES             (UI_GUI_PIXELS / 2u)
#define UI_GUI_WORDS             (UI_GUI_BYTES / 4u)
#define UI_PRESENT_TIMEOUT_MS    500u
#define UI_COOL_INTERVAL_MS      80u
#define UI_HEAT_MAX              72u
#define UI_LOG_COUNT             8u
#define UI_TRACE_COUNT           12u
#define UI_I2C_100KHZ            100000u
#define UI_I2C_400KHZ            400000u
#define UI_SCREEN_SNIP_CAPABILITY_REQUEST 0x1cu
#define UI_SCREEN_SNIP_CAPABILITY_ACK     0x06u
#define UI_SCREEN_SNIP_REQUEST            0x1du
#define UI_SCREEN_SNIP_HEADER_STANDARD \
    "\r\nH3SNIP1 320 200 1024 600 IDX8 256 64000\r\n"
#define UI_SCREEN_SNIP_HEADER_HIGH \
    "\r\nH3SNIP1 400 240 1024 600 IDX8 256 96000\r\n"
#define UI_SCREEN_SNIP_HEADER_GUI \
    "\r\nH3SNIP1 512 300 1024 600 IDX8 256 153600\r\n"

#if HAZARD3_VIDEO_GUI_FRAMEBUFFER_BASE + HAZARD3_VIDEO_GUI_BYTES > HAZARD3_VIDEO_LIMIT
#error "512x300 GUI framebuffer exceeds the reserved video aperture"
#endif

#define UI_COLOR_BLACK           0u
#define UI_COLOR_DARK_GRAY       1u
#define UI_COLOR_GRAY            2u
#define UI_COLOR_WHITE           3u
#define UI_COLOR_BLUE            4u
#define UI_COLOR_CYAN            5u
#define UI_COLOR_DARK_GREEN      6u
#define UI_COLOR_GREEN           7u
#define UI_COLOR_YELLOW          8u
#define UI_COLOR_ORANGE          9u
#define UI_COLOR_RED             10u
#define UI_COLOR_DARK_RED        11u
#define UI_COLOR_MAGENTA         12u
#define UI_COLOR_PURPLE          13u
#define UI_COLOR_NAVY            14u
#define UI_COLOR_PANEL           15u

#define TRACE_START              1u
#define TRACE_STOP               2u
#define TRACE_BYTE               3u
#define TRACE_ACK                1u
#define TRACE_NACK               0u
#define TRACE_MASTER_NACK        2u

#define EVENT_NONE               0u
#define EVENT_SCAN               1u
#define EVENT_PROBE              2u
#define EVENT_READ               3u
#define EVENT_WRITE              4u
#define EVENT_RECOVER            5u
#define EVENT_SPEED              6u

#define PROMPT_NONE              0u
#define PROMPT_PROBE             1u
#define PROMPT_READ              2u
#define PROMPT_WRITE             3u

struct ui_trace_item {
    uint8_t kind;
    uint8_t value;
    uint8_t ack;
};

struct ui_event {
    uint8_t kind;
    uint8_t address;
    uint8_t reg;
    uint8_t value;
    uint8_t extra;
    int result;
};

static int ui_high_resolution;
static int ui_gui_resolution;
static uint8_t ui_heat[128];
static struct ui_trace_item ui_trace[UI_TRACE_COUNT];
static struct ui_event ui_events[UI_LOG_COUNT];
static size_t ui_trace_used;
static size_t ui_event_head;
static size_t ui_event_used;
static uint32_t ui_i2c_hz = UI_I2C_100KHZ;
static uint32_t ui_palette_uploaded_mask;
static uint32_t ui_back_buffer;
static uint8_t ui_prompt_mode;
static uint8_t ui_prompt_digits[6];
static size_t ui_prompt_length;
static uint8_t ui_last_address;
static uint8_t ui_last_reg;
static uint8_t ui_last_value;
static int ui_last_result;
static size_t ui_last_scan_count;
static const char* ui_message = "READY";

static const uint8_t ui_palette[16] = {
    0x00u, 0x49u, 0x92u, 0xffu,
    0x03u, 0x1fu, 0x08u, 0x1cu,
    0xfcu, 0xf0u, 0xe0u, 0x60u,
    0xe3u, 0x83u, 0x01u, 0x24u
};

static char ascii_upper(char value)
{
    if (value >= 'a' && value <= 'z') {
        return (char)(value - 'a' + 'A');
    }
    return value;
}

static int hex_digit(char value)
{
    value = ascii_upper(value);
    if (value >= '0' && value <= '9') {
        return value - '0';
    }
    if (value >= 'A' && value <= 'F') {
        return value - 'A' + 10;
    }
    return -1;
}

/* 3x5 glyphs, packed as five 3-bit rows from top to bottom. */
static uint16_t glyph3x5(char value)
{
#define G(r0, r1, r2, r3, r4) \
    ((uint16_t)(r0) | ((uint16_t)(r1) << 3) | ((uint16_t)(r2) << 6) | \
     ((uint16_t)(r3) << 9) | ((uint16_t)(r4) << 12))
    switch (ascii_upper(value)) {
    case '0': return G(7, 5, 5, 5, 7);
    case '1': return G(2, 6, 2, 2, 7);
    case '2': return G(7, 1, 7, 4, 7);
    case '3': return G(7, 1, 7, 1, 7);
    case '4': return G(5, 5, 7, 1, 1);
    case '5': return G(7, 4, 7, 1, 7);
    case '6': return G(7, 4, 7, 5, 7);
    case '7': return G(7, 1, 1, 1, 1);
    case '8': return G(7, 5, 7, 5, 7);
    case '9': return G(7, 5, 7, 1, 7);
    case 'A': return G(2, 5, 7, 5, 5);
    case 'B': return G(6, 5, 6, 5, 6);
    case 'C': return G(3, 4, 4, 4, 3);
    case 'D': return G(6, 5, 5, 5, 6);
    case 'E': return G(7, 4, 6, 4, 7);
    case 'F': return G(7, 4, 6, 4, 4);
    case 'G': return G(3, 4, 5, 5, 3);
    case 'H': return G(5, 5, 7, 5, 5);
    case 'I': return G(7, 2, 2, 2, 7);
    case 'J': return G(1, 1, 1, 5, 2);
    case 'K': return G(5, 5, 6, 5, 5);
    case 'L': return G(4, 4, 4, 4, 7);
    case 'M': return G(5, 7, 7, 5, 5);
    case 'N': return G(5, 7, 7, 7, 5);
    case 'O': return G(2, 5, 5, 5, 2);
    case 'P': return G(6, 5, 6, 4, 4);
    case 'Q': return G(2, 5, 5, 7, 3);
    case 'R': return G(6, 5, 6, 5, 5);
    case 'S': return G(3, 4, 2, 1, 6);
    case 'T': return G(7, 2, 2, 2, 2);
    case 'U': return G(5, 5, 5, 5, 7);
    case 'V': return G(5, 5, 5, 5, 2);
    case 'W': return G(5, 5, 7, 7, 5);
    case 'X': return G(5, 5, 2, 5, 5);
    case 'Y': return G(5, 5, 2, 2, 2);
    case 'Z': return G(7, 1, 2, 4, 7);
    case ':': return G(0, 2, 0, 2, 0);
    case '.': return G(0, 0, 0, 0, 2);
    case '-': return G(0, 0, 7, 0, 0);
    case '_': return G(0, 0, 0, 0, 7);
    case '=': return G(0, 7, 0, 7, 0);
    case '/': return G(1, 1, 2, 4, 4);
    case '>': return G(4, 2, 1, 2, 4);
    case '<': return G(1, 2, 4, 2, 1);
    case '[': return G(6, 4, 4, 4, 6);
    case ']': return G(3, 1, 1, 1, 3);
    case '?': return G(7, 1, 3, 0, 2);
    case '+': return G(0, 2, 7, 2, 0);
    case '!': return G(2, 2, 2, 0, 2);
    case ' ': return 0u;
    default:  return G(7, 1, 2, 0, 2);
    }
#undef G
}

/* 5x7 glyphs used by the native 400x240 interface. */
static void glyph5x7(char value, uint8_t rows[7])
{
#define G5(r0, r1, r2, r3, r4, r5, r6) \
    do { \
        rows[0] = (r0); rows[1] = (r1); rows[2] = (r2); rows[3] = (r3); \
        rows[4] = (r4); rows[5] = (r5); rows[6] = (r6); \
        return; \
    } while (0)
    switch (ascii_upper(value)) {
    case '0': G5(14, 17, 19, 21, 25, 17, 14);
    case '1': G5(4, 12, 4, 4, 4, 4, 14);
    case '2': G5(14, 17, 1, 2, 4, 8, 31);
    case '3': G5(30, 1, 1, 14, 1, 1, 30);
    case '4': G5(2, 6, 10, 18, 31, 2, 2);
    case '5': G5(31, 16, 16, 30, 1, 1, 30);
    case '6': G5(14, 16, 16, 30, 17, 17, 14);
    case '7': G5(31, 1, 2, 4, 8, 8, 8);
    case '8': G5(14, 17, 17, 14, 17, 17, 14);
    case '9': G5(14, 17, 17, 15, 1, 1, 14);
    case 'A': G5(14, 17, 17, 31, 17, 17, 17);
    case 'B': G5(30, 17, 17, 30, 17, 17, 30);
    case 'C': G5(14, 17, 16, 16, 16, 17, 14);
    case 'D': G5(30, 17, 17, 17, 17, 17, 30);
    case 'E': G5(31, 16, 16, 30, 16, 16, 31);
    case 'F': G5(31, 16, 16, 30, 16, 16, 16);
    case 'G': G5(14, 17, 16, 23, 17, 17, 15);
    case 'H': G5(17, 17, 17, 31, 17, 17, 17);
    case 'I': G5(14, 4, 4, 4, 4, 4, 14);
    case 'J': G5(7, 2, 2, 2, 18, 18, 12);
    case 'K': G5(17, 18, 20, 24, 20, 18, 17);
    case 'L': G5(16, 16, 16, 16, 16, 16, 31);
    case 'M': G5(17, 27, 21, 21, 17, 17, 17);
    case 'N': G5(17, 25, 21, 19, 17, 17, 17);
    case 'O': G5(14, 17, 17, 17, 17, 17, 14);
    case 'P': G5(30, 17, 17, 30, 16, 16, 16);
    case 'Q': G5(14, 17, 17, 17, 21, 18, 13);
    case 'R': G5(30, 17, 17, 30, 20, 18, 17);
    case 'S': G5(15, 16, 16, 14, 1, 1, 30);
    case 'T': G5(31, 4, 4, 4, 4, 4, 4);
    case 'U': G5(17, 17, 17, 17, 17, 17, 14);
    case 'V': G5(17, 17, 17, 17, 17, 10, 4);
    case 'W': G5(17, 17, 17, 21, 21, 21, 10);
    case 'X': G5(17, 17, 10, 4, 10, 17, 17);
    case 'Y': G5(17, 17, 10, 4, 4, 4, 4);
    case 'Z': G5(31, 1, 2, 4, 8, 16, 31);
    case ':': G5(0, 4, 4, 0, 4, 4, 0);
    case '.': G5(0, 0, 0, 0, 0, 12, 12);
    case '-': G5(0, 0, 0, 31, 0, 0, 0);
    case '_': G5(0, 0, 0, 0, 0, 0, 31);
    case '=': G5(0, 0, 31, 0, 31, 0, 0);
    case '/': G5(1, 2, 2, 4, 8, 8, 16);
    case '>': G5(16, 8, 4, 2, 4, 8, 16);
    case '<': G5(1, 2, 4, 8, 4, 2, 1);
    case '[': G5(14, 8, 8, 8, 8, 8, 14);
    case ']': G5(14, 2, 2, 2, 2, 2, 14);
    case '?': G5(14, 17, 1, 2, 4, 0, 4);
    case '+': G5(0, 4, 4, 31, 4, 4, 0);
    case '!': G5(4, 4, 4, 4, 4, 0, 4);
    case ' ': G5(0, 0, 0, 0, 0, 0, 0);
    default:  G5(14, 17, 1, 2, 4, 0, 4);
    }
#undef G5
}

static unsigned int ui_canvas_width(void)
{
    if (ui_gui_resolution != 0) {
        return UI_GUI_WIDTH;
    }
    return ui_high_resolution != 0 ? UI_HIGH_WIDTH : UI_WIDTH;
}

static unsigned int ui_canvas_height(void)
{
    if (ui_gui_resolution != 0) {
        return UI_GUI_HEIGHT;
    }
    return ui_high_resolution != 0 ? UI_HIGH_HEIGHT : UI_HEIGHT;
}

static unsigned int ui_char_width(void)
{
    return ui_high_resolution != 0 || ui_gui_resolution != 0 ? 5u : 3u;
}

static unsigned int ui_char_pitch(void)
{
    return ui_high_resolution != 0 || ui_gui_resolution != 0 ? 6u : 4u;
}

static volatile uint8_t* ui_framebuffer(void)
{
    uintptr_t address;

    if (ui_gui_resolution != 0) {
        address = HAZARD3_VIDEO_GUI_FRAMEBUFFER_BASE;
    } else if (ui_high_resolution != 0) {
        address = HAZARD3_VIDEO_WORKBUFFER_BASE;
    } else {
        address = HAZARD3_DOOM_SCREENBUFFER_BASE;
    }
    return (volatile uint8_t*)address;
}

static size_t ui_physical_words(void)
{
    if (ui_gui_resolution != 0) {
        return UI_GUI_WORDS;
    }
    return ui_high_resolution != 0 ? UI_HIGH_WORDS : UI_WORDS;
}

static void screen_snip_send(void)
{
    const volatile uint8_t* framebuffer = ui_framebuffer();
    size_t pixel_count;
    const char* header;
    size_t i;

    if (ui_gui_resolution != 0) {
        pixel_count = UI_GUI_PIXELS;
        header = UI_SCREEN_SNIP_HEADER_GUI;
    } else if (ui_high_resolution != 0) {
        pixel_count = UI_HIGH_PIXELS;
        header = UI_SCREEN_SNIP_HEADER_HIGH;
    } else {
        pixel_count = UI_PIXELS;
        header = UI_SCREEN_SNIP_HEADER_STANDARD;
    }
    hazard3_console_puts(header);

    for (i = 0u; i < 256u; ++i) {
        hazard3_console_putc(i < sizeof(ui_palette) ? ui_palette[i] : 0u);
    }
    if (ui_gui_resolution != 0) {
        for (i = 0u; i < pixel_count; ++i) {
            uint8_t packed = framebuffer[i >> 1u];
            uint8_t pixel = (i & 1u) != 0u
                ? (uint8_t)(packed >> 4u)
                : (uint8_t)(packed & 0x0fu);
            hazard3_console_putc(pixel);
        }
    } else {
        for (i = 0u; i < pixel_count; ++i) {
            hazard3_console_putc(framebuffer[i]);
        }
    }
}

static void ui_pixel(unsigned int x, unsigned int y, uint8_t color)
{
    volatile uint8_t* framebuffer;
    unsigned int width = ui_canvas_width();
    unsigned int height = ui_canvas_height();

    if (x >= width || y >= height) {
        return;
    }

    framebuffer = ui_framebuffer();
    if (ui_gui_resolution != 0) {
        size_t offset = (size_t)y * (UI_GUI_WIDTH / 2u) + (x >> 1u);
        uint8_t packed = framebuffer[offset];

        if ((x & 1u) != 0u) {
            packed = (uint8_t)((packed & 0x0fu) | ((color & 0x0fu) << 4u));
        } else {
            packed = (uint8_t)((packed & 0xf0u) | (color & 0x0fu));
        }
        framebuffer[offset] = packed;
    } else {
        framebuffer[y * width + x] = color;
    }
}

static void ui_hline(unsigned int x0, unsigned int x1, unsigned int y, uint8_t color)
{
    unsigned int x;

    unsigned int width = ui_canvas_width();
    unsigned int height = ui_canvas_height();

    if (y >= height || x0 >= width) {
        return;
    }
    if (x1 >= width) {
        x1 = width - 1u;
    }
    for (x = x0; x <= x1; ++x) {
        ui_pixel(x, y, color);
    }
}

static void ui_vline(unsigned int x, unsigned int y0, unsigned int y1, uint8_t color)
{
    unsigned int y;

    unsigned int width = ui_canvas_width();
    unsigned int height = ui_canvas_height();

    if (x >= width || y0 >= height) {
        return;
    }
    if (y1 >= height) {
        y1 = height - 1u;
    }
    for (y = y0; y <= y1; ++y) {
        ui_pixel(x, y, color);
    }
}

static void ui_fill_rect(
    unsigned int x,
    unsigned int y,
    unsigned int width,
    unsigned int height,
    uint8_t color)
{
    unsigned int canvas_width = ui_canvas_width();
    unsigned int canvas_height = ui_canvas_height();
    unsigned int yy;
    unsigned int xx;

    for (yy = 0u; yy < height && y + yy < canvas_height; ++yy) {
        for (xx = 0u; xx < width && x + xx < canvas_width; ++xx) {
            ui_pixel(x + xx, y + yy, color);
        }
    }
}

static void ui_box(
    unsigned int x,
    unsigned int y,
    unsigned int width,
    unsigned int height,
    uint8_t color)
{
    if (width == 0u || height == 0u) {
        return;
    }
    ui_hline(x, x + width - 1u, y, color);
    ui_hline(x, x + width - 1u, y + height - 1u, color);
    ui_vline(x, y, y + height - 1u, color);
    ui_vline(x + width - 1u, y, y + height - 1u, color);
}

static void ui_clear(uint8_t color)
{
    uint32_t packed = (uint32_t)color;
    volatile uint32_t* destination =
        (volatile uint32_t*)(uintptr_t)ui_framebuffer();
    size_t word_count = ui_physical_words();
    size_t i;

    if (ui_gui_resolution != 0) {
        packed &= 0x0fu;
        packed |= packed << 4u;
    }
    packed |= packed << 8u;
    packed |= packed << 16u;
    for (i = 0u; i < word_count; ++i) {
        destination[i] = packed;
    }
}

static void ui_char(unsigned int x, unsigned int y, char value, uint8_t color)
{
    unsigned int row;
    unsigned int col;

    if (ui_high_resolution != 0 || ui_gui_resolution != 0) {
        uint8_t rows[7];

        glyph5x7(value, rows);
        for (row = 0u; row < 7u; ++row) {
            for (col = 0u; col < 5u; ++col) {
                if ((rows[row] & (uint8_t)(16u >> col)) != 0u) {
                    ui_pixel(x + col, y + row, color);
                }
            }
        }
        return;
    }

    {
        uint16_t glyph = glyph3x5(value);

        for (row = 0u; row < 5u; ++row) {
            uint8_t bits = (uint8_t)((glyph >> (row * 3u)) & 7u);
            for (col = 0u; col < 3u; ++col) {
                if ((bits & (uint8_t)(4u >> col)) != 0u) {
                    ui_pixel(x + col, y + row, color);
                }
            }
        }
    }
}

static void ui_text(unsigned int x, unsigned int y, const char* text, uint8_t color)
{
    unsigned int width = ui_canvas_width();
    unsigned int glyph_width = ui_char_width();
    unsigned int pitch = ui_char_pitch();

    while (*text != '\0' && x + glyph_width - 1u < width) {
        ui_char(x, y, *text++, color);
        x += pitch;
    }
}

static void ui_hex8(unsigned int x, unsigned int y, uint8_t value, uint8_t color)
{
    static const char digits[] = "0123456789ABCDEF";
    unsigned int pitch = ui_char_pitch();

    ui_char(x, y, digits[(value >> 4) & 0x0fu], color);
    ui_char(x + pitch, y, digits[value & 0x0fu], color);
}

static void ui_uint(unsigned int x, unsigned int y, size_t value, uint8_t color)
{
    char buffer[10];
    size_t count = 0u;
    size_t i;

    if (value == 0u) {
        ui_char(x, y, '0', color);
        return;
    }
    while (value != 0u && count < sizeof(buffer)) {
        buffer[count++] = (char)('0' + (value % 10u));
        value /= 10u;
    }
    for (i = 0u; i < count; ++i) {
        ui_char(x + i * ui_char_pitch(), y, buffer[count - i - 1u], color);
    }
}

static int elapsed(uint32_t now, uint32_t start, uint32_t interval)
{
    return (uint32_t)(now - start) >= interval;
}

static int video_wait_idle(uint32_t timeout_ms)
{
    uint32_t started = hazard3_ticks_ms();
    const uint32_t busy_mask = HAZARD3_VIDEO_STATUS_PRESENT_PENDING |
        HAZARD3_VIDEO_STATUS_DMA_BUSY | HAZARD3_VIDEO_STATUS_DIRECT_WRITE_BUSY;

    while ((HAZARD3_VIDEO_STATUS & busy_mask) != 0u) {
        if (elapsed(hazard3_ticks_ms(), started, timeout_ms)) {
            return 0;
        }
    }
    return 1;
}

static void video_upload_palette(unsigned int buffer_index)
{
    uint32_t bit = 1u << (buffer_index & 1u);
    unsigned int i;

    if ((ui_palette_uploaded_mask & bit) != 0u) {
        return;
    }

    HAZARD3_VIDEO_PALETTE_INDEX = (uint32_t)((buffer_index & 1u) << 8);
    for (i = 0u; i < 256u; ++i) {
        uint8_t color = i < sizeof(ui_palette) ? ui_palette[i] : 0u;
        HAZARD3_VIDEO_PALETTE_DATA = color;
    }
    ui_palette_uploaded_mask |= bit;
}

static int video_present(void)
{
    const volatile uint32_t* source =
        (const volatile uint32_t*)(uintptr_t)ui_framebuffer();
    size_t word_count = ui_physical_words();
    uint32_t status;
    uint32_t present_before;
    uint32_t started;
    uint32_t control;
    size_t i;

    status = HAZARD3_VIDEO_STATUS;

    if (ui_gui_resolution != 0) {
        if ((status & HAZARD3_VIDEO_STATUS_GUI_RES_SUPPORTED) == 0u) {
            return 0;
        }
        if (!video_wait_idle(UI_PRESENT_TIMEOUT_MS)) {
            return 0;
        }

        /*
         * The GUI is drawn as packed 4-bpp pixels in the uncached workbuffer.
         * PRESENT copies 38,400 halfwords into the inactive existing EBR bank,
         * then changes to 512x300 mode at vertical blank. There is no continuous
         * SDRAM scanout and no additional full-frame EBR allocation.
         */
        video_upload_palette(0u);
        present_before = HAZARD3_VIDEO_PRESENT_COUNT;
        HAZARD3_VIDEO_CONTROL =
            HAZARD3_VIDEO_CONTROL_INDEXED |
            HAZARD3_VIDEO_CONTROL_GUI_RES |
            HAZARD3_VIDEO_CONTROL_PRESENT;

        started = hazard3_ticks_ms();
        for (;;) {
            status = HAZARD3_VIDEO_STATUS;
            if ((status & HAZARD3_VIDEO_STATUS_PRESENT_PENDING) == 0u &&
                (status & HAZARD3_VIDEO_STATUS_GUI_RES_ACTIVE) != 0u &&
                HAZARD3_VIDEO_PRESENT_COUNT != present_before) {
                break;
            }
            if (elapsed(hazard3_ticks_ms(), started, UI_PRESENT_TIMEOUT_MS)) {
                return 0;
            }
        }
        return 1;
    }

    if ((status & HAZARD3_VIDEO_STATUS_DIRECT_SUPPORTED) == 0u) {
        return 0;
    }
    if (!video_wait_idle(UI_PRESENT_TIMEOUT_MS)) {
        return 0;
    }

    /*
     * STATUS_FRONT_BUFFER is the external/source buffer number.  The direct
     * APB path writes the internal EBR banks, so choose the bank opposite the
     * actual active internal bank (STATUS_INTERNAL_BUFFER).  These values can
     * differ after an SDRAM-to-EBR presentation by the resident monitor.
     */
    status = HAZARD3_VIDEO_STATUS;
    ui_back_buffer = (status & HAZARD3_VIDEO_STATUS_INTERNAL_BUFFER) != 0u
        ? 0u : 1u;

    HAZARD3_VIDEO_DIRECT_ADDRESS = hazard3_video_direct_halfword_base(
        ui_back_buffer, ui_high_resolution);
    for (i = 0u; i < word_count; ++i) {
        HAZARD3_VIDEO_DIRECT_DATA = source[i];
    }

    video_upload_palette((unsigned int)ui_back_buffer);
    present_before = HAZARD3_VIDEO_PRESENT_COUNT;
    control = HAZARD3_VIDEO_CONTROL_INDEXED |
              HAZARD3_VIDEO_CONTROL_DIRECT |
              HAZARD3_VIDEO_CONTROL_PRESENT;
    if (ui_high_resolution != 0) {
        control |= HAZARD3_VIDEO_CONTROL_HIGH_RES;
    }
    if (ui_back_buffer != 0u) {
        control |= HAZARD3_VIDEO_CONTROL_BUFFER1;
    }
    HAZARD3_VIDEO_CONTROL = control;

    started = hazard3_ticks_ms();
    for (;;) {
        status = HAZARD3_VIDEO_STATUS;
        if ((status & HAZARD3_VIDEO_STATUS_PRESENT_PENDING) == 0u &&
            HAZARD3_VIDEO_PRESENT_COUNT != present_before) {
            break;
        }
        if (elapsed(hazard3_ticks_ms(), started, UI_PRESENT_TIMEOUT_MS)) {
            return 0;
        }
    }

    return 1;
}

static void trace_clear(void)
{
    ui_trace_used = 0u;
}

static void trace_add(uint8_t kind, uint8_t value, uint8_t ack)
{
    if (ui_trace_used < UI_TRACE_COUNT) {
        ui_trace[ui_trace_used].kind = kind;
        ui_trace[ui_trace_used].value = value;
        ui_trace[ui_trace_used].ack = ack;
        ++ui_trace_used;
    }
}

static void trace_start(void)
{
    trace_add(TRACE_START, 0u, 0u);
}

static void trace_stop(void)
{
    trace_add(TRACE_STOP, 0u, 0u);
}

static void trace_byte(uint8_t value, uint8_t ack)
{
    trace_add(TRACE_BYTE, value, ack);
}

static void event_add(
    uint8_t kind,
    uint8_t address,
    uint8_t reg,
    uint8_t value,
    uint8_t extra,
    int result)
{
    struct ui_event* event = &ui_events[ui_event_head];

    event->kind = kind;
    event->address = address;
    event->reg = reg;
    event->value = value;
    event->extra = extra;
    event->result = result;
    ui_event_head = (ui_event_head + 1u) % UI_LOG_COUNT;
    if (ui_event_used < UI_LOG_COUNT) {
        ++ui_event_used;
    }
}

static const char* result_text(int result)
{
    switch (result) {
    case HAZARD3_SAO_OK:           return "OK";
    case HAZARD3_SAO_ERR_NACK:     return "NACK";
    case HAZARD3_SAO_ERR_TIMEOUT:  return "TIMEOUT";
    case HAZARD3_SAO_ERR_REJECTED: return "REJECT";
    case HAZARD3_SAO_ERR_ARGUMENT: return "ARG";
    default:                       return "ERROR";
    }
}

static void draw_event(unsigned int x, unsigned int y, const struct ui_event* event)
{
    uint8_t color = event->result == HAZARD3_SAO_OK ? UI_COLOR_GREEN : UI_COLOR_ORANGE;

    switch (event->kind) {
    case EVENT_SCAN:
        ui_text(x, y, "SCAN", UI_COLOR_CYAN);
        ui_uint(x + 20u, y, event->extra, UI_COLOR_WHITE);
        ui_text(x + 36u, y, "DEV", UI_COLOR_GRAY);
        break;
    case EVENT_PROBE:
        ui_text(x, y, "P", UI_COLOR_CYAN);
        ui_hex8(x + 8u, y, event->address, UI_COLOR_WHITE);
        ui_text(x + 20u, y, result_text(event->result), color);
        break;
    case EVENT_READ:
        ui_text(x, y, "R", UI_COLOR_CYAN);
        ui_hex8(x + 8u, y, event->address, UI_COLOR_WHITE);
        ui_text(x + 16u, y, ":", UI_COLOR_GRAY);
        ui_hex8(x + 20u, y, event->reg, UI_COLOR_WHITE);
        ui_text(x + 28u, y, "=", UI_COLOR_GRAY);
        if (event->result == HAZARD3_SAO_OK) {
            ui_hex8(x + 32u, y, event->value, UI_COLOR_YELLOW);
        } else {
            ui_text(x + 32u, y, result_text(event->result), color);
        }
        break;
    case EVENT_WRITE:
        ui_text(x, y, "W", UI_COLOR_CYAN);
        ui_hex8(x + 8u, y, event->address, UI_COLOR_WHITE);
        ui_text(x + 16u, y, ":", UI_COLOR_GRAY);
        ui_hex8(x + 20u, y, event->reg, UI_COLOR_WHITE);
        ui_text(x + 28u, y, "=", UI_COLOR_GRAY);
        ui_hex8(x + 32u, y, event->value, UI_COLOR_YELLOW);
        ui_text(x + 44u, y, result_text(event->result), color);
        break;
    case EVENT_RECOVER:
        ui_text(x, y, "RECOVER", UI_COLOR_CYAN);
        ui_text(x + 32u, y, result_text(event->result), color);
        break;
    case EVENT_SPEED:
        ui_text(x, y, "SPEED", UI_COLOR_CYAN);
        ui_text(x + 24u, y, event->extra == 4u ? "400K" : "100K", UI_COLOR_WHITE);
        break;
    default:
        break;
    }
}

static uint8_t heat_color(uint8_t heat)
{
    if (heat >= 48u) {
        return UI_COLOR_YELLOW;
    }
    if (heat >= 24u) {
        return UI_COLOR_GREEN;
    }
    if (heat != 0u) {
        return UI_COLOR_DARK_GREEN;
    }
    return UI_COLOR_PANEL;
}

static void draw_heatmap(void)
{
    unsigned int row;
    unsigned int col;
    unsigned int address;
    static const char digits[] = "0123456789ABCDEF";

    ui_text(2u, 22u, "I2C ADDRESS HEATMAP", UI_COLOR_CYAN);
    for (col = 0u; col < 16u; ++col) {
        ui_char(22u + col * 10u, 30u, digits[col], UI_COLOR_GRAY);
    }
    for (row = 0u; row < 8u; ++row) {
        ui_char(7u, 39u + row * 13u, digits[row], UI_COLOR_GRAY);
        for (col = 0u; col < 16u; ++col) {
            unsigned int x = 18u + col * 10u;
            unsigned int y = 37u + row * 13u;
            uint8_t background;
            uint8_t foreground;

            address = row * 16u + col;
            if (address < 0x08u || address > 0x77u) {
                background = UI_COLOR_BLACK;
                foreground = UI_COLOR_DARK_GRAY;
            } else {
                background = heat_color(ui_heat[address]);
                foreground = ui_heat[address] >= 48u ? UI_COLOR_BLACK : UI_COLOR_WHITE;
            }
            ui_fill_rect(x, y, 9u, 10u, background);
            if (address == ui_last_address && ui_last_result != HAZARD3_SAO_OK) {
                ui_box(x, y, 9u, 10u, UI_COLOR_ORANGE);
            }
            ui_hex8(x + 1u, y + 2u, (uint8_t)address, foreground);
        }
    }
}

static void draw_log(void)
{
    size_t i;
    size_t index;

    ui_text(185u, 22u, "TRANSACTION LOG", UI_COLOR_CYAN);
    ui_box(183u, 29u, 136u, 108u, UI_COLOR_DARK_GRAY);
    for (i = 0u; i < ui_event_used; ++i) {
        index = (ui_event_head + UI_LOG_COUNT - ui_event_used + i) % UI_LOG_COUNT;
        draw_event(187u, 34u + (unsigned int)i * 12u, &ui_events[index]);
    }
}

static void wave_segment(
    unsigned int* x,
    unsigned int width,
    unsigned int y,
    int high,
    uint8_t color)
{
    unsigned int yy = high ? y : y + 6u;

    if (*x + width >= ui_canvas_width()) {
        return;
    }
    ui_hline(*x, *x + width, yy, color);
    *x += width;
}

static void wave_transition(unsigned int x, unsigned int y, int from_high, int to_high, uint8_t color)
{
    unsigned int y0 = from_high ? y : y + 6u;
    unsigned int y1 = to_high ? y : y + 6u;

    if (y0 < y1) {
        ui_vline(x, y0, y1, color);
    } else {
        ui_vline(x, y1, y0, color);
    }
}

static void draw_waveform(void)
{
    unsigned int x = 27u;
    unsigned int i;
    unsigned int bit;
    unsigned int cell = 3u;
    int sda_high = 1;

    ui_text(2u, 143u, "LOGICAL TRACE", UI_COLOR_CYAN);
    ui_text(2u, 153u, "SDA", UI_COLOR_WHITE);
    ui_text(2u, 167u, "SCL", UI_COLOR_WHITE);
    ui_hline(26u, 317u, 153u, UI_COLOR_DARK_GRAY);
    ui_hline(26u, 317u, 167u, UI_COLOR_DARK_GRAY);

    for (i = 0u; i < ui_trace_used && x < 314u; ++i) {
        const struct ui_trace_item* item = &ui_trace[i];

        if (item->kind == TRACE_START) {
            wave_segment(&x, 2u, 153u, 1, UI_COLOR_YELLOW);
            wave_transition(x, 153u, 1, 0, UI_COLOR_YELLOW);
            sda_high = 0;
            wave_segment(&x, 2u, 153u, 0, UI_COLOR_YELLOW);
            ui_hline(x - 4u, x, 167u, UI_COLOR_CYAN);
            continue;
        }
        if (item->kind == TRACE_STOP) {
            wave_segment(&x, 2u, 153u, 0, UI_COLOR_YELLOW);
            wave_transition(x, 153u, 0, 1, UI_COLOR_YELLOW);
            sda_high = 1;
            wave_segment(&x, 2u, 153u, 1, UI_COLOR_YELLOW);
            ui_hline(x - 4u, x, 167u, UI_COLOR_CYAN);
            continue;
        }
        if (item->kind != TRACE_BYTE) {
            continue;
        }

        for (bit = 0u; bit < 9u && x + cell < 318u; ++bit) {
            int next_sda;
            uint8_t sda_color = UI_COLOR_YELLOW;
            uint8_t scl_color = UI_COLOR_CYAN;

            if (bit < 8u) {
                next_sda = (item->value & (uint8_t)(0x80u >> bit)) != 0u;
            } else {
                next_sda = item->ack == TRACE_ACK ? 0 : 1;
                if (item->ack == TRACE_ACK) {
                    sda_color = UI_COLOR_GREEN;
                } else if (item->ack == TRACE_MASTER_NACK) {
                    sda_color = UI_COLOR_ORANGE;
                } else {
                    sda_color = UI_COLOR_RED;
                }
            }
            if (next_sda != sda_high) {
                wave_transition(x, 153u, sda_high, next_sda, sda_color);
            }
            sda_high = next_sda;
            wave_segment(&x, cell, 153u, sda_high, sda_color);

            ui_hline(x - cell, x - cell + 1u, 173u, scl_color);
            ui_vline(x - cell + 1u, 167u, 173u, scl_color);
            ui_hline(x - cell + 1u, x - 1u, 167u, scl_color);
            ui_vline(x - 1u, 167u, 173u, scl_color);
        }
    }
}

static void draw_event_high(unsigned int x, unsigned int y, const struct ui_event* event)
{
    uint8_t color = event->result == HAZARD3_SAO_OK ? UI_COLOR_GREEN : UI_COLOR_ORANGE;

    switch (event->kind) {
    case EVENT_SCAN:
        ui_text(x, y, "SCAN", UI_COLOR_CYAN);
        ui_uint(x + 30u, y, event->extra, UI_COLOR_WHITE);
        ui_text(x + 60u, y, "DEV", UI_COLOR_GRAY);
        break;
    case EVENT_PROBE:
        ui_text(x, y, "P", UI_COLOR_CYAN);
        ui_hex8(x + 12u, y, event->address, UI_COLOR_WHITE);
        ui_text(x + 30u, y, result_text(event->result), color);
        break;
    case EVENT_READ:
        ui_text(x, y, "R", UI_COLOR_CYAN);
        ui_hex8(x + 12u, y, event->address, UI_COLOR_WHITE);
        ui_text(x + 24u, y, ":", UI_COLOR_GRAY);
        ui_hex8(x + 30u, y, event->reg, UI_COLOR_WHITE);
        ui_text(x + 42u, y, "=", UI_COLOR_GRAY);
        if (event->result == HAZARD3_SAO_OK) {
            ui_hex8(x + 48u, y, event->value, UI_COLOR_YELLOW);
        } else {
            ui_text(x + 48u, y, result_text(event->result), color);
        }
        break;
    case EVENT_WRITE:
        ui_text(x, y, "W", UI_COLOR_CYAN);
        ui_hex8(x + 12u, y, event->address, UI_COLOR_WHITE);
        ui_text(x + 24u, y, ":", UI_COLOR_GRAY);
        ui_hex8(x + 30u, y, event->reg, UI_COLOR_WHITE);
        ui_text(x + 42u, y, "=", UI_COLOR_GRAY);
        ui_hex8(x + 48u, y, event->value, UI_COLOR_YELLOW);
        ui_text(x + 66u, y, result_text(event->result), color);
        break;
    case EVENT_RECOVER:
        ui_text(x, y, "RECOVER", UI_COLOR_CYAN);
        ui_text(x + 48u, y, result_text(event->result), color);
        break;
    case EVENT_SPEED:
        ui_text(x, y, "SPEED", UI_COLOR_CYAN);
        ui_text(x + 36u, y, event->extra == 4u ? "400K" : "100K", UI_COLOR_WHITE);
        break;
    default:
        break;
    }
}

static void draw_heatmap_high(void)
{
    unsigned int row;
    unsigned int col;
    unsigned int address;
    static const char digits[] = "0123456789ABCDEF";

    ui_text(4u, 26u, "I2C ADDRESS HEATMAP", UI_COLOR_CYAN);
    for (col = 0u; col < 16u; ++col) {
        ui_char(29u + col * 12u, 35u, digits[col], UI_COLOR_GRAY);
    }
    for (row = 0u; row < 8u; ++row) {
        ui_char(8u, 47u + row * 14u, digits[row], UI_COLOR_GRAY);
        for (col = 0u; col < 16u; ++col) {
            unsigned int x = 24u + col * 12u;
            unsigned int y = 44u + row * 14u;
            uint8_t background;
            uint8_t foreground;

            address = row * 16u + col;
            if (address < 0x08u || address > 0x77u) {
                background = UI_COLOR_BLACK;
                foreground = UI_COLOR_DARK_GRAY;
            } else {
                background = heat_color(ui_heat[address]);
                foreground = ui_heat[address] >= 48u ? UI_COLOR_BLACK : UI_COLOR_WHITE;
            }
            ui_fill_rect(x, y, 11u, 12u, background);
            if (address == ui_last_address && ui_last_result != HAZARD3_SAO_OK) {
                ui_box(x, y, 11u, 12u, UI_COLOR_ORANGE);
            }
            ui_hex8(x, y + 2u, (uint8_t)address, foreground);
        }
    }
}

static void draw_log_high(void)
{
    size_t i;
    size_t index;

    ui_text(222u, 26u, "TRANSACTION LOG", UI_COLOR_CYAN);
    ui_box(220u, 35u, 177u, 124u, UI_COLOR_DARK_GRAY);
    for (i = 0u; i < ui_event_used; ++i) {
        index = (ui_event_head + UI_LOG_COUNT - ui_event_used + i) % UI_LOG_COUNT;
        draw_event_high(225u, 40u + (unsigned int)i * 14u, &ui_events[index]);
    }
}

static void draw_waveform_high(void)
{
    unsigned int x = 35u;
    unsigned int i;
    unsigned int bit;
    unsigned int cell = 3u;
    int sda_high = 1;

    ui_text(4u, 166u, "LOGICAL TRACE", UI_COLOR_CYAN);
    ui_text(4u, 179u, "SDA", UI_COLOR_WHITE);
    ui_text(4u, 197u, "SCL", UI_COLOR_WHITE);
    ui_hline(34u, 396u, 182u, UI_COLOR_DARK_GRAY);
    ui_hline(34u, 396u, 200u, UI_COLOR_DARK_GRAY);

    for (i = 0u; i < ui_trace_used && x < 393u; ++i) {
        const struct ui_trace_item* item = &ui_trace[i];

        if (item->kind == TRACE_START) {
            wave_segment(&x, 2u, 179u, 1, UI_COLOR_YELLOW);
            wave_transition(x, 179u, 1, 0, UI_COLOR_YELLOW);
            sda_high = 0;
            wave_segment(&x, 2u, 179u, 0, UI_COLOR_YELLOW);
            ui_hline(x - 4u, x, 197u, UI_COLOR_CYAN);
            continue;
        }
        if (item->kind == TRACE_STOP) {
            wave_segment(&x, 2u, 179u, 0, UI_COLOR_YELLOW);
            wave_transition(x, 179u, 0, 1, UI_COLOR_YELLOW);
            sda_high = 1;
            wave_segment(&x, 2u, 179u, 1, UI_COLOR_YELLOW);
            ui_hline(x - 4u, x, 197u, UI_COLOR_CYAN);
            continue;
        }
        if (item->kind != TRACE_BYTE) {
            continue;
        }

        for (bit = 0u; bit < 9u && x + cell < 397u; ++bit) {
            int next_sda;
            uint8_t sda_color = UI_COLOR_YELLOW;
            uint8_t scl_color = UI_COLOR_CYAN;

            if (bit < 8u) {
                next_sda = (item->value & (uint8_t)(0x80u >> bit)) != 0u;
            } else {
                next_sda = item->ack == TRACE_ACK ? 0 : 1;
                if (item->ack == TRACE_ACK) {
                    sda_color = UI_COLOR_GREEN;
                } else if (item->ack == TRACE_MASTER_NACK) {
                    sda_color = UI_COLOR_ORANGE;
                } else {
                    sda_color = UI_COLOR_RED;
                }
            }
            if (next_sda != sda_high) {
                wave_transition(x, 179u, sda_high, next_sda, sda_color);
            }
            sda_high = next_sda;
            wave_segment(&x, cell, 179u, sda_high, sda_color);

            ui_hline(x - cell, x - cell + 1u, 206u, scl_color);
            ui_vline(x - cell + 1u, 200u, 206u, scl_color);
            ui_hline(x - cell + 1u, x - 1u, 200u, scl_color);
            ui_vline(x - 1u, 200u, 206u, scl_color);
        }
    }
}

static void draw_header_high(void)
{
    uint32_t status = hazard3_sao_status();

    ui_fill_rect(0u, 0u, UI_HIGH_WIDTH, 22u, UI_COLOR_NAVY);
    ui_text(4u, 2u, "HAZARD3 I2CDRIVER", UI_COLOR_WHITE);
    ui_text(112u, 2u, ui_i2c_hz == UI_I2C_400KHZ ? "400 KHZ" : "100 KHZ", UI_COLOR_YELLOW);
    ui_text(166u, 2u, "SDA", UI_COLOR_GRAY);
    ui_char(190u, 2u, (status & HAZARD3_SAO_STATUS_SDA) != 0u ? '1' : '0', UI_COLOR_GREEN);
    ui_text(204u, 2u, "SCL", UI_COLOR_GRAY);
    ui_char(228u, 2u, (status & HAZARD3_SAO_STATUS_SCL) != 0u ? '1' : '0', UI_COLOR_GREEN);
    ui_text(244u, 2u, "ACTIVE MASTER", UI_COLOR_CYAN);
    ui_text(352u, 2u, "400X240", UI_COLOR_YELLOW);
    ui_text(4u, 12u, ui_message, ui_last_result == HAZARD3_SAO_OK ? UI_COLOR_GREEN : UI_COLOR_ORANGE);
}

static void draw_footer_high(void)
{
    size_t i;
    unsigned int x;

    ui_fill_rect(0u, 216u, UI_HIGH_WIDTH, 24u, UI_COLOR_NAVY);
    if (ui_prompt_mode == PROMPT_NONE) {
        ui_text(4u, 219u, "S SCAN P PROBE R READ W WRITE X RECOVER 1/4 SPEED H 512 G 400", UI_COLOR_WHITE);
        ui_text(4u, 230u, "C CLEAR Q EXIT  TRACE: INITIATED ONLY - PASSIVE NEEDS FPGA FIFO", UI_COLOR_GRAY);
        return;
    }

    if (ui_prompt_mode == PROMPT_PROBE) {
        ui_text(4u, 219u, "PROBE ADDR HEX: ", UI_COLOR_WHITE);
        x = 100u;
    } else if (ui_prompt_mode == PROMPT_READ) {
        ui_text(4u, 219u, "READ ADDR REG HEX: ", UI_COLOR_WHITE);
        x = 118u;
    } else {
        ui_text(4u, 219u, "WRITE ADDR REG VALUE HEX: ", UI_COLOR_WHITE);
        x = 154u;
    }
    for (i = 0u; i < ui_prompt_length; ++i) {
        ui_char(x + (unsigned int)i * 6u, 219u, "0123456789ABCDEF"[ui_prompt_digits[i]], UI_COLOR_YELLOW);
    }
    ui_text(4u, 230u, "ENTER EXECUTES  BACKSPACE EDITS  ESC CANCELS", UI_COLOR_GRAY);
}


static void draw_heatmap_gui(void)
{
    unsigned int row;
    unsigned int col;
    unsigned int address;
    static const char digits[] = "0123456789ABCDEF";

    ui_text(6u, 29u, "I2C ADDRESS HEATMAP", UI_COLOR_CYAN);
    for (col = 0u; col < 16u; ++col) {
        ui_char(29u + col * 16u, 41u, digits[col], UI_COLOR_GRAY);
    }
    for (row = 0u; row < 8u; ++row) {
        ui_char(7u, 55u + row * 16u, digits[row], UI_COLOR_GRAY);
        for (col = 0u; col < 16u; ++col) {
            unsigned int x = 23u + col * 16u;
            unsigned int y = 51u + row * 16u;
            uint8_t background;
            uint8_t foreground;

            address = row * 16u + col;
            if (address < 0x08u || address > 0x77u) {
                background = UI_COLOR_BLACK;
                foreground = UI_COLOR_DARK_GRAY;
            } else {
                background = heat_color(ui_heat[address]);
                foreground = ui_heat[address] >= 48u
                    ? UI_COLOR_BLACK : UI_COLOR_WHITE;
            }
            ui_fill_rect(x, y, 14u, 13u, background);
            if (address == ui_last_address &&
                ui_last_result != HAZARD3_SAO_OK) {
                ui_box(x, y, 14u, 13u, UI_COLOR_ORANGE);
            }
            ui_hex8(x + 1u, y + 3u, (uint8_t)address, foreground);
        }
    }
}

static void draw_log_gui(void)
{
    size_t i;
    size_t index;

    ui_text(310u, 29u, "TRANSACTION LOG", UI_COLOR_CYAN);
    ui_box(306u, 44u, 200u, 132u, UI_COLOR_DARK_GRAY);
    for (i = 0u; i < ui_event_used; ++i) {
        index = (ui_event_head + UI_LOG_COUNT - ui_event_used + i)
            % UI_LOG_COUNT;
        draw_event_high(312u, 51u + (unsigned int)i * 15u,
            &ui_events[index]);
    }
}

static void draw_waveform_gui(void)
{
    unsigned int x = 42u;
    unsigned int i;
    unsigned int bit;
    unsigned int cell = 4u;
    int sda_high = 1;

    ui_text(6u, 184u, "LOGICAL TRACE", UI_COLOR_CYAN);
    ui_text(6u, 199u, "SDA", UI_COLOR_WHITE);
    ui_text(6u, 225u, "SCL", UI_COLOR_WHITE);
    ui_hline(40u, 505u, 202u, UI_COLOR_DARK_GRAY);
    ui_hline(40u, 505u, 228u, UI_COLOR_DARK_GRAY);

    for (i = 0u; i < ui_trace_used && x < 502u; ++i) {
        const struct ui_trace_item* item = &ui_trace[i];

        if (item->kind == TRACE_START) {
            wave_segment(&x, 3u, 199u, 1, UI_COLOR_YELLOW);
            wave_transition(x, 199u, 1, 0, UI_COLOR_YELLOW);
            sda_high = 0;
            wave_segment(&x, 3u, 199u, 0, UI_COLOR_YELLOW);
            ui_hline(x - 6u, x, 225u, UI_COLOR_CYAN);
            continue;
        }
        if (item->kind == TRACE_STOP) {
            wave_segment(&x, 3u, 199u, 0, UI_COLOR_YELLOW);
            wave_transition(x, 199u, 0, 1, UI_COLOR_YELLOW);
            sda_high = 1;
            wave_segment(&x, 3u, 199u, 1, UI_COLOR_YELLOW);
            ui_hline(x - 6u, x, 225u, UI_COLOR_CYAN);
            continue;
        }
        if (item->kind != TRACE_BYTE) {
            continue;
        }

        for (bit = 0u; bit < 9u && x + cell < 506u; ++bit) {
            int next_sda;
            uint8_t sda_color = UI_COLOR_YELLOW;
            uint8_t scl_color = UI_COLOR_CYAN;

            if (bit < 8u) {
                next_sda =
                    (item->value & (uint8_t)(0x80u >> bit)) != 0u;
            } else {
                next_sda = item->ack == TRACE_ACK ? 0 : 1;
                if (item->ack == TRACE_ACK) {
                    sda_color = UI_COLOR_GREEN;
                } else if (item->ack == TRACE_MASTER_NACK) {
                    sda_color = UI_COLOR_ORANGE;
                } else {
                    sda_color = UI_COLOR_RED;
                }
            }
            if (next_sda != sda_high) {
                wave_transition(x, 199u, sda_high, next_sda, sda_color);
            }
            sda_high = next_sda;
            wave_segment(&x, cell, 199u, sda_high, sda_color);

            ui_hline(x - cell, x - cell + 1u, 234u, scl_color);
            ui_vline(x - cell + 1u, 228u, 234u, scl_color);
            ui_hline(x - cell + 1u, x - 1u, 228u, scl_color);
            ui_vline(x - 1u, 228u, 234u, scl_color);
        }
    }
}

static void draw_header_gui(void)
{
    uint32_t status = hazard3_sao_status();

    ui_fill_rect(0u, 0u, UI_GUI_WIDTH, 24u, UI_COLOR_NAVY);
    ui_text(6u, 2u, "HAZARD3 I2CDRIVER", UI_COLOR_WHITE);
    ui_text(126u, 2u,
        ui_i2c_hz == UI_I2C_400KHZ ? "400 KHZ" : "100 KHZ",
        UI_COLOR_YELLOW);
    ui_text(184u, 2u, "SDA", UI_COLOR_GRAY);
    ui_char(208u, 2u,
        (status & HAZARD3_SAO_STATUS_SDA) != 0u ? '1' : '0',
        UI_COLOR_GREEN);
    ui_text(224u, 2u, "SCL", UI_COLOR_GRAY);
    ui_char(248u, 2u,
        (status & HAZARD3_SAO_STATUS_SCL) != 0u ? '1' : '0',
        UI_COLOR_GREEN);
    ui_text(270u, 2u, "ACTIVE MASTER", UI_COLOR_CYAN);
    ui_text(464u, 2u, "512X300", UI_COLOR_YELLOW);
    ui_text(6u, 13u, ui_message,
        ui_last_result == HAZARD3_SAO_OK
            ? UI_COLOR_GREEN : UI_COLOR_ORANGE);
}

static void draw_footer_gui(void)
{
    size_t i;
    unsigned int x;

    ui_fill_rect(0u, 258u, UI_GUI_WIDTH, 42u, UI_COLOR_NAVY);
    if (ui_prompt_mode == PROMPT_NONE) {
        ui_text(6u, 264u,
            "S SCAN  P PROBE  R READ  W WRITE  X RECOVER  1/4 SPEED",
            UI_COLOR_WHITE);
        ui_text(6u, 278u,
            "H 512/320  G 400 TEST  C CLEAR  Q EXIT",
            UI_COLOR_GRAY);
        ui_text(274u, 278u,
            "TRACE: INITIATED TRAFFIC ONLY",
            UI_COLOR_DARK_GRAY);
        return;
    }

    if (ui_prompt_mode == PROMPT_PROBE) {
        ui_text(6u, 264u, "PROBE ADDR HEX: ", UI_COLOR_WHITE);
        x = 102u;
    } else if (ui_prompt_mode == PROMPT_READ) {
        ui_text(6u, 264u, "READ ADDR REG HEX: ", UI_COLOR_WHITE);
        x = 120u;
    } else {
        ui_text(6u, 264u, "WRITE ADDR REG VALUE HEX: ", UI_COLOR_WHITE);
        x = 156u;
    }
    for (i = 0u; i < ui_prompt_length; ++i) {
        ui_char(x + (unsigned int)i * 6u, 264u,
            "0123456789ABCDEF"[ui_prompt_digits[i]], UI_COLOR_YELLOW);
    }
    ui_text(6u, 280u,
        "ENTER EXECUTES  BACKSPACE EDITS  ESC CANCELS",
        UI_COLOR_GRAY);
}

static void draw_header(void)
{
    uint32_t status = hazard3_sao_status();

    ui_fill_rect(0u, 0u, UI_WIDTH, 18u, UI_COLOR_NAVY);
    ui_text(3u, 3u, "HAZARD3 I2CDRIVER", UI_COLOR_WHITE);
    ui_text(82u, 3u, ui_i2c_hz == UI_I2C_400KHZ ? "400 KHZ" : "100 KHZ", UI_COLOR_YELLOW);
    ui_text(123u, 3u, "SDA", UI_COLOR_GRAY);
    ui_char(139u, 3u, (status & HAZARD3_SAO_STATUS_SDA) != 0u ? '1' : '0', UI_COLOR_GREEN);
    ui_text(147u, 3u, "SCL", UI_COLOR_GRAY);
    ui_char(163u, 3u, (status & HAZARD3_SAO_STATUS_SCL) != 0u ? '1' : '0', UI_COLOR_GREEN);
    ui_text(173u, 3u, "ACTIVE MASTER", UI_COLOR_CYAN);
    ui_text(231u, 3u, "320X200", UI_COLOR_YELLOW);
    ui_text(3u, 11u, ui_message, ui_last_result == HAZARD3_SAO_OK ? UI_COLOR_GREEN : UI_COLOR_ORANGE);
}

static void draw_footer(void)
{
    size_t i;
    unsigned int x;

    ui_fill_rect(0u, 181u, UI_WIDTH, 19u, UI_COLOR_NAVY);
    if (ui_prompt_mode == PROMPT_NONE) {
        ui_text(3u, 184u, "S SCAN P PROBE R READ W WRITE X RECOVER 1/4 SPEED H 512 Q EXIT", UI_COLOR_WHITE);
        ui_text(3u, 192u, "TRACE IS INITIATED TRAFFIC - PASSIVE CAPTURE NEEDS FPGA FIFO", UI_COLOR_GRAY);
        return;
    }

    if (ui_prompt_mode == PROMPT_PROBE) {
        ui_text(3u, 184u, "PROBE ADDR HEX: ", UI_COLOR_WHITE);
    } else if (ui_prompt_mode == PROMPT_READ) {
        ui_text(3u, 184u, "READ ADDR REG HEX: ", UI_COLOR_WHITE);
    } else {
        ui_text(3u, 184u, "WRITE ADDR REG VALUE HEX: ", UI_COLOR_WHITE);
    }
    x = ui_prompt_mode == PROMPT_PROBE ? 67u :
        (ui_prompt_mode == PROMPT_READ ? 79u : 103u);
    for (i = 0u; i < ui_prompt_length; ++i) {
        ui_char(x + (unsigned int)i * 4u, 184u, "0123456789ABCDEF"[ui_prompt_digits[i]], UI_COLOR_YELLOW);
    }
    ui_text(3u, 192u, "ENTER EXECUTES  BACKSPACE EDITS  ESC CANCELS", UI_COLOR_GRAY);
}

static void draw_screen(void)
{
    ui_clear(UI_COLOR_BLACK);
    if (ui_gui_resolution != 0) {
        draw_header_gui();
        draw_heatmap_gui();
        draw_log_gui();
        draw_waveform_gui();
        draw_footer_gui();
        return;
    }
    if (ui_high_resolution != 0) {
        draw_header_high();
        draw_heatmap_high();
        draw_log_high();
        draw_waveform_high();
        draw_footer_high();
        return;
    }

    draw_header();
    draw_heatmap();
    draw_log();
    draw_waveform();
    draw_footer();
}

static int refresh_screen(void)
{
    draw_screen();
    return video_present();
}

static void set_message(const char* message, int result)
{
    ui_message = message;
    ui_last_result = result;
}

static void set_speed(uint32_t i2c_hz)
{
    ui_i2c_hz = i2c_hz;
    hazard3_sao_init(HAZARD3_SYS_CLK_HZ, i2c_hz);
    event_add(EVENT_SPEED, 0u, 0u, 0u, i2c_hz == UI_I2C_400KHZ ? 4u : 1u, HAZARD3_SAO_OK);
    set_message(i2c_hz == UI_I2C_400KHZ ? "BUS SPEED 400 KHZ" : "BUS SPEED 100 KHZ", HAZARD3_SAO_OK);
}

static int perform_probe(uint8_t address)
{
    int result = hazard3_sao_probe(address);

    trace_clear();
    trace_start();
    trace_byte((uint8_t)(address << 1), result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    trace_stop();
    ui_last_address = address;
    ui_last_reg = 0u;
    ui_last_value = 0u;
    if (result == HAZARD3_SAO_OK) {
        ui_heat[address] = UI_HEAT_MAX;
    }
    event_add(EVENT_PROBE, address, 0u, 0u, 0u, result);
    set_message(result == HAZARD3_SAO_OK ? "PROBE ACK" : result_text(result), result);
    return result;
}

static int perform_read(uint8_t address, uint8_t reg)
{
    uint8_t value = 0u;
    int result = hazard3_sao_read_reg8(address, reg, &value);

    trace_clear();
    trace_start();
    trace_byte((uint8_t)(address << 1), result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    trace_byte(reg, result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    trace_start();
    trace_byte((uint8_t)((address << 1) | 1u), result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    if (result == HAZARD3_SAO_OK) {
        trace_byte(value, TRACE_MASTER_NACK);
        ui_heat[address] = UI_HEAT_MAX;
    }
    trace_stop();
    ui_last_address = address;
    ui_last_reg = reg;
    ui_last_value = value;
    event_add(EVENT_READ, address, reg, value, 0u, result);
    set_message(result == HAZARD3_SAO_OK ? "REGISTER READ OK" : result_text(result), result);
    return result;
}

static int perform_write(uint8_t address, uint8_t reg, uint8_t value)
{
    int result = hazard3_sao_write_reg8(address, reg, value);

    trace_clear();
    trace_start();
    trace_byte((uint8_t)(address << 1), result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    trace_byte(reg, result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    trace_byte(value, result == HAZARD3_SAO_OK ? TRACE_ACK : TRACE_NACK);
    trace_stop();
    ui_last_address = address;
    ui_last_reg = reg;
    ui_last_value = value;
    if (result == HAZARD3_SAO_OK) {
        ui_heat[address] = UI_HEAT_MAX;
    }
    event_add(EVENT_WRITE, address, reg, value, 0u, result);
    set_message(result == HAZARD3_SAO_OK ? "REGISTER WRITE OK" : result_text(result), result);
    return result;
}

static void perform_recover(void)
{
    int result = hazard3_sao_recover();

    trace_clear();
    event_add(EVENT_RECOVER, 0u, 0u, 0u, 0u, result);
    set_message(result == HAZARD3_SAO_OK ? "BUS RECOVERY OK" : result_text(result), result);
}

static void perform_scan(void)
{
    uint8_t address;
    uint8_t last_found_address = 0u;
    size_t count = 0u;

    trace_clear();
    set_message("SCANNING 08-77", HAZARD3_SAO_OK);
    for (address = 0x08u; address <= 0x77u; ++address) {
        int result = hazard3_sao_probe(address);

        ui_last_address = address;
        ui_last_result = result;
        if (result == HAZARD3_SAO_OK) {
            ui_heat[address] = UI_HEAT_MAX;
            last_found_address = address;
            ++count;

            /* Keep the most recent ACKing scan probe as the logical trace. */
            trace_clear();
            trace_start();
            trace_byte((uint8_t)(address << 1), TRACE_ACK);
            trace_stop();
        }
        if ((address & 0x0fu) == 0x0fu) {
            draw_screen();
            (void)video_present();
        }
    }
    ui_last_scan_count = count;
    if (count != 0u) {
        ui_last_address = last_found_address;
        ui_last_result = HAZARD3_SAO_OK;
    }
    event_add(EVENT_SCAN, last_found_address, 0u, 0u, (uint8_t)count, HAZARD3_SAO_OK);
    set_message(count == 0u ? "SCAN COMPLETE - NO DEVICES" : "SCAN COMPLETE", HAZARD3_SAO_OK);
}

static void cool_heatmap(void)
{
    unsigned int address;

    for (address = 0x08u; address <= 0x77u; ++address) {
        if (ui_heat[address] != 0u) {
            --ui_heat[address];
        }
    }
}

static void prompt_begin(uint8_t mode)
{
    ui_prompt_mode = mode;
    ui_prompt_length = 0u;
    set_message("ENTER HEX OPERANDS", HAZARD3_SAO_OK);
}

static size_t prompt_required(void)
{
    if (ui_prompt_mode == PROMPT_PROBE) {
        return 2u;
    }
    if (ui_prompt_mode == PROMPT_READ) {
        return 4u;
    }
    if (ui_prompt_mode == PROMPT_WRITE) {
        return 6u;
    }
    return 0u;
}

static uint8_t prompt_byte(size_t offset)
{
    return (uint8_t)((ui_prompt_digits[offset] << 4) | ui_prompt_digits[offset + 1u]);
}

static void prompt_execute(void)
{
    if (ui_prompt_length != prompt_required()) {
        set_message("INCOMPLETE HEX INPUT", HAZARD3_SAO_ERR_ARGUMENT);
        return;
    }
    if (ui_prompt_mode == PROMPT_PROBE) {
        (void)perform_probe(prompt_byte(0u));
    } else if (ui_prompt_mode == PROMPT_READ) {
        (void)perform_read(prompt_byte(0u), prompt_byte(2u));
    } else if (ui_prompt_mode == PROMPT_WRITE) {
        (void)perform_write(prompt_byte(0u), prompt_byte(2u), prompt_byte(4u));
    }
    ui_prompt_mode = PROMPT_NONE;
    ui_prompt_length = 0u;
}

static int handle_prompt_key(uint8_t key)
{
    int digit;

    if (key == 0x1bu) {
        ui_prompt_mode = PROMPT_NONE;
        ui_prompt_length = 0u;
        set_message("INPUT CANCELLED", HAZARD3_SAO_OK);
        return 1;
    }
    if (key == 0x08u || key == 0x7fu) {
        if (ui_prompt_length != 0u) {
            --ui_prompt_length;
        }
        return 1;
    }
    if (key == (uint8_t)'\r' || key == (uint8_t)'\n') {
        prompt_execute();
        return 1;
    }
    digit = hex_digit((char)key);
    if (digit >= 0 && ui_prompt_length < prompt_required()) {
        ui_prompt_digits[ui_prompt_length++] = (uint8_t)digit;
        return 1;
    }
    return 0;
}

/* GCC 12.2.0 used by the Hazard3 toolchain can ICE when it turns a direct
 * capability-bit mask into an RTL constant. Keep these helpers out of line and
 * test bit zero after shifting. */
static __attribute__((noinline)) int video_high_resolution_supported(void)
{
    uint32_t status = HAZARD3_VIDEO_STATUS;
    volatile uint32_t shifted_status = status >> 11u;

    return (shifted_status & 1u) != 0u;
}

static __attribute__((noinline)) int video_gui_resolution_supported(void)
{
    uint32_t status = HAZARD3_VIDEO_STATUS;
    volatile uint32_t shifted_status = status >> 13u;

    return (shifted_status & 1u) != 0u;
}

static void toggle_resolution(void)
{
    if (ui_gui_resolution == 0 && !video_gui_resolution_supported()) {
        set_message("512X300 GUI NOT SUPPORTED BY FPGA", HAZARD3_SAO_ERR_REJECTED);
        return;
    }

    ui_gui_resolution = ui_gui_resolution == 0 ? 1 : 0;
    ui_high_resolution = 0;
    ui_palette_uploaded_mask = 0u;
    set_message(
        ui_gui_resolution != 0
            ? "HDMI SOURCE 512X300 GUI - EXACT 2X"
            : "HDMI SOURCE 320X200",
        HAZARD3_SAO_OK);
}

static void toggle_400_resolution(void)
{
    if (ui_high_resolution == 0 && !video_high_resolution_supported()) {
        set_message("400X240 NOT SUPPORTED BY FPGA", HAZARD3_SAO_ERR_REJECTED);
        return;
    }

    ui_high_resolution = ui_high_resolution == 0 ? 1 : 0;
    ui_gui_resolution = 0;
    ui_palette_uploaded_mask = 0u;
    set_message(
        ui_high_resolution != 0
            ? "HDMI SOURCE 400X240 TEST"
            : "HDMI SOURCE 320X200",
        HAZARD3_SAO_OK);
}

static int handle_idle_key(uint8_t key)
{
    key = (uint8_t)ascii_upper((char)key);
    switch (key) {
    case 'S':
        perform_scan();
        return 1;
    case 'P':
        prompt_begin(PROMPT_PROBE);
        return 1;
    case 'R':
        prompt_begin(PROMPT_READ);
        return 1;
    case 'W':
        prompt_begin(PROMPT_WRITE);
        return 1;
    case 'X':
        perform_recover();
        return 1;
    case '1':
        set_speed(UI_I2C_100KHZ);
        return 1;
    case '4':
        set_speed(UI_I2C_400KHZ);
        return 1;
    case 'H':
        toggle_resolution();
        return 1;
    case 'G':
        toggle_400_resolution();
        return 1;
    case 'C':
        for (key = 0u; key < 128u; ++key) {
            ui_heat[key] = 0u;
        }
        ui_event_used = 0u;
        ui_event_head = 0u;
        trace_clear();
        set_message("DISPLAY STATE CLEARED", HAZARD3_SAO_OK);
        return 1;
    default:
        return 0;
    }
}

static void initialize_state(void)
{
    size_t i;
    uint32_t status = HAZARD3_VIDEO_STATUS;

    for (i = 0u; i < sizeof(ui_heat); ++i) {
        ui_heat[i] = 0u;
    }
    for (i = 0u; i < UI_LOG_COUNT; ++i) {
        ui_events[i].kind = EVENT_NONE;
    }
    ui_trace_used = 0u;
    ui_event_head = 0u;
    ui_event_used = 0u;
    ui_prompt_mode = PROMPT_NONE;
    ui_prompt_length = 0u;
    ui_i2c_hz = UI_I2C_100KHZ;
    ui_palette_uploaded_mask = 0u;
    ui_high_resolution = 0;
    ui_gui_resolution = 0;
    ui_back_buffer = (status & HAZARD3_VIDEO_STATUS_INTERNAL_BUFFER) != 0u ? 0u : 1u;
    ui_last_address = 0xffu;
    ui_last_reg = 0u;
    ui_last_value = 0u;
    ui_last_result = HAZARD3_SAO_OK;
    ui_last_scan_count = 0u;
    ui_message = "READY";
}

void hazard3_i2cdriver_hdmi_run(void)
{
    uint32_t last_cool;
    uint32_t last_status_refresh;
    int running = 1;

    if (hazard3_sao_bridge_id() != HAZARD3_SAO_BRIDGE_ID) {
        hazard3_console_puts("I2CDriver HDMI: SAO bridge ID mismatch.\r\n");
        return;
    }
    if ((HAZARD3_VIDEO_STATUS & HAZARD3_VIDEO_STATUS_DIRECT_SUPPORTED) == 0u) {
        hazard3_console_puts("I2CDriver HDMI: direct indexed HDMI path is not supported by this bitstream.\r\n");
        return;
    }

    initialize_state();
    hazard3_sao_init(HAZARD3_SYS_CLK_HZ, UI_I2C_100KHZ);
    hazard3_console_puts("I2CDriver HDMI active. S scan, P probe, R read, W write, X recover, 1/4 speed, H 512/320, G 400 test, C clear, Q exit.\r\n");
    if (!refresh_screen()) {
        hazard3_console_puts("I2CDriver HDMI: initial HDMI presentation failed.\r\n");
        return;
    }

    last_cool = hazard3_ticks_ms();
    last_status_refresh = last_cool;
    while (running != 0) {
        uint32_t now = hazard3_ticks_ms();
        uint8_t key = 0u;
        int received = hazard3_console_getc_nonblocking(&key);
        int redraw = 0;

        if (received != 0) {
            if (key == UI_SCREEN_SNIP_CAPABILITY_REQUEST) {
                hazard3_console_putc(UI_SCREEN_SNIP_CAPABILITY_ACK);
                continue;
            }
            if (key == UI_SCREEN_SNIP_REQUEST) {
                screen_snip_send();
                continue;
            }
            if (key == 0x18u || key == (uint8_t)'q' || key == (uint8_t)'Q' ||
                (key == 0x1bu && ui_prompt_mode == PROMPT_NONE)) {
                running = 0;
                continue;
            }
            if (ui_prompt_mode != PROMPT_NONE) {
                redraw = handle_prompt_key(key);
            } else {
                redraw = handle_idle_key(key);
            }
        }

        if (elapsed(now, last_cool, UI_COOL_INTERVAL_MS)) {
            cool_heatmap();
            last_cool = now;
            redraw = 1;
        }
        if (elapsed(now, last_status_refresh, 200u)) {
            last_status_refresh = now;
            redraw = 1;
        }
        if (redraw != 0 && !refresh_screen()) {
            hazard3_console_puts("I2CDriver HDMI: HDMI presentation timeout.\r\n");
            break;
        }
    }

    /* Keep the ordinary monitor's documented/default I2C rate unchanged. */
    hazard3_sao_init(HAZARD3_SYS_CLK_HZ, UI_I2C_100KHZ);
    hazard3_console_puts("I2CDriver HDMI closed; SAO I2C restored to 100 kHz.\r\n");
}
