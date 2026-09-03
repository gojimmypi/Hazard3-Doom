[ULX4M Schematics](https://github.com/intergalaktik/ulx4m/blob/ulx4m-ls/doc/schematics.pdf)
[4G_DDR3_AS4C256M16D3C](https://www.alliancememory.com/wp-content/uploads/AllianceMemory_4G_DDR3_AS4C256M16D3C_May2020_Rev1.1_Final.pdf)

Zadig files, is the installer running?

```
PS C:\Windows\system32> Get-Process installer_x64 -ErrorAction SilentlyContinue

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    408      20     5148      27588       0.45  NNNNN   1 installer_x64

```

Depending on if / what the NNNNN value is reported, stop the process:

```
Stop-Process -Id NNNNN -Force
```

Power cycle the respective device and try again.


##

| Source/revision                   | DDR3                        |                  |
| --------------------------------- | --------------------------- | ---------------- |
| Crowd Supply ULX4M-LD             |   `MT41K512M16HA-125`       |                  |
| Full Micron ordering number       | **`MT41K512M16HA-125:A`**   | 0 C to +95 C     |
| Alternate Micron ordering number  |   `MT41K512M16HA-125 AIT:A` | `-40 C to +95 C` |
| Current ULX4M-LD GitHub schematic | **`AS4C256M16D3`**          |                  |


```
8 Gbit DDR3L
512M x16
1.35 V
DDR3-1600 / 800 MHz clock
CL11
96-ball 9 x 14 mm TFBGA
same HA-125 speed/package family


DDR3 geometry probe:
  x16 interface
  8 banks
  1024 columns
  32768 rows detected
  capacity: 512 MiB
  probable device: AS4C256M16D3-class

DDR3 geometry probe:
  x16 interface
  8 banks
  1024 columns
  65536 rows detected
  capacity: 1024 MiB
  probable device: MT41K512M16-class
```

Check SW1 (both should normally be off):

```
$ ./bin/fujprog-v48-win64.exe  ./build/fpga_ulx4m_ld.bit
ULX2S / ULX3S JTAG programmer v4.8 (git 96ebb45 built Oct  7 2020 22:42:00)
Copyright (C) Marko Zec, EMARD, gojimmypi, kost and contributors
CABLE_HW_UNKNOWN failed
Cannot find JTAG cable.
```

Try the Tigard/ Update docs with this info:

```
$ ./bin/openFPGALoader.exe \
    -c tigard \
    ./build/fpga_ulx4m_ld.bit
Jtag frequency : requested 6.00MHz    -> real 6.00MHz
Open file: DONE
b3bdffff
Parse file: DONE
Enable configuration: DONE
SRAM erase: DONE
Loading: [=====================================             ] 73.41%
Loading: [==================================================] 100.00%

Done
Disable configuration: DONE
```