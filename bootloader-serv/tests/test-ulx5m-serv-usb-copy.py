#!/usr/bin/env python3
"""Host-side ASan regression for the exact firmware usb_data_write routine."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / "fw/usb.c").read_text(encoding="ascii")
start = text.index("void\nusb_data_write(")
end = text.index("\nvoid\nusb_data_read", start)
function = text[start:end]

harness = r'''#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static uint32_t ram[64];
#define USB_DATA_BASE ((uintptr_t)ram)
''' + function + r'''
int main(void)
{
    for (int align = 0; align < 4; align++) {
        for (int count = 0; count <= 65; count++) {
            size_t allocation = (size_t)(count + align);
            uint8_t *storage = malloc(allocation ? allocation : 1);
            if (!storage) return 1;
            uint8_t *src = storage + align;
            for (int i = 0; i < count; i++)
                src[i] = (uint8_t)(i * 37 + 19);
            memset(ram, 0xa5, sizeof(ram));
            usb_data_write(16, src, count);
            uint8_t *dst = (uint8_t *)ram + 16;
            int rounded = (count + 3) & ~3;
            for (int i = 0; i < 72; i++) {
                uint8_t expected = i < count ? src[i] :
                                   i < rounded ? 0 : 0xa5;
                if (dst[i] != expected) {
                    fprintf(stderr, "Mismatch alignment=%d len=%d byte=%d\n",
                            align, count, i);
                    return 1;
                }
            }
            free(storage);
        }
    }
    puts("[PASS] 264 USB data copies (0..65 bytes, alignments 0..3)");
    return 0;
}
'''
cc = shutil.which(os.environ.get("CC", "gcc"))
if not cc:
    raise SystemExit("ERROR: host GCC missing (needed for AddressSanitizer test)")
with tempfile.TemporaryDirectory(prefix="ulx5m-serv-usb-") as tmp:
    src = Path(tmp) / "test.c"
    exe = Path(tmp) / "test"
    src.write_text(harness, encoding="ascii")
    subprocess.run([cc, "-std=c11", "-O1", "-Wall", "-Wextra",
                    "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
                    str(src), "-o", str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
