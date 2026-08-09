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
#define MISA_EXT_E 4u
#define MISA_EXT_I 8u
#define MISA_EXT_M 12u
#define MISA_EXT_S 18u
#define MISA_EXT_U 20u

#define H3_MISA_BITMAP_LENGTH_INDEX 0x400u
#define H3_EXTENSION_NO 0
#define H3_EXTENSION_YES 1
#define H3_EXTENSION_NOT_ENUMERATED 2

#define FEATURE_NO 0
#define FEATURE_YES 1
#define FEATURE_UNKNOWN (-1)

#define COREMARK_DIAG __attribute__((section(".coremark_diag.text")))

typedef struct standard_extension_info {
    const char *name;
    unsigned int group_id;
    unsigned int bit_position;
    const char *description;
} standard_extension_info;

static const standard_extension_info hazard3_standard_extensions[] = {
    {"B", 0u, 1u, "bit manipulation extension (Zba + Zbb + Zbs)"},
    {"Zba", 0u, 27u, "address generation"},
    {"Zbb", 0u, 28u, "basic bit manipulation"},
    {"Zbc", 0u, 29u, "carry-less multiplication"},
    {"Zbkb", 0u, 30u, "basic bit manipulation for scalar cryptography"},
    {"Zbkc", 0u, 31u, "carry-less multiplication for scalar cryptography"},
    {"Zbkx", 0u, 32u, "crossbar permutation instructions"},
    {"Zbs", 0u, 33u, "single-bit manipulation"},
    {"Zkt", 0u, 46u, "data-independent execution latency"},
    {"Zca", 1u, 2u, "base compressed instruction subset"},
    {"Zcb", 1u, 3u, "basic additional compressed instructions"},
    {"Zilsd", 1u, 8u, "load/store pair instructions"},
    {"Zclsd", 1u, 9u, "compressed load/store pair instructions"},
    {"Zcmp", 1u, 10u, "push/pop and double-move instructions"},
    {"Zifencei", 1u, 11u, "instruction-fetch fence"},
    {"Zmmul", 1u, 12u, "integer multiplication subset of M"},
};

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
static uint64_t start_instret_val;
static uint64_t stop_instret_val;

static inline uint64_t read_mcycle64(void)
{
    uint32_t high_before;
    uint32_t low;
    uint32_t high_after;

    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r" (high_before));
        __asm__ volatile ("csrr %0, mcycle" : "=r" (low));
        __asm__ volatile ("csrr %0, mcycleh" : "=r" (high_after));
    } while (high_before != high_after);

    return ((uint64_t)high_after << 32) | low;
}

static inline uint64_t read_minstret64(void)
{
    uint32_t high_before;
    uint32_t low;
    uint32_t high_after;

    do {
        __asm__ volatile ("csrr %0, minstreth" : "=r" (high_before));
        __asm__ volatile ("csrr %0, minstret" : "=r" (low));
        __asm__ volatile ("csrr %0, minstreth" : "=r" (high_after));
    } while (high_before != high_after);

    return ((uint64_t)high_after << 32) | low;
}

static COREMARK_DIAG uint32_t read_misa(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, misa" : "=r" (value));
    return value;
}

static COREMARK_DIAG uint32_t h3_misa_read(uint32_t index)
{
    uint32_t value;
    __asm__ volatile (
        "csrrw %0, 0xbf1, %1"
        : "=r" (value)
        : "r" (index)
    );
    return value;
}

static COREMARK_DIAG int h3_misa_extension_status(
    uint32_t bitmap_length,
    unsigned int group_id,
    unsigned int bit_position)
{
    unsigned int index = group_id * 64u + bit_position;

    if (index >= bitmap_length) {
        return H3_EXTENSION_NOT_ENUMERATED;
    }

    return ((h3_misa_read(index >> 5) >> (index & 31u)) & 1u) != 0u ?
        H3_EXTENSION_YES : H3_EXTENSION_NO;
}

static COREMARK_DIAG uint32_t misa_extension_supported(uint32_t misa, unsigned int bit_position)
{
    return (misa >> bit_position) & 1u;
}

static COREMARK_DIAG const char *yes_no(uint32_t value)
{
    return value != 0u ? "yes" : "no";
}

static COREMARK_DIAG const char *extension_status_name(int status)
{
    if (status == H3_EXTENSION_YES) {
        return "yes";
    }
    if (status == H3_EXTENSION_NO) {
        return "no";
    }
    return "not-enumerated";
}

static COREMARK_DIAG const char *feature_status_name(int status)
{
    if (status == FEATURE_YES) {
        return "yes";
    }
    if (status == FEATURE_NO) {
        return "no";
    }
    return "unknown";
}

static COREMARK_DIAG uint32_t read_mscratch(void)
{
    uint32_t value = 0u;
    __asm__ volatile ("csrr %0, mscratch" : "+r" (value));
    return value;
}

static COREMARK_DIAG void write_mscratch(uint32_t value)
{
    __asm__ volatile ("csrw mscratch, %0" :: "r" (value));
}

static COREMARK_DIAG uint32_t read_mtvec(void)
{
    uint32_t value = 0u;
    __asm__ volatile ("csrr %0, mtvec" : "+r" (value));
    return value;
}

static COREMARK_DIAG void write_mtvec(uint32_t value)
{
    __asm__ volatile ("csrw mtvec, %0" :: "r" (value));
}

static COREMARK_DIAG uint32_t read_cycle(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, cycle" : "=r" (value));
    return value;
}

volatile uint32_t coremark_probe_faulted;
extern void coremark_probe_trap(void);

static COREMARK_DIAG int detect_trap_support(void)
{
    uint32_t original = read_mscratch();
    uint32_t test_value = original ^ 0xa55aa55au;
    uint32_t readback;

    write_mscratch(test_value);
    readback = read_mscratch();
    write_mscratch(original);

    return readback == test_value ? FEATURE_YES : FEATURE_NO;
}

static COREMARK_DIAG int install_probe_trap(uint32_t *saved_mtvec)
{
    uint32_t handler = ((uint32_t)(uintptr_t)coremark_probe_trap) & ~0x3u;
    uint32_t readback;

    *saved_mtvec = read_mtvec();
    write_mtvec(handler);
    readback = read_mtvec();

    if ((readback & ~0x3u) != handler) {
        write_mtvec(*saved_mtvec);
        return FEATURE_NO;
    }

    return FEATURE_YES;
}

static COREMARK_DIAG int probe_tselect(uint32_t *value)
{
    uint32_t readback = 0u;

    coremark_probe_faulted = 0u;
    __asm__ volatile ("csrr %0, 0x7a0" : "+r" (readback));
    *value = readback;
    return coremark_probe_faulted == 0u ? FEATURE_YES : FEATURE_NO;
}

static COREMARK_DIAG void write_tselect(uint32_t value)
{
    __asm__ volatile ("csrw 0x7a0, %0" :: "r" (value));
}

static COREMARK_DIAG uint32_t read_tselect(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, 0x7a0" : "=r" (value));
    return value;
}

static COREMARK_DIAG uint32_t read_tinfo(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, 0x7a4" : "=r" (value));
    return value;
}

static COREMARK_DIAG int probe_pmpcfg0(uint32_t *value)
{
    uint32_t readback = 0u;

    coremark_probe_faulted = 0u;
    __asm__ volatile ("csrr %0, 0x3a0" : "+r" (readback));
    *value = readback;
    return coremark_probe_faulted == 0u ? FEATURE_YES : FEATURE_NO;
}

static COREMARK_DIAG unsigned int count_instruction_address_triggers(void)
{
    uint32_t original_tselect = read_tselect();
    unsigned int breakpoint_count = 0u;
    unsigned int index;

    for (index = 0u; index < 32u; ++index) {
        uint32_t selected;
        uint32_t tinfo;

        write_tselect(index);
        selected = read_tselect();
        if (selected != index) {
            break;
        }

        tinfo = read_tinfo();
        if (tinfo == 0u || (tinfo & 1u) != 0u) {
            break;
        }
        if ((tinfo & (1u << 2)) != 0u) {
            ++breakpoint_count;
        }
    }

    write_tselect(original_tselect);
    return breakpoint_count;
}

static COREMARK_DIAG void print_memory_info(void)
{
    extern char __ram_origin[];
    extern char __ram_length[];
    extern char __image_end[];
    extern char __stack_top[];
    uintptr_t ram_base = (uintptr_t)__ram_origin;
    uintptr_t ram_size = (uintptr_t)__ram_length;
    uintptr_t image_end = (uintptr_t)__image_end;
    uintptr_t stack_top = (uintptr_t)__stack_top;

    ee_printf("Memory:\n");
    ee_printf("   type         = internal SRAM\n");
    ee_printf("   base         = 0x%08lx\n", (unsigned long)ram_base);
    ee_printf("   size         = %lu bytes (%lu KiB)\n",
        (unsigned long)ram_size, (unsigned long)(ram_size / 1024u));
    ee_printf("   placement    = code/data/stack\n");
    ee_printf("   image end    = 0x%08lx\n", (unsigned long)image_end);
    ee_printf("   stack top    = 0x%08lx\n", (unsigned long)stack_top);
    ee_printf("   image->stack = %lu bytes\n", (unsigned long)(stack_top - image_end));
    ee_printf("   physical     = not hart-detectable (e.g. ECP5 EBR vs other SRAM)\n");
}

static COREMARK_DIAG void print_standard_extension(
    uint32_t bitmap_length,
    const standard_extension_info *extension)
{
    int status = h3_misa_extension_status(
        bitmap_length, extension->group_id, extension->bit_position);

    ee_printf("   %s = %s;  %s\n", extension->name,
        extension_status_name(status), extension->description);
}

static COREMARK_DIAG void print_hazard3_isa(void)
{
    uint32_t misa = read_misa();
    uint32_t bitmap_length = h3_misa_read(H3_MISA_BITMAP_LENGTH_INDEX);
    uint32_t rv32i =
        ((misa >> MISA_MXL_SHIFT) & MISA_MXL_MASK) == MISA_MXL_RV32 &&
        misa_extension_supported(misa, MISA_EXT_I);
    uint32_t rv32e =
        ((misa >> MISA_MXL_SHIFT) & MISA_MXL_MASK) == MISA_MXL_RV32 &&
        misa_extension_supported(misa, MISA_EXT_E);
    uint32_t extension_a = misa_extension_supported(misa, MISA_EXT_A);
    unsigned int i;

    ee_printf("Hazard3 ISA:   misa       = 0x%08x\n", misa);
    ee_printf("   RV32E      = %s\n", yes_no(rv32e));
    ee_printf("   RV32I      = %s\n", yes_no(rv32i));
    ee_printf("   M          = %s;  integer multiply/divide/modulo\n",
        yes_no(misa_extension_supported(misa, MISA_EXT_M)));
    ee_printf("   A          = %s;  atomic memory operations, with AHB5 global exclusives\n",
        yes_no(extension_a));
    ee_printf("   Zaamo      = %s;  atomic memory operations subset of A\n", yes_no(extension_a));
    ee_printf("   Zalrsc     = %s;  load-reserved/store-conditional subset of A\n", yes_no(extension_a));
    ee_printf("   C          = %s;  compressed instructions\n",
        yes_no(misa_extension_supported(misa, MISA_EXT_C)));
    ee_printf("   Zicsr      = yes;  CSR access (required to read misa/h3.misa)\n");
    (void)read_cycle();
    ee_printf("   Zicntr     = yes;  cycle/instret counters used by CoreMark\n");

    for (i = 0u; i < sizeof(hazard3_standard_extensions) / sizeof(hazard3_standard_extensions[0]); ++i) {
        print_standard_extension(bitmap_length, &hazard3_standard_extensions[i]);
    }

    ee_printf("   h3.misa bitmap length = %lu bits\n", (unsigned long)bitmap_length);
    for (i = 0u; i < (bitmap_length + 31u) / 32u; ++i) {
        ee_printf("   h3.misa[%lu] = 0x%08x\n",
            (unsigned long)i, h3_misa_read(i));
    }
}

static COREMARK_DIAG void print_hazard3_features(void)
{
    uint32_t misa = read_misa();
    int trap_support = detect_trap_support();
    int probe_support = FEATURE_UNKNOWN;
    int debug_support = FEATURE_UNKNOWN;
    int pmp_support = FEATURE_UNKNOWN;
    uint32_t saved_mtvec = 0u;
    uint32_t value = 0u;
    unsigned int breakpoint_count = 0u;

    if (trap_support == FEATURE_YES) {
        probe_support = install_probe_trap(&saved_mtvec);
        if (probe_support == FEATURE_YES) {
            debug_support = probe_tselect(&value);
            if (debug_support == FEATURE_YES) {
                breakpoint_count = count_instruction_address_triggers();
            }

            pmp_support = probe_pmpcfg0(&value);
            write_mtvec(saved_mtvec);
        }
    }

    ee_printf("Hazard3 implementation features:\n");
    ee_printf("   Machine mode       = yes\n");
    ee_printf("   User mode          = %s\n",
        yes_no(misa_extension_supported(misa, MISA_EXT_U)));
    ee_printf("   Supervisor mode    = %s;  not implemented by Hazard3\n",
        yes_no(misa_extension_supported(misa, MISA_EXT_S)));
    ee_printf("   Trap support       = %s\n", feature_status_name(trap_support));
    ee_printf("   ecall              = yes;  implemented with Hazard3 CSR support\n");
    ee_printf("   ebreak             = yes;  implemented with Hazard3 CSR support\n");
    ee_printf("   mret               = yes;  implemented with Hazard3 CSR support in M-mode\n");
    ee_printf("   wfi                = yes;  implemented with Hazard3 CSR support\n");
    ee_printf("   Current privilege  = Machine\n");
    ee_printf("   Debug support      = %s;  trigger CSR support\n",
        feature_status_name(debug_support));
    ee_printf("   External debug     = not hart-detectable from M-mode\n");
    ee_printf("   Debug transport    = not hart-detectable (JTAG/APB is integration-specific)\n");
    if (debug_support == FEATURE_YES) {
        ee_printf("   HW breakpoints     = %lu;  instruction-address triggers\n",
            (unsigned long)breakpoint_count);
    } else {
        ee_printf("   HW breakpoints     = %s\n", feature_status_name(debug_support));
    }
    ee_printf("   PMP                = %s\n", feature_status_name(pmp_support));
    if (pmp_support == FEATURE_YES) {
        ee_printf("   PMP regions        = present, max 16; exact configured count not hart-detectable\n");
        ee_printf("   PMP NAPOT/NA4      = not hart-detectable without changing PMP configuration\n");
        ee_printf("   PMP TOR            = not hart-detectable without changing PMP configuration\n");
    } else if (pmp_support == FEATURE_NO) {
        ee_printf("   PMP regions        = 0\n");
        ee_printf("   PMP NAPOT/NA4      = n/a\n");
        ee_printf("   PMP TOR            = n/a\n");
    } else {
        ee_printf("   PMP regions        = unknown\n");
        ee_printf("   PMP NAPOT/NA4      = unknown\n");
        ee_printf("   PMP TOR            = unknown\n");
    }
    if (trap_support == FEATURE_YES && probe_support != FEATURE_YES) {
        ee_printf("   Optional CSR probe = unavailable; mtvec cannot point at probe handler\n");
    }
}

COREMARK_DIAG void coremark_uart_send_char(char c)
{
    if (c == '\n') {
        coremark_uart_send_char('\r');
    }
    while ((UART_FSTAT & UART_FSTAT_TX_FULL) != 0u) {
    }
    UART_TX = (uint32_t)(uint8_t)c;
}

static COREMARK_DIAG void uart_init(void)
{
    UART_DIV = UART_DIV_X16;
    UART_CSR = UART_CSR_ENABLE;
}

static COREMARK_DIAG uint64_t divide_unsigned64_by_u32(uint64_t value, uint32_t divisor)
{
    uint64_t quotient = 0u;
    uint32_t remainder = 0u;
    unsigned int bit;

    for (bit = 0u; bit < 64u; ++bit) {
        remainder = (remainder << 1) | (uint32_t)(value >> 63);
        value <<= 1;
        quotient <<= 1;
        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= 1u;
        }
    }

    return quotient;
}

void start_time(void)
{
    start_time_val = read_mcycle64();
    start_instret_val = read_minstret64();
}

void stop_time(void)
{
    stop_instret_val = read_minstret64();
    stop_time_val = read_mcycle64();
}

CORE_TICKS get_time(void)
{
    return (CORE_TICKS)(stop_time_val - start_time_val);
}

COREMARK_DIAG secs_ret time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)divide_unsigned64_by_u32(ticks, HAZARD3_SYS_CLK_HZ);
}

COREMARK_DIAG void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    uart_init();
    ee_printf("\nHazard3 ULX3S CoreMark\n");
    ee_printf("CPU clock        : %lu Hz\n", (unsigned long)HAZARD3_SYS_CLK_HZ);
    ee_printf("UART             : 115200 8N1\n");
    print_memory_info();
    print_hazard3_isa();
    print_hazard3_features();
    p->portable_id = 1u;
}

COREMARK_DIAG void portable_fini(core_portable *p)
{
    uint64_t cycles = stop_time_val - start_time_val;
    uint64_t instructions = stop_instret_val - start_instret_val;

    p->portable_id = 0u;
    ee_printf("Rate note        : standard target time/rate are integer-truncated; use host summary\n");
    ee_printf("Hazard3 counters:\n");
    ee_printf("   cycles       = %llu\n", (unsigned long long)cycles);
    ee_printf("   instructions = %llu\n", (unsigned long long)instructions);
    ee_printf("COREMARK_DONE\n");
}
