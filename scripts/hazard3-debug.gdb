# VisualGDB startup helper for the standalone Hazard3-Doom monitor.
define hazard3-start
    monitor halt
    load
    compare-sections
    set $pc = _start
end

document hazard3-start
Load the Hazard3-Doom monitor, verify its sections, and set the entry point.
end
