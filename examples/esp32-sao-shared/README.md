# ULX3S ESP32 shared SAO example

This ESP-IDF example uses the ULX3S FPGA as the sole electrical I2C master on
its SAO connector. The ESP32 sends complete SAO transactions to the FPGA over
its dedicated Serial1 GPIO pair:

- ESP32 GPIO17 TX -> FPGA `wifi_gpio17` (N3)
- FPGA `wifi_gpio16` (L1) -> ESP32 GPIO16 RX
- 115200 baud, 8N1

The FPGA output to GPIO16 is tri-stated except while a response frame is being
sent; the FPGA pad pull-up maintains UART idle high.

No external jumper wires are required on ULX3S v2.0.x/v3.0.x boards; these are
PCB routes between the FPGA and ESP32.

The FPGA arbitrates complete transactions. An in-progress Hazard3 START..STOP
sequence is allowed to finish before an ESP32 request is granted. Once an
ESP32 request is pending, new Hazard3 I2C commands are rejected until the ESP32
transaction completes. The ESP32 proxy always issues STOP (or ABORT on timeout)
before releasing ownership.

## UART frame protocol

Request, 7 bytes:

```
A5 5A CMD ADDR REG VALUE XOR
```

Response, 7 bytes:

```
5A A5 STATUS CMD ADDR VALUE XOR
```

`XOR` is the XOR of the preceding six bytes.

Commands:

- `01` INFO -- response VALUE is protocol version (`0x21` = 2.1)
- `02` RECOVER -- I2C bus recovery
- `03` PROBE -- probe 7-bit ADDR
- `04` READ8 -- register read from ADDR/REG
- `05` WRITE8 -- write VALUE to ADDR/REG

Status values:

- `00` OK
- `01` NACK
- `02` TIMEOUT
- `03` BUSY (Hazard3 held the bus longer than the grant timeout)
- `04` BAD_COMMAND
- `05` BAD_FRAME

## Build

From an ESP-IDF shell:

```
idf.py set-target esp32
idf.py build
idf.py flash monitor
```

The example scans the bus, reads Touchwheel address `0x54` register `0x00`,
then writes/reads/restores register `0x0e` as a visible status-LED test.

## Board revision note

The included FPGA constraints use the ULX3S v20 mapping (v2.0.x/v3.0.x), where
ESP32 GPIO16/17 are routed to FPGA pins L1/N3. ULX3S v3.1.4 and later changed
the ESP32 pinout for WROVER compatibility; GPIO16/17 are not available there.
Those boards need the sideband remapped to available GPIOs such as 26/27 using
the matching board-revision constraints.
