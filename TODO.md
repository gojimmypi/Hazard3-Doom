# To Do

Some features and improvements planned and/or in progress for the next release.

# HDMI Startup Diagnostics

Add an FPGA-only HDMI diagnostic pattern that works without Hazard3, monitor firmware, or SDRAM.

# ESP32 Programming RTL

Integrate `esp32_prog_ctrl.v` and SD bus arbitration so Hazard3 can safely take and release SD-card ownership.

## Fix RTL causing pinned ULX4M bootloader build failure

See [commit f12d091b](https://github.com/gojimmypi/Hazard3-Doom/commit/f12d091bd57ec38729d86c47697abf27889f28cb#diff-e526455223a9dc08040f54ac4a5a2206ad28f44724240db3847bc14bb6c66c63) and prior failure in [workflow](https://github.com/ulx3s/Hazard3-Doom/actions/runs/35130997354/workflow)
that needs to have related RTL tightened.

Clean up input-only TRELLIS_IO RTL and then test and advance the pinned OSS CAD Suite version:

See [bootloader/rtl/soc_had_misc.v](https://github.com/ulx3s/Hazard3-Doom/blob/9b4d84b2df1de85969dbe193b145fa8cd9596422/bootloader/rtl/soc_had_misc.v#L185) pattern:

```verilog
TRELLIS_IO #(
    .DIR("INPUT")
) btn_io_I[7:0] (
    .B(btn),
    .I(1'b0),
    .T(1'b0),
    .O(btn_io)
);
```

Unpin workflow OSS CAD Suite version once fixed.

## Full regression test with all builds for latest yoysys

There may be other, similar problems as noted with bootleader, above.

## Implement ULX3S button GPIO RTL

- Implement `F1` `F2`, Arrows , `Reset` Buttons as GPIO peripherals, so that they can be used in the Doom game.

- Implement OLED peripherals to display the button states.

## One universal .h3d 

The .h3d is application software is current board specific; ideally the FPGA/monitor layer should 
hide the board differences behind the monitor service ABI. Doom shouldn't need to know whether it is 
running on ULX3S 12F, ULX3S 85F, or ULX4M-LD.

## wolfBoot example

- Get doom to boot from a secure bootloader, see [wolfssl/wolfboot](https://github.com/wolfssl/wolfboot)

## Implement UART or OTG device on ULX3S `US2`

- This USB connection is conspicuously unused. 

## Transistor Tester

Make the ULX3S a Transistor Tester. See:

- https://www.mikrocontroller.net/articles/AVR_Transistortester
- https://github.com/kubi48/TransistorTester-source
- https://github.com/madires/Transistortester-Warehouse
