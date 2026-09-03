/*
 * spi.c
 *
 * Copyright (C) 2019 Sylvain Munaut
 * All rights reserved.
 *
 * LGPL v3+, see LICENSE.lgpl3
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "spi.h"

#include "utils.h"
#include "console.h"


struct spi {
	uint32_t csr;
	uint32_t data;
} __attribute__((packed,aligned(4)));

static volatile struct spi * const spi_regs = (void*)(SPI_BASE);


void
spi_init(void)
{
	spi_regs->csr = 0xff02c0;
	flash_wake_up();
}

void
spi_xfer(unsigned cs, struct spi_xfer_chunk *xfer, unsigned n)
{
	/* CS low */
	spi_regs->csr &= ~(1 << (16+cs));

	/* Run the chunks */
	while (n--) {
		for (int i=0; i<xfer->len; i++)
		{
			uint32_t d = (xfer->write ? xfer->data[i] : 0x00) | (xfer->read ? 0x100 : 0x000);
			spi_regs->data = d;
			if (xfer->read) {
				do {
					d = spi_regs->data;
				} while (d & 0x80000000);
				xfer->data[i] = d;
			}
		}
		xfer++;
	}

	/* CS high */
	spi_regs->csr |= (1 << (16+cs));
}

/*
return value:
0: should do nothing, equal content
1: should erase
2: should write
3: should erase and write
*/
uint8_t
spi_xfer_verify(unsigned cs, struct spi_xfer_chunk *xfer, unsigned n)
{
	uint8_t should_e = 0, should_ew = 0, should_w = 0;

	/* CS low */
	spi_regs->csr &= ~(1 << (16+cs));

	/* Run the chunks */
	while (n-- != 0) {
		for (int i=0; i<xfer->len; i++)
		{
			uint32_t d = (xfer->write ? xfer->data[i] : 0x00) | (xfer->read ? 0x100 : 0x000);
			spi_regs->data = d;
			if (xfer->read) {
				do {
					d = spi_regs->data;
				} while (d & 0x80000000);
				/*
if request is 1 at flash 0, block should be erased
flash 1 can become 0 by write and doesn't need erase, but
flash 0 can become 1 only by erase
				*/
				should_e  |= (xfer->data[i]  & (uint8_t)d) != xfer->data[i] ? 1 : 0;
				should_w  |=  xfer->data[i] != (uint8_t)d                   ? 2 : 0;
				/*
erase sets all to 0xFF. after erase, if request is not 0xFF
then block should be written
				*/
				should_ew |=  xfer->data[i] != 0xFF                         ? 3 : 1;
			}
		}
		xfer++;
	}

	/* CS high */
	spi_regs->csr |= (1 << (16+cs));

	if(should_e) /* 1: should be erased */
	  return should_ew; /* 1->3: should be erased and written */
	else
	  return should_w; /* 0->2: should be written */
}


#define FLASH_CMD_RESET_ENABLE		0x66
#define FLASH_CMD_RESET_EXECUTE		0x99
#define FLASH_CMD_DEEP_POWER_DOWN	0xb9
#define FLASH_CMD_WAKE_UP		0xab
#define FLASH_CMD_WRITE_ENABLE		0x06
#define FLASH_CMD_WRITE_ENABLE_VOLATILE	0x50
#define FLASH_CMD_WRITE_DISABLE		0x04

#define FLASH_CMD_QPI_ENTER		0x38
#define FLASH_CMD_QPI_EXIT		0xff

#define FLASH_CMD_READ_MANUF_ID		0x9f
#define FLASH_CMD_READ_UNIQUE_ID	0x4b

#define FLASH_CMD_READ_SR1		0x05
#define FLASH_CMD_READ_SR2		0x35
#define FLASH_CMD_READ_SR3		0x15
#define FLASH_CMD_WRITE_SR1		0x01
#define FLASH_CMD_WRITE_SR2		0x31
#define FLASH_CMD_WRITE_SR3		0x11

#define FLASH_CMD_READ_DATA		0x03
#define FLASH_CMD_PAGE_PROGRAM		0x02
#define FLASH_CMD_QUAD_PAGE_PROGRAM	0x32
#define FLASH_CMD_CHIP_ERASE		0x60
#define FLASH_CMD_SECTOR_ERASE		0x20
#define FLASH_CMD_BLOCK_ERASE_32k	0x52
#define FLASH_CMD_BLOCK_ERASE_64k	0xd8

void
flash_cmd(uint8_t cmd)
{
	struct spi_xfer_chunk xfer[1] = {
		{ .data = (void*)&cmd, .len = 1, .read = false, .write = true,  },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 1);
}

void
flash_cmd_qpi(uint8_t cmd)
{
	/* CS low */
	spi_regs->csr &= ~(1 << 16);

	/* Command in quad-mode */
	spi_regs->data = cmd | 0x200;

	/* Wait for completion */
	while (!(spi_regs->csr & (1 << 27)));

	/* CS high */
	spi_regs->csr |= (1 << 16);
}

void
flash_reset(void)
{
	/* Send 'Exit QPI' in quad mode */
	flash_cmd_qpi(FLASH_CMD_QPI_EXIT);

	/* Soft reset */
	flash_cmd(FLASH_CMD_RESET_ENABLE);
	flash_cmd(FLASH_CMD_RESET_EXECUTE);
}

void
flash_deep_power_down(void)
{
	flash_cmd(FLASH_CMD_DEEP_POWER_DOWN);
}

void
flash_wake_up(void)
{
	flash_cmd(FLASH_CMD_WAKE_UP);
}

void
flash_write_enable(void)
{
	flash_cmd(FLASH_CMD_WRITE_ENABLE);
}

void
flash_write_enable_volatile(void)
{
	flash_cmd(FLASH_CMD_WRITE_ENABLE_VOLATILE);
}

void
flash_write_disable(void)
{
	flash_cmd(FLASH_CMD_WRITE_DISABLE);
}

void
flash_manuf_id(void *manuf)
{
	uint8_t cmd = FLASH_CMD_READ_MANUF_ID;
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)&cmd,  .len = 1, .read = false, .write = true,  },
		{ .data = (void*)manuf, .len = 3, .read = true,  .write = false, },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 2);
}

void
flash_unique_id(void *id)
{
	uint8_t cmd = FLASH_CMD_READ_UNIQUE_ID;
	struct spi_xfer_chunk xfer[3] = {
		{ .data = (void*)&cmd, .len = 1, .read = false, .write = true,  },
		{ .data = (void*)0,    .len = 4, .read = false, .write = false, },
		{ .data = (void*)id,   .len = 8, .read = true,  .write = false, },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 3);
}

uint8_t
flash_read_reg(uint8_t reg)
{
	uint8_t cmd = reg;
	uint8_t rv;
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)&cmd, .len = 1, .read = false, .write = true,  },
		{ .data = (void*)&rv,  .len = 1, .read = true,  .write = false, },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 2);
	return rv;
}

void
flash_write_reg(uint8_t reg, uint8_t val)
{
	uint8_t cmd[2] = { reg, val };
	struct spi_xfer_chunk xfer[1] = {
		{ .data = (void*)cmd, .len = 2, .read = false, .write = true,  },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 1);
}

uint8_t
flash_read_sr(void)
{
	uint8_t cmd = FLASH_CMD_READ_SR1;
	uint8_t rv;
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)&cmd, .len = 1, .read = false, .write = true,  },
		{ .data = (void*)&rv,  .len = 1, .read = true,  .write = false, },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 2);
	return rv;
}

void
flash_write_sr(uint8_t srno, uint8_t sr)
{
	uint8_t cmd[2] = { 0, sr };
	if (srno==1) cmd[0]=FLASH_CMD_WRITE_SR1;
	if (srno==2) cmd[0]=FLASH_CMD_WRITE_SR2;
	if (srno==3) cmd[0]=FLASH_CMD_WRITE_SR3;
	if (cmd[0]==0) return;
	struct spi_xfer_chunk xfer[1] = {
		{ .data = (void*)cmd, .len = 2, .read = false, .write = true,  },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 1);
}

void
flash_read(void *dst, uint32_t addr, unsigned len)
{
	uint8_t cmd[4] = { FLASH_CMD_READ_DATA, ((addr >> 16) & 0xff), ((addr >> 8) & 0xff), (addr & 0xff)  };
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)cmd, .len = 4,   .read = false, .write = true,  },
		{ .data = (void*)dst, .len = len, .read = true,  .write = false, },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 2);
}

/*
return value:
0: should do nothing, equal content
1: should erase
2: should write
3: should erase and write
*/
uint8_t
flash_verify(void *dst, uint32_t addr, unsigned len)
{
	uint8_t cmd[4] = { FLASH_CMD_READ_DATA, ((addr >> 16) & 0xff), ((addr >> 8) & 0xff), (addr & 0xff)  };
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)cmd, .len = 4,   .read = false, .write = true,  },
		{ .data = (void*)dst, .len = len, .read = true,  .write = false, },
	};
	return spi_xfer_verify(SPI_CS_FLASH, xfer, 2);
}

void
flash_page_program(void *src, uint32_t addr, unsigned len)
{
	uint8_t cmd[4] = { FLASH_CMD_PAGE_PROGRAM, ((addr >> 16) & 0xff), ((addr >> 8) & 0xff), (addr & 0xff)  };
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)cmd, .len = 4,   .read = false, .write = true, },
		{ .data = (void*)src, .len = len, .read = false, .write = true, },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 2);
}

void
flash_quad_page_program(void *src, uint32_t addr, unsigned len)
{
	uint8_t *p = src;

	/* CS low */
	spi_regs->csr &= ~(1 << 16);

	/* Command and address */
	spi_regs->data = FLASH_CMD_QUAD_PAGE_PROGRAM;
	spi_regs->data = (addr >> 16) & 0xff;
	spi_regs->data = (addr >>  8) & 0xff;
	spi_regs->data = (addr      ) & 0xff;

	/* All bytes in Quad Write mode */
	while (len--)
		spi_regs->data = *p++ | 0x200;

	/* Wait for completion */
	while (!(spi_regs->csr & (1 << 27)));

	/* CS high */
	spi_regs->csr |= (1 << 16);
}

static void
_flash_erase(uint8_t cmd_byte, uint32_t addr)
{
	uint8_t cmd[4] = { cmd_byte, ((addr >> 16) & 0xff), ((addr >> 8) & 0xff), (addr & 0xff)  };
	struct spi_xfer_chunk xfer[1] = {
		{ .data = (void*)cmd, .len = 4,   .read = false, .write = true,  },
	};
	spi_xfer(SPI_CS_FLASH, xfer, 1);
}

void
flash_sector_erase(uint32_t addr)
{
	_flash_erase(FLASH_CMD_SECTOR_ERASE, addr);
}

void
flash_block_erase_32k(uint32_t addr)
{
	_flash_erase(FLASH_CMD_BLOCK_ERASE_32k, addr);
}

void
flash_block_erase_64k(uint32_t addr)
{
	_flash_erase(FLASH_CMD_BLOCK_ERASE_64k, addr);
}

// NOTE: this is specific to the Winbond W25Q128JV*, see datasheet p.18
// https://www.winbond.com/resource-files/w25q128jv%20revf%2003272018%20plus.pdf
// This also assumes an ECP5 bootloader partition of 2MB (0x000000 - 0x1FFFFF).
void
winbond_flash_write_protect(uint8_t winbond_sr1_wanted)
{
	// Winbond registers
	uint8_t winbond_sr1;
	uint8_t winbond_sr3;
	const uint8_t winbond_sr3_wanted = 0x60;

	printf("Winbond W25Q128\n");
	winbond_sr1 = flash_read_reg(0x05);
	printf("SR1=0x%02X, wanted (SR1 & 0xFC) = 0x%02X\n", winbond_sr1, winbond_sr1_wanted);
	if((winbond_sr1 & 0xFC) != winbond_sr1_wanted)
	{
		printf("Writing SR1\n");
		flash_write_enable();
		flash_write_reg(0x01, winbond_sr1_wanted); // protect setting bits
		while(flash_read_sr() & 1);
	}
	winbond_sr3 = flash_read_reg(0x15);
	printf("SR3=0x%02X, wanted (SR3 & 0x64) = 0x%02X\n", winbond_sr3, winbond_sr3_wanted);
	if((winbond_sr3 & 0x64) != winbond_sr3_wanted)
	{
		printf("Writing SR3\n");
		flash_write_enable();
		flash_write_reg(0x11, winbond_sr3_wanted); // set write protection scheme
		while(flash_read_sr() & 1);
	}
}

void
issi_flash_write_protect(uint8_t issi_sr_wanted)
{
	// ISSI registers
	uint8_t issi_sr;
	uint8_t issi_fr;
	const uint8_t issi_fr_wanted = 0x02; // OTP this bit has to be set

	printf("ISSI IS25LP128\n");
	issi_sr = flash_read_reg(0x05);
	printf("SR=0x%02X, wanted (SR & 0x3C) = 0x%02X\n", issi_sr, issi_sr_wanted);
	if((issi_sr & 0x3C) != issi_sr_wanted)
	{
		printf("Writing SR\n");
		flash_write_enable();
		flash_write_reg(0x01, issi_sr_wanted); // protect setting bits
		while(flash_read_sr() & 1);
	}
	issi_fr = flash_read_reg(0x48);
	printf("FR=0x%02X, wanted (FR & 0x02) = 0x%02X\n", issi_fr, issi_fr_wanted);
	if((issi_fr & 0x02) != issi_fr_wanted)
	{
		printf("Writing FR (OTP)\n");
		flash_write_enable();
		flash_write_reg(0x42, issi_fr_wanted); // set write protection scheme
		while(flash_read_sr() & 1);
	}
}

void
flash_write_protect_bootloader()
{
	uint32_t manuf_id = 0;
	flash_manuf_id(&manuf_id);
	printf("Protect manufacturer ID : 0x%06X\n", manuf_id);
	// protect lower 2MB
	if(manuf_id == 0x1840EF)
		winbond_flash_write_protect(0x30);
	if(manuf_id == 0x18609D)
		issi_flash_write_protect(0x18); 
}

void
flash_write_unprotect_bootloader()
{
	uint32_t manuf_id = 0;
	flash_manuf_id(&manuf_id);
	printf("Unprotect manufacturer ID : 0x%06X\n", manuf_id);
	// unprotect all
	if(manuf_id == 0x1840EF)
		winbond_flash_write_protect(0);
	if(manuf_id == 0x18609D)
		issi_flash_write_protect(0); 
}

#define PSRAM_CMD_WRITE	0x02
#define PSRAM_CMD_READ	0x03

void
psram_read(int id, void *dst, uint32_t addr, unsigned len)
{
	uint8_t cmd[4] = { PSRAM_CMD_READ, ((addr >> 16) & 0xff), ((addr >> 8) & 0xff), (addr & 0xff)  };
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)cmd, .len = 4,   .read = false, .write = true,  },
		{ .data = (void*)dst, .len = len, .read = true,  .write = false, },
	};
	spi_xfer(SPI_CS_PSRAMA + id, xfer, 2);
}

void
psram_write(int id, void *dst, uint32_t addr, unsigned len)
{
	uint8_t cmd[4] = { PSRAM_CMD_WRITE, ((addr >> 16) & 0xff), ((addr >> 8) & 0xff), (addr & 0xff)  };
	struct spi_xfer_chunk xfer[2] = {
		{ .data = (void*)cmd, .len = 4,   .read = false, .write = true,  },
		{ .data = (void*)dst, .len = len, .read = false, .write = true, },
	};
	spi_xfer(SPI_CS_PSRAMA + id, xfer, 2);
}

void
psram_qpi_exit(int id)
{
	/* CS low */
	spi_regs->csr &= ~(1 << (17+id));

	/* Command in Quad IO mode */
	spi_regs->data = 0x2f5;

	/* Wait for completion */
	while (!(spi_regs->csr & (1 << 27)));

	/* CS high */
	spi_regs->csr |= (1 << (17+id));
}
