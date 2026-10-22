/* Native-host-only DFU -> actual MMIO adapter -> SPI flash model.
 * NEVER connect these test callbacks to physical registers.
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_at25ql321_hw.h"
#include "ulx5m_flash_program.h"
#include "ulx5m-at25ql321-mock.h"
#include "ulx5m_dfu_stream.h"
#include "usb_dfu_proto.h"

#ifndef ULX5M_AT25QL321_MMIO_HOST_TEST
#error "This test must use the host-only MMIO simulation profile"
#endif
#ifdef __riscv
#error "MMIO emulator tests must not target the FPGA"
#endif

#define BASE 0x84000000u
#define CS_LOW 0x00000f00u
#define CS_HIGH 0x00010f00u
#define RX_DUMMY 0x100u
#define RX_PENDING 0x80000000u

struct fake_mmio {
    struct ulx5m_spi_mock flash;
    struct ulx5m_at25ql321_bus spi;
    unsigned cs_low, cs_high, data_tx, data_rx, reads;
    uint8_t rx_byte;
    int rx_waiting, fail_rx;
};

static struct fake_mmio mmio;
static struct ulx5m_at25ql321_hw hw;
static struct ulx5m_at25ql321 chip;
static struct ulx5m_flash_program programmer;
static uint8_t scratch[64];

static void write_reg(void *ctx, uintptr_t reg, uint32_t value)
{
    struct fake_mmio *f = ctx;
    int result;
    if (reg == BASE) {
        if (value == CS_LOW) {
            assert(!f->flash.selected);
            f->rx_waiting = 0;
            result = f->spi.begin(f->spi.ctx);
            assert(result == 0);
            ++f->cs_low;
        } else {
            assert(value == CS_HIGH && f->flash.selected);
            result = f->spi.end(f->spi.ctx);
            assert(result == 0);
            ++f->cs_high;
        }
        return;
    }
    assert(reg == BASE + 4u && f->flash.selected);
    if (value == RX_DUMMY) {
        assert(!f->rx_waiting);
        result = f->spi.transfer(f->spi.ctx, 0u, &f->rx_byte);
        assert(result == 0);
        f->rx_waiting = 1;
        ++f->data_rx;
    } else {
        assert(value <= 0xffu && !f->rx_waiting);
        result = f->spi.transfer(f->spi.ctx, (uint8_t)value, 0);
        assert(result == 0);
        ++f->data_tx;
    }
}

static uint32_t read_reg(void *ctx, uintptr_t reg)
{
    struct fake_mmio *f = ctx;
    assert(reg == BASE + 4u && f->flash.selected && f->rx_waiting);
    ++f->reads;
    if (f->fail_rx)
        return RX_PENDING;
    f->rx_waiting = 0;
    return f->rx_byte;
}

static int erase_sector(void *unused, uint32_t address)
{
    (void)unused;
    return ulx5m_at25ql321_erase_4k(&chip, address) == ULX5M_AT25_OK ? 0 : -1;
}

static int program_page(void *unused, uint32_t address,
                        const uint8_t *data, unsigned length)
{
    (void)unused;
    return ulx5m_at25ql321_program_page(&chip, address, data, length) ==
           ULX5M_AT25_OK ? 0 : -1;
}

static int read_bytes(void *unused, uint32_t address, uint8_t *data,
                      unsigned length)
{
    (void)unused;
    return ulx5m_at25ql321_read(&chip, address, data, length) ==
           ULX5M_AT25_OK ? 0 : -1;
}

static int sink(uint32_t offset, const uint8_t *bytes, unsigned len)
{
    return ulx5m_flash_program_feed(&programmer, offset, bytes, len) ==
           ULX5M_PROGRAM_OK ? 0 : -1;
}

static uint32_t crc32(const uint8_t *data, unsigned length)
{
    uint32_t crc = 0xffffffffu;
    for (unsigned i = 0; i < length; ++i) {
        crc ^= data[i];
        for (unsigned b = 0; b < 8; ++b)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc ^ 0xffffffffu;
}

static enum usb_fnd_resp request(uint8_t type, uint8_t cmd,
                                 unsigned value, unsigned len,
                                 struct usb_xfer *xfer)
{
    struct usb_ctrl_req req = {
        .bmRequestType = type, .bRequest = cmd, .wValue = value,
        .wIndex = 0, .wLength = len
    };
    memset(xfer, 0, sizeof(*xfer));
    xfer->data = scratch;
    xfer->len = sizeof(scratch);
    return ulx5m_dfu_stream_req(&req, xfer);
}

static uint32_t le32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

int main(void)
{
    const unsigned total = 419538u;
    uint8_t *image = malloc(total);
    assert(image);
    for (unsigned i = 0; i < total; ++i)
        image[i] = (uint8_t)((i * 17u + (i >> 9) + 0x35u) & 255u);

    ulx5m_spi_mock_init(&mmio.flash);
    mmio.spi = ulx5m_spi_mock_bus(&mmio.flash);
    memset(mmio.flash.memory, 0xa5, ULX5M_FLASH_CANDIDATE_START);
    ulx5m_at25ql321_hw_init(&hw, BASE);
    hw.io_ctx = &mmio;
    hw.write32 = write_reg;
    hw.read32 = read_reg;
    ulx5m_at25ql321_hw_bind(&chip, &hw);

    uint8_t id[3];
    assert(ulx5m_at25ql321_identify(&chip, id) == ULX5M_AT25_OK);
    assert(id[0] == 0x1fu && id[1] == 0x42u && id[2] == 0x16u);
    struct ulx5m_flash_program_ops ops = {
        .ctx = 0, .erase_sector = erase_sector,
        .program_page = program_page, .read_bytes = read_bytes
    };
    ulx5m_dfu_stream_reset();
    ulx5m_dfu_stream_set_test_sink(sink);
    const uint32_t expected = crc32(image, total);
    assert(ulx5m_flash_program_begin(&programmer, &ops, total, expected) ==
           ULX5M_PROGRAM_OK);

    struct usb_xfer xfer;
    for (unsigned offset = 0, block = 0; offset < total; ++block) {
        unsigned n = total - offset;
        if (n > 64u)
            n = 64u;
        assert(request(0x21, USB_REQ_DFU_DNLOAD, block, n, &xfer) ==
               USB_FND_SUCCESS);
        assert(xfer.cb_done && xfer.data != scratch && xfer.len == (int)n);
        memcpy(xfer.data, image + offset, n);
        xfer.ofs = n;
        assert(xfer.cb_done(&xfer));
        assert(request(0xa1, USB_REQ_DFU_GETSTATUS, 0, 6, &xfer) ==
               USB_FND_SUCCESS);
        assert(xfer.data[0] == OK && xfer.data[4] == dfuDNLOAD_IDLE);
        offset += n;
    }
    assert(request(0xc0, ULX5M_STREAM_INFO_REQ, 0, 20, &xfer) ==
           USB_FND_SUCCESS);
    assert(!memcmp(xfer.data, "STR1", 4));
    assert(le32(xfer.data + 4) == total);
    assert(le32(xfer.data + 8) == expected);
    assert(ulx5m_flash_program_finish(&programmer) == ULX5M_PROGRAM_OK);

    assert(memcmp(mmio.flash.memory + ULX5M_FLASH_CANDIDATE_START,
                  image, total) == 0);
    assert(mmio.flash.erases == 103 && mmio.flash.pages == 1639);
    assert(mmio.flash.write_enables == 103 + 1639);
    assert(!mmio.flash.writes_to_factory && !mmio.flash.bad_command);
    for (unsigned i = 0; i < ULX5M_FLASH_CANDIDATE_START; ++i)
        assert(mmio.flash.memory[i] == 0xa5);
    assert(mmio.cs_low == mmio.cs_high && !mmio.flash.selected);
    assert(mmio.data_rx > total && mmio.data_tx > total);
    puts("[PASS] DFU -> programmer -> AT25QL321 -> real CSR/DATA adapter -> mock SPI");
    puts("[PASS] 419538 bytes, 103 erases, 1639 pages; factory 2 MiB unchanged");

    assert(request(0x21, USB_REQ_DFU_DNLOAD, (total + 63u) / 64u, 0,
                   &xfer) == USB_FND_SUCCESS);
    assert(xfer.cb_done(&xfer));
    assert(request(0xa1, USB_REQ_DFU_GETSTATUS, 0, 6, &xfer) ==
           USB_FND_SUCCESS);
    assert(xfer.data[0] == errNOTDONE && xfer.data[4] == dfuERROR);

    unsigned cs = mmio.cs_high;
    mmio.fail_rx = 1;
    uint8_t status;
    assert(ulx5m_at25ql321_status(&chip, &status) == ULX5M_AT25_IO);
    assert(mmio.cs_high == cs + 1 && mmio.cs_low == mmio.cs_high);
    assert(!mmio.flash.selected && !mmio.flash.writes_to_factory);
    puts("[PASS] MMIO receive timeout releases CS; manifestation refused");
    free(image);
    return 0;
}
