#include <stddef.h>
#include <stdint.h>

#include "doom_image_format.h"
#include "doom_image_loader.h"
#include "doom_wad_loader.h"
#include "hazard3_monitor_services.h"
#include "hazard3_platform.h"
#include "hazard3_video.h"

#define LOADER_BYTE_TIMEOUT_MS 5000u
#define IMAGE_BACKUP_ALIGNMENT 16u
#define SDRAM_UNCACHED_ALIAS_OFFSET \
    (HAZARD3_SDRAM_DIAGNOSTIC_ALIAS_BASE - \
        HAZARD3_SDRAM_PHYSICAL_BASE)

static hazard3_doom_image_header_t loaded_header;
static uint32_t receive_run_count;
static uint32_t receive_failure_count;
static uint32_t launch_run_count;
static uint32_t launch_failure_count;
static uint32_t last_receive_elapsed_ms;
static uint32_t last_launch_elapsed_ms;
static uint32_t last_crc_expected;
static uint32_t last_crc_actual;
static uint32_t last_entry_return;
static uint32_t image_loaded;
static uint32_t image_backup_address;
static uint32_t image_backup_crc;
static uint32_t image_restore_count;
static uint32_t image_restart_ready;

extern void* _sbrk(ptrdiff_t increment);

static void clear_bss(uint32_t address, uint32_t byte_count);

static uint32_t crc32_update(uint32_t crc, uint8_t value)
{
    crc ^= value;
    for (uint32_t bit = 0u; bit < 8u; ++bit) {
        uint32_t mask = 0u - (crc & 1u);
        crc = (crc >> 1) ^ (0xedb88320u & mask);
    }
    return crc;
}

static int read_byte_with_timeout(uint8_t* value)
{
    uint32_t start_ticks = hazard3_ticks_ms();
    for (;;) {
        if (hazard3_console_getc_nonblocking(value)) {
            return 1;
        }
        if ((uint32_t)(hazard3_ticks_ms() - start_ticks) >= LOADER_BYTE_TIMEOUT_MS) {
            return 0;
        }
    }
}

static int read_exact(void* buffer, uint32_t byte_count)
{
    uint8_t* bytes = (uint8_t*)buffer;
    for (uint32_t i = 0u; i < byte_count; ++i) {
        if (!read_byte_with_timeout(&bytes[i])) {
            return 0;
        }
    }
    return 1;
}

static void drain_uart_rx(void)
{
    uint8_t ignored;
    while (hazard3_console_getc_nonblocking(&ignored)) {
    }
}

static int range_is_valid(uint32_t address, uint32_t byte_count)
{
    if (address < HAZARD3_DOOM_IMAGE_BASE || address > HAZARD3_DOOM_IMAGE_LIMIT) {
        return 0;
    }
    return byte_count <= HAZARD3_DOOM_IMAGE_LIMIT - address;
}

static int header_is_valid(const hazard3_doom_image_header_t* header)
{
    uint32_t load_end;
    uint32_t bss_end;
    if (header->magic != HAZARD3_DOOM_IMAGE_MAGIC ||
        header->header_bytes != HAZARD3_DOOM_IMAGE_HEADER_BYTES ||
        header->format_version != HAZARD3_DOOM_IMAGE_FORMAT_VERSION ||
        header->flags != HAZARD3_DOOM_IMAGE_FLAG_CRC32 ||
        header->load_address != HAZARD3_DOOM_IMAGE_BASE ||
        header->image_bytes == 0u ||
        !range_is_valid(header->load_address, header->image_bytes) ||
        !range_is_valid(header->bss_address, header->bss_bytes)) {
        return 0;
    }
    load_end = header->load_address + header->image_bytes;
    bss_end = header->bss_address + header->bss_bytes;
    if (header->entry_address < header->load_address ||
        header->entry_address >= load_end || header->bss_address < load_end ||
        (header->bss_address & 3u) != 0u || bss_end > HAZARD3_DOOM_IMAGE_LIMIT) {
        return 0;
    }
    for (uint32_t i = 0u; i < 6u; ++i) {
        if (header->reserved[i] != 0u) {
            return 0;
        }
    }
    return 1;
}

static uint32_t align_down(uint32_t value, uint32_t alignment)
{
    return value & ~(alignment - 1u);
}

static uint32_t image_backup_uncached_address(void)
{
    return image_backup_address + SDRAM_UNCACHED_ALIAS_OFFSET;
}

static void copy_memory(
    volatile uint8_t* destination,
    const volatile uint8_t* source,
    uint32_t byte_count)
{
    while ((((uintptr_t)destination | (uintptr_t)source) & 3u) != 0u &&
        byte_count != 0u) {
        *destination++ = *source++;
        --byte_count;
    }

    {
        volatile uint32_t* destination_words =
            (volatile uint32_t*)(uintptr_t)destination;
        const volatile uint32_t* source_words =
            (const volatile uint32_t*)(uintptr_t)source;
        uint32_t word_count = byte_count / sizeof(uint32_t);

        for (uint32_t i = 0u; i < word_count; ++i) {
            destination_words[i] = source_words[i];
        }

        destination += word_count * sizeof(uint32_t);
        source += word_count * sizeof(uint32_t);
        byte_count -= word_count * sizeof(uint32_t);
    }

    while (byte_count != 0u) {
        *destination++ = *source++;
        --byte_count;
    }
}

static uint32_t crc32_memory(
    const volatile uint8_t* source,
    uint32_t byte_count)
{
    uint32_t crc = 0xffffffffu;

    for (uint32_t i = 0u; i < byte_count; ++i) {
        crc = crc32_update(crc, source[i]);
    }

    return crc ^ 0xffffffffu;
}

static int prepare_image_backup(
    const hazard3_doom_image_header_t* header)
{
    uint32_t active_end = header->bss_address + header->bss_bytes;
    uint32_t backup_address = align_down(
        HAZARD3_DOOM_IMAGE_LIMIT - header->image_bytes,
        IMAGE_BACKUP_ALIGNMENT);
    volatile uint8_t* destination;
    const volatile uint8_t* source;

    if (backup_address < active_end ||
        backup_address < HAZARD3_DOOM_IMAGE_BASE ||
        backup_address + header->image_bytes >
            HAZARD3_DOOM_IMAGE_LIMIT) {
        return 0;
    }

    image_backup_address = backup_address;
    destination = (volatile uint8_t*)(uintptr_t)(
        image_backup_uncached_address());
    source = (const volatile uint8_t*)(uintptr_t)header->load_address;

    copy_memory(destination, source, header->image_bytes);
    hazard3_memory_barrier();

    image_backup_crc = crc32_memory(destination, header->image_bytes);
    if (image_backup_crc != header->payload_crc32) {
        image_backup_address = 0u;
        image_backup_crc = 0u;
        return 0;
    }

    image_restart_ready = 1u;
    return 1;
}

static int restore_image_from_backup(void)
{
    volatile uint8_t* destination;
    const volatile uint8_t* source;
    uint32_t restored_crc;

    if (image_restart_ready == 0u ||
        image_backup_address == 0u) {
        return 0;
    }

    destination = (volatile uint8_t*)(uintptr_t)loaded_header.load_address;
    source = (const volatile uint8_t*)(uintptr_t)(
        image_backup_uncached_address());

    copy_memory(destination, source, loaded_header.image_bytes);
    clear_bss(loaded_header.bss_address, loaded_header.bss_bytes);
    hazard3_memory_barrier();

    restored_crc = crc32_memory(
        (const volatile uint8_t*)(uintptr_t)loaded_header.load_address,
        loaded_header.image_bytes);
    if (restored_crc != loaded_header.payload_crc32) {
        image_restart_ready = 0u;
        image_loaded = 0u;
        return 0;
    }

    ++image_restore_count;
    __asm__ volatile ("fence.i" ::: "memory");
    return 1;
}

static void clear_bss(uint32_t address, uint32_t byte_count)
{
    volatile uint32_t* words = (volatile uint32_t*)(uintptr_t)address;
    uint32_t word_count = byte_count / sizeof(uint32_t);
    uint32_t remainder = byte_count & 3u;
    for (uint32_t i = 0u; i < word_count; ++i) {
        words[i] = 0u;
    }
    if (remainder != 0u) {
        volatile uint8_t* bytes = (volatile uint8_t*)(uintptr_t)(
            address + word_count * sizeof(uint32_t));
        for (uint32_t i = 0u; i < remainder; ++i) {
            bytes[i] = 0u;
        }
    }
}

static void copy_header(
    volatile hazard3_doom_image_header_t* destination,
    const hazard3_doom_image_header_t* source)
{
    volatile uint32_t* destination_words = (volatile uint32_t*)destination;
    const uint32_t* source_words = (const uint32_t*)source;
    for (uint32_t i = 0u; i < sizeof(*source) / sizeof(uint32_t); ++i) {
        destination_words[i] = source_words[i];
    }
}

static void print_header_summary(const hazard3_doom_image_header_t* header)
{
    hazard3_console_puts("  load=");
    hazard3_console_put_hex32(header->load_address);
    hazard3_console_puts(" bytes=");
    hazard3_console_put_hex32(header->image_bytes);
    hazard3_console_puts(" entry=");
    hazard3_console_put_hex32(header->entry_address);
    hazard3_console_puts("\r\n  bss=");
    hazard3_console_put_hex32(header->bss_address);
    hazard3_console_puts(" bss_bytes=");
    hazard3_console_put_hex32(header->bss_bytes);
    hazard3_console_puts(" crc32=");
    hazard3_console_put_hex32(header->payload_crc32);
    hazard3_console_puts("\r\n");
}

void doom_image_loader_invalidate(void)
{
    image_loaded = 0u;
    image_restart_ready = 0u;
    image_backup_address = 0u;
    image_backup_crc = 0u;
}

int doom_image_loader_receive(void)
{
    hazard3_doom_image_header_t header;
    volatile uint8_t* destination;
    uint32_t start_ticks;
    uint32_t crc = 0xffffffffu;
    ++receive_run_count;
    image_loaded = 0u;
    image_restart_ready = 0u;
    image_backup_address = 0u;
    image_backup_crc = 0u;
    image_restore_count = 0u;
    last_crc_actual = 0u;
    last_crc_expected = 0u;
    start_ticks = hazard3_ticks_ms();
    drain_uart_rx();
    hazard3_console_puts("\r\nH3L READY\r\n");
    if (!read_exact(&header, sizeof(header))) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts("H3L ERROR header timeout\r\n");
        return 0;
    }
    if (!header_is_valid(&header)) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts("H3L ERROR invalid header\r\n");
        print_header_summary(&header);
        return 0;
    }
    print_header_summary(&header);
    /*
     * The host sends only the fixed-size header first, then waits for this
     * marker before sending the payload.  This prevents the two-byte UART RX
     * FIFO from overflowing while the monitor prints the header summary.
     */
    hazard3_console_puts("H3L DATA\r\n");
    destination = (volatile uint8_t*)(uintptr_t)header.load_address;
    for (uint32_t i = 0u; i < header.image_bytes; ++i) {
        uint8_t value;
        if (!read_byte_with_timeout(&value)) {
            ++receive_failure_count;
            last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
            hazard3_console_puts("H3L ERROR payload timeout at offset=");
            hazard3_console_put_hex32(i);
            hazard3_console_puts("\r\n");
            return 0;
        }
        destination[i] = value;
        crc = crc32_update(crc, value);
    }
    crc ^= 0xffffffffu;
    last_crc_expected = header.payload_crc32;
    last_crc_actual = crc;
    hazard3_memory_barrier();
    if (crc != header.payload_crc32) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts("H3L ERROR CRC expected=");
        hazard3_console_put_hex32(header.payload_crc32);
        hazard3_console_puts(" actual=");
        hazard3_console_put_hex32(crc);
        hazard3_console_puts("\r\n");
        return 0;
    }
    copy_header(&loaded_header, &header);
    if (!prepare_image_backup(&header)) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts(
            "H3L ERROR could not create verified restart image\r\n");
        return 0;
    }
    if (!restore_image_from_backup()) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts(
            "H3L ERROR could not verify restored image\r\n");
        return 0;
    }
    image_loaded = 1u;
    last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
    hazard3_console_puts("H3L OK elapsed_ms=");
    hazard3_console_put_hex32(last_receive_elapsed_ms);
    hazard3_console_puts("\r\n");
    return 1;
}

int doom_image_loader_launch(void)
{
    typedef int32_t (*doom_entry_fn_t)(const hazard3_monitor_services_t* services);
    hazard3_monitor_services_t services = {
        .abi_version = HAZARD3_MONITOR_ABI_VERSION,
        .struct_bytes = sizeof(hazard3_monitor_services_t),
        .console_putc = hazard3_console_putc,
        .console_puts = hazard3_console_puts,
        .console_put_hex32 = hazard3_console_put_hex32,
        .console_getc_nonblocking = hazard3_console_getc_nonblocking,
        .ticks_ms = hazard3_ticks_ms,
        .sleep_ms = hazard3_sleep_ms,
        .sbrk = _sbrk,
        .memory_barrier = hazard3_memory_barrier,
        .image_base = HAZARD3_DOOM_IMAGE_BASE,
        .image_limit = HAZARD3_DOOM_IMAGE_LIMIT,
        .heap_base = HAZARD3_DOOM_HEAP_BASE,
        .heap_limit = HAZARD3_DOOM_HEAP_LIMIT,
        .video_base = HAZARD3_VIDEO_BASE,
        .video_limit = HAZARD3_VIDEO_LIMIT,
        .wad_base = HAZARD3_DOOM_WAD_BASE,
        .wad_limit = HAZARD3_DOOM_WAD_LIMIT,
        .wad_bytes = doom_wad_loader_bytes(),
        .wad_name = doom_wad_loader_name(),
        .screen_base = HAZARD3_DOOM_SCREENBUFFER_BASE,
        .screen_bytes = HAZARD3_DOOM_SCREENBUFFER_BYTES
    };
    doom_entry_fn_t entry;
    uint32_t start_ticks;
    int32_t result;
    ++launch_run_count;
    if (image_loaded == 0u) {
        ++launch_failure_count;
        hazard3_console_puts(
            "\r\nNo validated Doom image is loaded. Use the image uploader first.\r\n");
        return 0;
    }
    if (!doom_wad_loader_is_loaded()) {
        ++launch_failure_count;
        hazard3_console_puts(
            "\r\nNo validated IWAD is loaded. Use the WAD uploader first.\r\n");
        return 0;
    }
    hazard3_heap_reset();
    if (!restore_image_from_backup()) {
        ++launch_failure_count;
        hazard3_console_puts(
            "\r\nDoom restart image verification failed. "
            "Upload the H3D again.\r\n");
        return 0;
    }
    entry = (doom_entry_fn_t)(uintptr_t)loaded_header.entry_address;
    hazard3_console_puts("\r\nLaunching Doom image from SDRAM entry=");
    hazard3_console_put_hex32(loaded_header.entry_address);
    hazard3_console_puts(" IWAD=");
    hazard3_console_puts(services.wad_name);
    hazard3_console_puts("\r\n");
    drain_uart_rx();
    hazard3_console_input_capture_begin();
    start_ticks = hazard3_ticks_ms();
    result = entry(&services);
    last_launch_elapsed_ms = hazard3_ticks_ms() - start_ticks;
    hazard3_console_input_capture_end();
    last_entry_return = (uint32_t)result;
    hazard3_console_puts("Doom image returned status=");
    hazard3_console_put_hex32(last_entry_return);
    hazard3_console_puts(" elapsed_ms=");
    hazard3_console_put_hex32(last_launch_elapsed_ms);
    hazard3_console_puts("\r\nDoom UART captured=");
    hazard3_console_put_hex32(hazard3_console_input_capture_received());
    hazard3_console_puts(" overflows=");
    hazard3_console_put_hex32(hazard3_console_input_capture_overflows());
    hazard3_console_puts(
        "\r\nRestart image preserved; enter j to restart without uploading.\r\n");
    if (result != 0) {
        ++launch_failure_count;
        return 0;
    }
    return 1;
}

void doom_image_loader_print_status(void)
{
    hazard3_console_puts("\r\ndoom_image_loaded=");
    hazard3_console_puts(image_loaded != 0u ? "YES" : "NO");
    hazard3_console_puts(" receive_runs=");
    hazard3_console_put_hex32(receive_run_count);
    hazard3_console_puts(" receive_failures=");
    hazard3_console_put_hex32(receive_failure_count);
    hazard3_console_puts(" receive_elapsed_ms=");
    hazard3_console_put_hex32(last_receive_elapsed_ms);
    hazard3_console_puts(" restart_ready=");
    hazard3_console_puts(image_restart_ready != 0u ? "YES" : "NO");
    hazard3_console_puts(" restores=");
    hazard3_console_put_hex32(image_restore_count);
    hazard3_console_puts("\r\ndoom_image_bytes=");
    hazard3_console_put_hex32(loaded_header.image_bytes);
    hazard3_console_puts(" entry=");
    hazard3_console_put_hex32(loaded_header.entry_address);
    hazard3_console_puts(" bss_bytes=");
    hazard3_console_put_hex32(loaded_header.bss_bytes);
    hazard3_console_puts("\r\ndoom_image_crc_expected=");
    hazard3_console_put_hex32(last_crc_expected);
    hazard3_console_puts(" actual=");
    hazard3_console_put_hex32(last_crc_actual);
    hazard3_console_puts(" backup=");
    hazard3_console_put_hex32(image_backup_address);
    hazard3_console_puts(" backup_crc=");
    hazard3_console_put_hex32(image_backup_crc);
    hazard3_console_puts("\r\ndoom_launch_runs=");
    hazard3_console_put_hex32(launch_run_count);
    hazard3_console_puts(" launch_failures=");
    hazard3_console_put_hex32(launch_failure_count);
    hazard3_console_puts(" launch_elapsed_ms=");
    hazard3_console_put_hex32(last_launch_elapsed_ms);
    hazard3_console_puts(" last_return=");
    hazard3_console_put_hex32(last_entry_return);
}

uint32_t doom_image_loader_receive_runs(void) { return receive_run_count; }
uint32_t doom_image_loader_receive_failures(void) { return receive_failure_count; }
uint32_t doom_image_loader_launch_runs(void) { return launch_run_count; }
uint32_t doom_image_loader_launch_failures(void) { return launch_failure_count; }
int doom_image_loader_is_loaded(void) { return image_loaded != 0u; }
