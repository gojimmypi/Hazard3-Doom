/* Test real vendor request dispatch with mocked AT25 chip operations.
 * No QSPI hardware access; production erase/program cannot be called.
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define main ulx5m_unused_at25_main
#include "../fw/fw_ulx5m_flash_read.c"
#undef main

static unsigned identify_calls, status_calls, read_calls;

void ulx5m_at25ql321_hw_init(struct ulx5m_at25ql321_hw *hw, uintptr_t base)
{
    assert(base == SPI_BASE);
    (void)hw;
}

void ulx5m_at25ql321_hw_bind(struct ulx5m_at25ql321 *dev,
                              struct ulx5m_at25ql321_hw *hw)
{
    (void)dev;
    (void)hw;
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_identify(struct ulx5m_at25ql321 *dev, uint8_t id[3])
{
    (void)dev;
    ++identify_calls;
    id[0] = 0x1f; id[1] = 0x42; id[2] = 0x16;
    return ULX5M_AT25_OK;
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_status(struct ulx5m_at25ql321 *dev, uint8_t *status)
{
    (void)dev;
    ++status_calls;
    *status = 0x1cu;
    return ULX5M_AT25_OK;
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_read(struct ulx5m_at25ql321 *dev, uint32_t addr,
                       uint8_t *buffer, unsigned length)
{
    (void)dev;
    ++read_calls;
    for (unsigned i = 0; i < length; ++i)
        buffer[i] = (uint8_t)((addr + i) ^ 0x5au);
    return ULX5M_AT25_OK;
}

static enum usb_fnd_resp request(uint8_t dir, uint8_t request,
                                 uint16_t value, uint16_t index,
                                 uint16_t count, struct usb_xfer *xfer)
{
    struct usb_ctrl_req r = {
        .bmRequestType = dir, .bRequest = request,
        .wValue = value, .wIndex = index, .wLength = count
    };
    return flash_ctrl_req(&r, xfer);
}

int main(void)
{
    uint8_t output[40];
    struct usb_xfer x = {.data = output, .len = sizeof(output)};
    memset(output, 0xacu, sizeof(output));
    assert(request(0xc0, 0x5a, 0, 0, 8, &x) == USB_FND_SUCCESS);
    assert(x.len == 8 && !memcmp(output, "A251", 4));
    assert(output[4] == 0x1f && output[5] == 0x42 &&
           output[6] == 0x16 && output[7] == 0x1c);
    assert(output[8] == 0xacu);
    assert(identify_calls == 1 && status_calls == 1 && read_calls == 0);

    assert(request(0xc0, 0x5a, 1, 0, 8, &x) == USB_FND_ERROR);
    assert(request(0xc0, 0x5a, 0, 1, 8, &x) == USB_FND_ERROR);
    assert(request(0xc0, 0x5a, 0, 0, 7, &x) == USB_FND_ERROR);
    assert(request(0x40, 0x5a, 0, 0, 8, &x) != USB_FND_SUCCESS);
    assert(identify_calls == 1 && status_calls == 1);

    assert(request(0xc0, 0x5b, 0x0102, 0x0003, 32, &x) == USB_FND_SUCCESS);
    assert(x.len == 32);
    for (unsigned i = 0; i < 32; ++i)
        assert(output[i] == (uint8_t)((0x030102u + i) ^ 0x5au));
    assert(request(0xc0, 0x5b, 0xffff, 0x003f, 1, &x) == USB_FND_SUCCESS);
    assert(request(0xc0, 0x5b, 0xffff, 0x003f, 2, &x) == USB_FND_ERROR);
    assert(request(0xc0, 0x5b, 0, 0, 0, &x) == USB_FND_ERROR);
    assert(request(0xc0, 0x5b, 0, 0, 33, &x) == USB_FND_ERROR);
    assert(request(0x40, 0x5b, 0, 0, 32, &x) != USB_FND_SUCCESS);
    assert(read_calls == 2 && identify_calls == 3);
    puts("[PASS] real 0x5A/0x5B vendor dispatch: IN-only, bounds, A251, reads");
    return 0;
}
