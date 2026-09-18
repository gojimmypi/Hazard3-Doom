APB adresni prostor periferija
==============================

Hazard3-Doom izlaže sporije SoC periferije preko 32-bitnog APB sabirničkog
prostora iza Hazard3 AHB-L sistemske sabirnice. CPU load/store pristupi u
području ``0x40000000`` prolaze kroz AHB-u-APB most, a zatim ih dekodira APB
splitter u ``third_party/Hazard3/example_soc/soc/example_soc.v``.

Adrese na ovoj stranici pripadaju Hazard3-Doom SoC integraciji. One nisu
arhitekturne RISC-V adrese i nisu fiksirane samim Hazard3 CPU-om.

APB prozori dekodera
--------------------

Trenutačni APB splitter izlaže šest slave blokova:

.. list-table::
   :header-rows: 1
   :widths: 20 20 20 40

   * - Periferija
     - CPU baza
     - Prozor dekodera
     - RTL / softversko sučelje
   * - RISC-V timer
     - ``0x40000000``
     - ``0x40000000-0x40003FFF``
     - ``hazard3_riscv_timer.v``
   * - UART
     - ``0x40004000``
     - ``0x40004000-0x40007FFF``
     - ``uart_mini`` / ``uart_regs.v``
   * - GPIO
     - ``0x40008000``
     - ``0x40008000-0x40008FFF``
     - ``apb_gpio.v``
   * - SAO I2C/GPIO
     - ``0x40009000``
     - ``0x40009000-0x40009FFF``
     - ``apb_sao_bridge.v``
   * - micro-SD SPI
     - ``0x4000A000``
     - ``0x4000A000-0x4000AFFF``
     - ``apb_sd_spi.v``
   * - HDMI/video
     - ``0x4000C000``
     - ``0x4000C000-0x4000FFFF``
     - ``doom/hazard3_video.h`` i HDMI APB blok

Prozori dekodera veći su od stvarno implementiranih skupova registara. Adresa
unutar dekodiranog prozora ne znači da na toj adresi postoji registar. Softver
treba koristiti samo dokumentirane offsete u nastavku.

Raspon ``0x4000B000-0x4000BFFF`` trenutačno nije dodijeljen nijednoj APB
periferiji.

Zajednički MMIO pristup
-----------------------

Samostalni primjeri koriste jednostavan volatile 32-bitni pristup:

.. code-block:: c

   #include <stdint.h>

   #define MMIO32(address) \
       (*(volatile uint32_t *)(uintptr_t)(address))

Zajedničke definicije primjera nalaze se u
``examples/common/hazard3_apb.h``. Jedan zajednički header smanjuje mogućnost da
se pojedini primjeri odvoje od stvarne RTL mape.

RISC-V timer - 0x40000000
-------------------------

Timer implementira 64-bitni ``mtime`` brojač i 64-bitni ``mtimecmp`` komparator
preko 32-bitnog APB-a. Hazard3-Doom mu daje tick od jedne mikrosekunde, pa
``mtime`` broji mikrosekunde dok hart radi. Brojač se zaustavlja dok je hart
zaustavljen debuggerom.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Adresa
     - Registar
     - Opis
   * - ``0x00``
     - ``0x40000000``
     - ``CTRL``
     - Bit 0 uključuje timer. Nakon reseta je uključen.
   * - ``0x08``
     - ``0x40000008``
     - ``MTIME``
     - ``mtime[31:0]``.
   * - ``0x0C``
     - ``0x4000000C``
     - ``MTIMEH``
     - ``mtime[63:32]``.
   * - ``0x10``
     - ``0x40000010``
     - ``MTIMECMP``
     - ``mtimecmp[31:0]``.
   * - ``0x14``
     - ``0x40000014``
     - ``MTIMECMPH``
     - ``mtimecmp[63:32]``.

Za koherentno 64-bitno čitanje provjerite da se gornja riječ nije promijenila
oko čitanja donje riječi:

.. code-block:: c

   static uint64_t timer_read_us(void)
   {
       uint32_t hi1;
       uint32_t lo;
       uint32_t hi2;

       do {
           hi1 = MMIO32(0x4000000cu);
           lo  = MMIO32(0x40000008u);
           hi2 = MMIO32(0x4000000cu);
       } while (hi1 != hi2);

       return ((uint64_t)hi1 << 32) | lo;
   }

Pri izmjeni ``mtimecmp`` najprije upišite ``0xFFFFFFFF`` u gornju riječ ako bi
privremeno compare podudaranje bilo problematično, zatim donju riječ i na kraju
konačnu gornju riječ.

UART - 0x40004000
-----------------

UART je Hazard3-libfpga ``uart_mini`` periferija. Sadrži male TX/RX FIFO-e,
frakcijski djelitelj, opcionalne prekide, CTS i loopback.

.. list-table::
   :header-rows: 1
   :widths: 18 20 20 42

   * - Offset
     - Adresa
     - Registar
     - Važna polja
   * - ``0x00``
     - ``0x40004000``
     - ``CSR``
     - bit 0 EN, bit 1 BUSY, bit 2 TXIE, bit 3 RXIE, bit 4 CTSEN, bit 8 LOOPBACK.
   * - ``0x04``
     - ``0x40004004``
     - ``DIV``
     - bitovi 13:4 cijeli dio, bitovi 3:0 frakcijski dio djelitelja.
   * - ``0x08``
     - ``0x40004008``
     - ``FSTAT``
     - TX/RX nivo, full/empty i sticky error status.
   * - ``0x0C``
     - ``0x4000400C``
     - ``TX``
     - Upis bitova 7:0 dodaje jedan bajt u TX FIFO.
   * - ``0x10``
     - ``0x40004010``
     - ``RX``
     - Čitanje bitova 7:0 vraća i uklanja jedan bajt iz RX FIFO-a.

``FSTAT`` polja su:

.. code-block:: text

    7:0   TXLEVEL
    8     TXFULL
    9     TXEMPTY
   10     TXOVER       sticky, upis 1 briše
   11     TXUNDER      sticky, upis 1 briše
   23:16  RXLEVEL
   24     RXFULL
   25     RXEMPTY
   26     RXOVER       sticky, upis 1 briše
   27     RXUNDER      sticky, upis 1 briše

Uz normalni 8x oversampling, djelitelj je fixed-point vrijednost s četiri
frakcijska bita:

.. code-block:: text

   baud ~= sys_clk / (8 * DIV)
   DIV_register = round((sys_clk * 16) / (baud * 8))

Trenutačno generirani ``uart_regs.v`` pri čitanju ``DIV`` vraća reset vrijednost,
a ne programirani djelitelj. Softver zato ne treba koristiti ``DIV`` readback
za provjeru baud-rate upisa.

Minimalni blokirajući TX:

.. code-block:: c

   #define UART_FSTAT   MMIO32(0x40004008u)
   #define UART_TX      MMIO32(0x4000400cu)
   #define UART_TXFULL  (1u << 8)

   static void uart_putc(char c)
   {
       while ((UART_FSTAT & UART_TXFULL) != 0u) {
       }
       UART_TX = (uint8_t)c;
   }

GPIO - 0x40008000
-----------------

GPIO blok trenutačno ima jedan 8-bitni izlazni registar.

.. list-table::
   :header-rows: 1
   :widths: 18 20 20 42

   * - Offset
     - Adresa
     - Registar
     - Opis
   * - ``0x00``
     - ``0x40008000``
     - ``GPIO_OUT``
     - Bitovi 7:0 upravljaju ``gpio_out[7:0]``; čitanje vraća spremljenu izlaznu vrijednost.

Zadržava se samo donji bajt upisa:

.. code-block:: c

   MMIO32(0x40008000u) = 0x55u;

Wrapper pločice određuje što pojedini ``gpio_out`` bit stvarno upravlja na
danoj FPGA ciljnoj pločici.

SAO I2C/GPIO - 0x40009000
-------------------------

SAO periferija kombinira softverski upravljani I2C engine, dva SAO GPIO-a,
sirovi status linija, identifikacijske registre te status ESP32/Hazard3
vlasništva.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Adresa
     - Registar
     - Opis
   * - ``0x00``
     - ``0x40009000``
     - ``COMMAND``
     - Upis niskorazinske I2C naredbe.
   * - ``0x04``
     - ``0x40009004``
     - ``STATUS``
     - I2C rezultat, linije, GPIO i status vlasništva.
   * - ``0x08``
     - ``0x40009008``
     - ``TXDATA``
     - Bajt za WRITE naredbu.
   * - ``0x0C``
     - ``0x4000900C``
     - ``RXDATA``
     - Zadnji primljeni bajt.
   * - ``0x10``
     - ``0x40009010``
     - ``CLKDIV``
     - 16-bitni I2C timing djelitelj.
   * - ``0x14``
     - ``0x40009014``
     - ``TIMEOUT``
     - Clock-stretch timeout u ciklusima sistemskog takta.
   * - ``0x18``
     - ``0x40009018``
     - ``GPIO``
     - SAO GPIO izlaz/OE i sinkronizirano stanje ulaza.
   * - ``0x1C``
     - ``0x4000901C``
     - ``LINES``
     - Sirovo sinkronizirano stanje SDA, SCL, GPIO1 i GPIO2.
   * - ``0x20``
     - ``0x40009020``
     - ``ID``
     - ``0x53414F31`` (ASCII ``SAO1``).
   * - ``0x24``
     - ``0x40009024``
     - ``VERSION``
     - Trenutačna verzija ``0x00020100`` = 2.1.0.
   * - ``0x28``
     - ``0x40009028``
     - ``OWNER``
     - bit 0 ESP owner, bit 1 ESP request.

Vrijednosti ``COMMAND``:

.. code-block:: text

   1 START
   2 STOP
   3 WRITE
   4 READ_ACK
   5 READ_NACK
   6 RECOVER
   7 ABORT

Bitovi ``STATUS``:

.. code-block:: text

    0 BUSY
    1 DONE
    2 ACK
    3 NACK
    4 TIMEOUT
    5 REJECTED
    6 BUS_ACTIVE
    7 SDA
    8 SCL
    9 GPIO1
   10 GPIO2
   11 RECOVERED
   12 ESP_OWNER
   13 ESP_REQUEST

``DONE``, ``TIMEOUT``, ``REJECTED`` i ``RECOVERED`` su sticky. Upis jedinice u
odgovarajući ``STATUS`` bit briše taj sticky status.

Reset I2C djelitelj odabire se iz sistemskog takta za približno 100 kHz, a reset
clock-stretch timeout je 10 ms.

micro-SD SPI - 0x4000A000
-------------------------

micro-SD periferija je mali softverski upravljani SPI mode-0 master, MSB first,
namjerno bez FIFO-a i DMA-a.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Adresa
     - Registar
     - Opis
   * - ``0x00``
     - ``0x4000A000``
     - ``CTRL``
     - bit 0 je ``CS_n``; 1 deselektira karticu.
   * - ``0x04``
     - ``0x4000A004``
     - ``CLKDIV``
     - 16-bitni djelitelj poluperiode SPI takta.
   * - ``0x08``
     - ``0x4000A008``
     - ``DATA``
     - Upis donjeg bajta pokreće transfer; čitanje vraća primljeni bajt.
   * - ``0x0C``
     - ``0x4000A00C``
     - ``STATUS``
     - bit 0 BUSY.

SPI takt je:

.. code-block:: text

   SCLK = sys_clk / (2 * (CLKDIV + 1))

Na 50 MHz reset vrijednost 124 daje 200 kHz za inicijalizaciju. APB prozor
postoji i kada je ``SD_SPI_ENABLE`` false; tada onemogućena integracija vraća
nule i ostavlja SD izlaze neaktivnima.

Transfer jednog bajta:

.. code-block:: c

   static uint8_t sd_spi_xfer(uint8_t tx)
   {
       while ((MMIO32(0x4000a00cu) & 1u) != 0u) {
       }

       MMIO32(0x4000a008u) = tx;

       while ((MMIO32(0x4000a00cu) & 1u) != 0u) {
       }

       return (uint8_t)MMIO32(0x4000a008u);
   }

Ne pokrećite proizvoljne transfere dok druga softverska komponenta koristi
karticu ili tijekom provjere zajedničkog ULX3S ESP32/FPGA SD vlasništva.

HDMI/video - 0x4000C000
-----------------------

Video APB blok upravlja HDMI/video putem i izvještava njegovo stanje.
Framebuffer pikseli nisu u ovom APB prozoru; framebufferi se nalaze u video
rezervaciji vanjske memorije opisanoj u :doc:`../architecture/memory-map`.

.. list-table::
   :header-rows: 1
   :widths: 18 20 24 38

   * - Offset
     - Adresa
     - Registar
     - Opis
   * - ``0x00``
     - ``0x4000C000``
     - ``STATUS``
     - Video mode, framebuffer, DMA i capability status.
   * - ``0x04``
     - ``0x4000C004``
     - ``CONTROL``
     - Indexed/buffer/present/direct/resolution kontrola.
   * - ``0x08``
     - ``0x4000C008``
     - ``PALETTE_INDEX``
     - Odabir palette unosa.
   * - ``0x0C``
     - ``0x4000C00C``
     - ``PALETTE_DATA``
     - Podatak palette.
   * - ``0x10``
     - ``0x4000C010``
     - ``FRAME_COUNT``
     - Brojač frameova.
   * - ``0x14``
     - ``0x4000C014``
     - ``DMA_CYCLES``
     - Dijagnostički DMA cycle brojač.
   * - ``0x18``
     - ``0x4000C018``
     - ``PRESENT_COUNT``
     - Broj dovršenih present operacija.
   * - ``0x1C``
     - ``0x4000C01C``
     - ``FPGA_BUILD_ID``
     - Identifikator pločice/FPGA builda.
   * - ``0x20``
     - ``0x4000C020``
     - ``DDR_STATUS``
     - Status kontrolera/adaptera vanjske memorije.
   * - ``0x24``
     - ``0x4000C024``
     - ``DDR_CORE_BUILD_ID``
     - Identifikator jezgre vanjske memorije.
   * - ``0x28``
     - ``0x4000C028``
     - ``DDR_ADAPTER_BUILD_ID``
     - Identifikator Hazard3 memorijskog adaptera.
   * - ``0x2C``
     - ``0x4000C02C``
     - ``DIRECT_ADDRESS``
     - Adresa/kontrola izravnog video upisa.
   * - ``0x30``
     - ``0x4000C030``
     - ``DIRECT_DATA``
     - Podatak izravnog video upisa.

Važni ``STATUS`` bitovi:

.. code-block:: text

    0 FRONT_BUFFER
    1 PRESENT_PENDING
    2 INDEXED
    3 VBLANK
    4 SDRAM_READY
    5 FRAME_VALID
    6 INTERNAL_BUFFER
    7 DMA_BUSY
    8 SWAP_PENDING
    9 DIRECT_SUPPORTED
   10 DIRECT_WRITE_BUSY
   11 HIGH_RES_SUPPORTED
   12 HIGH_RES_ACTIVE
   13 GUI_RES_SUPPORTED
   14 GUI_RES_ACTIVE

``CONTROL`` trenutačno koristi:

.. code-block:: text

   0 INDEXED
   1 BUFFER1
   2 PRESENT
   3 DIRECT
   4 HIGH_RES
   5 GUI_RES

``doom/hazard3_video.h`` je izvor istine za softverski vidljive video bitove i
povezani raspored framebuffer memorije.

Samostalni APB primjeri
-----------------------

U ``examples/`` su dodana dva bare-metal primjera. Ne linkaju se s rezidentnim
monitorom niti s Doomom.

``examples/apb-register-dump``
   Inicijalizira UART i ispisuje nedestruktivni snapshot svih šest APB
   periferija. Ne pokreće SAO ili SD transakcije, ne mijenja GPIO izlaze i ne
   mijenja video stanje.

``examples/apb-uart-timer``
   Aktivno demonstrira timer i UART. Uključuje timer, čita ``mtime``, čeka
   milijun mikrosekundnih tickova, ispisuje proteklo vrijeme i zatim radi UART
   echo sve
   dok ne primi ``q`` ili ``Q``.

Oba primjera dijele definicije registara i minimalni startup u
``examples/common/``. Svaki se i dalje može izgraditi zasebno.

Izgradnja primjera
^^^^^^^^^^^^^^^^^^

Iz Bash-a ili WSL-a u korijenu repozitorija:

.. code-block:: bash

   make -C examples

Ili samo jedan primjer:

.. code-block:: bash

   make -C examples/apb-register-dump
   make -C examples/apb-uart-timer

Zadana izgradnja pretpostavlja Hazard3 sistemski takt 50 MHz i UART 115200
baud. Za cilj od 40 MHz, poput normalnih ULX4M-LD ili ULX3S 12F profila:

.. code-block:: bash

   make -C examples SYS_CLK_HZ=40000000

Makefileovi slijede iste konvencije za toolchain kao glavni projekt. Prvo
postuju ``TOOLCHAIN_PREFIX``, prihvacaju i ``CROSS_COMPILE``, prepoznaju staru
lokaciju ``/opt/riscv/bin/riscv32-unknown-elf-`` te inace koriste
``riscv-none-elf-*`` iz ``PATH``. Uobicajeni puni instalacijski postupak stavlja
xPack kompajler u ``PATH``. Lokalna instalacija pod ``bin/riscv-gcc`` ostaje kao
kompatibilni fallback. Windows ``.exe`` alati otkrivaju se automatski kada je
njihov put vidljiv iz Bash/WSL-a; ``EXEEXT=.exe`` moze se postaviti i rucno.

Svaki primjer proizvodi ``.elf``, ``.bin``, ``.map`` i ``.lst`` u svom
``build/`` direktoriju. Generirani output nije namijenjen commitiranju.

Pokretanje preko OpenOCD/GDB
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Primjeri su linkani na ``0x20100000``, normalni početak Doom executable prozora.
Time ostaju izvan rezidentnog monitora i rade s 32 MiB i 64 MiB softverskim
memorijskim profilima.

Kontroler vanjske memorije mora već biti inicijaliziran. Najjednostavnije je
pokrenuti normalni rezidentni monitor, potvrditi da je vanjska memorija spremna,
pokrenuti normalnu Hazard3 OpenOCD sesiju i zatim spojiti GDB bez reseta FPGA-a
ili harta.

Za ``apb-register-dump``:

.. code-block:: text

   riscv-none-elf-gdb examples/apb-register-dump/build/apb-register-dump.elf
   (gdb) target extended-remote :3333
   (gdb) monitor halt
   (gdb) load
   (gdb) set $pc = _start
   (gdb) continue

Za drugi ELF koristite isti postupak. Budući da primjer zamjenjuje normalni
izvršni sadržaj na ``0x20100000``, prije ponovnog pokretanja Dooma ponovno ga
učitajte.

.. important::

   Nemojte napraviti target reset neposredno prije učitavanja primjera. Reset
   može vratiti sustav u stanje prije inicijalizacije SDRAM/DDR memorije, dok se
   ovi ELF-ovi izvršavaju upravo iz vanjske memorije.

Izvorne datoteke koje su izvor istine
-------------------------------------

Kod promjene SoC-a provjerite ovu stranicu i
``examples/common/hazard3_apb.h`` prema implementaciji:

* ``third_party/Hazard3/example_soc/soc/example_soc.v`` - APB dekoder.
* ``third_party/Hazard3/example_soc/soc/peri/hazard3_riscv_timer.v`` - timer.
* ``third_party/Hazard3/example_soc/libfpga/peris/uart/uart_regs.v`` - UART registri.
* ``third_party/Hazard3/example_soc/soc/apb_gpio.v`` - GPIO.
* ``third_party/Hazard3/example_soc/soc/apb_sao_bridge.v`` - SAO.
* ``third_party/Hazard3/example_soc/soc/apb_sd_spi.v`` - SD SPI.
* ``doom/hazard3_video.h`` - softverski vidljive video definicije.
