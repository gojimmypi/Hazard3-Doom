#include "sdram_exec_test.h"

#include <stddef.h>
#include <stdint.h>

#include "hazard3_platform.h"

#define SDRAM_EXEC_ITERATIONS 8192u
#define SDRAM_EXEC_SEED       0x48415a33u
#define SDRAM_EXEC_CONSTANT   0x9e3779b9u
#define SDRAM_EXEC_MAX_BYTES  4096u

typedef uint32_t (*sdram_exec_function_t)(
    volatile uint32_t* scratch,
    uint32_t iteration_count,
    uint32_t seed);

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
    hazard3_console_puts("  ");
    hazard3_console_puts(name);
    hazard3_console_puts(": ");
    hazard3_console_puts(passed != 0 ? "PASS\r\n" : "FAIL\r\n");
}

int sdram_exec_test_run(void)
{
    const uint8_t* source = sdram_exec_payload_start;
    uint8_t* destination = (uint8_t*)(uintptr_t)hazard3_doom_image_base();
    volatile uint32_t* scratch = (volatile uint32_t*)(uintptr_t)(
        hazard3_doom_image_limit() - sizeof(uint32_t));
    sdram_exec_function_t function;
    uint32_t expected_scratch;
    uint32_t actual_scratch;
    uint32_t start_ticks;
    uint32_t payload_size;
    int size_passed;
    int copy_passed;
    int result_passed;
    int scratch_passed;
    int timer_passed;
    int elapsed_passed;
    int passed;

    payload_size = (uint32_t)((uintptr_t)sdram_exec_payload_end -
        (uintptr_t)sdram_exec_payload_start);
    exec_payload_bytes = payload_size;
    ++exec_runs;
    exec_last_passed = 0;
    exec_last_timer_hits = 0u;

    hazard3_console_puts("\r\nSDRAM executable-code test\r\n");
    hazard3_console_puts("  image_base=");
    hazard3_console_put_hex32(hazard3_doom_image_base());
    hazard3_console_puts(" image_limit=");
    hazard3_console_put_hex32(hazard3_doom_image_limit());
    hazard3_console_puts(" payload_bytes=");
    hazard3_console_put_hex32(payload_size);
    hazard3_console_puts("\r\n");

    size_passed = payload_size != 0u && payload_size <= SDRAM_EXEC_MAX_BYTES;

    if (size_passed) {
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
    } else {
        copy_passed = 0;
    }

    exec_last_expected = payload_model(
        SDRAM_EXEC_ITERATIONS,
        SDRAM_EXEC_SEED,
        &expected_scratch);

    *scratch = 0u;
    hazard3_memory_barrier();
    __asm__ volatile ("fence.i" ::: "memory");

    function = (sdram_exec_function_t)(uintptr_t)hazard3_doom_image_base();
    exec_run_timer_hits = 0u;
    exec_active = 1u;
    start_ticks = hazard3_ticks_ms();

    if (size_passed && copy_passed) {
        exec_last_result = function(
            scratch,
            SDRAM_EXEC_ITERATIONS,
            SDRAM_EXEC_SEED);
    } else {
        exec_last_result = 0u;
    }

    exec_last_elapsed_ms = hazard3_ticks_ms() - start_ticks;
    exec_active = 0u;
    exec_last_timer_hits = exec_run_timer_hits;
    hazard3_memory_barrier();
    actual_scratch = *scratch;

    result_passed = exec_last_result == exec_last_expected;
    scratch_passed = actual_scratch == expected_scratch;
    timer_passed = exec_last_timer_hits != 0u;
    elapsed_passed = exec_last_elapsed_ms >= 10u;

    print_result_line("payload size", size_passed);
    print_result_line("copy/readback", copy_passed);
    print_result_line("return value", result_passed);
    print_result_line("SDRAM data access", scratch_passed);
    print_result_line("timer interrupt while executing SDRAM", timer_passed);
    print_result_line("execution crossed timer period", elapsed_passed);

    passed = size_passed && copy_passed && result_passed && scratch_passed &&
        timer_passed && elapsed_passed;
    exec_last_passed = passed;

    if (!passed) {
        ++exec_failures;
    }

    hazard3_console_puts("  result: ");
    hazard3_console_puts(passed != 0 ? "PASS" : "FAIL");
    hazard3_console_puts(" elapsed_ms=");
    hazard3_console_put_hex32(exec_last_elapsed_ms);
    hazard3_console_puts(" timer_hits=");
    hazard3_console_put_hex32(exec_last_timer_hits);
    hazard3_console_puts(" actual=");
    hazard3_console_put_hex32(exec_last_result);
    hazard3_console_puts(" expected=");
    hazard3_console_put_hex32(exec_last_expected);
    hazard3_console_puts("\r\n");

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
