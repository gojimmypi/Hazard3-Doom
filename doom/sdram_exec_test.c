/* -----------------------------------------------------------------------------
 * File:        sdram_exec_test.c
 * Path:        doom/sdram_exec_test.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Exercise code execution from external SDRAM and report timing and
 *              integrity results.
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

#include "sdram_exec_test.h"

#include <stddef.h>
#include <stdint.h>

#include "hazard3_platform.h"

#ifdef HAZARD3_TINY_MEM_TEST
#define SDRAM_EXEC_ITERATIONS 8192u
#else
#define SDRAM_EXEC_ITERATIONS 262144u
#endif

#define SDRAM_EXEC_SEED               0x48415a33u
#define SDRAM_EXEC_CONSTANT           0x9e3779b9u
#define SDRAM_EXEC_MAX_BYTES          4096u
#define SDRAM_EXEC_MIN_TIMER_HITS     2u
#define SDRAM_EXEC_MIN_ELAPSED_MS     20u

/*
 * Put foreign gp at the center of a 4096-byte sacrificial window. Standard
 * signed 12-bit GP-relative accesses (-2048..+2047) then remain in that window.
 * Guards immediately outside the window catch any unexpected escape.
 */
#define SDRAM_EXEC_FOREIGN_GP_BYTES   4096u
#define SDRAM_EXEC_GUARD_WORDS        16u
#define SDRAM_EXEC_GUARD_BYTES        (SDRAM_EXEC_GUARD_WORDS * sizeof(uint32_t))
#define SDRAM_EXEC_RESERVED_BYTES     8192u
#define SDRAM_EXEC_SACRIFICIAL_FROM_LIMIT 6144u
#define SDRAM_EXEC_GUARD_LOW_BASE     0x13579bdfu
#define SDRAM_EXEC_GUARD_HIGH_BASE    0x2468ace0u
#define SDRAM_EXEC_BODY_BASE          0xa5c30000u

typedef uint32_t (*sdram_exec_function_t)(
    volatile uint32_t* scratch,
    uint32_t iteration_count,
    uint32_t seed,
    uint32_t foreign_gp_base);

extern const uint8_t sdram_exec_payload_start[];
extern const uint8_t sdram_exec_payload_end[];

static volatile uint32_t exec_active;
static volatile uint32_t exec_run_timer_hits;
static uint32_t exec_runs;
static uint32_t exec_failures;
static uint32_t exec_last_elapsed_ms;
static uint32_t exec_last_timer_hits;
static uint32_t exec_last_result;
static uint32_t exec_last_expected;
static uint32_t exec_payload_bytes;
static int exec_last_passed;

static uint32_t payload_model(
    uint32_t iteration_count,
    uint32_t seed,
    uint32_t* final_scratch)
{
    uint32_t state = seed;
    uint32_t scratch = 0u;

    while (iteration_count-- != 0u) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;

        scratch = state;
        state ^= scratch + SDRAM_EXEC_CONSTANT;
    }

    *final_scratch = scratch;
    return state;
}

static void print_result_line(const char* name, int passed)
{
    hazard3_console_puts("    ");
    hazard3_console_puts(name);
    hazard3_console_puts(": ");
    hazard3_console_puts(passed != 0 ? "PASS\r\n" : "FAIL\r\n");
}

static uint32_t sacrificial_expected(uint32_t index)
{
    return SDRAM_EXEC_BODY_BASE ^ (index * SDRAM_EXEC_CONSTANT);
}

static uint32_t guard_low_expected(uint32_t index)
{
    return SDRAM_EXEC_GUARD_LOW_BASE ^ (index * SDRAM_EXEC_CONSTANT);
}

static uint32_t guard_high_expected(uint32_t index)
{
    return SDRAM_EXEC_GUARD_HIGH_BASE ^ (index * SDRAM_EXEC_CONSTANT);
}

static void sacrificial_initialize(
    volatile uint32_t* guard_low,
    volatile uint32_t* sacrificial,
    volatile uint32_t* guard_high)
{
    uint32_t index;
    uint32_t body_words = SDRAM_EXEC_FOREIGN_GP_BYTES / sizeof(uint32_t);

    for (index = 0u; index < SDRAM_EXEC_GUARD_WORDS; ++index) {
        guard_low[index] = guard_low_expected(index);
        guard_high[index] = guard_high_expected(index);
    }

    for (index = 0u; index < body_words; ++index) {
        sacrificial[index] = sacrificial_expected(index);
    }

    hazard3_memory_barrier();
}

static int sacrificial_verify(
    volatile uint32_t* guard_low,
    volatile uint32_t* sacrificial,
    volatile uint32_t* guard_high,
    int* guards_passed)
{
    uint32_t index;
    uint32_t body_words = SDRAM_EXEC_FOREIGN_GP_BYTES / sizeof(uint32_t);
    uint32_t first_address = 0u;
    uint32_t first_expected = 0u;
    uint32_t first_actual = 0u;
    int body_passed = 1;

    *guards_passed = 1;

#define CHECK_WORD(address_, expected_, body_) do { \
        uint32_t actual_ = *(address_); \
        uint32_t expected_value_ = (expected_); \
        if (actual_ != expected_value_) { \
            if ((body_) != 0) { \
                body_passed = 0; \
            } else { \
                *guards_passed = 0; \
            } \
            if (first_address == 0u) { \
                first_address = (uint32_t)(uintptr_t)(address_); \
                first_expected = expected_value_; \
                first_actual = actual_; \
            } \
        } \
    } while (0)

    for (index = 0u; index < SDRAM_EXEC_GUARD_WORDS; ++index) {
        CHECK_WORD(&guard_low[index], guard_low_expected(index), 0);
    }

    for (index = 0u; index < body_words; ++index) {
        CHECK_WORD(&sacrificial[index], sacrificial_expected(index), 1);
    }

    for (index = 0u; index < SDRAM_EXEC_GUARD_WORDS; ++index) {
        CHECK_WORD(&guard_high[index], guard_high_expected(index), 0);
    }

#undef CHECK_WORD

    if (first_address != 0u) {
        hazard3_console_puts("    first mutation: addr=");
        hazard3_console_put_hex32(first_address);
        hazard3_console_puts(" expected=");
        hazard3_console_put_hex32(first_expected);
        hazard3_console_puts(" actual=");
        hazard3_console_put_hex32(first_actual);
        hazard3_console_puts("\r\n");
    }

    return body_passed;
}

static int run_payload_phase(
    const char* name,
    sdram_exec_function_t function,
    volatile uint32_t* scratch,
    volatile uint32_t* guard_low,
    volatile uint32_t* sacrificial,
    volatile uint32_t* guard_high,
    uint32_t foreign_gp_base,
    uint32_t expected_scratch)
{
    uint32_t start_ticks;
    uint32_t actual_scratch;
    int result_passed;
    int scratch_passed;
    int timer_passed;
    int elapsed_passed;
    int sacrificial_passed;
    int guards_passed;
    int passed;

    sacrificial_initialize(guard_low, sacrificial, guard_high);
    *scratch = 0u;
    hazard3_memory_barrier();

    exec_run_timer_hits = 0u;
    exec_active = 1u;
    start_ticks = hazard3_ticks_ms();

    exec_last_result = function(
        scratch,
        SDRAM_EXEC_ITERATIONS,
        SDRAM_EXEC_SEED,
        foreign_gp_base);

    exec_last_elapsed_ms = hazard3_ticks_ms() - start_ticks;
    exec_active = 0u;
    exec_last_timer_hits = exec_run_timer_hits;
    hazard3_memory_barrier();
    actual_scratch = *scratch;

    result_passed = exec_last_result == exec_last_expected;
    scratch_passed = actual_scratch == expected_scratch;
    timer_passed = exec_last_timer_hits >= SDRAM_EXEC_MIN_TIMER_HITS;
    elapsed_passed = exec_last_elapsed_ms >= SDRAM_EXEC_MIN_ELAPSED_MS;
    sacrificial_passed = sacrificial_verify(
        guard_low,
        sacrificial,
        guard_high,
        &guards_passed);

    hazard3_console_puts("  phase ");
    hazard3_console_puts(name);
    hazard3_console_puts("\r\n");
    print_result_line("return value", result_passed);
    print_result_line("SDRAM data access", scratch_passed);
    print_result_line("timer interrupts", timer_passed);
    print_result_line("execution duration", elapsed_passed);
    print_result_line("sacrificial GP window unchanged", sacrificial_passed);
    print_result_line("sacrificial guards unchanged", guards_passed);

    hazard3_console_puts("    elapsed_ms=");
    hazard3_console_put_hex32(exec_last_elapsed_ms);
    hazard3_console_puts(" timer_hits=");
    hazard3_console_put_hex32(exec_last_timer_hits);
    hazard3_console_puts(" actual=");
    hazard3_console_put_hex32(exec_last_result);
    hazard3_console_puts(" expected=");
    hazard3_console_put_hex32(exec_last_expected);
    hazard3_console_puts("\r\n");

    passed = result_passed && scratch_passed && timer_passed && elapsed_passed &&
        sacrificial_passed && guards_passed;
    hazard3_console_puts("    phase result: ");
    hazard3_console_puts(passed != 0 ? "PASS\r\n" : "FAIL\r\n");
    return passed;
}

int sdram_exec_test_run(void)
{
    const uint8_t* source = sdram_exec_payload_start;
    uint32_t image_base = hazard3_doom_image_base();
    uint32_t image_limit = hazard3_doom_image_limit();
    uint8_t* destination = (uint8_t*)(uintptr_t)image_base;
    volatile uint32_t* guard_low;
    volatile uint32_t* sacrificial;
    volatile uint32_t* guard_high;
    volatile uint32_t* scratch;
    sdram_exec_function_t function;
    uint32_t expected_scratch;
    uint32_t payload_size;
    uint32_t foreign_gp_base;
    int size_passed;
    int layout_passed;
    int copy_passed;
    int normal_passed = 0;
    int foreign_passed = 0;
    int passed;

    payload_size = (uint32_t)((uintptr_t)sdram_exec_payload_end -
        (uintptr_t)sdram_exec_payload_start);
    exec_payload_bytes = payload_size;
    ++exec_runs;
    exec_last_passed = 0;
    exec_last_timer_hits = 0u;

    hazard3_console_puts("\r\nSDRAM executable-code / foreign-GP test\r\n");
    hazard3_console_puts("  image_base=");
    hazard3_console_put_hex32(image_base);
    hazard3_console_puts(" image_limit=");
    hazard3_console_put_hex32(image_limit);
    hazard3_console_puts(" payload_bytes=");
    hazard3_console_put_hex32(payload_size);
    hazard3_console_puts("\r\n");

    size_passed = payload_size != 0u && payload_size <= SDRAM_EXEC_MAX_BYTES;
    layout_passed = image_limit > image_base &&
        image_limit - image_base > SDRAM_EXEC_RESERVED_BYTES +
            SDRAM_EXEC_MAX_BYTES;

    sacrificial = (volatile uint32_t*)(uintptr_t)(
        image_limit - SDRAM_EXEC_SACRIFICIAL_FROM_LIMIT);
    guard_low = (volatile uint32_t*)(uintptr_t)(
        (uint32_t)(uintptr_t)sacrificial - SDRAM_EXEC_GUARD_BYTES);
    guard_high = (volatile uint32_t*)(uintptr_t)(
        (uint32_t)(uintptr_t)sacrificial + SDRAM_EXEC_FOREIGN_GP_BYTES);
    scratch = (volatile uint32_t*)(uintptr_t)(image_limit - sizeof(uint32_t));
    foreign_gp_base = (uint32_t)(uintptr_t)sacrificial;

    hazard3_console_puts("  sacrificial=");
    hazard3_console_put_hex32((uint32_t)(uintptr_t)sacrificial);
    hazard3_console_puts(" bytes=");
    hazard3_console_put_hex32(SDRAM_EXEC_FOREIGN_GP_BYTES);
    hazard3_console_puts(" foreign_gp_window_base=");
    hazard3_console_put_hex32(foreign_gp_base);
    hazard3_console_puts(" gp_offset=0x00000800\r\n");

    copy_passed = 0;
    if (size_passed && layout_passed) {
        uint32_t index;

        for (index = 0u; index < payload_size; ++index) {
            destination[index] = source[index];
        }

        hazard3_memory_barrier();
        copy_passed = 1;

        for (index = 0u; index < payload_size; ++index) {
            if (destination[index] != source[index]) {
                copy_passed = 0;
                break;
            }
        }
    }

    print_result_line("payload size", size_passed);
    print_result_line("reserved layout", layout_passed);
    print_result_line("copy/readback", copy_passed);

    exec_last_expected = payload_model(
        SDRAM_EXEC_ITERATIONS,
        SDRAM_EXEC_SEED,
        &expected_scratch);

    function = (sdram_exec_function_t)(uintptr_t)image_base;
    hazard3_memory_barrier();
    __asm__ volatile ("fence.i" ::: "memory");

    if (size_passed && layout_passed && copy_passed) {
        normal_passed = run_payload_phase(
            "normal-gp",
            function,
            scratch,
            guard_low,
            sacrificial,
            guard_high,
            0u,
            expected_scratch);

        foreign_passed = run_payload_phase(
            "foreign-gp",
            function,
            scratch,
            guard_low,
            sacrificial,
            guard_high,
            foreign_gp_base,
            expected_scratch);
    }

    passed = size_passed && layout_passed && copy_passed &&
        normal_passed && foreign_passed;
    exec_last_passed = passed;

    if (!passed) {
        ++exec_failures;
    }

    hazard3_console_puts("  overall result: ");
    hazard3_console_puts(passed != 0 ? "PASS\r\n" : "FAIL\r\n");
    return passed;
}

void sdram_exec_test_note_timer_pc(uint32_t mepc)
{
    if (exec_active != 0u &&
        mepc >= hazard3_doom_image_base() &&
        mepc < hazard3_doom_image_limit()) {
        ++exec_run_timer_hits;
    }
}

uint32_t sdram_exec_test_runs(void)
{
    return exec_runs;
}

uint32_t sdram_exec_test_failures(void)
{
    return exec_failures;
}

uint32_t sdram_exec_test_last_elapsed_ms(void)
{
    return exec_last_elapsed_ms;
}

uint32_t sdram_exec_test_last_timer_hits(void)
{
    return exec_last_timer_hits;
}

uint32_t sdram_exec_test_last_result(void)
{
    return exec_last_result;
}

uint32_t sdram_exec_test_last_expected(void)
{
    return exec_last_expected;
}

uint32_t sdram_exec_test_payload_bytes(void)
{
    return exec_payload_bytes;
}

int sdram_exec_test_last_passed(void)
{
    return exec_last_passed;
}
