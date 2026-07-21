#include <stdint.h>

#include "doom_wad_format.h"
#include "doom_wad_loader.h"
#include "hazard3_platform.h"

#define WAD_LOADER_BYTE_TIMEOUT_MS 5000u
#define WAD_HEADER_BYTES           12u
#define WAD_DIRECTORY_ENTRY_BYTES  16u

static hazard3_doom_wad_header_t loaded_header;
static uint32_t receive_run_count;
static uint32_t receive_failure_count;
static uint32_t last_receive_elapsed_ms;
static uint32_t last_crc_expected;
static uint32_t last_crc_actual;
static uint32_t last_lump_count;
static uint32_t last_directory_offset;
static uint32_t wad_loaded;

static uint32_t crc32_update(uint32_t crc, uint8_t value)
{
    crc ^= value;
    for (uint32_t bit = 0u; bit < 8u; ++bit) {
        uint32_t mask = 0u - (crc & 1u);
        crc = (crc >> 1) ^ (0xedb88320u & mask);
    }
    return crc;
}

static uint32_t read_le32(const volatile uint8_t* bytes)
{
    return (uint32_t)bytes[0] |
        ((uint32_t)bytes[1] << 8) |
        ((uint32_t)bytes[2] << 16) |
        ((uint32_t)bytes[3] << 24);
}

static int read_byte_with_timeout(uint8_t* value)
{
    uint32_t start_ticks = hazard3_ticks_ms();
    for (;;) {
        if (hazard3_console_getc_nonblocking(value)) {
            return 1;
        }
        if ((uint32_t)(hazard3_ticks_ms() - start_ticks) >=
            WAD_LOADER_BYTE_TIMEOUT_MS) {
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

static int wad_name_is_valid(const char* name)
{
    uint32_t length = 0u;
    for (; length < HAZARD3_DOOM_WAD_NAME_BYTES; ++length) {
        uint8_t value = (uint8_t)name[length];
        if (value == 0u) {
            break;
        }
        if (!((value >= (uint8_t)'a' && value <= (uint8_t)'z') ||
              (value >= (uint8_t)'A' && value <= (uint8_t)'Z') ||
              (value >= (uint8_t)'0' && value <= (uint8_t)'9') ||
              value == (uint8_t)'.' || value == (uint8_t)'_' ||
              value == (uint8_t)'-')) {
            return 0;
        }
    }
    if (length < 5u || length >= HAZARD3_DOOM_WAD_NAME_BYTES) {
        return 0;
    }
    return name[length - 4u] == '.' &&
        (name[length - 3u] == 'w' || name[length - 3u] == 'W') &&
        (name[length - 2u] == 'a' || name[length - 2u] == 'A') &&
        (name[length - 1u] == 'd' || name[length - 1u] == 'D');
}

static int header_is_valid(const hazard3_doom_wad_header_t* header)
{
    if (header->magic != HAZARD3_DOOM_WAD_MAGIC ||
        header->header_bytes != HAZARD3_DOOM_WAD_HEADER_BYTES ||
        header->format_version != HAZARD3_DOOM_WAD_FORMAT_VERSION ||
        header->flags != HAZARD3_DOOM_WAD_FLAG_CRC32 ||
        header->load_address != HAZARD3_DOOM_WAD_BASE ||
        header->wad_bytes < WAD_HEADER_BYTES ||
        header->wad_bytes > HAZARD3_DOOM_WAD_LIMIT - HAZARD3_DOOM_WAD_BASE ||
        header->reserved0 != 0u || !wad_name_is_valid(header->file_name)) {
        return 0;
    }
    for (uint32_t i = 0u; i < 4u; ++i) {
        if (header->reserved[i] != 0u) {
            return 0;
        }
    }
    return 1;
}

static int payload_is_valid(
    const volatile uint8_t* wad,
    uint32_t wad_bytes,
    uint32_t* lump_count,
    uint32_t* directory_offset)
{
    uint32_t count;
    uint32_t offset;
    uint32_t directory_bytes;
    if (wad[0] != (uint8_t)'I' || wad[1] != (uint8_t)'W' ||
        wad[2] != (uint8_t)'A' || wad[3] != (uint8_t)'D') {
        return 0;
    }
    count = read_le32(wad + 4u);
    offset = read_le32(wad + 8u);
    if (count == 0u || count > UINT32_MAX / WAD_DIRECTORY_ENTRY_BYTES) {
        return 0;
    }
    directory_bytes = count * WAD_DIRECTORY_ENTRY_BYTES;
    if (offset > wad_bytes || directory_bytes > wad_bytes - offset) {
        return 0;
    }
    for (uint32_t i = 0u; i < count; ++i) {
        const volatile uint8_t* entry =
            wad + offset + i * WAD_DIRECTORY_ENTRY_BYTES;
        uint32_t file_position = read_le32(entry);
        uint32_t lump_bytes = read_le32(entry + 4u);
        if (file_position > wad_bytes || lump_bytes > wad_bytes - file_position) {
            return 0;
        }
    }
    *lump_count = count;
    *directory_offset = offset;
    return 1;
}

static void copy_header(
    hazard3_doom_wad_header_t* destination,
    const hazard3_doom_wad_header_t* source)
{
    uint32_t* destination_words = (uint32_t*)destination;
    const uint32_t* source_words = (const uint32_t*)source;
    for (uint32_t i = 0u; i < sizeof(*source) / sizeof(uint32_t); ++i) {
        destination_words[i] = source_words[i];
    }
}

static void print_name(const char* name)
{
    for (uint32_t i = 0u; i < HAZARD3_DOOM_WAD_NAME_BYTES && name[i] != '\0'; ++i) {
        hazard3_console_putc((uint8_t)name[i]);
    }
}

static void print_header_summary(const hazard3_doom_wad_header_t* header)
{
    hazard3_console_puts("  name=");
    print_name(header->file_name);
    hazard3_console_puts(" load=");
    hazard3_console_put_hex32(header->load_address);
    hazard3_console_puts(" bytes=");
    hazard3_console_put_hex32(header->wad_bytes);
    hazard3_console_puts(" crc32=");
    hazard3_console_put_hex32(header->payload_crc32);
    hazard3_console_puts("\r\n");
}

void doom_wad_loader_invalidate(void)
{
    wad_loaded = 0u;
}

int doom_wad_loader_receive(void)
{
    hazard3_doom_wad_header_t header;
    volatile uint8_t* destination;
    uint32_t start_ticks;
    uint32_t crc = 0xffffffffu;
    uint32_t lump_count;
    uint32_t directory_offset;
    ++receive_run_count;
    wad_loaded = 0u;
    last_crc_actual = 0u;
    last_crc_expected = 0u;
    last_lump_count = 0u;
    last_directory_offset = 0u;
    start_ticks = hazard3_ticks_ms();
    drain_uart_rx();
    hazard3_console_puts("\r\nH3W READY\r\n");
    if (!read_exact(&header, sizeof(header))) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts("H3W ERROR header timeout\r\n");
        return 0;
    }
    if (!header_is_valid(&header)) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts("H3W ERROR invalid header\r\n");
        print_header_summary(&header);
        return 0;
    }
    print_header_summary(&header);
    hazard3_console_puts("H3W DATA\r\n");
    destination = (volatile uint8_t*)(uintptr_t)header.load_address;
    for (uint32_t i = 0u; i < header.wad_bytes; ++i) {
        uint8_t value;
        if (!read_byte_with_timeout(&value)) {
            ++receive_failure_count;
            last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
            hazard3_console_puts("H3W ERROR payload timeout at offset=");
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
        hazard3_console_puts("H3W ERROR CRC expected=");
        hazard3_console_put_hex32(header.payload_crc32);
        hazard3_console_puts(" actual=");
        hazard3_console_put_hex32(crc);
        hazard3_console_puts("\r\n");
        return 0;
    }
    if (!payload_is_valid(
            destination, header.wad_bytes, &lump_count, &directory_offset)) {
        ++receive_failure_count;
        last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
        hazard3_console_puts("H3W ERROR invalid IWAD structure\r\n");
        return 0;
    }
    copy_header(&loaded_header, &header);
    last_lump_count = lump_count;
    last_directory_offset = directory_offset;
    wad_loaded = 1u;
    last_receive_elapsed_ms = hazard3_ticks_ms() - start_ticks;
    hazard3_console_puts("H3W OK elapsed_ms=");
    hazard3_console_put_hex32(last_receive_elapsed_ms);
    hazard3_console_puts(" lumps=");
    hazard3_console_put_hex32(last_lump_count);
    hazard3_console_puts(" directory=");
    hazard3_console_put_hex32(last_directory_offset);
    hazard3_console_puts("\r\n");
    return 1;
}

void doom_wad_loader_print_status(void)
{
    hazard3_console_puts("\r\ndoom_wad_loaded=");
    hazard3_console_puts(wad_loaded != 0u ? "YES" : "NO");
    hazard3_console_puts(" receive_runs=");
    hazard3_console_put_hex32(receive_run_count);
    hazard3_console_puts(" receive_failures=");
    hazard3_console_put_hex32(receive_failure_count);
    hazard3_console_puts(" receive_elapsed_ms=");
    hazard3_console_put_hex32(last_receive_elapsed_ms);
    hazard3_console_puts("\r\ndoom_wad_name=");
    print_name(loaded_header.file_name);
    hazard3_console_puts(" bytes=");
    hazard3_console_put_hex32(loaded_header.wad_bytes);
    hazard3_console_puts(" lumps=");
    hazard3_console_put_hex32(last_lump_count);
    hazard3_console_puts(" directory=");
    hazard3_console_put_hex32(last_directory_offset);
    hazard3_console_puts("\r\ndoom_wad_crc_expected=");
    hazard3_console_put_hex32(last_crc_expected);
    hazard3_console_puts(" actual=");
    hazard3_console_put_hex32(last_crc_actual);
}

int doom_wad_loader_is_loaded(void) { return wad_loaded != 0u; }
uint32_t doom_wad_loader_base(void) { return HAZARD3_DOOM_WAD_BASE; }
uint32_t doom_wad_loader_bytes(void)
{
    return wad_loaded != 0u ? loaded_header.wad_bytes : 0u;
}
const char* doom_wad_loader_name(void)
{
    return wad_loaded != 0u ? loaded_header.file_name : (const char*)0;
}
uint32_t doom_wad_loader_lump_count(void) { return last_lump_count; }
uint32_t doom_wad_loader_directory_offset(void) { return last_directory_offset; }
