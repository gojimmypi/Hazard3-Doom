#include "doom_port_smoke.h"

#include "hazard3_platform.h"

#define DOOM_SCREEN_WIDTH             320u
#define DOOM_SCREEN_HEIGHT            200u
#define DOOM_SCREEN_BYTES             (DOOM_SCREEN_WIDTH * DOOM_SCREEN_HEIGHT)
#define DOOM_ZONE_BYTES               (6u * 1024u * 1024u)
#define DOOM_WAD_WORK_BYTES           (256u * 1024u)
#define DOOM_ZONE_SAMPLE_STRIDE_BYTES 4096u
#define DOOM_REQUIRED_ALIGNMENT       16u

static uint32_t smoke_runs;
static uint32_t smoke_failures;
static uint32_t smoke_last_elapsed_ms;
static uint32_t smoke_last_heap_used;
static int smoke_last_passed;

static uint32_t pattern_word(uint32_t byte_address, uint32_t seed)
{
    uint32_t value = byte_address ^ seed ^ 0x9e3779b9u;

    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

static int pointer_is_aligned(const void* pointer)
{
    return (((uintptr_t)pointer & (DOOM_REQUIRED_ALIGNMENT - 1u)) == 0u);
}

static int framebuffer_test(uint8_t* framebuffer)
{
    uint32_t index;

    for (index = 0u; index < DOOM_SCREEN_BYTES; ++index) {
        framebuffer[index] = (uint8_t)(index ^ (index >> 8));
    }

    for (index = 0u; index < DOOM_SCREEN_BYTES; ++index) {
        uint8_t expected = (uint8_t)(index ^ (index >> 8));

        if (framebuffer[index] != expected) {
            return 0;
        }
    }

    return 1;
}

static int zone_sample_test(uint32_t* zone)
{
    const uint32_t stride_words = DOOM_ZONE_SAMPLE_STRIDE_BYTES / sizeof(uint32_t);
    const uint32_t word_count = DOOM_ZONE_BYTES / sizeof(uint32_t);
    uint32_t index;

    for (index = 0u; index < word_count; index += stride_words) {
        uint32_t address = (uint32_t)(uintptr_t)&zone[index];
        zone[index] = pattern_word(address, 0x444f4f4du);
    }

    zone[word_count - 1u] = pattern_word(
        (uint32_t)(uintptr_t)&zone[word_count - 1u],
        0x5a4f4e45u);

    for (index = 0u; index < word_count; index += stride_words) {
        uint32_t address = (uint32_t)(uintptr_t)&zone[index];
        uint32_t expected = pattern_word(address, 0x444f4f4du);

        if (zone[index] != expected) {
            return 0;
        }
    }

    return zone[word_count - 1u] == pattern_word(
        (uint32_t)(uintptr_t)&zone[word_count - 1u],
        0x5a4f4e45u);
}

static int wad_work_test(uint32_t* work_area)
{
    const uint32_t word_count = DOOM_WAD_WORK_BYTES / sizeof(uint32_t);
    uint32_t index;

    for (index = 0u; index < word_count; ++index) {
        uint32_t address = (uint32_t)(uintptr_t)&work_area[index];
        work_area[index] = pattern_word(address, 0x57414421u);
    }

    for (index = 0u; index < word_count; ++index) {
        uint32_t address = (uint32_t)(uintptr_t)&work_area[index];
        uint32_t expected = pattern_word(address, 0x57414421u);

        if (work_area[index] != expected) {
            return 0;
        }
    }

    return 1;
}

static void print_result_line(const char* name, int passed)
{
    hazard3_console_puts("  ");
    hazard3_console_puts(name);
    hazard3_console_puts(": ");
    hazard3_console_puts(passed != 0 ? "PASS\r\n" : "FAIL\r\n");
}

int doom_port_smoke_run(void)
{
    uint8_t* framebuffer;
    uint32_t* zone;
    uint32_t* wad_work;
    uint32_t start_ticks;
    uint32_t sleep_start;
    int allocation_passed;
    int alignment_passed;
    int framebuffer_passed;
    int zone_passed;
    int wad_work_passed;
    int timer_passed;
    int passed;

    if (hazard3_heap_is_active()) {
        hazard3_console_puts("\r\nREFUSED: the SDRAM heap is already active.\r\n");
        hazard3_console_puts(
            "Run z first; every existing heap pointer will become invalid.\r\n");
        return 0;
    }

    ++smoke_runs;
    smoke_last_passed = 0;
    start_ticks = hazard3_ticks_ms();

    hazard3_console_puts("\r\nDoom Hazard3 platform smoke test\r\n");
    hazard3_console_puts("  framebuffer: 320x200, 8-bit, bytes=");
    hazard3_console_put_hex32(DOOM_SCREEN_BYTES);
    hazard3_console_puts("\r\n  zone target: ");
    hazard3_console_put_hex32(DOOM_ZONE_BYTES);
    hazard3_console_puts(" bytes\r\n");

    framebuffer = (uint8_t*)hazard3_heap_alloc(DOOM_SCREEN_BYTES);
    zone = (uint32_t*)hazard3_heap_alloc(DOOM_ZONE_BYTES);
    wad_work = (uint32_t*)hazard3_heap_alloc(DOOM_WAD_WORK_BYTES);

    allocation_passed = framebuffer != (void*)0 &&
        zone != (void*)0 && wad_work != (void*)0;
    alignment_passed = allocation_passed &&
        pointer_is_aligned(framebuffer) &&
        pointer_is_aligned(zone) &&
        pointer_is_aligned(wad_work);

    framebuffer_passed = allocation_passed && framebuffer_test(framebuffer);
    zone_passed = allocation_passed && zone_sample_test(zone);
    wad_work_passed = allocation_passed && wad_work_test(wad_work);

    sleep_start = hazard3_ticks_ms();
    hazard3_sleep_ms(20u);
    timer_passed = (uint32_t)(hazard3_ticks_ms() - sleep_start) >= 20u;

    print_result_line("allocations", allocation_passed);
    print_result_line("16-byte alignment", alignment_passed);
    print_result_line("320x200 framebuffer memory", framebuffer_passed);
    print_result_line("6 MiB Doom zone samples", zone_passed);
    print_result_line("256 KiB WAD work area", wad_work_passed);
    print_result_line("millisecond timer/sleep", timer_passed);

    passed = allocation_passed && alignment_passed &&
        framebuffer_passed && zone_passed && wad_work_passed && timer_passed;

    smoke_last_elapsed_ms = hazard3_ticks_ms() - start_ticks;
    smoke_last_heap_used = hazard3_heap_used();
    smoke_last_passed = passed;

    if (!passed) {
        ++smoke_failures;
    }

    hazard3_console_puts("  result: ");
    hazard3_console_puts(passed != 0 ? "PASS" : "FAIL");
    hazard3_console_puts(" elapsed_ms=");
    hazard3_console_put_hex32(smoke_last_elapsed_ms);
    hazard3_console_puts(" heap_used=");
    hazard3_console_put_hex32(smoke_last_heap_used);
    hazard3_console_puts(" remaining=");
    hazard3_console_put_hex32(hazard3_heap_remaining());
    hazard3_console_puts("\r\n");

    return passed;
}

uint32_t doom_port_smoke_runs(void)
{
    return smoke_runs;
}

uint32_t doom_port_smoke_failures(void)
{
    return smoke_failures;
}

uint32_t doom_port_smoke_last_elapsed_ms(void)
{
    return smoke_last_elapsed_ms;
}

uint32_t doom_port_smoke_last_heap_used(void)
{
    return smoke_last_heap_used;
}

int doom_port_smoke_last_passed(void)
{
    return smoke_last_passed;
}
