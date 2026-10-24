/* Native-only mock for the real experimental flash arm/DFU/finish protocol. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "config.h"
#include "ulx5m_flash_hw_test.h"
#include "ulx5m_dfu_stream.h"
#include "ulx5m_at25ql321_hw.h"
#include "ulx5m-at25ql321-mock.h"
#include "usb_dfu_proto.h"

#if !defined(ULX5M_FLASH_HW_HOST_TEST) || defined(__riscv)
#error "Native-only mock required"
#endif
static struct ulx5m_spi_mock model;
static struct ulx5m_at25ql321_bus mock_bus;
static uint8_t answer[64];

void ulx5m_at25ql321_hw_init(struct ulx5m_at25ql321_hw *hw, uintptr_t base)
{
    (void)hw;
    assert(base == SPI_BASE);
}
void ulx5m_at25ql321_hw_bind(struct ulx5m_at25ql321 *dev,
                              struct ulx5m_at25ql321_hw *hw)
{
    (void)hw;
    ulx5m_at25ql321_init(dev, &mock_bus);
}
static enum usb_fnd_resp req(uint8_t type, uint8_t request, unsigned value,
                              unsigned index, unsigned length, struct usb_xfer *x)
{
    struct usb_ctrl_req r = {
        .bmRequestType = type, .bRequest = request,
        .wValue = value, .wIndex = index, .wLength = length
    };
    memset(x, 0, sizeof(*x));
    x->data = answer;
    x->len = sizeof(answer);
    enum usb_fnd_resp result = ulx5m_flash_hw_test_req(&r, x);
    if (result == USB_FND_CONTINUE)
        result = ulx5m_dfu_stream_req(&r, x);
    return result;
}
static unsigned phase(void)
{
    struct usb_xfer x;
    assert(req(0xc0, ULX5M_HW_STATUS_REQ, 0, 0, 24, &x) == USB_FND_SUCCESS);
    assert(!memcmp(x.data, "FWTN", 4) && x.len == 24);
    return x.data[4];
}
static uint32_t crc(const uint8_t *data, unsigned count)
{
    uint32_t sum = ~0u;
    for (unsigned i = 0; i < count; ++i) {
        sum ^= data[i];
        for (unsigned bit = 0; bit < 8; ++bit)
            sum = (sum >> 1) ^ ((sum & 1) ? 0xedb88320u : 0);
    }
    return ~sum;
}
static void put32(uint8_t *p, uint32_t v)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(v >> (8u * i));
}
static void arm_for(const uint8_t *image, unsigned length, int wrong_token)
{
    struct usb_xfer x;
    assert(req(0x40, ULX5M_HW_ARM_REQ, 1, 0x2000, 16, &x) == USB_FND_SUCCESS);
    assert(x.cb_done && x.len == 16);
    memcpy(x.data, "U5WN", 4);
    put32(x.data + 4, length);
    /* Rejected oversize length must not read beyond the test payload. */
    put32(x.data + 8, crc(image, length > 16384u ? 16384u : length));
    put32(x.data + 12, wrong_token ? 0 : ULX5M_HW_ARM_TOKEN);
    x.ofs = 16;
    assert(x.cb_done(&x));
}
int main(int argc, char **argv)
{
    struct usb_xfer x;
    static uint8_t image[4096];
    assert(argc == 2);
    FILE *file = fopen(argv[1], "rb");
    assert(file != NULL);
    const unsigned bytes = (unsigned)fread(image, 1, sizeof(image), file);
    assert(!ferror(file) && fgetc(file) == EOF && fclose(file) == 0);
    assert(bytes == 3026u);
    assert(image[0] == 0xd9u && image[1] == 0x01u &&
           image[2] == 0xedu && image[3] == 0x96u);
    ulx5m_spi_mock_init(&model);
    mock_bus = ulx5m_spi_mock_bus(&model);
    memset(model.memory, 0x95, ULX5M_AT25QL321_CANDIDATE_START);
    ulx5m_dfu_stream_reset();
    assert(phase() == 0);
    arm_for(image, 4097u, 0);
    assert(phase() == 3 && model.erases == 0);
    ulx5m_dfu_stream_reset();
    arm_for(image, bytes, 1);
    assert(phase() == 3 && model.erases == 0);
    ulx5m_dfu_stream_reset();
    arm_for(image, bytes, 0);
    assert(phase() == 1);
    for (unsigned off = 0, block = 0; off < bytes; block++) {
        unsigned count = bytes - off;
        if (count > 64u) count = 64u;
        assert(req(0x21, USB_REQ_DFU_DNLOAD, block, 0, count, &x) == USB_FND_SUCCESS);
        assert(x.cb_done && (unsigned)x.len == count);
        memcpy(x.data, image + off, count);
        x.ofs = count;
        assert(x.cb_done(&x));
        assert(req(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
        assert(x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
        off += count;
    }
    assert(req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) == USB_FND_SUCCESS);
    assert(x.cb_done && x.cb_done(&x) && phase() == 2);
    assert(model.erases == 1 && model.pages == 12);
    assert(!memcmp(model.memory + ULX5M_AT25QL321_CANDIDATE_START, image, bytes));
    for (unsigned i = 0; i < ULX5M_AT25QL321_CANDIDATE_START; ++i)
        assert(model.memory[i] == 0x95);
    for (unsigned i = ULX5M_AT25QL321_CANDIDATE_START + bytes;
         i < ULX5M_AT25QL321_CANDIDATE_START + 4096; ++i)
        assert(model.memory[i] == 0xff);
    assert(!model.writes_to_factory && !model.bad_command);
    struct ulx5m_at25ql321 identified_chip;
    uint8_t id[3];
    ulx5m_at25ql321_init(&identified_chip, &mock_bus);
    assert(ulx5m_at25ql321_identify(&identified_chip, id) == ULX5M_AT25_OK);
    assert(ulx5m_at25ql321_erase_4k(&identified_chip, 0x200000u) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_erase_4k(&identified_chip, 0x202000u) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_program_page(&identified_chip, 0x200000u,
                                        image, 64) == ULX5M_AT25_RANGE);
    assert(ulx5m_at25ql321_program_page(&identified_chip, 0x202000u,
                                        image, 64) == ULX5M_AT25_RANGE);
    ulx5m_dfu_stream_reset();
    arm_for(image, bytes, 0);
    assert(phase() == 3); /* Cannot silently restart on written data. */
    puts("[PASS] Real GateMate image: USB DFU blocks -> physical 0x201000 mock");
    puts("[PASS] 0x000000..0x200fff unchanged; one-sector write/readback verified");
    puts("[PASS] Wrong token, oversize, restart, metadata and boundary writes blocked");
    return 0;
}
