# VisualGDB

This Visual Studio [VisualGDB](https://visualgdb.com/) project directory is part of [UXL-Doom](https://ulx3s.github.io/ulx-doom/) on the Hazard3 RISC-V.

**NOTE** The `win32` project Solution Platform is *not* `win32`, not `x86` - it is `RISC-V` and expects a RISC-V toolchain, specifically a non-MSBuild/NMake project.

As of this release, it appears that Microsoft does *not* includes a RISC-V toolchain with [Visual Studio](https://visualstudio.microsoft.com/).

If not using [WSL](https://learn.microsoft.com/en-us/windows/wsl/install), a Windows/DOS RISC-V compiler is needed
such as [xpack-dev-tools/riscv-none-elf-gcc-xpack](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/).

See the [installation instructions](https://xpack-dev-tools.github.io/riscv-none-elf-gcc-xpack/docs/install/) or use the included [script](../scripts/setup-xpack-riscv-gcc.cmd).

```DOS
REM Run from repo root:
.\scripts\setup-xpack-riscv-gcc.cmd
```

Additionally, this VisualGDB solution does not implement the FPGA synthesis (yosys, nexpnr, etc). For getting started,
there's a pre-synthesized `fpga_ulx3s_hdmi_doom.bit` file in the [.\bin\](../bin/) directory.

## Hazard3-Doom Project

This is a completely self-contained Windows/DOS Project that uses OpenOCD and GDB in the `./bin/` directory.

Ensure the ECP5 bitstream file is already loaded onto the FPGA. This is the soft RISC-V CPU. See [the instructions](https://ulx3s.github.io/ulx-doom/#program-the-fpga).

Do not start OpenOCD manually without first disabling the launch in `GDBServerCommand` of the respective `.vgdbsettings` file.

When the RISC-V xpack is installed in `./bin/riscv-gcc`, the normal `F5` debugging can be used to build and step into code.

Begin debugging with `Start debugging with VisualGDB` when skipping the compile.

See the output Window - select "VisualGDB Program Output` and if successful, text similar to this should be seen:

```
xPack Open On-Chip Debugger 0.12.0+dev-02228-ge5888bda3-dirty (2025-10-04-22:44)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : clock speed 1000 kHz
Info : JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043 (mfg: 0x021 (Lattice Semi.), part: 0x1113, ver: 0x4)
Info : datacount=1 progbufsize=2
Info : Disabling abstract command reads from CSRs.
Info : Examined RISC-V core; found 1 harts
Info :  hart 0: XLEN=32, misa=0x40801106
Info : [lfe5u85.hazard3] Examination succeed
Info : [lfe5u85.hazard3] starting gdb server on 3333
Info : Listening on port 3333 for gdb connections
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Info : accepting 'gdb' connection on tcp/3333
Info : Disabling abstract command writes to CSRs.
Info : [lfe5u85.hazard3] Found 3 triggers
```

## Troubleshooting

Some suggestions for common problems.

### OpenOCD already running

VisualGDB settings will launch OpenOCD automatically. There must not be an instance already running.

Ensure nothing is listening on port 3333.

```
taskkill /F /IM openocd.exe
netstat -ano | findstr LISTENING | findstr :3333
```

### No executable file specified

When using `Debug - Start Debugging with GDB` _without_ having first compiled to RISC-V elf file, and error similar to this may be encountered:

```
C:\temp\Hazard3-Doom\bin\gdb\riscv-none-elf-gdb.exe --interpreter mi --args "C:/temp/Hazard3-Doom/build/hazard3-boot-monitor.elf"
No executable file specified.
Use the "file" or "exec-file" command.
-stack-list-frames did not finish within 10000 msec and has been stopped.
You can increase the unrespnosive GDB command timeout via VisualGDB settings.
Consider setting a backtrace frame limit via VisualGDB Project Properties -> Advanced GDB Settings.
Quit
-data-evaluate-expression did not finish within 10000 msec and has been stopped.
You can increase the unrespnosive GDB command timeout via VisualGDB settings.
Quit
```

There are pre-compiled binaries in the `/bin/` directory that can be copied to `/build/`. Otherwise install a RISC-V toolchain.
See the `scripts/setup-xpack-riscv-gcc.cmd` to install the [xpack](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/)
and build from within Visual Studio or use the `scripts/build-xpack.cmd` build script.
