# DFU bootloader for ULX3S

This bootloader makes passthru at US1 port for ESP32 flashing
and USB DFU at US2 port for FPGA flashing. DFU is very fast.
Source is based on [HAD2019 badge bootloader](https://github.com/smunaut/had2019-playground)
modified to [ULX3S bootloader](https://github.com/emard/had2019-playground)

To install new bootloader for the first time (5 minutes flashing)
we have [precompiled binaries at ulx3s-bin](https://github.com/emard/ulx3s-bin/tree/master/fpga/dfu)
choose image for your board and:

    fujprog -j flash multiboot.img
    or
    openFPGALoader -b ulx3s --file-type bin -f multiboot.img

Bootloader by default skips to user's bitstream.
If FLASH doesn't contain valid user's bitstream, LEDs will blink
because bootloader is constantly restaring. This is normal.

To enter bootloader, hold BTN1 or set DIP SW1=ON and plug US2
In bootloader mode, LEDs 0-2 should be ON, other LEDs 3-7 OFF:

|   D7   |   D6   |   D5   |   D4   |   D3   |    D2   |    D1   |    D0   |
|--------|--------|--------|--------|--------|---------|---------|---------|
|&#x2b1b;|&#x2b1b;|&#x2b1b;|&#x2b1b;|&#x2b1b;|&#x1f7e9;|&#x1f7e7;|&#x1f7e5;|

Depending on USB and RTC state (low power sleep),
board may not immediately power on when US2 is plugged.
If board doesn't power on from US2:

    Option 1: additionaly plug US1
    Option 2: hold BTN1 as "shift" key and shortly press BTN0 for board to power ON

DFU should enumerate on US2 port:

    less /var/log/syslog
    [138611.358798] usb 1-9.1: new full-speed USB device number 109 using xhci_hcd
    [138611.462365] usb 1-9.1: New USB device found, idVendor=1d50, idProduct=614b, bcdDevice= 0.05
    [138611.462380] usb 1-9.1: New USB device strings: Mfr=2, Product=3, SerialNumber=1
    [138611.462387] usb 1-9.1: Product: ULX3S FPGA (DFU)
    [138611.462392] usb 1-9.1: Manufacturer: FER-RADIONA-EMARD
    [138611.462396] usb 1-9.1: SerialNumber: 5031473636340015

    lsusb
    Bus 001 Device 117: ID 1d50:614b OpenMoko, Inc. ULX3S FPGA (DFU)

On linux, it's practical to add a udev rule which allows normal users
members of "dialout" group to also run dfu-util,
otherwise it should be run as root:

    # file: /etc/udev/rules.d/80-fpga-dfu.rules
    # this is for DFU 1d50:614b libusb access
    ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="614b", \
    GROUP="dialout", MODE="666"

DFU is very fast, writes bitstream in few seconds.

# Usage

To upload user bitstream, hold BTN1 or turn on DIP SW1 and plug
USB. Here are some commandline examples:

    dfu-util -a 0 -D blink.bit
    zcat blink.bit.gz | dfu-util -a 0 -D -
    openFPGALoader --dfu --vid 0x1d50 --pid 0x614b --altsetting 0 blink.bit
    openFPGALoader --board=ulx3s blink.bit
    openFPGALoader -b ulx3s blink.bit.gz

To exit bootloader and execute user's bistream, use DFU command:

    dfu-util -a 0 -e

For boards without buttons, compile bootloader with
BTN1 and BTN2 always "pressed", modify remapper
in file "top-ulx3s.v"

    assign btn_remap_i = ~8'b1100000;

To upgrade bootloader, hold BTN1 and BTN2 and plug USB:

    make flash_dfu

To list all flashing destinations for -a N

    dfu-util -l

# Install to FLASH

Multiboot image with bootloader and user bitstream
should be flashed first and then write protection enabled.

    fujprog -j flash multiboot.img
    or
    openFPGALoader -b ulx3s --file-type bin -f multiboot.img

Bootloader write protects itself (first 2MB) of FLASH for
Winbond W25Q128 or ISSI IS25LP128 chips. For other chips,
it will not attempt to protect because protection registers
are vendor-specific.

To have interactive access to ESP32 micropython,
bitstream can also work as usb-serial console and
connect RS232 control lines to allow programming
of ESP32.

It is desirable to make bitstreams so that ESP32
does not reboot by switching from bootloader to user
bitstream and back. This can be done by 3-state driving
wifi_en and other ESP32 strapping pins in both bootloader
and user bitstream.

Boards v2.x.x and v3.0.x have the same ESP32 pinout but
new v3.1.x is different at ESP32 pinout.
Current default is for v2.x.x and v3.0.x.

For v3.1.x adjust ESP32-JTAG pinout in "ecp5wp.py",
in bitstreams adjust ESP32-i2c pinout (gpio16,17) in toplevel.
In the makefile, select board name because it
also defines constraints file with pinout.

    BOARD ?= ulx3s-v20
    #BOARD ?= ulx3s-v317

Some boards have problems getting JTAG-FLASH access without
discarding running bitstream. This problem manifestst as
flash ID reading as FF FF FF ...
In this case bitstream must be discarded, but ESP32
should not reboot after reloading the bitstream from FLASH.
For this there is option in "ecp5wp.py"

    discard=1

# Write Protecting Bootloader

To prevent accidental overwrite,
flash chips have options to
protect range of address space.

    16MB ISSI and Winbond FLASH chips are supported

Different FLASH chips have standard/compatible
commands for reading and writing but different
commands for write protection. On ULX3S usual
16MB chips are ISSI IS25LP128 or Winbond W25Q128,
both are supported by esp32ecp5 and work.

    4MB ISSI FLASH chip is not supported

ISSI IS25LP032 4MB is actually "supported",
it has same datasheet and commands as IS25LP128
but onboard chip probably has some bug, it can't
protect address range where bootloader is.

    Protected range: first 2MB

For this bootloader, first 2MB (address
0 - 0x1FFFFF) should be write protected.
It contains bootloader bitstream and some
data structure that can jump to user's
bitstream which starts from 0x200000.

    From what it protects

FLASH protection applied here is based on non-OTP
bits so it's reversible and protects from accidental
overwrite with "fujprog", "esp32ecp5" and
DFU bootloader itself. "fujprog" will early
segfault, "esp32ecp5" will stop after first
block verify, bootloader will upload data without
error but content will not be written.

Current version of "openFPGALoader" will silently
remove non-OTP write protection, overwrite bootloader and
leave FLASH chip unprotected. 

ISSI FLASH should be always safe and reversible.
Winbond FLASH protection can set non-reversible
OTP status register lock bit and in that case,
there is no known way to remove protection.

# Using "ecp5wp.py" to write protect

After multiboot image is flashed and esp32ecp5 uploaded
to ESP32, run serial console to ESP32 and "import ecp5wp".
Tool will detect and identify FPGA and FLASH chips and
print write protection status. On last line it will print
command that should be copy-pasted or typed to enable
write protection.

It is very important to allows access
from JTAG to FLASH in the running bitstream.

This is done by compiling bitstream with
"SYSCONFIG MASTER_SPI_PORT=ENABLE" in ".lpf" file
and without "USRMCLK" module in ".v" files. 

Tool may complain if FPGA or FLASH is not detected and
suggest some fix for a typical cause.

For ISSI IS25LP128 OTP (one-time programmable) function register
must be written because factory default is to protect "Top"
address range and bootloader needs "Bottom" protected.
Once written, there is no way back, but that should be
no problem because final state is suitable for this
bootloader.

Winbond W25Q128JV has OTP (one-time programmable) status-2
register which comes by factory default in the state suitable
for this bootloader, but if its CMP (Complement Protect) or
SRL (STATUS REGISTER LOCK) bit is written 1, then depending on
other status registers, the chip may be left a in state not
suitable for write protection, for the bootloader or permanently
read-only.

    >>> import ecp5wp
    FPGA JTAG IDCODE 0x81113043
    Warning: SPI(-1, ...) is deprecated, use SoftSPI(...) instead
    Read 0x90: Manufacture/Device ID: 9D 17
    Read 0x9F: JEDEC              ID: 9D 60 18
    Read 0x4B: Unique             ID: 50 31 47 36 36 34 00 15
    ISSI IS25LP128
    Warning: SPI(-1, ...) is deprecated, use SoftSPI(...) instead
    Read 0x05: Status Register = 0x00
    00000000
    .x...... QE  Quad Enable        : No
    ..xxxx.. BP  Protected Range    : None
    Read 0x48: Function Register = 0x01
    00000001 OTP warning value 1 can't reset to 0
    xxxx.... IRL Information Lock   : 0
    ......x. TBS Top/Bottom Select  : Top
    ecp5wp.is25lp128_protect()
    ecp5wp.is25lp128_status()

Now type suggested command to write protect

    >>> ecp5wp.is25lp128_protect()
    Warning: SPI(-1, ...) is deprecated, use SoftSPI(...) instead

Display status

    >>> ecp5wp.is25lp128_status()
    Warning: SPI(-1, ...) is deprecated, use SoftSPI(...) instead
    Read 0x05: Status Register = 0x18
    00011000
    .x...... QE  Quad Enable        : No
    ..xxxx.. BP  Protected Range    : 0x000000 - 0x1FFFFF
    Read 0x48: Function Register = 0x03
    00000011 OTP warning value 1 can't reset to 0
    xxxx.... IRL Information Lock   : 0
    ......x. TBS Top/Bottom Select  : Bottom
    >>> 

To remove protection, use parameter 0

    >>> ecp5wp.is25lp128_protect(0)

Or simply override protection by flashing bitstream
with "openFPGALoader".
