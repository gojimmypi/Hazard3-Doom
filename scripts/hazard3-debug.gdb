# VisualGDB startup helper for the standalone Hazard3-Doom monitor.

set confirm off
set pagination off
set remotetimeout 30

# Hazard3 exposes three hardware breakpoint triggers and no hardware watchpoints.
set remote hardware-breakpoint-limit 3
set remote hardware-watchpoint-limit 0
set can-use-hw-watchpoints 0

define hazard3-start
    monitor halt
    load
    set $pc = _start
end

document hazard3-start
Halt Hazard3, load the monitor, set the entry point, and remain halted.
end
