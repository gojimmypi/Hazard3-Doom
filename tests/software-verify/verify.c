/* -----------------------------------------------------------------------------
 * File:        verify.c
 * Path:        tests/software-verify/verify.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Exercise Hazard3 CPU and memory behavior using deterministic
 *              software verification tests.
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

#include <stddef.h>
#include <stdint.h>

#ifndef VERIFY_SYS_CLK_HZ
#define VERIFY_SYS_CLK_HZ 50000000u
#endif

#ifndef VERIFY_ROUNDS
#define VERIFY_ROUNDS 10000u
#endif

#define UART_BASE       0x40004000u
#define UART_CSR        (*(volatile uint32_t *)(UART_BASE + 0x00u))
#define UART_DIV        (*(volatile uint32_t *)(UART_BASE + 0x04u))
#define UART_FSTAT      (*(volatile uint32_t *)(UART_BASE + 0x08u))
#define UART_TX         (*(volatile uint32_t *)(UART_BASE + 0x0cu))
#define UART_CSR_ENABLE (1u << 0)
#define UART_FSTAT_TX_FULL (1u << 8)

#define UART_BAUD_HZ     115200u
#define UART_OVERSAMPLE  8u
#define UART_DIV_X16     ((VERIFY_SYS_CLK_HZ * 16u + \
    (UART_BAUD_HZ * UART_OVERSAMPLE) / 2u) / \
    (UART_BAUD_HZ * UART_OVERSAMPLE))

/*
 * The verifier intentionally uses only the first 32 MiB of external SDRAM so
 * the exact same ELF can be used as a 12F test and as an 85F control test.
 * 0x20000000 is the cached physical window. 0x24000000 is its uncached
 * diagnostic alias in the current Hazard3-Doom memory map.
 */
#define CACHED_A_BASE       0x20400000u
#define CACHED_B_BASE       0x20c00000u
#define UNCACHED_CTRL_BASE  0x24c80000u
#define LOOKUP_A_BASE       0x20500000u
#define LOOKUP_B_BASE       0x20d00000u

#define CACHED_WORD_COUNT   (64u * 1024u)
#define UNCACHED_WORD_COUNT (16u * 1024u)
#define CACHE_CHURN_READS   (512u * 1024u)
#define LOOKUP_COLUMNS      128u
#define LOOKUP_PATCHES      5u
#define LOOKUP_HEIGHT       96u
#define LOOKUP_FINAL_SIZE   (LOOKUP_COLUMNS * LOOKUP_HEIGHT)
#define ALU_ITERATIONS      200000u
#define ALU_EXPECTED        0x491b0ed0u

#define GUARD_WORDS 8u
#define GUARD0 0x13579bdfu
#define GUARD1 0x2468ace0u
#define GUARD2 0x55aa33ccu
#define GUARD3 0xc001d00du
#define GUARD4 0x0badf00du

struct texpatch {
    int16_t originx;
    int16_t originy;
    uint32_t patch;
};

struct texture_desc {
    char name[8];
    int16_t width;
    int16_t height;
    uint32_t index;
    uint32_t next;
    int16_t patchcount;
    int16_t reserved;
    struct texpatch patches[LOOKUP_PATCHES];
};

struct synthetic_patch {
    int16_t width;
    int16_t height;
    int16_t leftoffset;
    int16_t topoffset;
    uint32_t columnofs[16];
};

struct lookup_workspace {
    uint32_t guard0[GUARD_WORDS];
    struct texture_desc texture;
    uint32_t guard1[GUARD_WORDS];
    uint8_t patchcount[LOOKUP_COLUMNS];
    uint32_t guard2[GUARD_WORDS];
    uint16_t column_lump[LOOKUP_COLUMNS];
    uint32_t guard3[GUARD_WORDS];
    uint16_t column_ofs[LOOKUP_COLUMNS];
    uint32_t guard4[GUARD_WORDS];
    uint32_t composite_size;
    struct synthetic_patch realpatch[2];
    uint32_t signature;
};

static void uart_putc(uint8_t value)
{
    while ((UART_FSTAT & UART_FSTAT_TX_FULL) != 0u) {
    }
    UART_TX = value;
}

static void uart_puts(const char *text)
{
    while (*text != '\0') {
        uart_putc((uint8_t)*text++);
    }
}

static void uart_put_hex32(uint32_t value)
{
    static const char digits[] = "0123456789ABCDEF";

    uart_puts("0x");
    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_putc((uint8_t)digits[(value >> (uint32_t)shift) & 0x0fu]);
    }
}

static void uart_init(void)
{
    UART_DIV = UART_DIV_X16;
    UART_CSR = UART_CSR_ENABLE;
}

static void memory_barrier(void)
{
    __asm__ volatile ("fence rw, rw" ::: "memory");
}

static uint32_t rotl32(uint32_t value, uint32_t shift)
{
    return (value << shift) | (value >> (32u - shift));
}

static uint32_t pattern_word(uint32_t index, uint32_t seed)
{
    uint32_t value = index ^ seed;

    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    value ^= index * 0x9e3779b9u;
    return value;
}

__attribute__((noreturn))
static void park(void)
{
    for (;;) {
        __asm__ volatile ("wfi");
    }
}

__attribute__((noreturn))
static void verify_fail(const char *phase, uint32_t pass, uint32_t index,
    uint32_t address, uint32_t expected, uint32_t actual)
{
    uart_puts("\r\nVERIFY FAIL phase=");
    uart_puts(phase);
    uart_puts(" pass=");
    uart_put_hex32(pass);
    uart_puts(" index=");
    uart_put_hex32(index);
    uart_puts(" addr=");
    uart_put_hex32(address);
    uart_puts(" expected=");
    uart_put_hex32(expected);
    uart_puts(" actual=");
    uart_put_hex32(actual);
    uart_puts("\r\nVERIFY RESULT: FAIL\r\n");
    park();
}

__attribute__((noreturn))
void verify_trap(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
    uart_init();
    uart_puts("\r\nVERIFY TRAP mcause=");
    uart_put_hex32(mcause);
    uart_puts(" mepc=");
    uart_put_hex32(mepc);
    uart_puts(" mtval=");
    uart_put_hex32(mtval);
    uart_puts("\r\nVERIFY RESULT: FAIL\r\n");
    park();
}

static void phase_alu(void)
{
    uint32_t a = 0x12345678u;
    uint32_t b = 0x9abcdef0u;
    uint32_t c = 0x0f1e2d3cu;

    uart_puts("phase alu/control-flow: ");
    for (uint32_t i = 0u; i < ALU_ITERATIONS; ++i) {
        a += rotl32(b ^ i ^ 0x9e3779b9u, (i & 15u) + 1u);
        b ^= a * 0x045d9f3bu;
        c += (a ^ (b >> 7)) + 0x7f4a7c15u;
        if ((c & 0x80000000u) != 0u) {
            a ^= c;
        } else {
            b += c ^ i;
        }
        c = rotl32(c ^ a, 5u) + b;
    }

    uint32_t signature = a ^ rotl32(b, 11u) ^ rotl32(c, 23u);
    if (signature != ALU_EXPECTED) {
        verify_fail("alu", 0u, 0u, 0u, ALU_EXPECTED, signature);
    }
    uart_puts("PASS signature=");
    uart_put_hex32(signature);
    uart_puts("\r\n");
}

static void fill_words(volatile uint32_t *words, uint32_t count, uint32_t seed)
{
    for (uint32_t i = 0u; i < count; ++i) {
        words[i] = pattern_word(i, seed);
    }
}

static void check_words(const char *phase, volatile uint32_t *words,
    uint32_t count, uint32_t seed, uint32_t pass)
{
    for (uint32_t i = 0u; i < count; ++i) {
        uint32_t expected = pattern_word(i, seed);
        uint32_t actual = words[i];
        if (actual != expected) {
            verify_fail(phase, pass, i,
                (uint32_t)(uintptr_t)&words[i], expected, actual);
        }
    }
}

static void phase_uncached_control(void)
{
    volatile uint32_t *words =
        (volatile uint32_t *)(uintptr_t)UNCACHED_CTRL_BASE;

    uart_puts("phase uncached SDRAM control: ");
    fill_words(words, UNCACHED_WORD_COUNT, 0x31415926u);
    memory_barrier();
    check_words("uncached", words, UNCACHED_WORD_COUNT, 0x31415926u, 0u);
    uart_puts("PASS bytes=");
    uart_put_hex32(UNCACHED_WORD_COUNT * 4u);
    uart_puts("\r\n");
}

static void phase_cached_memory(void)
{
    volatile uint32_t *a = (volatile uint32_t *)(uintptr_t)CACHED_A_BASE;
    volatile uint32_t *b = (volatile uint32_t *)(uintptr_t)CACHED_B_BASE;
    uint32_t lfsr = 0x6d2b79f5u;
    uint32_t signature = 0u;

    uart_puts("phase cached SDRAM patterns: ");
    fill_words(a, CACHED_WORD_COUNT, 0x89abcdefu);
    fill_words(b, CACHED_WORD_COUNT, 0x10203040u);
    memory_barrier();
    check_words("cached-a", a, CACHED_WORD_COUNT, 0x89abcdefu, 0u);
    check_words("cached-b", b, CACHED_WORD_COUNT, 0x10203040u, 0u);

    for (uint32_t i = 0u; i < CACHE_CHURN_READS; ++i) {
        lfsr ^= lfsr << 13;
        lfsr ^= lfsr >> 17;
        lfsr ^= lfsr << 5;
        uint32_t index_a = lfsr & (CACHED_WORD_COUNT - 1u);
        uint32_t index_b = (lfsr ^ (lfsr >> 9)) &
            (CACHED_WORD_COUNT - 1u);
        uint32_t actual_a = a[index_a];
        uint32_t actual_b = b[index_b];
        uint32_t expected_a = pattern_word(index_a, 0x89abcdefu);
        uint32_t expected_b = pattern_word(index_b, 0x10203040u);

        if (actual_a != expected_a) {
            verify_fail("cached-churn-a", i, index_a,
                (uint32_t)(uintptr_t)&a[index_a], expected_a, actual_a);
        }
        if (actual_b != expected_b) {
            verify_fail("cached-churn-b", i, index_b,
                (uint32_t)(uintptr_t)&b[index_b], expected_b, actual_b);
        }
        signature = rotl32(signature ^ actual_a, 3u) + actual_b + i;
    }

    uart_puts("PASS signature=");
    uart_put_hex32(signature);
    uart_puts("\r\n");
}

static void set_guard(volatile uint32_t *guard, uint32_t value)
{
    for (uint32_t i = 0u; i < GUARD_WORDS; ++i) {
        guard[i] = value ^ (i * 0x11111111u);
    }
}

static void check_guard(const char *phase, volatile uint32_t *guard,
    uint32_t value, uint32_t pass)
{
    for (uint32_t i = 0u; i < GUARD_WORDS; ++i) {
        uint32_t expected = value ^ (i * 0x11111111u);
        uint32_t actual = guard[i];
        if (actual != expected) {
            verify_fail(phase, pass, i,
                (uint32_t)(uintptr_t)&guard[i], expected, actual);
        }
    }
}

static void init_lookup_workspace(volatile struct lookup_workspace *w)
{
    static const int16_t origins[LOOKUP_PATCHES] = {0, 0, 17, 64, 64};
    static const uint32_t ids[LOOKUP_PATCHES] = {1070, 1070, 1170, 1070, 1070};

    w->texture.name[0] = 'B';
    w->texture.name[1] = 'I';
    w->texture.name[2] = 'G';
    w->texture.name[3] = 'D';
    w->texture.name[4] = 'O';
    w->texture.name[5] = 'O';
    w->texture.name[6] = 'R';
    w->texture.name[7] = '1';
    w->texture.width = (int16_t)LOOKUP_COLUMNS;
    w->texture.height = (int16_t)LOOKUP_HEIGHT;
    w->texture.index = 0x11223344u;
    w->texture.next = 0u;
    w->texture.patchcount = (int16_t)LOOKUP_PATCHES;
    w->texture.reserved = 0;

    for (uint32_t i = 0u; i < LOOKUP_PATCHES; ++i) {
        w->texture.patches[i].originx = origins[i];
        w->texture.patches[i].originy = (i & 1u) != 0u ? 24 : 0;
        w->texture.patches[i].patch = ids[i];
    }

    w->realpatch[0].width = 64;
    w->realpatch[0].height = 72;
    w->realpatch[0].leftoffset = 31;
    w->realpatch[0].topoffset = 67;
    w->realpatch[1].width = 16;
    w->realpatch[1].height = 144;
    w->realpatch[1].leftoffset = 7;
    w->realpatch[1].topoffset = 139;

    for (uint32_t i = 0u; i < 16u; ++i) {
        w->realpatch[0].columnofs[i] = 264u + 77u * i;
        w->realpatch[1].columnofs[i] = 72u + 153u * i;
    }
}

static void verify_texture_descriptor(volatile struct lookup_workspace *w,
    uint32_t pass)
{
    static const int16_t origins[LOOKUP_PATCHES] = {0, 0, 17, 64, 64};
    static const uint32_t ids[LOOKUP_PATCHES] = {1070, 1070, 1170, 1070, 1070};

    if (w->texture.width != (int16_t)LOOKUP_COLUMNS) {
        verify_fail("texture-width", pass, 0u,
            (uint32_t)(uintptr_t)&w->texture.width, LOOKUP_COLUMNS,
            (uint16_t)w->texture.width);
    }
    if (w->texture.height != (int16_t)LOOKUP_HEIGHT) {
        verify_fail("texture-height", pass, 0u,
            (uint32_t)(uintptr_t)&w->texture.height, LOOKUP_HEIGHT,
            (uint16_t)w->texture.height);
    }
    if (w->texture.patchcount != (int16_t)LOOKUP_PATCHES) {
        verify_fail("texture-patchcount", pass, 0u,
            (uint32_t)(uintptr_t)&w->texture.patchcount, LOOKUP_PATCHES,
            (uint16_t)w->texture.patchcount);
    }

    for (uint32_t i = 0u; i < LOOKUP_PATCHES; ++i) {
        if (w->texture.patches[i].originx != origins[i]) {
            verify_fail("texture-originx", pass, i,
                (uint32_t)(uintptr_t)&w->texture.patches[i].originx,
                (uint16_t)origins[i],
                (uint16_t)w->texture.patches[i].originx);
        }
        if (w->texture.patches[i].patch != ids[i]) {
            verify_fail("texture-patch-id", pass, i,
                (uint32_t)(uintptr_t)&w->texture.patches[i].patch,
                ids[i], w->texture.patches[i].patch);
        }
    }
}

static void clear_lookup_arrays(volatile struct lookup_workspace *w)
{
    for (uint32_t x = 0u; x < LOOKUP_COLUMNS; ++x) {
        w->patchcount[x] = 0u;
        w->column_lump[x] = 0u;
        w->column_ofs[x] = 0u;
    }
    w->composite_size = 0u;
}

static void run_lookup_round(volatile struct lookup_workspace *w,
    uint32_t pass, uint32_t *signature)
{
    set_guard(w->guard0, GUARD0 ^ pass);
    set_guard(w->guard1, GUARD1 ^ pass);
    set_guard(w->guard2, GUARD2 ^ pass);
    set_guard(w->guard3, GUARD3 ^ pass);
    set_guard(w->guard4, GUARD4 ^ pass);
    clear_lookup_arrays(w);
    memory_barrier();
    verify_texture_descriptor(w, pass);

    for (uint32_t i = 0u; i < (uint32_t)w->texture.patchcount; ++i) {
        volatile struct texpatch *patch = &w->texture.patches[i];
        uint32_t patch_index = patch->patch == 1170u ? 1u : 0u;
        volatile struct synthetic_patch *realpatch = &w->realpatch[patch_index];
        int32_t x1 = patch->originx;
        int32_t x2 = x1 + realpatch->width;

        if (x1 < 0) {
            x1 = 0;
        }
        if (x2 > w->texture.width) {
            x2 = w->texture.width;
        }

        for (int32_t x = x1; x < x2; ++x) {
            uint32_t column = (uint32_t)x;
            uint32_t source_column = (uint32_t)(x - patch->originx);
            w->patchcount[column] = (uint8_t)(w->patchcount[column] + 1u);
            w->column_lump[column] = (uint16_t)patch->patch;
            w->column_ofs[column] = (uint16_t)(3u + source_column * 4u);
        }
    }

    memory_barrier();

    for (uint32_t x = 0u; x < LOOKUP_COLUMNS; ++x) {
        uint32_t expected_count = (x >= 17u && x < 33u) ? 3u : 2u;
        uint32_t actual_count = w->patchcount[x];

        if (actual_count != expected_count) {
            verify_fail("lookup-patchcount", pass, x,
                (uint32_t)(uintptr_t)&w->patchcount[x],
                expected_count, actual_count);
        }

        if (actual_count > 1u) {
            uint32_t before = w->composite_size;
            uint32_t limit = 0x10000u - (uint16_t)w->texture.height;

            w->column_lump[x] = 0xffffu;
            w->column_ofs[x] = (uint16_t)before;
            if (before > limit) {
                verify_fail("lookup-64k", pass, x,
                    (uint32_t)(uintptr_t)&w->composite_size,
                    x * LOOKUP_HEIGHT, before);
            }
            w->composite_size = before + (uint16_t)w->texture.height;
        }
    }

    memory_barrier();

    if (w->composite_size != LOOKUP_FINAL_SIZE) {
        verify_fail("lookup-final-size", pass, LOOKUP_COLUMNS,
            (uint32_t)(uintptr_t)&w->composite_size,
            LOOKUP_FINAL_SIZE, w->composite_size);
    }

    for (uint32_t x = 0u; x < LOOKUP_COLUMNS; ++x) {
        uint32_t expected_ofs = x * LOOKUP_HEIGHT;
        if (w->column_lump[x] != 0xffffu) {
            verify_fail("lookup-lump", pass, x,
                (uint32_t)(uintptr_t)&w->column_lump[x],
                0xffffu, w->column_lump[x]);
        }
        if (w->column_ofs[x] != (uint16_t)expected_ofs) {
            verify_fail("lookup-ofs", pass, x,
                (uint32_t)(uintptr_t)&w->column_ofs[x],
                expected_ofs, w->column_ofs[x]);
        }
        *signature = rotl32(*signature ^ w->column_ofs[x], 5u) +
            w->patchcount[x] + x;
    }

    check_guard("lookup-guard0", w->guard0, GUARD0 ^ pass, pass);
    check_guard("lookup-guard1", w->guard1, GUARD1 ^ pass, pass);
    check_guard("lookup-guard2", w->guard2, GUARD2 ^ pass, pass);
    check_guard("lookup-guard3", w->guard3, GUARD3 ^ pass, pass);
    check_guard("lookup-guard4", w->guard4, GUARD4 ^ pass, pass);
}

static void phase_doom_lookup(void)
{
    volatile struct lookup_workspace *a =
        (volatile struct lookup_workspace *)(uintptr_t)LOOKUP_A_BASE;
    volatile struct lookup_workspace *b =
        (volatile struct lookup_workspace *)(uintptr_t)LOOKUP_B_BASE;
    volatile uint32_t *cache_a =
        (volatile uint32_t *)(uintptr_t)CACHED_A_BASE;
    volatile uint32_t *cache_b =
        (volatile uint32_t *)(uintptr_t)CACHED_B_BASE;
    uint32_t signature = 0x4c4f4f4bu;
    uint32_t lfsr = 0xa5c3f17du;

    init_lookup_workspace(a);
    init_lookup_workspace(b);
    memory_barrier();

    uart_puts("phase Doom-like cached lookup: ");
    for (uint32_t pass = 0u; pass < VERIFY_ROUNDS; ++pass) {
        volatile struct lookup_workspace *w = (pass & 1u) != 0u ? b : a;

        for (uint32_t i = 0u; i < 64u; ++i) {
            lfsr ^= lfsr << 13;
            lfsr ^= lfsr >> 17;
            lfsr ^= lfsr << 5;
            uint32_t ia = lfsr & (CACHED_WORD_COUNT - 1u);
            uint32_t ib = (lfsr ^ (lfsr >> 11)) &
                (CACHED_WORD_COUNT - 1u);
            uint32_t va = cache_a[ia];
            uint32_t vb = cache_b[ib];
            uint32_t ea = pattern_word(ia, 0x89abcdefu);
            uint32_t eb = pattern_word(ib, 0x10203040u);

            if (va != ea) {
                verify_fail("lookup-thrash-a", pass, ia,
                    (uint32_t)(uintptr_t)&cache_a[ia], ea, va);
            }
            if (vb != eb) {
                verify_fail("lookup-thrash-b", pass, ib,
                    (uint32_t)(uintptr_t)&cache_b[ib], eb, vb);
            }
            signature = rotl32(signature ^ va, 7u) + vb;
        }

        run_lookup_round(w, pass, &signature);

        if ((pass & 0x3ffu) == 0x3ffu) {
            uart_putc('.');
        }
    }

    uart_puts(" PASS rounds=");
    uart_put_hex32(VERIFY_ROUNDS);
    uart_puts(" signature=");
    uart_put_hex32(signature);
    uart_puts("\r\n");
}

__attribute__((noreturn))
void verify_main(void)
{
    uart_init();
    uart_puts("\r\nHazard3 cached-path software verifier\r\n");
    uart_puts("code executes from cached external SDRAM at 0x20000040\r\n");
    uart_puts("cached test regions: 0x20400000 and 0x20C00000\r\n");
    uart_puts("uncached control: 0x24C80000\r\n");
    uart_puts("rounds=");
    uart_put_hex32(VERIFY_ROUNDS);
    uart_puts("\r\n");

    phase_alu();
    phase_uncached_control();
    phase_cached_memory();
    phase_doom_lookup();

    uart_puts("VERIFY RESULT: PASS\r\n");
    park();
}
