/* -----------------------------------------------------------------------------
 * File:        hazard3_video.h
 * Path:        doom/hazard3_video.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define the shared Hazard3 video register interface, framebuffer
 *              layout, and capabilities.
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

#ifndef HAZARD3_VIDEO_H
#define HAZARD3_VIDEO_H

#include <stdint.h>

#include "hazard3_memory_map.h"

#define HAZARD3_VIDEO_REG_BASE          0x4000c000u
#define HAZARD3_VIDEO_STATUS            \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x00u))
#define HAZARD3_VIDEO_CONTROL           \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x04u))
#define HAZARD3_VIDEO_PALETTE_INDEX     \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x08u))
#define HAZARD3_VIDEO_PALETTE_DATA      \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x0cu))
#define HAZARD3_VIDEO_FRAME_COUNT       \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x10u))
#define HAZARD3_VIDEO_DMA_CYCLES        \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x14u))
#define HAZARD3_VIDEO_PRESENT_COUNT     \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x18u))
#define HAZARD3_VIDEO_FPGA_BUILD_ID     \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x1cu))
#define HAZARD3_VIDEO_DDR_STATUS        \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x20u))
#define HAZARD3_VIDEO_DDR_CORE_BUILD_ID \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x24u))
#define HAZARD3_VIDEO_DDR_ADAPTER_BUILD_ID \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x28u))
#define HAZARD3_VIDEO_DIRECT_ADDRESS       \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x2cu))
#define HAZARD3_VIDEO_DIRECT_DATA          \
    (*(volatile uint32_t *)(HAZARD3_VIDEO_REG_BASE + 0x30u))

#define HAZARD3_FPGA_BUILD_ID_ULX4M_LD          0x4c445035u
#define HAZARD3_MEMORY_CORE_BUILD_ID_ULX4M_LD   0x32343132u
#define HAZARD3_MEMORY_ADAPTER_BUILD_ID_ULX4M_LD 0x41444c35u
#define HAZARD3_FPGA_BUILD_ID_ULX3S             0x554c5035u
#define HAZARD3_FPGA_BUILD_ID_ULX3S_12F         0x554c3132u
#define HAZARD3_MEMORY_CORE_BUILD_ID_ULX3S       0x53445235u
#define HAZARD3_MEMORY_ADAPTER_BUILD_ID_ULX3S    0x41485335u
#define HAZARD3_FIRMWARE_BUILD_ID                0x48335235u

/* Begin Build Info */
#define HAZARD3_STRINGIFY_INNER(value) #value
#define HAZARD3_STRINGIFY(value) HAZARD3_STRINGIFY_INNER(value)

#ifndef HAZARD3_FIRMWARE_MEMORY_PROFILE
    #ifdef HAZARD3_SDRAM_32MB
        #define HAZARD3_FIRMWARE_MEMORY_PROFILE "32m"
    #else
        #define HAZARD3_FIRMWARE_MEMORY_PROFILE "64m"
    #endif
#endif /* HAZARD3_FIRMWARE_MEMORY_PROFILE */

#ifndef HAZARD3_FIRMWARE_SYS_CLK_NAME
    #ifdef HAZARD3_FIRMWARE_SYS_CLK_MHZ
        #define HAZARD3_FIRMWARE_SYS_CLK_NAME \
                HAZARD3_STRINGIFY(HAZARD3_FIRMWARE_SYS_CLK_MHZ) "MHz"
    #elif defined(HAZARD3_SYS_CLK_HZ)
        #if HAZARD3_SYS_CLK_HZ == 25000000u
            #define HAZARD3_FIRMWARE_SYS_CLK_NAME "25MHz"
            #elif HAZARD3_SYS_CLK_HZ == 40000000u
            #define HAZARD3_FIRMWARE_SYS_CLK_NAME "40MHz"
            #elif HAZARD3_SYS_CLK_HZ == 50000000u
            #define HAZARD3_FIRMWARE_SYS_CLK_NAME "50MHz"
            #elif HAZARD3_SYS_CLK_HZ == 60000000u
            #define HAZARD3_FIRMWARE_SYS_CLK_NAME "60MHz"
            #elif HAZARD3_SYS_CLK_HZ == 75000000u
            #define HAZARD3_FIRMWARE_SYS_CLK_NAME "75MHz"
        #else
            #define HAZARD3_FIRMWARE_SYS_CLK_NAME "clock-custom"
        #endif /* HAZARD3_SYS_CLK_HZ */
    #else
        #define HAZARD3_FIRMWARE_SYS_CLK_NAME "clock-unknown"
    #endif /* HAZARD3_FIRMWARE_SYS_CLK_MHZ */
#endif /* HAZARD3_FIRMWARE_SYS_CLK_NAME */

#ifndef HAZARD3_FIRMWARE_BUILD_DATE
    #define HAZARD3_FIRMWARE_BUILD_DATE __DATE__
#endif

#define HAZARD3_FIRMWARE_BUILD_NAME \
    "ULX-Doom-Console-0.2.0-" \
    HAZARD3_FIRMWARE_MEMORY_PROFILE "-" \
    HAZARD3_FIRMWARE_SYS_CLK_NAME "-" \
    HAZARD3_FIRMWARE_BUILD_DATE
/* End Build Info */

#define HAZARD3_DDR_STATUS_INIT_DONE          (1u << 0)
#define HAZARD3_DDR_STATUS_INIT_ERROR         (1u << 1)
#define HAZARD3_DDR_STATUS_PLL_LOCKED         (1u << 2)
#define HAZARD3_DDR_STATUS_USER_CLOCK_READY   (1u << 3)
#define HAZARD3_DDR_STATUS_READY              (1u << 4)
#define HAZARD3_DDR_STATUS_ADAPTER_BUSY       (1u << 5)
#define HAZARD3_DDR_STATUS_USER_WB_BUSY       (1u << 6)
#define HAZARD3_DDR_STATUS_WB_ERROR           (1u << 7)
#define HAZARD3_DDR_STATUS_STATE_SHIFT        8u
#define HAZARD3_DDR_STATUS_STATE_MASK         (7u << 8)
#define HAZARD3_DDR_STATUS_RMW_ACTIVE         (1u << 11)
#define HAZARD3_DDR_STATUS_VIDEO_OWNER        (1u << 12)
#define HAZARD3_DDR_STATUS_WRITE              (1u << 13)
#define HAZARD3_DDR_STATUS_RESPONSE_PENDING   (1u << 14)
#define HAZARD3_DDR_STATUS_REQUEST_TOGGLE     (1u << 15)
#define HAZARD3_DDR_STATUS_MARKER_MASK        0xffff0000u
#define HAZARD3_DDR_STATUS_MARKER_ULX4M_LD    0x4c440000u
#define HAZARD3_DDR_STATUS_MARKER_ULX3S       0x53440000u

#define HAZARD3_VIDEO_STATUS_FRONT_BUFFER       (1u << 0)
#define HAZARD3_VIDEO_STATUS_PRESENT_PENDING    (1u << 1)
#define HAZARD3_VIDEO_STATUS_INDEXED            (1u << 2)
#define HAZARD3_VIDEO_STATUS_VBLANK             (1u << 3)
#define HAZARD3_VIDEO_STATUS_SDRAM_READY        (1u << 4)
#define HAZARD3_VIDEO_STATUS_FRAME_VALID        (1u << 5)
#define HAZARD3_VIDEO_STATUS_INTERNAL_BUFFER    (1u << 6)
#define HAZARD3_VIDEO_STATUS_DMA_BUSY           (1u << 7)
#define HAZARD3_VIDEO_STATUS_SWAP_PENDING       (1u << 8)
#define HAZARD3_VIDEO_STATUS_DIRECT_SUPPORTED   (1u << 9)
#define HAZARD3_VIDEO_STATUS_DIRECT_WRITE_BUSY  (1u << 10)
#define HAZARD3_VIDEO_STATUS_HIGH_RES_SUPPORTED (1u << 11)
#define HAZARD3_VIDEO_STATUS_HIGH_RES_ACTIVE    (1u << 12)
#define HAZARD3_VIDEO_STATUS_GUI_RES_SUPPORTED  (1u << 13)
#define HAZARD3_VIDEO_STATUS_GUI_RES_ACTIVE     (1u << 14)

#define HAZARD3_VIDEO_CONTROL_INDEXED         (1u << 0)
#define HAZARD3_VIDEO_CONTROL_BUFFER1         (1u << 1)
#define HAZARD3_VIDEO_CONTROL_PRESENT         (1u << 2)
#define HAZARD3_VIDEO_CONTROL_DIRECT          (1u << 3)
#define HAZARD3_VIDEO_CONTROL_HIGH_RES        (1u << 4)
#define HAZARD3_VIDEO_CONTROL_GUI_RES         (1u << 5)

#define HAZARD3_VIDEO_STANDARD_WIDTH          320u
#define HAZARD3_VIDEO_STANDARD_HEIGHT         200u
#define HAZARD3_VIDEO_STANDARD_BYTES          \
    (HAZARD3_VIDEO_STANDARD_WIDTH * HAZARD3_VIDEO_STANDARD_HEIGHT)
#define HAZARD3_VIDEO_HIGH_WIDTH              400u
#define HAZARD3_VIDEO_HIGH_HEIGHT             240u
#define HAZARD3_VIDEO_HIGH_BYTES              \
    (HAZARD3_VIDEO_HIGH_WIDTH * HAZARD3_VIDEO_HIGH_HEIGHT)
#define HAZARD3_VIDEO_GUI_WIDTH               512u
#define HAZARD3_VIDEO_GUI_HEIGHT              300u
#define HAZARD3_VIDEO_GUI_PIXELS              \
    (HAZARD3_VIDEO_GUI_WIDTH * HAZARD3_VIDEO_GUI_HEIGHT)
#define HAZARD3_VIDEO_GUI_BYTES               (HAZARD3_VIDEO_GUI_PIXELS / 2u)
#define HAZARD3_VIDEO_GUI_HALFWORDS           (HAZARD3_VIDEO_GUI_PIXELS / 4u)

/*
 * Screen Snip cache shared by the resident monitor and the Doom image. The
 * cache always stores an unpacked IDX8 source image, even when a producer uses
 * a packed framebuffer format. Size for the largest supported source so this
 * layout can also accommodate a future cached 512x300 GUI capture.
 */
#define HAZARD3_SCREEN_SNIP_CACHE_MAGIC       0x48335343u
#define HAZARD3_SCREEN_SNIP_CACHE_VERSION     1u
#define HAZARD3_SCREEN_SNIP_PALETTE_BYTES     256u
#define HAZARD3_SCREEN_SNIP_MAX_PIXEL_BYTES   HAZARD3_VIDEO_GUI_PIXELS
#define HAZARD3_SCREEN_SNIP_CACHE_HEADER_BYTES (8u * sizeof(uint32_t))
#define HAZARD3_SCREEN_SNIP_CACHE_BYTES       \
    (HAZARD3_SCREEN_SNIP_CACHE_HEADER_BYTES + \
        HAZARD3_SCREEN_SNIP_PALETTE_BYTES + \
        HAZARD3_SCREEN_SNIP_MAX_PIXEL_BYTES)

typedef struct {
    uint32_t magic;
    uint32_t magic_inverse;
    uint32_t version;
    uint32_t source_width;
    uint32_t source_height;
    uint32_t palette_bytes;
    uint32_t pixel_bytes;
    uint32_t reserved;
    uint8_t palette[HAZARD3_SCREEN_SNIP_PALETTE_BYTES];
    uint8_t pixels[HAZARD3_SCREEN_SNIP_MAX_PIXEL_BYTES];
} hazard3_screen_snip_cache_t;

#define HAZARD3_VIDEO_DIRECT_BUFFER1_STANDARD_HALFWORD 0x00008000u
#define HAZARD3_VIDEO_DIRECT_BUFFER1_HIGH_HALFWORD     0x0000c000u
#define HAZARD3_VIDEO_DIRECT_ADDRESS_HIGH_RES_FLAG     0x80000000u

#define HAZARD3_DOOM_SCREENBUFFER_BASE        0x00010000u
/*
 * The 12F compact target cannot reserve a 64 KiB on-chip Doom screen. Its
 * monitor occupies the first 256 KiB of SDRAM, and Doom renders into the next
 * cacheable 64 KiB region before copying completed frames to the uncached
 * video aperture.
 */
#define HAZARD3_DOOM_SCREENBUFFER_12F_BASE    \
    (HAZARD3_SDRAM_PHYSICAL_BASE + 0x00040000u)
#define HAZARD3_DOOM_SCREENBUFFER_BYTES       HAZARD3_VIDEO_STANDARD_BYTES

#ifdef HAZARD3_VIDEO_HIGH_RES
#define HAZARD3_VIDEO_FRAMEBUFFER_WIDTH       HAZARD3_VIDEO_HIGH_WIDTH
#define HAZARD3_VIDEO_FRAMEBUFFER_HEIGHT      HAZARD3_VIDEO_HIGH_HEIGHT
#define HAZARD3_VIDEO_FRAMEBUFFER_BYTES       HAZARD3_VIDEO_HIGH_BYTES
#define HAZARD3_VIDEO_MODE_CONTROL            HAZARD3_VIDEO_CONTROL_HIGH_RES
#define HAZARD3_VIDEO_HIGH_RES_ENABLED         1u
#define HAZARD3_VIDEO_MINIMUM_RESERVE_BYTES   \
    (0x00030000u + HAZARD3_VIDEO_HIGH_BYTES)
#else
#define HAZARD3_VIDEO_FRAMEBUFFER_WIDTH       HAZARD3_VIDEO_STANDARD_WIDTH
#define HAZARD3_VIDEO_FRAMEBUFFER_HEIGHT      HAZARD3_VIDEO_STANDARD_HEIGHT
#define HAZARD3_VIDEO_FRAMEBUFFER_BYTES       HAZARD3_VIDEO_STANDARD_BYTES
#define HAZARD3_VIDEO_MODE_CONTROL            0u
#define HAZARD3_VIDEO_HIGH_RES_ENABLED         0u
#define HAZARD3_VIDEO_MINIMUM_RESERVE_BYTES   \
    (0x00010000u + HAZARD3_VIDEO_STANDARD_BYTES)
#endif

static inline uint32_t hazard3_video_direct_halfword_base(
    uint32_t buffer_index,
    int high_resolution)
{
    uint32_t address = buffer_index == 0u ? 0u :
        (high_resolution != 0
            ? HAZARD3_VIDEO_DIRECT_BUFFER1_HIGH_HALFWORD
            : HAZARD3_VIDEO_DIRECT_BUFFER1_STANDARD_HALFWORD);

    if (high_resolution != 0) {
        address |= HAZARD3_VIDEO_DIRECT_ADDRESS_HIGH_RES_FLAG;
    }
    return address;
}

static inline volatile uint32_t* hazard3_video_framebuffer_words_for_mode(
    uint32_t buffer_index,
    int high_resolution)
{
    uintptr_t address = HAZARD3_VIDEO_FRAMEBUFFER0_BASE;

    if (buffer_index != 0u) {
        address = high_resolution != 0
            ? HAZARD3_VIDEO_FRAMEBUFFER1_HIGH_BASE
            : HAZARD3_VIDEO_FRAMEBUFFER1_BASE;
    }
    return (volatile uint32_t*)address;
}

static inline volatile uint32_t* hazard3_video_framebuffer_words(
    uint32_t buffer_index)
{
#ifdef HAZARD3_VIDEO_HIGH_RES
    return hazard3_video_framebuffer_words_for_mode(buffer_index, 1);
#else
    return hazard3_video_framebuffer_words_for_mode(buffer_index, 0);
#endif
}

#endif
