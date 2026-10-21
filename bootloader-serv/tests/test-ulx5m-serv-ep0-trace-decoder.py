#!/usr/bin/env python3
"""Validate v16f hardware ACK trace wire format without USB or Verilog tools."""
import importlib.util
from pathlib import Path
import struct

source = Path(__file__).resolve().with_name("diagnose-ulx5m-serv-ep0.py")
spec = importlib.util.spec_from_file_location("serv_ep0_diag", source)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def page(*words):
    return mod.decode_page(struct.pack("<4I", mod.MAGIC, *words))

pages = {0: page(0x02060301, 0x4012, 0x4040)}
for i in range(1, 5):
    pages[i] = page(i, i+1, i+2)
for i in range(5, 11):
    base = 3*(i-5)
    vals = [0xe017 + j for j in range(base, base+3)]
    pages[i] = page(*vals)
s = mod.decode_snapshot(pages)
assert s["before_request"] == 6
assert s["before_in_bd"] == 0x4012
assert s["trace_signature"] == 0xe017
assert s["ep0_in_tokens"] == 0xe018
assert s["last_tx_pid"] == 0xe020
assert s["ack_window_sync"] == 0xe021
assert s["last_ack_result"] == 0xe027
assert s["ack_line_changes"] == 0xe028
assert len(mod.TRACE_FIELDS) == 18

# The hardware stage counters are 16-bit modulo counters, not last-value
# registers. In particular, they must report deltas after a failed transfer.
from contextlib import redirect_stdout
from io import StringIO

baseline = s.copy()
after = s.copy()
for name in ("ack_window_sync", "ack_pid_valid", "ack_window_eop",
             "ack_rx_error", "ack_timeout", "ack_bd_done", "ack_line_changes"):
    baseline[name] = 0xfffe
    after[name] = 1
output = StringIO()
with redirect_stdout(output):
    mod.show_snapshot("AFTER FAILURE", after, baseline)
lines = output.getvalue().splitlines()
for name in ("ack_window_sync", "ack_pid_valid", "ack_window_eop",
             "ack_rx_error", "ack_timeout", "ack_bd_done", "ack_line_changes"):
    assert any(line.strip().startswith(name) and "(delta +3)" in line
               for line in lines), (name, output.getvalue())
assert any("last_ack_result" in line and "(delta" not in line
           for line in lines)
print("[PASS] EP0 v16f host decoder: 16-byte pages, trace fields and modulo-16 deltas")
