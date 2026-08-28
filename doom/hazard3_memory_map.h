/* -----------------------------------------------------------------------------
 * File:        hazard3_memory_map.h
 * Path:        doom/hazard3_memory_map.h
 *
 * Project:     Hazard3-Doom
 * Purpose:     Define shared external-memory regions used by the monitor and
 *              loaded Doom image.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the Apache License, Version 2.0.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * This software is provided under the terms of the applicable license.
 * See LICENSES/Apache-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

#ifndef HAZARD3_MEMORY_MAP_H
#define HAZARD3_MEMORY_MAP_H

/*
 * Hazard3 external-memory profiles.
 *
 * The proven ULX3S target has 64 MiB of 16-bit SDR SDRAM. ULX4M-LD uses
 * the same software map over the low 64 MiB of its DDR3 device. ULX4M-LS
 * v0.0.2 has 32 MiB and is selected by defining HAZARD3_SDRAM_32MB when
 * building both the monitor and the separately linked Doom image.
 */
#define HAZARD3_SDRAM_PHYSICAL_BASE          0x20000000u
#define HAZARD3_SDRAM_DIAGNOSTIC_ALIAS_BASE  0x24000000u

#define HAZARD3_DOOM_IMAGE_BASE               0x20100000u
#define HAZARD3_DOOM_IMAGE_LIMIT              0x20400000u
#define HAZARD3_DOOM_HEAP_BASE                0x20400000u

#ifdef HAZARD3_SDRAM_32MB
#define HAZARD3_SDRAM_PROFILE_NAME            "32 MiB"
#define HAZARD3_SDRAM_BYTES                   (32u * 1024u * 1024u)
#define HAZARD3_SDRAM_BANK_BYTES              (8u * 1024u * 1024u)
#define HAZARD3_DOOM_HEAP_LIMIT               0x21000000u
#define HAZARD3_DOOM_WAD_BASE                 0x21000000u
#define HAZARD3_DOOM_WAD_LIMIT                0x21c00000u
#define HAZARD3_VIDEO_BASE                    0x21c00000u
#define HAZARD3_VIDEO_LIMIT                   0x22000000u
#else
#define HAZARD3_SDRAM_PROFILE_NAME            "64 MiB"
#define HAZARD3_SDRAM_BYTES                   (64u * 1024u * 1024u)
#define HAZARD3_SDRAM_BANK_BYTES              (16u * 1024u * 1024u)
#define HAZARD3_DOOM_HEAP_LIMIT               0x22c00000u
#define HAZARD3_DOOM_WAD_BASE                 0x22c00000u
#define HAZARD3_DOOM_WAD_LIMIT                0x23c00000u
#define HAZARD3_VIDEO_BASE                    0x23c00000u
#define HAZARD3_VIDEO_LIMIT                   0x24000000u
#endif

#define HAZARD3_SDRAM_BANK_COUNT              4u

/*
 * HDMI SDRAM staging layout.
 *
 * The legacy 320x200 path keeps its original 64 KiB bank spacing so existing
 * software continues to work unchanged. The optional 400x240 test mode uses a
 * 96 KiB-aligned second staging buffer. A separate uncached workbuffer follows
 * both high-resolution staging buffers. The 512x300 GUI uses this workbuffer as
 * a packed 4-bpp staging surface; presentation copies it into the existing EBR
 * frame banks, so there is no continuous SDRAM video scanout.
 */
#define HAZARD3_VIDEO_FRAMEBUFFER0_BASE       HAZARD3_VIDEO_BASE
#define HAZARD3_VIDEO_FRAMEBUFFER1_BASE       (HAZARD3_VIDEO_BASE + 0x00010000u)
#define HAZARD3_VIDEO_FRAMEBUFFER1_HIGH_BASE  (HAZARD3_VIDEO_BASE + 0x00018000u)
#define HAZARD3_VIDEO_GUI_FRAMEBUFFER_BASE    (HAZARD3_VIDEO_BASE + 0x00030000u)
#define HAZARD3_VIDEO_WORKBUFFER_BASE         HAZARD3_VIDEO_GUI_FRAMEBUFFER_BASE

/*
 * Persistent Screen Snip cache. Keep it separate from all staging/workbuffer
 * surfaces so monitor, Doom, and GUI presentation cannot overwrite it.
 */
#define HAZARD3_SCREEN_SNIP_CACHE_BASE        (HAZARD3_VIDEO_BASE + 0x00050000u)

#endif
