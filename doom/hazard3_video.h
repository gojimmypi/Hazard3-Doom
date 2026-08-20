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
#define HAZARD3_MEMORY_CORE_BUILD_ID_ULX3S       0x53445235u
#define HAZARD3_MEMORY_ADAPTER_BUILD_ID_ULX3S    0x41485335u
#define HAZARD3_FIRMWARE_BUILD_ID                0x48335235u
#define HAZARD3_FIRMWARE_BUILD_NAME \
    "H3-DoomPerformance-R5-20260716"

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

#define HAZARD3_VIDEO_CONTROL_INDEXED         (1u << 0)
#define HAZARD3_VIDEO_CONTROL_BUFFER1         (1u << 1)
#define HAZARD3_VIDEO_CONTROL_PRESENT         (1u << 2)
#define HAZARD3_VIDEO_CONTROL_DIRECT          (1u << 3)
#define HAZARD3_VIDEO_CONTROL_HIGH_RES        (1u << 4)

#define HAZARD3_VIDEO_STANDARD_WIDTH          320u
#define HAZARD3_VIDEO_STANDARD_HEIGHT         200u
#define HAZARD3_VIDEO_STANDARD_BYTES          \
    (HAZARD3_VIDEO_STANDARD_WIDTH * HAZARD3_VIDEO_STANDARD_HEIGHT)
#define HAZARD3_VIDEO_HIGH_WIDTH              400u
#define HAZARD3_VIDEO_HIGH_HEIGHT             240u
#define HAZARD3_VIDEO_HIGH_BYTES              \
    (HAZARD3_VIDEO_HIGH_WIDTH * HAZARD3_VIDEO_HIGH_HEIGHT)

/*
 * Retained HDMI screen-snip cache. Active display clients update this only
 * when they are about to return control to the resident monitor. It therefore
 * has no per-frame cost for Doom or the I2CDriver GUI. The monitor can then
 * return the last successfully displayed source frame after the client exits.
 */
#define HAZARD3_SCREEN_SNIP_CACHE_OFFSET       0x00048000u
#define HAZARD3_SCREEN_SNIP_CACHE_BASE         \
    (HAZARD3_VIDEO_BASE + HAZARD3_SCREEN_SNIP_CACHE_OFFSET)
#define HAZARD3_SCREEN_SNIP_CACHE_REGION_BYTES 0x00018000u
#define HAZARD3_SCREEN_SNIP_CACHE_MAGIC        0x31504e53u
#define HAZARD3_SCREEN_SNIP_CACHE_VERSION      1u
#define HAZARD3_SCREEN_SNIP_PALETTE_BYTES      256u
#define HAZARD3_SCREEN_SNIP_MAX_PIXELS         HAZARD3_VIDEO_HIGH_BYTES

typedef struct hazard3_screen_snip_cache {
    uint32_t magic;
    uint32_t magic_inverse;
    uint32_t version;
    uint32_t source_width;
    uint32_t source_height;
    uint32_t palette_bytes;
    uint32_t pixel_bytes;
    uint32_t reserved;
    uint8_t palette[HAZARD3_SCREEN_SNIP_PALETTE_BYTES];
    uint8_t pixels[HAZARD3_SCREEN_SNIP_MAX_PIXELS];
} hazard3_screen_snip_cache_t;

#define HAZARD3_VIDEO_DIRECT_BUFFER1_STANDARD_HALFWORD 0x00008000u
#define HAZARD3_VIDEO_DIRECT_BUFFER1_HIGH_HALFWORD     0x0000c000u
#define HAZARD3_VIDEO_DIRECT_ADDRESS_HIGH_RES_FLAG     0x80000000u

#define HAZARD3_DOOM_SCREENBUFFER_BASE        0x00010000u
/* The resident monitor always reserves exactly the original on-chip screen. */
#define HAZARD3_DOOM_SCREENBUFFER_BYTES       HAZARD3_VIDEO_STANDARD_BYTES

#ifdef HAZARD3_VIDEO_HIGH_RES
#define HAZARD3_VIDEO_FRAMEBUFFER_WIDTH       HAZARD3_VIDEO_HIGH_WIDTH
#define HAZARD3_VIDEO_FRAMEBUFFER_HEIGHT      HAZARD3_VIDEO_HIGH_HEIGHT
#define HAZARD3_VIDEO_FRAMEBUFFER_BYTES       HAZARD3_VIDEO_HIGH_BYTES
#define HAZARD3_VIDEO_MODE_CONTROL            HAZARD3_VIDEO_CONTROL_HIGH_RES
#define HAZARD3_VIDEO_HIGH_RES_ENABLED         1u
#else
#define HAZARD3_VIDEO_FRAMEBUFFER_WIDTH       HAZARD3_VIDEO_STANDARD_WIDTH
#define HAZARD3_VIDEO_FRAMEBUFFER_HEIGHT      HAZARD3_VIDEO_STANDARD_HEIGHT
#define HAZARD3_VIDEO_FRAMEBUFFER_BYTES       HAZARD3_VIDEO_STANDARD_BYTES
#define HAZARD3_VIDEO_MODE_CONTROL            0u
#define HAZARD3_VIDEO_HIGH_RES_ENABLED         0u
#endif

#define HAZARD3_VIDEO_MINIMUM_RESERVE_BYTES   \
    (HAZARD3_SCREEN_SNIP_CACHE_OFFSET + HAZARD3_SCREEN_SNIP_CACHE_REGION_BYTES)

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
