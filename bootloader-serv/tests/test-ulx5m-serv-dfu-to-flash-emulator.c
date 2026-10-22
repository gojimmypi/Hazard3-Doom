/* Actual DFU stream requests -> host-only mock flash update callback.
 * No real SPI hardware or FLASH authorization, EVER.
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ulx5m_flash_program.h"
#include "ulx5m_dfu_stream.h"
#include "usb_dfu_proto.h"

static uint8_t fake_flash[ULX5M_FLASH_BYTES];
static struct ulx5m_flash_program programmer;
static uint8_t scratch[64];
static unsigned sectors, pages;

static int erase_sector(void *unused, uint32_t addr)
{
    (void)unused;
    if (addr < ULX5M_FLASH_CANDIDATE_START ||
        addr % ULX5M_FLASH_ERASE_BYTES || addr >= ULX5M_FLASH_BYTES)
        return -1;
    memset(fake_flash+addr, 0xff, ULX5M_FLASH_ERASE_BYTES);
    ++sectors;
    return 0;
}
static int program_page(void *unused, uint32_t addr,
                        const uint8_t *data, unsigned len)
{
    (void)unused;
    if (addr < ULX5M_FLASH_CANDIDATE_START ||
        addr % ULX5M_FLASH_PAGE_BYTES ||
        len > ULX5M_FLASH_PAGE_BYTES ||
        addr > ULX5M_FLASH_BYTES-len)
        return -1;
    for (unsigned i = 0; i < len; ++i) {
        if ((fake_flash[addr+i] & data[i]) != data[i])
            return -1;
        fake_flash[addr+i] &= data[i];
    }
    ++pages;
    return 0;
}
static int read_bytes(void *unused, uint32_t addr, uint8_t *out, unsigned len)
{
    (void)unused;
    if (addr >= ULX5M_FLASH_BYTES || len > ULX5M_FLASH_BYTES-addr)
        return -1;
    memcpy(out, fake_flash+addr, len);
    return 0;
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
    memset(fake_flash,0xa5,ULX5M_FLASH_CANDIDATE_START);
    memset(fake_flash+ULX5M_FLASH_CANDIDATE_START,0xff,
           ULX5M_FLASH_CANDIDATE_BYTES);
    struct ulx5m_flash_program_ops ops = {
        .ctx=NULL, .erase_sector=erase_sector,
        .program_page=program_page, .read_bytes=read_bytes
    };
    ulx5m_dfu_stream_reset();
    ulx5m_dfu_stream_set_test_sink(sink);
    const uint32_t expected=crc32(image,total);
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
    assert(memcmp(fake_flash+ULX5M_FLASH_CANDIDATE_START,image,total)==0);
    assert(sectors==103 && pages==1639);
    for (unsigned i=0;i<ULX5M_FLASH_CANDIDATE_START;++i)
        assert(fake_flash[i]==0xa5);
    assert(req(0x21,USB_REQ_DFU_DNLOAD,(total+63)/64,0,&x)==USB_FND_SUCCESS);
    assert(x.cb_done(&x));
    assert(req(0xa1,USB_REQ_DFU_GETSTATUS,0,6,&x)==USB_FND_SUCCESS);
    assert(x.data[0]==errNOTDONE && x.data[4]==dfuERROR);
    puts("[PASS] 419538 bytes across actual DFU request/state callbacks to mock flash");
    puts("[PASS] 103 mock erases, 1639 mock pages, page/full-image verification");
    puts("[PASS] factory half untouched; manifestation still refused");
    free(image);
    return 0;
}
