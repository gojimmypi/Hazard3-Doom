| SW1 upper / lower | CFG_MD[3:0] | GateMate configuration |
| ----------------  | ----------- | ---------------------- | 
| ON / ON           | 1100 (0xC)  | JTAG — the mode used throughout development
| OFF / OFF         | 0000 (0x0)  | SPI-active — cold boot from onboard flash
| ON / OFF          | 0100 (0x4)  | SPI-passive — not for flash cold boot
| OFF / ON          | 1000 (0x8)  | Unsupported
