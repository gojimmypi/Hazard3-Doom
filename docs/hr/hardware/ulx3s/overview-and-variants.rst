Pregled i varijante pločice
===========================

Što je ULX3S
------------

ULX3S je samostalna open-hardware ECP5 FPGA razvojna pločica za obrazovanje,
istraživanje i ugrađene FPGA projekte. Lattice ECP5 kombinira s vanjskim SDR
SDRAM-om i dovoljno I/O-a da korisni sustavi mogu raditi bez velike carrier
pločice.

Tipični resursi uključuju ECP5 u 381-ball kućištu, 16-bitni SDR SDRAM, SPI
flash, dva micro-USB priključka, FT231X na ``US1``, GPDI video, micro-SD, dva
40-pinska GPIO konektora, ESP32, tipke i LED-ove, audio, priključak za zaslon,
ADC, RTC i 25 MHz oscilator.

Hazard3-Doom ne koristi svaki periferni sklop. Projekt je usmjeren na Hazard3,
vanjski SDRAM, GPDI video, monitor/UART/JTAG, programiranje FPGA-a, micro-SD boot
i odabrana dijeljena FPGA/ESP32 sučelja.

FPGA gustoća nije PCB revizija
------------------------------

ULX3S postoji s ECP5 gustoćama 12F, 25F, 45F i 85F, dok se PCB revizija razvija
neovisno.

.. list-table:: Dokumentirani Hazard3-Doom ciljevi
   :header-rows: 1

   * - Cilj
     - Memorijski profil
     - Vanjska memorija
     - Hazard3 takt
   * - ULX3S 85F
     - ``64m``
     - 16-bitni SDR SDRAM, nativni projektni kontroler
     - 50 MHz
   * - ULX3S 12F
     - zadano ``32m``; ``64m`` opcionalno kada pločica odgovara
     - 16-bitni SDR SDRAM, nativni projektni kontroler
     - 40 MHz

Postojanje 25F ili 45F pločice ne čini je automatski potpunim Hazard3-Doom
ciljem. Potrebni su kvalificiran synthesis/routing put, odgovarajuća ograničenja
i hardversko testiranje.

Disciplina revizija
-------------------

Za hardverski rad zabilježite barem PCB reviziju, FPGA gustoću/kućište, SDRAM
populaciju i LPF koji build stvarno koristi. Shema druge revizije može pomoći u
učenju, ali nije automatski točan pinout svake ULX3S pločice.
