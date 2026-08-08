#include "coremark.h"
#include "core_portme.h"

#ifndef HAZARD3_SYS_CLK_HZ
    #define HAZARD3_SYS_CLK_HZ 50000000u
#endif
#ifndef ITERATIONS
    #define ITERATIONS 3000
#endif

#define UART_BASE 0x40004000u
#define UART_CSR (*(volatile uint32_t *)(UART_BASE + 0x00u))
#define UART_DIV (*(volatile uint32_t *)(UART_BASE + 0x04u))
#define UART_FSTAT (*(volatile uint32_t *)(UART_BASE + 0x08u))
#define UART_TX (*(volatile uint32_t *)(UART_BASE + 0x0cu))
#define UART_CSR_ENABLE (1u << 0)
#define UART_FSTAT_TX_FULL (1u << 8)
#define UART_BAUD_HZ 115200u
#define UART_OVERSAMPLE 8u
#define UART_DIV_X16 ((HAZARD3_SYS_CLK_HZ * 16u + \
                       (UART_BAUD_HZ * UART_OVERSAMPLE) / 2u) / \
                       (UART_BAUD_HZ * UART_OVERSAMPLE))

#define MISA_MXL_SHIFT 30u
#define MISA_MXL_MASK 0x3u
#define MISA_MXL_RV32 0x1u
#define MISA_EXT_A 0u
#define MISA_EXT_C 2u
#define MISA_EXT_I 8u
#define MISA_EXT_M 12u

#define H3_MISA_BITMAP_LENGTH_INDEX 0x400u
#define H3_MISA_GROUP_ZB 0u
#define H3_MISA_ZBA_BIT 27u
#define H3_MISA_ZBB_BIT 28u
#define H3_MISA_ZBC_BIT 29u
#define H3_MISA_ZBKB_BIT 30u
#define H3_MISA_ZBKX_BIT 32u
#define H3_MISA_ZBS_BIT 33u
#define H3_MISA_GROUP_ZI 1u
#define H3_MISA_ZIFENCEI_BIT 11u

#if VALIDATION_RUN
    volatile ee_s32 seed1_volatile = 0x3415;
    volatile ee_s32 seed2_volatile = 0x3415;
    volatile ee_s32 seed3_volatile = 0x66;
#elif PERFORMANCE_RUN
    volatile ee_s32 seed1_volatile = 0x0;
    volatile ee_s32 seed2_volatile = 0x0;
    volatile ee_s32 seed3_volatile = 0x66;
#else
    #error "Build CoreMark with PERFORMANCE_RUN or VALIDATION_RUN"
#endif

volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

ee_u32 default_num_contexts = 1u;

static CORETIMETYPE start_time_val;
static CORETIMETYPE stop_time_val;

static inline uint32_t read_mcycle(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, mcycle" : "=r" (value));
    return value;
}

static inline uint32_t read_misa(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, misa" : "=r" (value));
    return value;
}

static uint32_t h3_misa_read(uint32_t index)
{
    uint32_t value;
    __asm__ volatile (
        "csrrw %0, 0xbf1, %1"
        : "=r" (value)
        : "r" (index)
    );
    return value;
}

static uint32_t h3_misa_extension_supported(
    uint32_t bitmap_length,
    unsigned int group_id,
    unsigned int bit_position)
{
    unsigned int index = group_id * 64u + bit_position;

    if (index >= bitmap_length) {
        return 0u;
    }

    return (h3_misa_read(index >> 5) >> (index & 31u)) & 1u;
}

static uint32_t misa_extension_supported(uint32_t misa, unsigned int bit_position)
{
    return (misa >> bit_position) & 1u;
}

static const char *yes_no(uint32_t value)
{
    return value != 0u ? "yes" : "no";
}

static void print_hazard3_isa(void)
{
    uint32_t misa = read_misa();
    uint32_t bitmap_length = h3_misa_read(H3_MISA_BITMAP_LENGTH_INDEX);
    uint32_t rv32i =
        ((misa >> MISA_MXL_SHIFT) & MISA_MXL_MASK) == MISA_MXL_RV32 &&
        misa_extension_supported(misa, MISA_EXT_I);

    ee_printf("Hazard3 ISA:   misa       = 0x%08x\n", misa);
    ee_printf("   RV32I      = %s\n", yes_no(rv32i));
    ee_printf("   M          = %s\n", yes_no(misa_extension_supported(misa, MISA_EXT_M)));
    ee_printf("   A          = %s\n", yes_no(misa_extension_supported(misa, MISA_EXT_A)));
    ee_printf("   C          = %s\n", yes_no(misa_extension_supported(misa, MISA_EXT_C)));
    ee_printf("   Zba        = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZB, H3_MISA_ZBA_BIT)));
    ee_printf("   Zbb        = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZB, H3_MISA_ZBB_BIT)));
    ee_printf("   Zbc        = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZB, H3_MISA_ZBC_BIT)));
    ee_printf("   Zbkb       = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZB, H3_MISA_ZBKB_BIT)));
    ee_printf("   Zbkx       = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZB, H3_MISA_ZBKX_BIT)));
    ee_printf("   Zbs        = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZB, H3_MISA_ZBS_BIT)));
    ee_printf("   Zifencei   = %s\n", yes_no(h3_misa_extension_supported(
        bitmap_length, H3_MISA_GROUP_ZI, H3_MISA_ZIFENCEI_BIT)));
}

void coremark_uart_send_char(char c)
{
    if (c == '\n') {
        coremark_uart_send_char('\r');
    }
    while ((UART_FSTAT & UART_FSTAT_TX_FULL) != 0u) {
    }
    UART_TX = (uint32_t)(uint8_t)c;
}

static void uart_init(void)
{
    UART_DIV = UART_DIV_X16;
    UART_CSR = UART_CSR_ENABLE;
}

void start_time(void)
{
    start_time_val = read_mcycle();
}

void stop_time(void)
{
    stop_time_val = read_mcycle();
}

CORE_TICKS get_time(void)
{
    return (CORE_TICKS)(stop_time_val - start_time_val);
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)(ticks / (CORE_TICKS)HAZARD3_SYS_CLK_HZ);
}

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    uart_init();
    ee_printf("\nHazard3 ULX3S CoreMark\n");
    ee_printf("CPU clock        : %lu Hz\n", (unsigned long)HAZARD3_SYS_CLK_HZ);
    ee_printf("UART             : 115200 8N1\n");
    print_hazard3_isa();
    p->portable_id = 1u;
}

void portable_fini(core_portable *p)
{
    p->portable_id = 0u;
    ee_printf("COREMARK_DONE\n");
}
