/* Native host regression for the same boot decision function used by SERV. */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "ulx5m_spi_active_boot.h"

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #x); return 1; } } while (0)
static uint8_t sector[4096];
static unsigned reads, released, armed, executed;
static int bad_page, ready, reject_arm, reject_exec;
static uint32_t last_arm, last_exec;
static int read_flash(void *ctx, uint32_t addr, uint8_t *out, unsigned n)
{
    (void)ctx;
    if (addr < ULX5M_V41_NATIVE_ADDR || n > 4096u ||
        addr - ULX5M_V41_NATIVE_ADDR > 4096u - n)
        return -1;
    if ((int)reads++ == bad_page)
        return -1;
    memcpy(out, sector + (addr - ULX5M_V41_NATIVE_ADDR), n);
    return 0;
}
static void release_flash(void *ctx) { (void)ctx; ++released; }
static uint32_t status(void *ctx)
{
    (void)ctx;
    return (ready ? 1u : 0u) | 16u |
           ((!reject_arm && armed) ? ULX5M_SPI_BOOT_ARMED : 0u) |
           ((!reject_exec && executed) ? ULX5M_SPI_BOOT_FIRED : 0u);
}
static void arm(void *ctx, uint32_t key) { (void)ctx; ++armed; last_arm = key; }
static void exec(void *ctx, uint32_t key) { (void)ctx; ++executed; last_exec = key; }
static void clear_counts(void)
{
    reads = released = armed = executed = 0;
    last_arm = last_exec = 0;
    bad_page = -1;
    ready = 1;
    reject_arm = reject_exec = 0;
}
int main(int argc, char **argv)
{
    struct ulx5m_normal_image_reader reader = {0, read_flash};
    struct ulx5m_spi_active_boot_gate gate = {0, release_flash, status, arm, exec};
    FILE *f;
    int i;
    if (argc != 2) return 2;
    f = fopen(argv[1], "rb");
    if (!f) return 2;
    if (fread(sector, 1, 4096, f) != 4096 || fgetc(f) != EOF) return 2;
    fclose(f);
    clear_counts();
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 1) == ULX5M_SPI_BOOT_DFU);
    CHECK(!reads && !released && !armed && !executed);
    clear_counts();
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_REQUESTED);
    CHECK(reads == 16 && released == 1 && armed == 1 && executed == 1);
    CHECK(last_arm == ULX5M_SPI_BOOT_ARM_KEY && last_exec == ULX5M_SPI_BOOT_EXEC_KEY);
    for (i = 0; i != 16; ++i) {
        clear_counts(); bad_page = i;
        CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_INVALID);
        CHECK(!armed && !executed && released == 1);
    }
    clear_counts(); ready = 0;
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_GATE_ERROR);
    CHECK(reads == 16 && released == 1 && !armed && !executed);
    clear_counts(); reject_arm = 1;
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_GATE_ERROR);
    CHECK(armed == 1 && executed == 0);
    clear_counts(); reject_exec = 1;
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_GATE_ERROR);
    CHECK(armed == 1 && executed == 1);
    clear_counts();
    sector[0] ^= 1;
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_INVALID);
    CHECK(!executed);
    sector[0] ^= 1;
    clear_counts();
    sector[4095] = 0;
    CHECK(ulx5m_spi_active_boot_run(&reader, &gate, 0) == ULX5M_SPI_BOOT_INVALID);
    CHECK(!executed);
    puts("[PASS] v47 real C boot decision: valid slot, BTN2, 16 read faults, gate faults, corruption, timeout");
    return 0;
}
