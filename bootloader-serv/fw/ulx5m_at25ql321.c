/* AT25QL321 read commands and gated experimental 0x06/0x04/0x20/0x02.
 * Normal firmware denies erase/program. Hardware authorization exists only
 * in the separate volatile one-sector test image, never in a release image.
 * No status-register writes, bulk erase, or boot activation.
 */
#include "ulx5m_at25ql321.h"

#if defined(ULX5M_FLASH_HW_TEST) && \
    !((defined(__riscv) && defined(ULX5M_DFU_HW_TEST_ONLY)) || \
      defined(ULX5M_FLASH_HW_HOST_TEST))
#error "Hardware flash writes require isolated experimental build"
#endif

#if defined(__riscv) && defined(ULX5M_FLASH_HW_HOST_TEST)
#error "Hardware MMIO host simulation is forbidden in FPGA firmware"
#endif

#if defined(__riscv) && defined(ULX5M_AT25QL321_EMULATOR_TEST)
#error "AT25QL321 emulator write authorization is forbidden on FPGA firmware"
#endif

#define CMD_RDID 0x9fu
#define CMD_RDSR 0x05u
#define CMD_READ 0x03u
#if defined(ULX5M_AT25QL321_EMULATOR_TEST) || defined(ULX5M_FLASH_HW_TEST)
#define CMD_WREN 0x06u
#define CMD_WRDI 0x04u
#define CMD_BE4K 0x20u
#define CMD_PP   0x02u
#endif

static int valid_bus(const struct ulx5m_at25ql321 *d)
{
    return d && d->bus.begin && d->bus.end && d->bus.transfer;
}

static enum ulx5m_at25ql321_result command(
    struct ulx5m_at25ql321 *d, const uint8_t *tx, unsigned tx_len,
    uint8_t *rx, unsigned rx_len)
{
    int ok = 1;
    if (!valid_bus(d) || !tx || !tx_len || (rx_len && !rx))
        return ULX5M_AT25_IO;
    if (d->bus.begin(d->bus.ctx))
        return ULX5M_AT25_IO;
    for (unsigned i = 0; i < tx_len; ++i) {
        if (d->bus.transfer(d->bus.ctx, tx[i], 0)) {
            ok = 0;
            break;
        }
    }
    if (ok) {
        for (unsigned i = 0; i < rx_len; ++i) {
            if (d->bus.transfer(d->bus.ctx, 0u, &rx[i])) {
                ok = 0;
                break;
            }
        }
    }
    /* Always release CS, including failed transfers. */
    if (d->bus.end(d->bus.ctx))
        ok = 0;
    return ok ? ULX5M_AT25_OK : ULX5M_AT25_IO;
}

void ulx5m_at25ql321_init(struct ulx5m_at25ql321 *dev,
                           const struct ulx5m_at25ql321_bus *bus)
{
    if (!dev)
        return;
    dev->identified = 0;
    if (bus)
        dev->bus = *bus;
    else {
        dev->bus.ctx = 0;
        dev->bus.begin = 0;
        dev->bus.transfer = 0;
        dev->bus.end = 0;
    }
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_identify(struct ulx5m_at25ql321 *dev, uint8_t id[3])
{
    const uint8_t opcode = CMD_RDID;
    enum ulx5m_at25ql321_result r;
    if (!dev || !id)
        return ULX5M_AT25_IO;
    dev->identified = 0;
    r = command(dev, &opcode, 1, id, 3);
    if (r != ULX5M_AT25_OK)
        return r;
    if (id[0] != ULX5M_AT25QL321_JEDEC0 ||
        id[1] != ULX5M_AT25QL321_JEDEC1 ||
        id[2] != ULX5M_AT25QL321_JEDEC2)
        return ULX5M_AT25_ID;
    dev->identified = 1;
    return ULX5M_AT25_OK;
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_status(struct ulx5m_at25ql321 *dev, uint8_t *status1)
{
    const uint8_t opcode = CMD_RDSR;
    if (!dev || !dev->identified || !status1)
        return ULX5M_AT25_ID;
    return command(dev, &opcode, 1, status1, 1);
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_read(struct ulx5m_at25ql321 *dev, uint32_t address,
                       uint8_t *buffer, unsigned length)
{
    if (!dev || !dev->identified)
        return ULX5M_AT25_ID;
    if (!buffer || !length || address >= ULX5M_FLASH_BYTES ||
        length > ULX5M_FLASH_BYTES - address)
        return ULX5M_AT25_RANGE;
    const uint8_t cmd[4] = {
        CMD_READ, (uint8_t)(address >> 16),
        (uint8_t)(address >> 8), (uint8_t)address
    };
    return command(dev, cmd, sizeof(cmd), buffer, length);
}

#if defined(ULX5M_AT25QL321_EMULATOR_TEST) || defined(ULX5M_FLASH_HW_TEST)
static enum ulx5m_at25ql321_result wait_ready(struct ulx5m_at25ql321 *d)
{
    for (unsigned i = 0; i < ULX5M_AT25QL321_MAX_POLLS; ++i) {
        uint8_t status;
        enum ulx5m_at25ql321_result r = ulx5m_at25ql321_status(d, &status);
        if (r != ULX5M_AT25_OK)
            return r;
        if (!(status & 0x01u))
            return ULX5M_AT25_OK;
    }
    return ULX5M_AT25_BUSY;
}

static void disable_write(struct ulx5m_at25ql321 *d);

static enum ulx5m_at25ql321_result enable_write(struct ulx5m_at25ql321 *d)
{
    uint8_t status;
    const uint8_t opcode = CMD_WREN;
    enum ulx5m_at25ql321_result r = wait_ready(d);
    if (r != ULX5M_AT25_OK)
        return r;
    r = command(d, &opcode, 1, 0, 0);
    if (r != ULX5M_AT25_OK)
        return r;
    r = ulx5m_at25ql321_status(d, &status);
    if (r != ULX5M_AT25_OK || !(status & 0x02u)) {
        disable_write(d);
        return r != ULX5M_AT25_OK ? r : ULX5M_AT25_WEL;
    }
    return ULX5M_AT25_OK;
}

static void disable_write(struct ulx5m_at25ql321 *d)
{
    const uint8_t opcode = CMD_WRDI;
    (void)command(d, &opcode, 1, 0, 0);
}

static enum ulx5m_at25ql321_result candidate_range(
    struct ulx5m_at25ql321 *d, uint32_t address, unsigned len)
{
    if (!d || !d->identified)
        return ULX5M_AT25_ID;
    if (address < ULX5M_AT25QL321_CANDIDATE_START ||
        address >= ULX5M_FLASH_BYTES || !len ||
        len > ULX5M_FLASH_BYTES - address)
        return ULX5M_AT25_RANGE;
#ifdef ULX5M_FLASH_HW_TEST
    if (len > 4096u ||
        address - ULX5M_AT25QL321_CANDIDATE_START > 4096u - len)
        return ULX5M_AT25_RANGE;
#endif
    return ULX5M_AT25_OK;
}
#endif

enum ulx5m_at25ql321_result
ulx5m_at25ql321_erase_4k(struct ulx5m_at25ql321 *dev, uint32_t address)
{
#if !defined(ULX5M_AT25QL321_EMULATOR_TEST) && !defined(ULX5M_FLASH_HW_TEST)
    (void)dev;
    (void)address;
    return ULX5M_AT25_DENIED;
#else
    enum ulx5m_at25ql321_result r = candidate_range(dev, address,
                                                    ULX5M_FLASH_ERASE_BYTES);
    if (r != ULX5M_AT25_OK)
        return r;
    if (address % ULX5M_FLASH_ERASE_BYTES)
        return ULX5M_AT25_RANGE;
    r = enable_write(dev);
    if (r != ULX5M_AT25_OK)
        return r;
    const uint8_t cmd[4] = {
        CMD_BE4K, (uint8_t)(address >> 16),
        (uint8_t)(address >> 8), (uint8_t)address
    };
    r = command(dev, cmd, sizeof(cmd), 0, 0);
    if (r == ULX5M_AT25_OK)
        r = wait_ready(dev);
    if (r != ULX5M_AT25_OK)
        disable_write(dev);
    return r;
#endif
}

enum ulx5m_at25ql321_result
ulx5m_at25ql321_program_page(struct ulx5m_at25ql321 *dev,
                               uint32_t address, const uint8_t *data,
                               unsigned length)
{
#if !defined(ULX5M_AT25QL321_EMULATOR_TEST) && !defined(ULX5M_FLASH_HW_TEST)
    (void)dev;
    (void)address;
    (void)data;
    (void)length;
    return ULX5M_AT25_DENIED;
#else
    enum ulx5m_at25ql321_result r = candidate_range(dev, address, length);
    if (r != ULX5M_AT25_OK)
        return r;
    if (!data || length > ULX5M_FLASH_PAGE_BYTES ||
        length > ULX5M_FLASH_PAGE_BYTES - (address % ULX5M_FLASH_PAGE_BYTES))
        return ULX5M_AT25_RANGE;
    uint8_t before[ULX5M_FLASH_PAGE_BYTES];
    r = wait_ready(dev);
    if (r != ULX5M_AT25_OK)
        return r;
    r = ulx5m_at25ql321_read(dev, address, before, length);
    if (r != ULX5M_AT25_OK)
        return r;
    for (unsigned i = 0; i < length; ++i) {
        if (before[i] != 0xffu)
            return ULX5M_AT25_NOT_ERASED;
    }
    r = enable_write(dev);
    if (r != ULX5M_AT25_OK)
        return r;
    uint8_t cmd[4 + ULX5M_FLASH_PAGE_BYTES];
    cmd[0] = CMD_PP;
    cmd[1] = (uint8_t)(address >> 16);
    cmd[2] = (uint8_t)(address >> 8);
    cmd[3] = (uint8_t)address;
    for (unsigned i = 0; i < length; ++i)
        cmd[4 + i] = data[i];
    r = command(dev, cmd, 4 + length, 0, 0);
    if (r == ULX5M_AT25_OK)
        r = wait_ready(dev);
    if (r != ULX5M_AT25_OK)
        disable_write(dev);
    return r;
#endif
}
