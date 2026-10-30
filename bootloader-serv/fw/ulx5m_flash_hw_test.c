/* Opt-in USB DFU physical flash writer. The golden build retains its
 * isolated 4 KiB native test profile. Full-image mode writes only the
 * native secondary at 0x201000; it never activates or selects boot targets.
 */
#include <stdint.h>
#include "config.h"
#include "ulx5m_flash_hw_test.h"
#include "ulx5m_dfu_stream.h"
#include "ulx5m_at25ql321_hw.h"
#include "ulx5m_flash_program.h"

#if !defined(ULX5M_FLASH_HW_TEST) || !defined(ULX5M_DFU_HW_TEST_ONLY)
#error "Hardware writer is available only in opt-in experimental firmware"
#endif
#if defined(ULX5M_FLASH_HW_QUAD_TEST) && \
    !defined(ULX5M_DFU_HW_QUAD_TEST_ONLY) && !defined(ULX5M_DFU_HW_NATIVE_TEST_ONLY)
#error "Four-sector writer requires its isolated experimental profile"
#endif
#if defined(ULX5M_FLASH_HW_MULTI_TEST) && !defined(ULX5M_DFU_HW_MULTI_TEST_ONLY)
#error "Multi-sector writer requires its isolated experimental profile"
#endif
#if defined(ULX5M_FLASH_HW_MULTI_TEST) && defined(ULX5M_FLASH_HW_QUAD_TEST)
#error "Four-sector and two-sector profiles are mutually exclusive"
#endif
#if defined(ULX5M_DFU_FULL_IMAGE_TEST) && \
    (defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST) || \
     defined(ULX5M_FLASH_HW_QUAD_TEST) || \
     defined(ULX5M_FLASH_HW_MULTI_TEST))
#error "Full-image and limited experimental profiles are mutually exclusive"
#endif
#ifdef ULX5M_FLASH_HW_NATIVE_SLOT_TEST
#if !defined(ULX5M_DFU_HW_NATIVE_TEST_ONLY) || \
    !defined(ULX5M_FLASH_HW_QUAD_TEST) || defined(ULX5M_DFU_HW_QUAD_TEST_ONLY)
#error "Native slot hardware profile must be isolated from FWT3"
#endif
_Static_assert(ULX5M_FLASH_CANDIDATE_START == 0x00201000u,
               "Incorrect native program base");
_Static_assert(ULX5M_AT25QL321_CANDIDATE_START == 0x00201000u,
               "Incorrect native SPI address");
#endif
#if !defined(__riscv) && !defined(ULX5M_FLASH_HW_HOST_TEST)
#error "Hardware writer host execution requires explicit host mock"
#endif
#if defined(ULX5M_FLASH_HW_HOST_TEST) && defined(__riscv)
#error "Hardware flash host mocks are forbidden in FPGA firmware"
#endif
#if defined(ULX5M_AT25QL321_EMULATOR_TEST) && defined(__riscv)
#error "Emulator authorization must not be used in hardware firmware"
#endif

#ifndef ULX5M_FLASH_HW_HOST_TEST
static struct ulx5m_at25ql321_hw hw;
#endif
#ifdef ULX5M_FLASH_HW_HOST_TEST
static const struct ulx5m_at25ql321_bus *test_bus;
void ulx5m_flash_hw_test_set_test_bus(const struct ulx5m_at25ql321_bus *bus)
{
    test_bus = bus;
}
#endif
static struct ulx5m_at25ql321 chip;
static struct ulx5m_flash_program program;
static uint8_t arm_buffer[ULX5M_HW_ARM_BYTES] __attribute__((aligned(4)));
static uint32_t image_bytes;
static uint32_t expected_crc;
static uint8_t phase;  /* 0=disarmed, 1=armed, 2=verified, 3=failed */
static uint8_t error_code;

static uint32_t get32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static void put32(uint8_t *p, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(value >> (8u * i));
}
static int spi_erase(void *ctx, uint32_t address)
{
    (void)ctx;
    return ulx5m_at25ql321_erase_4k(&chip, address) == ULX5M_AT25_OK ? 0 : -1;
}
static int spi_program(void *ctx, uint32_t address,
                       const uint8_t *bytes, unsigned len)
{
    (void)ctx;
    return ulx5m_at25ql321_program_page(&chip, address, bytes, len) ==
           ULX5M_AT25_OK ? 0 : -1;
}
static int spi_read(void *ctx, uint32_t address, uint8_t *bytes, unsigned len)
{
    (void)ctx;
    return ulx5m_at25ql321_read(&chip, address, bytes, len) ==
           ULX5M_AT25_OK ? 0 : -1;
}
static int sink(uint32_t offset, const uint8_t *bytes, unsigned len)
{
    enum ulx5m_flash_program_result result;
    if (phase != 1)
        return -1;
    result = ulx5m_flash_program_feed(&program, offset, bytes, len);
    if (result != ULX5M_PROGRAM_OK) {
        phase = 3;
        error_code = (uint8_t)result;
        ulx5m_dfu_stream_set_flash_sink(0);
        return -1;
    }
    return 0;
}

#ifdef ULX5M_DFU_FULL_IMAGE_TEST
int ulx5m_flash_hw_test_is_armed(void)
{
    return phase == 1u;
}
#endif

void ulx5m_flash_hw_test_reset(void)
{
    ulx5m_dfu_stream_set_flash_sink(0);
    program.active = 0;
    phase = 0;
    error_code = 0;
    image_bytes = 0;
    expected_crc = 0;
}

static int arm(uint32_t length, uint32_t crc)
{
    uint8_t id[3];
    uint8_t status;
#ifndef ULX5M_DFU_FULL_IMAGE_TEST
    uint8_t scratch[256];
#endif
    struct ulx5m_flash_program_ops ops = {
        .ctx = 0, .erase_sector = spi_erase,
        .program_page = spi_program, .read_bytes = spi_read
    };
    if (phase != 0 || !ulx5m_dfu_stream_can_arm() ||
        !length || length > ULX5M_HW_MAX_BYTES)
        return -1;
#ifdef ULX5M_FLASH_HW_HOST_TEST
    if (!test_bus)
        return -1;
    ulx5m_at25ql321_init(&chip, test_bus);
#else
    ulx5m_at25ql321_hw_init(&hw, SPI_BASE);
    ulx5m_at25ql321_hw_bind(&chip, &hw);
#endif
    if (ulx5m_at25ql321_identify(&chip, id) != ULX5M_AT25_OK ||
        ulx5m_at25ql321_status(&chip, &status) != ULX5M_AT25_OK ||
        (status & 0x03u))
        return -1;
#ifndef ULX5M_DFU_FULL_IMAGE_TEST
    /* Fail closed unless the candidate sector is entirely erased.
     * Incomplete transfers cannot be silently restarted or resumed. */
    for (unsigned off = 0; off < ULX5M_HW_MAX_BYTES; off += 256u) {
        if (ulx5m_at25ql321_read(&chip, ULX5M_FLASH_CANDIDATE_START + off,
                                  scratch, sizeof(scratch)) != ULX5M_AT25_OK)
            return -1;
        for (unsigned i = 0; i < sizeof(scratch); ++i)
            if (scratch[i] != 0xffu)
                return -1;
    }
#endif
    if (ulx5m_flash_program_begin(&program, &ops, length, crc) !=
        ULX5M_PROGRAM_OK)
        return -1;
    image_bytes = length;
    expected_crc = crc;
    phase = 1;
    ulx5m_dfu_stream_set_flash_sink(sink);
    return 0;
}

static bool arm_done(struct usb_xfer *xfer)
{
    if (xfer->data != arm_buffer || xfer->ofs != ULX5M_HW_ARM_BYTES ||
        xfer->len != ULX5M_HW_ARM_BYTES ||
        arm_buffer[0] != 'U' || arm_buffer[1] != '5' ||
        arm_buffer[2] != 'W' ||
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
        arm_buffer[3] != 'F' ||
#elif defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST)
        arm_buffer[3] != 'N' ||
#elif defined(ULX5M_FLASH_HW_QUAD_TEST)
        arm_buffer[3] != '3' ||
#elif defined(ULX5M_FLASH_HW_MULTI_TEST)
        arm_buffer[3] != '2' ||
#else
        arm_buffer[3] != '1' ||
#endif
        get32(arm_buffer + 12) != ULX5M_HW_ARM_TOKEN ||
        arm(get32(arm_buffer + 4), get32(arm_buffer + 8))) {
        phase = 3;
        error_code = ULX5M_PROGRAM_DENIED;
        ulx5m_dfu_stream_set_flash_sink(0);
    }
    return true;
}
static bool finish_done(struct usb_xfer *xfer)
{
    enum ulx5m_flash_program_result result;
    (void)xfer;
    if (phase != 1 || program.received != image_bytes) {
        phase = 3;
        error_code = ULX5M_PROGRAM_STATE;
        ulx5m_dfu_stream_set_flash_sink(0);
        return true;
    }
    result = ulx5m_flash_program_finish(&program);
    phase = result == ULX5M_PROGRAM_OK ? 2 : 3;
    error_code = (uint8_t)result;
    ulx5m_dfu_stream_set_flash_sink(0);
    return true;
}

enum usb_fnd_resp ulx5m_flash_hw_test_req(struct usb_ctrl_req *req,
                                           struct usb_xfer *xfer)
{
    if (req->bRequest == ULX5M_HW_STATUS_REQ && req->bmRequestType == 0xc0u) {
        if (req->wIndex || req->wValue ||
            req->wLength != ULX5M_HW_STATUS_BYTES)
            return USB_FND_ERROR;
        xfer->data[0] = 'F'; xfer->data[1] = 'W';
        xfer->data[2] = 'T';
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
        xfer->data[3] = 'F';
#elif defined(ULX5M_FLASH_HW_NATIVE_SLOT_TEST)
        xfer->data[3] = 'N';
#elif defined(ULX5M_FLASH_HW_QUAD_TEST)
        xfer->data[3] = '3';
#elif defined(ULX5M_FLASH_HW_MULTI_TEST)
        xfer->data[3] = '2';
#else
        xfer->data[3] = '1';
#endif
        put32(xfer->data + 4, phase);
        put32(xfer->data + 8, image_bytes);
        put32(xfer->data + 12, expected_crc);
        put32(xfer->data + 16, program.received);
        put32(xfer->data + 20, error_code);
        xfer->len = ULX5M_HW_STATUS_BYTES;
        return USB_FND_SUCCESS;
    }
    if (req->bRequest == ULX5M_HW_ARM_REQ && req->bmRequestType == 0x40u) {
        if (req->wIndex != 0x2000u || req->wValue != 0x0001u ||
            req->wLength != ULX5M_HW_ARM_BYTES || phase != 0)
            return USB_FND_ERROR;
        xfer->data = arm_buffer;
        xfer->len = ULX5M_HW_ARM_BYTES;
        xfer->cb_done = arm_done;
        return USB_FND_SUCCESS;
    }
    if (req->bRequest == ULX5M_HW_FINISH_REQ && req->bmRequestType == 0x40u) {
        if (req->wIndex != 0x2026u || req->wValue != 0x5afeu ||
            req->wLength || phase != 1 || program.received != image_bytes)
            return USB_FND_ERROR;
        xfer->len = 0;
        xfer->cb_done = finish_done;
        return USB_FND_SUCCESS;
    }
    /* Reject wrong-direction versions of our mutating requests. */
    if (req->bRequest == ULX5M_HW_ARM_REQ ||
        req->bRequest == ULX5M_HW_FINISH_REQ ||
        req->bRequest == ULX5M_HW_STATUS_REQ)
        return USB_FND_ERROR;
    return USB_FND_CONTINUE;
}
