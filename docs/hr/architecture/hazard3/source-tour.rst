Vođeni obilazak izvornog koda
=============================

Ova je stranica karta čitanja za studente koji žele prijeći s blok dijagrama na
stvarni RTL. Sve poveznice projekta u nastavku prikvačene su na commit
|hazard3_commit|, pa se sadržaj redaka neće tiho
promijeniti kada grana napreduje.

Preporučeni redoslijed čitanja
------------------------------

1. Najprije konfiguracija
~~~~~~~~~~~~~~~~~~~~~~~~~

Počnite s
:hazard3-src:`hazard3_config.vh <hdl/hazard3_config.vh>` i
:hazard3-src:`hazard3_config_inst.vh <hdl/hazard3_config_inst.vh>`.

Pitanja na koja treba odgovoriti prije čitanja datapatha:

* Koja ISA proširenja ova snimka može sintetizirati?
* Koje su značajke zadano uključene ili isključene?
* Koji parametri utječu na arhitekturu, a koji na performanse/površinu?
* Kako se parametri propagiraju kroz ugniježđene instance modula?

Zatim otvorite
:hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>` i usporedite vrijednosti
projekta s tim generičkim zadanim vrijednostima.

2. Pronađite CPU u SoC-u
~~~~~~~~~~~~~~~~~~~~~~~~

Otvorite
:hazard3-src:`example_soc.v <example_soc/soc/example_soc.v>` i pronađite
``hazard3_cpu_1port``. Zabilježite fiksne sistemske odluke oko instance: reset
vektor, podršku za trap CSR, omogućavanje debugiranja, broj IRQ-ova, UART prekid
i timerski prekid.

Zatim otvorite
:hazard3-src:`hazard3_cpu_1port.v <hdl/hazard3_cpu_1port.v>`. Prepoznajte tri skupine
signala:

* jedan AHB5 master prema SoC-u;
* interni promet instrukcija/podataka povezan s ``hazard3_core``; i
* upravljačke/signale sistemske sabirnice debuggera.

Omotač je dobar primjer prilagodbe sučelja: arhitekturna jezgra ne mora u sebi
sadržavati politiku dijeljenja jedne vanjske sabirnice.

3. Prođite kroz cjevovod
~~~~~~~~~~~~~~~~~~~~~~~~

Otvorite :hazard3-src:`hazard3_core.v <hdl/hazard3_core.v>` i potražite naslove stupnjeva.
Pratite:

* ulaze F-stupnja iz front enda;
* signale dekodiranja/izvršavanja X-stupnja;
* skup registara cjevovoda X-prema-M;
* signale writebacka i zastoja M-stupnja; i
* putove preusmjeravanja/trapa/debuga natrag prema dohvatu.

Ne pokušavajte pri prvom prolazu razumjeti svaku žicu. Pratite jednu jednostavnu
instrukciju poput ``addi``, zatim load, pa branch.

4. Proučite dohvat instrukcija
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Otvorite
:hazard3-src:`hazard3_frontend.v <hdl/hazard3_frontend.v>` i
:hazard3-src:`hazard3_instr_decompress.v <hdl/hazard3_instr_decompress.v>`.

Potražite:

* prefetch FIFO od dvije riječi;
* međuspremanje poluriječi instrukcija;
* odabir komprimirane nasuprot 32-bitnoj instrukciji;
* preusmjeravanja fetch PC-a;
* priključne točke za provjeru PMP dopuštenja izvršavanja; i
* ubrizgavanje debug instrukcija.

Vježba: nacrtajte koje su poluriječi potrebne kada 32-bitna instrukcija počinje
na adresi koja završava s ``...2`` dok je ``C`` omogućeno.

5. Dekodirajte nekoliko instrukcija
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Otvorite :hazard3-src:`hazard3_decode.v <hdl/hazard3_decode.v>`. Odaberite po jednu
instrukciju iz svake klase:

* ``add`` - osnovni cjelobrojni ALU;
* ``lw`` - load/store put;
* ``beq`` - branch put;
* ``mul`` - M proširenje;
* Zba scaled-add instrukciju; i
* kodiranje atomske instrukcije dok je ``EXTENSION_A=0``.

Posljednji primjer posebno je koristan: konfiguracijski parametri sudjeluju u
provjeri legalnosti, pa konfiguracija sinteze postaje vidljiva softveru kroz
trap ilegalne instrukcije.

6. Pratite ALU i M proširenje
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Relevantni aritmetički izvori uključuju:

* :hazard3-src:`hazard3_alu.v <hdl/arith/hazard3_alu.v>`
* :hazard3-src:`hazard3_mul_fast.v <hdl/arith/hazard3_mul_fast.v>`
* :hazard3-src:`hazard3_muldiv_seq.v <hdl/arith/hazard3_muldiv_seq.v>`

Usporedite brzi množitelj s iterativnom jedinicom i povežite ih s
``MUL_FAST``, ``MUL_FASTER``, ``MULH_FAST`` i ``MULDIV_UNROLL``. To je
praktična FPGA arhitekturna vježba u zamjeni troška LUT/DSP/usmjeravanja za
latenciju.

7. Čitajte CSR i stanje trapa
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Otvorite :hazard3-src:`hazard3_csr.v <hdl/hazard3_csr.v>`. Ovim redom tražite nazive:

.. code-block:: text

   MSTATUS
   MTVEC
   MEPC
   MCAUSE
   MIE
   MIP
   MCYCLE
   MINSTRET
   DCSR

Primijetite da je prisutnost CSR registara parametrizirana. Zatim se vratite u
``hazard3_core.v`` i pronađite gdje ulaz u trap i povratak upravljaju
preusmjeravanjem cjevovoda.

8. Čitajte debug stack
~~~~~~~~~~~~~~~~~~~~~~

Koristite ovaj redoslijed:

* :hazard3-src:`hazard3_dm.v <hdl/debug/dm/hazard3_dm.v>` - stanje Debug Modulea,
  apstraktne naredbe, program buffer i pristup sistemskoj sabirnici.
* :hazard3-src:`hazard3_ecp5_jtag_dtm.v <hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>` -
  DMI transport kroz ECP5 JTAGG.
* ``hazard3_frontend.v`` i ``hazard3_core.v`` - ponašanje halt/debug načina na
  strani jezgre i ubrizganih instrukcija.

Zatim usporedite hardverski tijek s naredbama u
:doc:`../../user-guide/jtag-debugging`.

9. Prijeđite granicu CPU/SoC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Tek nakon razumijevanja CPU omotača proučite dodatke SoC-a specifične za
projekt:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Prikvačeni izvor
     - Što naučiti
   * - :hazard3-src:`ahb_sdram.v <example_soc/soc/ahb_sdram.v>`
     - Kako se uobičajeni AHB CPU promet prilagođava ponašanju vanjskog SDRAM-a.
   * - :hazard3-src:`ulx3s_sdram_controller.v <example_soc/soc/ulx3s_sdram_controller.v>`
     - Vremenski odnosi SDR SDRAM naredbi/podataka usmjereni na pločicu.
   * - :hazard3-src:`apb_sd_spi.v <example_soc/soc/apb_sd_spi.v>`
     - Kompaktna APB periferija i SPI automat stanja.
   * - :hazard3-src:`apb_sao_bridge.v <example_soc/soc/apb_sao_bridge.v>`
     - Memorijski mapirano projektno upravljanje oko SAO podsustava.
   * - :hazard3-src:`sao_shared_controller.v <example_soc/soc/sao_shared_controller.v>`
     - Politika vlasništva/arbitraže za zajedničke resurse pločice.
   * - :hazard3-src:`sao_esp32_uart_bridge.v <example_soc/soc/sao_esp32_uart_bridge.v>`
     - Projektna sporedna komunikacija s ESP32.

Ovaj redoslijed pomaže spriječiti čestu pogrešku pri čitanju izvora:
pretpostavku da je svaki modul pod ``example_soc`` dio Hazard3 procesora.

Predložena laboratorijska pitanja
---------------------------------

Cjevovod
   Koje obrasce ovisnosti rješava bypassing, a koji prisiljavaju X da čeka M?

Komprimirani ISA
   Zašto sabirnica može dohvaćati poravnate 32-bitne riječi dok je
   arhitekturni PC poravnat samo na 16 bita?

Konfiguracija
   Koji bi se softverski simptom pojavio kada bi binarna datoteka sadržavala
   instrukciju ``amo*`` u ovom buildu s ``EXTENSION_A=0``?

Prekidi
   Pratite UART IRQ žicu od UART periferije do ``hazard3_cpu_1port``, zatim do
   ``mip``/odabira trapa.

Debug
   Koje operacije debuggera zahtijevaju da hart izvršava ubrizgane instrukcije,
   a koje mogu koristiti pristup sistemskoj sabirnici?

Integracija
   Odaberite SDRAM adresu iz :doc:`../memory-map` i pratite kako uobičajeni
   CPU load/store postaje vanjska SDRAM transakcija.

Usporedba s upstreamom
----------------------

Nakon proučavanja prikvačenih datoteka otvorite
`trenutačni upstream stable <https://github.com/Wren6991/Hazard3/tree/stable>`_ i usporedite iste module. Promjene
tamo smatrajte evolucijom upstream procesora dok projekt Hazard3-Doom ne
ažurira svoj prikvačeni submodul. Ta navika održava proučavanje izvora
reproducibilnim.
