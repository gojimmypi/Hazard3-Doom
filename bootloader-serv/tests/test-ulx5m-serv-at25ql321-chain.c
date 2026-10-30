/* DFU callbacks -> flash program engine -> AT25QL321 command driver ->
 * native-host SPI model. All write authorization is emulator-only.
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_flash_program.h"
#include "ulx5m-at25ql321-mock.h"
#include "ulx5m_dfu_stream.h"
#include "usb_dfu_proto.h"

#ifdef ULX5M_FLASH_HW_HOST_TEST
#include "ulx5m_flash_hw_test.h"

static struct ulx5m_spi_mock vendor_mock;
static uint8_t vendor_buf[64];

static enum usb_fnd_resp vendor_req(uint8_t type, uint8_t command,
                                    uint16_t value, uint16_t index,
                                    unsigned length, struct usb_xfer *x)
{
    struct usb_ctrl_req r = {
        .bmRequestType = type, .bRequest = command,
        .wValue = value, .wIndex = index, .wLength = length
    };
    memset(x, 0, sizeof(*x));
    x->data = vendor_buf;
    x->len = sizeof(vendor_buf);
    if (type == 0xc0 || type == 0x40)
        return ulx5m_flash_hw_test_req(&r, x);
    return ulx5m_dfu_stream_req(&r, x);
}

static uint32_t vendor_get32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void vendor_put32(uint8_t *p, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i)
        p[i] = (uint8_t)(value >> (8u * i));
}

static uint32_t vendor_crc(const uint8_t *bytes, unsigned len)
{
    uint32_t crc = 0xffffffffu;
    for (unsigned i = 0; i < len; ++i) {
        crc ^= bytes[i];
        for (unsigned b = 0; b < 8; ++b)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc ^ 0xffffffffu;
}

static void vendor_arm(unsigned total, uint32_t crc)
{
    struct usb_xfer x;
    assert(vendor_req(0x40, ULX5M_HW_ARM_REQ, 1, 0x2000,
                      ULX5M_HW_ARM_BYTES, &x) == USB_FND_SUCCESS);
    assert(x.len == 16 && x.cb_done);
    memcpy(x.data, "U5WF", 4);
    vendor_put32(x.data + 4, total);
    vendor_put32(x.data + 8, crc);
    vendor_put32(x.data + 12, ULX5M_HW_ARM_TOKEN);
    x.ofs = 16;
    assert(x.cb_done(&x));
    assert(vendor_req(0xc0, ULX5M_HW_STATUS_REQ, 0, 0,
                      ULX5M_HW_STATUS_BYTES, &x) == USB_FND_SUCCESS);
    assert(memcmp(x.data, "FWTF", 4) == 0);
    assert(vendor_get32(x.data + 4) == 1u);
    assert(vendor_get32(x.data + 8) == total);
}

static void vendor_block(const uint8_t *image, unsigned offset, unsigned length)
{
    struct usb_xfer x;
    assert(vendor_req(0x21, USB_REQ_DFU_DNLOAD, offset / 64u, 0,
                      length, &x) == USB_FND_SUCCESS);
    assert(x.cb_done && x.len == (int)length);
    memcpy(x.data, image + offset, length);
    x.ofs = length;
    assert(x.cb_done(&x));
    assert(vendor_req(0xa1, USB_REQ_DFU_GETSTATUS, 0, 0, 6, &x) ==
           USB_FND_SUCCESS);
    assert(x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
}

int main(void)
{
    static uint8_t image[419538];
    struct usb_xfer x;
    ulx5m_spi_mock_init(&vendor_mock);
    struct ulx5m_at25ql321_bus bus = ulx5m_spi_mock_bus(&vendor_mock);
    /* Simulate a fully occupied native sector and protected factory payload. */
    memset(vendor_mock.memory, 0x71, 0x201000u);
    memset(vendor_mock.memory + 0x201000u, 0x35, sizeof(image));
    for (unsigned i = 0; i < sizeof(image); ++i)
        image[i] = (uint8_t)((i * 17u + (i >> 9) + 53u) & 255u);
    memcpy(image, "\xd9\x01\xed\x96", 4);
    const uint32_t crc = vendor_crc(image, sizeof(image));
    uint8_t layout[32];
    ulx5m_flash_layout_encode(layout);
    assert(vendor_get32(layout + 20) == 0x201000u);
    assert(vendor_get32(layout + 24) == 1u);
    assert(vendor_get32(layout + 28) == 0u);
    assert(ulx5m_flash_check_erase(0x200000u, 0x1000u) ==
           ULX5M_FLASH_WRITE_PROTECTED);
    assert(ulx5m_flash_check_erase(0x201000u, 0x1000u) ==
           ULX5M_FLASH_WRITE_OK);
    assert(ulx5m_flash_check_program(0x400000u, 1u) ==
           ULX5M_FLASH_WRITE_BAD_RANGE);
    assert(ulx5m_flash_check_program(0x201000u, 64u) ==
           ULX5M_FLASH_WRITE_OK);
    ulx5m_dfu_stream_reset();
    ulx5m_flash_hw_test_set_test_bus(&bus);
    assert(vendor_req(0x21, USB_REQ_DFU_DNLOAD, 0, 0, 64, &x) == USB_FND_ERROR);
    assert(vendor_req(0x21, USB_REQ_DFU_CLRSTATUS, 0, 0, 0, &x) == USB_FND_SUCCESS);
    /* Wrong JEDEC cannot arm or mutate flash. */
    vendor_mock.jedec[2] = 0;
    assert(vendor_req(0x40, ULX5M_HW_ARM_REQ, 1, 0x2000, 16, &x) == USB_FND_SUCCESS);
    memcpy(x.data, "U5WF", 4);
    vendor_put32(x.data + 4, sizeof(image));
    vendor_put32(x.data + 8, crc);
    vendor_put32(x.data + 12, ULX5M_HW_ARM_TOKEN);
    x.ofs = 16;
    assert(x.cb_done(&x));
    assert(!vendor_mock.erases && !vendor_mock.pages);
    ulx5m_dfu_stream_reset();
    vendor_mock.jedec[2] = ULX5M_AT25QL321_JEDEC2;
    vendor_arm(sizeof(image), crc);
    /* Premature FINISH is rejected without mutating data. */
    assert(vendor_req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) ==
           USB_FND_ERROR);
    for (unsigned off = 0; off < 256u; off += 64u)
        vendor_block(image, off, 64u);
    assert(vendor_mock.erases == 1u);
    /* Power/USB reset during the stream drops the session; re-arm overwrites. */
    ulx5m_dfu_stream_reset();
    vendor_arm(sizeof(image), crc);
    for (unsigned off = 0; off < sizeof(image); off += 64u) {
        unsigned n = sizeof(image) - off;
        if (n > 64u)
            n = 64u;
        vendor_block(image, off, n);
    }
    assert(vendor_req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) ==
           USB_FND_SUCCESS);
    assert(x.cb_done && x.cb_done(&x));
    assert(vendor_req(0xc0, ULX5M_HW_STATUS_REQ, 0, 0, 24, &x) == USB_FND_SUCCESS);
    assert(vendor_get32(x.data + 4) == 2u);
    assert(vendor_get32(x.data + 16) == sizeof(image));
    assert(vendor_get32(x.data + 20) == ULX5M_PROGRAM_OK);
    assert(memcmp(vendor_mock.memory + 0x201000u, image, sizeof(image)) == 0);
    for (unsigned i = 0; i < 0x201000u; ++i)
        assert(vendor_mock.memory[i] == 0x71);
    assert(!vendor_mock.writes_to_factory && !vendor_mock.bad_command);
    /* A fully transferred image with the wrong claimed CRC must not verify. */
    ulx5m_dfu_stream_reset();
    vendor_arm(256u, vendor_crc(image, 256u) ^ 1u);
    for (unsigned off = 0; off < 256u; off += 64u)
        vendor_block(image, off, 64u);
    assert(vendor_req(0x40, ULX5M_HW_FINISH_REQ, 0x5afe, 0x2026, 0, &x) ==
           USB_FND_SUCCESS);
    assert(x.cb_done && x.cb_done(&x));
    assert(vendor_req(0xc0, ULX5M_HW_STATUS_REQ, 0, 0, 24, &x) == USB_FND_SUCCESS);
    assert(vendor_get32(x.data + 4) == 3u);
    assert(vendor_get32(x.data + 20) == ULX5M_PROGRAM_CRC);
    assert(!vendor_mock.writes_to_factory && !vendor_mock.bad_command);
    assert(vendor_req(0x21, USB_REQ_DFU_DNLOAD,
                      (sizeof(image) + 63u) / 64u, 0, 1, &x) == USB_FND_ERROR);
    puts("[PASS] full-image ARM/DNLOAD/GETSTATUS/FINISH across hardware-writer mock");
    puts("[PASS] wrong JEDEC, premature finish, interrupted restart and protected 0x000000..0x200fff");
    puts("[LIMIT] CPU/USB timing, routing and physical SPI not qualified by host test");
    return 0;
}
#else

static struct ulx5m_spi_mock mock;
static struct ulx5m_at25ql321 chip;
static struct ulx5m_flash_program programmer;
static uint8_t scratch[64];

static int erase_sector(void *unused, uint32_t addr)
{
    (void)unused;
    return ulx5m_at25ql321_erase_4k(&chip, addr) == ULX5M_AT25_OK ? 0 : -1;
}
static int program_page(void *unused, uint32_t addr,
                        const uint8_t *data, unsigned len)
{
    (void)unused;
    return ulx5m_at25ql321_program_page(&chip, addr, data, len) ==
           ULX5M_AT25_OK ? 0 : -1;
}
static int read_bytes(void *unused, uint32_t addr, uint8_t *out, unsigned len)
{
    (void)unused;
    return ulx5m_at25ql321_read(&chip, addr, out, len) ==
           ULX5M_AT25_OK ? 0 : -1;
}
static int sink(uint32_t offset, const uint8_t *bytes, unsigned len)
{
    return ulx5m_flash_program_feed(&programmer, offset, bytes, len) ==
           ULX5M_PROGRAM_OK ? 0 : -1;
}
static uint32_t crc32(const uint8_t *bytes, unsigned len)
{
    uint32_t crc=0xffffffffu;
    for (unsigned i=0; i<len; ++i) {
        crc ^= bytes[i];
        for (unsigned j=0; j<8; ++j)
            crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u);
    }
    return crc ^ 0xffffffffu;
}
static enum usb_fnd_resp req(uint8_t type, uint8_t cmd,
                             unsigned value, unsigned len, struct usb_xfer *x)
{
    struct usb_ctrl_req r = {
        .bmRequestType=type, .bRequest=cmd, .wValue=value,
        .wIndex=0, .wLength=len
    };
    memset(x, 0, sizeof(*x));
    x->data=scratch;
    x->len=sizeof(scratch);
    return ulx5m_dfu_stream_req(&r,x);
}
static uint32_t le32(const uint8_t *buf)
{
    return (uint32_t)buf[0] | ((uint32_t)buf[1]<<8) |
           ((uint32_t)buf[2]<<16) | ((uint32_t)buf[3]<<24);
}
int main(void)
{
    const unsigned total=419538;
    uint8_t *image=malloc(total);
    assert(image);
    for (unsigned i=0; i<total; ++i)
        image[i]=(uint8_t)((i*17u+(i>>9)+0x35u)&255u);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    memcpy(image, "\xd9\x01\xed\x96", 4);
#endif
    ulx5m_spi_mock_init(&mock);
    memset(mock.memory, 0xa5, ULX5M_FLASH_CANDIDATE_START);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    /* Already occupied working secondary: erasure must be allowed in full mode. */
    memset(mock.memory + ULX5M_FLASH_CANDIDATE_START, 0x55, 4096);
    memset(mock.memory + ULX5M_FLASH_CANDIDATE_START + ((total + 0xfffu) & ~0xfffu) + 0x4000u,
           0x28, ULX5M_FLASH_ERASE_BYTES);
    assert(ULX5M_FLASH_CANDIDATE_START == 0x201000u);
    assert(ULX5M_FLASH_CANDIDATE_BYTES == 0x1ff000u);
#endif
    struct ulx5m_at25ql321_bus spi_bus = ulx5m_spi_mock_bus(&mock);
    ulx5m_at25ql321_init(&chip, &spi_bus);
    uint8_t jedec[3];
    assert(ulx5m_at25ql321_identify(&chip, jedec) == ULX5M_AT25_OK);
    struct ulx5m_flash_program_ops ops = {
        .ctx=NULL, .erase_sector=erase_sector,
        .program_page=program_page, .read_bytes=read_bytes
    };
    ulx5m_dfu_stream_reset();
    ulx5m_dfu_stream_set_test_sink(sink);
    const uint32_t expected=crc32(image,total);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    assert(ulx5m_flash_program_begin(&programmer,&ops,
                                     ULX5M_FLASH_CANDIDATE_BYTES + 1u, expected) ==
           ULX5M_PROGRAM_RANGE);
    assert(ulx5m_flash_program_begin(&programmer,&ops,
                                     ULX5M_FLASH_CANDIDATE_BYTES, expected) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_begin(&programmer,&ops, 4, expected) ==
           ULX5M_PROGRAM_FORMAT);
#endif
    assert(ulx5m_flash_program_begin(&programmer,&ops,total,expected) ==
           ULX5M_PROGRAM_OK);
    struct usb_xfer x;
    for (unsigned off=0,block=0;off<total;++block) {
        unsigned n=total-off;
        if (n>64) n=64;
        assert(req(0x21,USB_REQ_DFU_DNLOAD,block,n,&x)==USB_FND_SUCCESS);
        assert(x.cb_done && x.data != scratch && x.len==(int)n);
        memcpy(x.data,image+off,n);
        x.ofs=n;
        assert(x.cb_done(&x));
        assert(req(0xa1,USB_REQ_DFU_GETSTATUS,0,6,&x)==USB_FND_SUCCESS);
        assert(x.data[0]==OK && x.data[4]==dfuDNLOAD_IDLE);
        off+=n;
    }
    assert(req(0xc0,ULX5M_STREAM_INFO_REQ,0,20,&x)==USB_FND_SUCCESS);
    assert(!memcmp(x.data,"STR1",4));
    assert(le32(x.data+4)==total && le32(x.data+8)==expected);
    assert(ulx5m_flash_program_finish(&programmer)==ULX5M_PROGRAM_OK);
    assert(memcmp(mock.memory+ULX5M_FLASH_CANDIDATE_START,image,total)==0);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    assert(mock.erases==104 && mock.pages==1639);
    for (unsigned i = 0; i < ULX5M_FLASH_ERASE_BYTES; ++i)
        assert(mock.memory[ULX5M_FLASH_CANDIDATE_START +
                           total + 0x4000u + i] == 0xffu);
#else
    assert(mock.erases==103 && mock.pages==1639);
#endif
    assert(!mock.writes_to_factory && !mock.bad_command);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    assert(mock.write_enables == 104 + 1639);
#else
    assert(mock.write_enables == 103 + 1639);
#endif
    for (unsigned i=0;i<ULX5M_FLASH_CANDIDATE_START;++i)
        assert(mock.memory[i]==0xa5);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    assert(memcmp(mock.memory + 0x200000u, "\xa5\xa5\xa5\xa5", 4) == 0);
    /* Second session: invalid synchronization must fail before any erase. */
    unsigned erases_before = mock.erases;
    assert(ulx5m_flash_program_begin(&programmer,&ops,512,expected) ==
           ULX5M_PROGRAM_OK);
    uint8_t wrong[64] = {0};
    assert(ulx5m_flash_program_feed(&programmer,0,wrong,sizeof(wrong)) ==
           ULX5M_PROGRAM_FORMAT);
    assert(mock.erases == erases_before);
    /* Power interruption/restart: an occupied native slot can be re-armed. */
    assert(ulx5m_flash_program_begin(&programmer,&ops,512,expected) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&programmer,0,image,64) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&programmer,0,image,64) ==
           ULX5M_PROGRAM_ORDER);
    assert(mock.erases == erases_before);
    assert(ulx5m_flash_program_begin(&programmer,&ops,512,expected) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_feed(&programmer,0,image,64) ==
           ULX5M_PROGRAM_OK);
    assert(ulx5m_flash_program_finish(&programmer) == ULX5M_PROGRAM_STATE);
    assert(mock.erases == erases_before);
    puts("[PASS] native occupied secondary, strict size/magic/order and aborted recovery");
#endif
    assert(req(0x21,USB_REQ_DFU_DNLOAD,(total+63)/64,0,&x)==USB_FND_SUCCESS);
    assert(x.cb_done(&x));
    assert(req(0xa1,USB_REQ_DFU_GETSTATUS,0,6,&x)==USB_FND_SUCCESS);
    assert(x.data[0]==errNOTDONE && x.data[4]==dfuERROR);
    puts("[PASS] 419538 bytes across actual DFU request/state callbacks to mock flash");
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    puts("[PASS] 104 SPI erases including stale-tail scrub, 1639 pages, WREN/WEL/WIP/readback");
#else
    puts("[PASS] 103 SPI erases, 1639 pages, WREN/WEL/WIP/readback");
#endif
    puts("[PASS] factory half untouched; manifestation still refused");
    free(image);
#ifdef ULX5M_DFU_FULL_IMAGE_TEST
    /* Exact physical end-of-chip boundary through the real DFU callbacks. */
    const unsigned maximum = ULX5M_FLASH_CANDIDATE_BYTES;
    uint8_t *edge = malloc(maximum);
    assert(edge);
    for (unsigned i = 0; i < maximum; ++i)
        edge[i] = (uint8_t)((i * 19u + (i >> 6)) & 255u);
    memcpy(edge, "\xd9\x01\xed\x96", 4);
    ulx5m_dfu_stream_reset();
    assert(ulx5m_flash_program_begin(&programmer, &ops, maximum,
                                     crc32(edge, maximum)) == ULX5M_PROGRAM_OK);
    const unsigned erase_start = mock.erases;
    const unsigned page_start = mock.pages;
    for (unsigned off = 0, block = 0; off < maximum; ++block) {
        assert(req(0x21, USB_REQ_DFU_DNLOAD, block, 64, &x) == USB_FND_SUCCESS);
        memcpy(x.data, edge + off, 64);
        x.ofs = 64;
        assert(x.cb_done(&x));
        assert(req(0xa1, USB_REQ_DFU_GETSTATUS, 0, 6, &x) == USB_FND_SUCCESS);
        assert(x.data[0] == OK && x.data[4] == dfuDNLOAD_IDLE);
        off += 64;
    }
    assert(ulx5m_flash_program_finish(&programmer) == ULX5M_PROGRAM_OK);
    assert(mock.erases - erase_start == maximum / ULX5M_FLASH_ERASE_BYTES);
    assert(mock.pages - page_start == maximum / ULX5M_FLASH_PAGE_BYTES);
    assert(memcmp(mock.memory + ULX5M_FLASH_CANDIDATE_START, edge, maximum) == 0);
    for (unsigned i = 0; i < ULX5M_FLASH_CANDIDATE_START; ++i)
        assert(mock.memory[i] == 0xa5);
    puts("[PASS] 2093056-byte exact-maximum DFU stream and flash-end readback");
    free(edge);
#endif
    return 0;
}

#endif
