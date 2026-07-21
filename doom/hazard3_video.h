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

#define HAZARD3_VIDEO_STATUS_FRONT_BUFFER    (1u << 0)
#define HAZARD3_VIDEO_STATUS_PRESENT_PENDING (1u << 1)
#define HAZARD3_VIDEO_STATUS_INDEXED         (1u << 2)
#define HAZARD3_VIDEO_STATUS_VBLANK          (1u << 3)
#define HAZARD3_VIDEO_STATUS_SDRAM_READY      (1u << 4)
#define HAZARD3_VIDEO_STATUS_FRAME_VALID      (1u << 5)
#define HAZARD3_VIDEO_STATUS_INTERNAL_BUFFER   (1u << 6)
#define HAZARD3_VIDEO_STATUS_DMA_BUSY          (1u << 7)
#define HAZARD3_VIDEO_STATUS_SWAP_PENDING      (1u << 8)
#define HAZARD3_VIDEO_STATUS_DIRECT_SUPPORTED   (1u << 9)
#define HAZARD3_VIDEO_STATUS_DIRECT_WRITE_BUSY  (1u << 10)

#define HAZARD3_VIDEO_CONTROL_INDEXED         (1u << 0)
#define HAZARD3_VIDEO_CONTROL_BUFFER1         (1u << 1)
#define HAZARD3_VIDEO_CONTROL_PRESENT         (1u << 2)
#define HAZARD3_VIDEO_CONTROL_DIRECT          (1u << 3)

#define HAZARD3_VIDEO_FRAMEBUFFER_WIDTH       320u
#define HAZARD3_VIDEO_FRAMEBUFFER_HEIGHT      200u
#define HAZARD3_VIDEO_FRAMEBUFFER_BYTES       \
    (HAZARD3_VIDEO_FRAMEBUFFER_WIDTH * HAZARD3_VIDEO_FRAMEBUFFER_HEIGHT)

#define HAZARD3_DOOM_SCREENBUFFER_BASE       0x00010000u
#define HAZARD3_DOOM_SCREENBUFFER_BYTES      HAZARD3_VIDEO_FRAMEBUFFER_BYTES

static inline volatile uint32_t* hazard3_video_framebuffer_words(
    uint32_t buffer_index)
{
    uintptr_t address = buffer_index != 0u
        ? HAZARD3_VIDEO_FRAMEBUFFER1_BASE
        : HAZARD3_VIDEO_FRAMEBUFFER0_BASE;
    return (volatile uint32_t*)address;
}

#endif
