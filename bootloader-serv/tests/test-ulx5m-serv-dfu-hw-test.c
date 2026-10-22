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
    assert(!memcmp(x.data, "FWT1", 4) && x.len == 24);
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
    memcpy(x.data, "U5W1", 4);
    put32(x.data + 4, length);
    /* Rejected oversize length must not read beyond the test payload. */
    put32(x.data + 8, crc(image, length > 4096u ? 4096u : length));
    put32(x.data + 12, wrong_token ? 0 : ULX5M_HW_ARM_TOKEN);
    x.ofs = 16;
    assert(x.cb_done(&x));
}
int main(void)
{
    struct usb_xfer x;
    uint8_t image[4096];
    for (unsigned i = 0; i < sizeof(image); ++i)
        image[i] = (uint8_t)((i * 37u + 0x5au) & 0xffu);
    ulx5m_spi_mock_init(&model);
    mock_bus = ulx5m_spi_mock_bus(&model);
    memset(model.memory, 0x95, ULX5M_AT25QL321_CANDIDATE_START);
    ulx5m_dfu_stream_reset();
    assert(phase() == 0 && model.erases == 0 && model.pages == 0);
    assert(req(0x40, ULX5M_HW_ARM_REQ, 0, 0, 16, &x) == USB_FND_ERROR);
    assert(req(0xc0, ULX5M_HW_ARM_REQ, 1, 0x2000, 16, &x) == USB_FND_ERROR);
    assert(req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) == USB_FND_ERROR);
    arm_for(image, 4097, 0);
    assert(phase() == 3 && model.erases == 0);
    ulx5m_dfu_stream_reset();
    arm_for(image, 512, 1);
    assert(phase() == 3 && model.erases == 0);
    ulx5m_dfu_stream_reset();
    arm_for(image, 512, 0);
    assert(phase() == 1);
    for (unsigned block = 0; block < 8; ++block) {
        assert(req(0x21, USB_REQ_DFU_DNLOAD, block, 0, 64, &x) == USB_FND_SUCCESS);
        assert(x.cb_done);
        memcpy(x.data, image + block*64, 64);
        x.ofs = 64;
        assert(x.cb_done(&x));
        assert(req(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
        assert(x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
    }
    assert(phase() == 1);
    assert(req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) == USB_FND_SUCCESS);
    assert(x.cb_done && x.cb_done(&x));
    assert(phase() == 2);
    assert(model.erases == 1 && model.pages == 2);
    assert(memcmp(model.memory + ULX5M_AT25QL321_CANDIDATE_START, image, 512) == 0);
    for (unsigned i = 0; i < ULX5M_AT25QL321_CANDIDATE_START; ++i)
        assert(model.memory[i] == 0x95);
    assert(!model.writes_to_factory && !model.bad_command);
    assert(ulx5m_at25ql321_erase_4k(&(struct ulx5m_at25ql321){0},
                                      ULX5M_AT25QL321_CANDIDATE_START + 4096u) != ULX5M_AT25_OK);
    ulx5m_dfu_stream_reset();
    assert(phase() == 0);
    arm_for(image, 512, 0);
    assert(phase() == 3); /* Non-blank candidate cannot be armed again. */
    /* Separate erased-sector run: all 64 ordered blocks across 16 pages. */
    ulx5m_spi_mock_init(&model);
    mock_bus = ulx5m_spi_mock_bus(&model);
    memset(model.memory, 0x95, ULX5M_AT25QL321_CANDIDATE_START);
    ulx5m_dfu_stream_reset();
    arm_for(image, 4096, 0);
    assert(phase() == 1);
    for (unsigned block = 0; block < 64; ++block) {
        assert(req(0x21, USB_REQ_DFU_DNLOAD, block, 0, 64, &x) == USB_FND_SUCCESS);
        memcpy(x.data, image + block * 64, 64);
        x.ofs = 64;
        assert(x.cb_done && x.cb_done(&x));
        assert(req(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) == USB_FND_SUCCESS);
        assert(x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
    }
    assert(req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) == USB_FND_SUCCESS);
    assert(x.cb_done && x.cb_done(&x) && phase() == 2);
    assert(model.erases == 1 && model.pages == 16);
    assert(!memcmp(model.memory + ULX5M_AT25QL321_CANDIDATE_START,
                   image, sizeof(image)));
    for (unsigned i = 0; i < ULX5M_AT25QL321_CANDIDATE_START; ++i)
        assert(model.memory[i] == 0x95);
    assert(!model.writes_to_factory && !model.bad_command);
    puts("[PASS] 4096-byte DFU: 64 blocks, 16 pages, 1 sector erase, CRC finish");
    puts("[PASS] explicit arm, 4KiB limit, 512 byte DFU to flash and CRC finish");
    puts("[PASS] factory intact, duplicate arm rejected, second attempt blocked by nonblank slot");
    return 0;
}
