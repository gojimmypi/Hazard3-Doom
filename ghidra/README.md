# Hazard3-Doom Ghidra Extension

H3IMG is the executable image format used by the Hazard3-Doom boot monitor. 
Each image contains a 64-byte header followed by a binary payload. Images can be 
transferred through the monitor's UART interface (including via a USB-to-UART adapter) 
or loaded from supported storage media.

This directory contains the [Hazard3H3IMG Ghidra extension](Hazard3H3IMG/README.md), 
which includes an H3IMG image loader and a Hazard3-Doom MMIO analyzer. The loader 
imports packaged executable images; the analyzer adds peripheral memory blocks and 
register symbols for static analysis. See the extension README for build, installation, 
and import instructions.

The header is 64 bytes long and contains the following fields:

| Offset | Size | Field |
|--------|------|-------|
| `0x00` | 4 | `magic` |
| `0x04` | 4 | `header_bytes` |
| `0x08` | 4 | `format_version` |
| `0x0C` | 4 | `flags` |
| `0x10` | 4 | `load_address` |
| `0x14` | 4 | `image_bytes` |
| `0x18` | 4 | `entry_address` |
| `0x1C` | 4 | `bss_address` |
| `0x20` | 4 | `bss_bytes` |
| `0x24` | 4 | `payload_crc32` |
| `0x28-0x3F` | 24 | `reserved[6]` |


## Hazard3 H3IMG

Defined in [doom_image_format.h](https://github.com/ulx3s/Hazard3-Doom/blob/main/doom/doom_image_format.h) is 
the `hazard3_doom_image_header_t` struct, which is used to represent the header of a Hazard3 image file.

```c
typedef struct hazard3_doom_image_header {
    uint32_t magic;
    uint32_t header_bytes;
    uint32_t format_version;
    uint32_t flags;
    uint32_t load_address;
    uint32_t image_bytes;
    uint32_t entry_address;
    uint32_t bss_address;
    uint32_t bss_bytes;
    uint32_t payload_crc32;
    uint32_t reserved[6];
} hazard3_doom_image_header_t;
```

See the [doom/doom_image_loader.c](https://github.com/ulx3s/Hazard3-Doom/blob/main/doom/doom_image_loader.c)
and the [ELF-to-H3IMG converter script](https://github.com/gojimmypi/Hazard3-Doom/blob/develop/doom/package-doom-image.py)

The web uploader uses the following format identifiers and transfer-protocol constants. 

```
const H3IMG_IMAGE_MAGIC_TEXT = "H3I1";
const H3IMG_IMAGE_MAGIC = 0x31493348; // Little-endian uint32 encoding of H3I1.
const H3IMG_HEADER_BYTES = 64;
const H3IMG_FORMAT_VERSION = 1;
const H3IMG_FLAG_CRC32 = 1;
const H3IMG_UPLOAD_CHUNK_BYTES = 4096;
const H3IMG_READY_MARKER = "H3L READY\r\n";
const H3IMG_DATA_MARKER = "H3L DATA\r\n";
const H3IMG_OK_MARKER = "H3L OK";
const H3IMG_ERROR_MARKER = "H3L ERROR";
```

The `H3IMG_UPLOAD_CHUNK_BYTES` and the `H3L` markers describe the UART upload protocol, 
not fields in the H3IMG file header:

## References

- [Building Hazard3-Doom](https://hazard3-doom.readthedocs.io/en/latest/getting-started/build.html)
- [Using the Web Tool](https://hazard3-doom.readthedocs.io/en/latest/user-guide/web-tool.html)
- [Web App Source: web/app.js](https://github.com/ulx3s/Hazard3-Doom/blob/main/web/app.js)
- [github.com/nationalsecurityagency/ghidra](https://github.com/nationalsecurityagency/ghidra)
- [ghidrabook.com](https://www.ghidrabook.com/)
- [The Ghidra Book, 2nd Edition](https://nostarch.com/ghidra-book-2e)
