#!/usr/bin/env python3

cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv

python3 - <<'PY'
from pathlib import Path
import hashlib

src = Path("build-ulx5m-gs/flash-install-20261030T155241133153Z/flash-after.bin")
dst = Path("build-ulx5m-gs/native-v41-secondary-3026.bit")

flash = src.read_bytes()
assert len(flash) == 0x400000

image = flash[0x201000:0x201000 + 3026]
expected = "68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"

assert hashlib.sha256(image).hexdigest() == expected
assert flash[0x201000 + 3026:0x202000] == b"\xff" * (4096 - 3026)

dst.write_bytes(image)
print("[PASS]", dst)
print("[PASS] 3026-byte known-working secondary SHA256", expected)
PY
