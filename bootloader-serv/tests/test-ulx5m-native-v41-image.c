/* Host test using the independently read 4096-byte real flash sector. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_native_v41_image.h"

static uint8_t sector[ULX5M_V41_NATIVE_SECTOR_BYTES];
static uint8_t pristine[ULX5M_V41_NATIVE_SECTOR_BYTES];
static unsigned reads, fail_read, wrong_region;
static int read_sector(void *ctx, uint32_t address, uint8_t *out, unsigned length)
{
    (void)ctx;
    ++reads;
    if (address < ULX5M_V41_NATIVE_ADDR ||
        address - ULX5M_V41_NATIVE_ADDR >= ULX5M_V41_NATIVE_SECTOR_BYTES ||
        length > ULX5M_V41_NATIVE_SECTOR_BYTES -
                 (address - ULX5M_V41_NATIVE_ADDR)) {
        ++wrong_region;
        return -1;
    }
    if (fail_read && reads == fail_read)
        return -1;
    memcpy(out, sector + (address - ULX5M_V41_NATIVE_ADDR), length);
    return 0;
}
static struct ulx5m_normal_image_reader reader = {NULL, read_sector};
static void reset(void)
{
    memcpy(sector, pristine, sizeof(sector));
    reads = fail_read = wrong_region = 0;
}
static void expect(enum ulx5m_v41_probe_result want, int btn2)
{
    uint32_t crc = 0xaaaaaaaa;
    assert(ulx5m_v41_native_probe(&reader, btn2, &crc) == want);
    assert(crc == (want == ULX5M_V41_VERIFIED_ONLY ?
                   ULX5M_V41_NATIVE_CRC32 : 0u));
    assert(wrong_region == 0u);
}
int main(int argc, char **argv)
{
    FILE *f;
    assert(argc == 2);
    f = fopen(argv[1], "rb");
    assert(f);
    assert(fread(pristine, 1, sizeof(pristine), f) == sizeof(pristine));
    assert(fgetc(f) == EOF);
    assert(fclose(f) == 0);

    reset();
    expect(ULX5M_V41_VERIFIED_ONLY, 0);
    assert(reads == 16u);
    puts("[PASS] Real independent 4096-byte native slot validates without U5IM");

    reset();
    expect(ULX5M_V41_STAY_DFU_BTN2, 1);
    assert(reads == 0);
    puts("[PASS] Latched BTN2 avoids every SPI read");

    reset();
    sector[0] ^= 1;
    expect(ULX5M_V41_INVALID_IMAGE, 0);
    puts("[PASS] GateMate stream signature corruption rejected");

    reset();
    sector[1000] ^= 1;
    expect(ULX5M_V41_INVALID_IMAGE, 0);
    puts("[PASS] Midstream corruption rejected");

    reset();
    sector[ULX5M_V41_NATIVE_BYTES - 1] ^= 1;
    expect(ULX5M_V41_INVALID_IMAGE, 0);
    puts("[PASS] Final application byte corruption rejected");

    reset();
    sector[ULX5M_V41_NATIVE_BYTES] = 0;
    expect(ULX5M_V41_INVALID_IMAGE, 0);
    puts("[PASS] First erased-tail byte corruption rejected");

    reset();
    sector[sizeof(sector) - 1] = 0;
    expect(ULX5M_V41_INVALID_IMAGE, 0);
    puts("[PASS] Final erased-tail byte corruption rejected");

    reset();
    memset(sector, 0xff, sizeof(sector));
    expect(ULX5M_V41_INVALID_IMAGE, 0);
    puts("[PASS] Completely erased sector rejected");

    for (unsigned n = 1; n <= 16u; ++n) {
        reset();
        fail_read = n;
        expect(ULX5M_V41_READ_ERROR, 0);
    }
    puts("[PASS] All 16 page-read fault positions rejected");

    reset();
    assert(ulx5m_v41_native_probe(NULL, 0, NULL) == ULX5M_V41_BAD_READER);
    assert(ulx5m_v41_native_probe(&reader, 0, NULL) == ULX5M_V41_VERIFIED_ONLY);
    puts("[PASS] Missing reader and null result handling");

    assert(memcmp(pristine, "\xd9\x01\xed\x96", 4) == 0);
    puts("[BLOCK] Verified-only is not a configuration handoff or flash authorization");
    return 0;
}
