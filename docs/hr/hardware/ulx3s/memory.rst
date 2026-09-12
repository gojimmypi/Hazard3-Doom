Vanjska memorija: SDR SDRAM
===========================

ULX3S ima vanjski 16-bitni sinkroni SDR SDRAM. Hazard3-Doom ga koristi kao
glavnu radnu memoriju za učitanu aplikaciju, heap, IWAD podatke i druge velike
objekte koji ne stanu u ECP5 EBR.

Vidi i :doc:`../../architecture/hazard3/memory-and-bus`.

Put kontrolera
--------------

.. code-block:: text

   Hazard3 -> AHB5 -> ahb_sdram.v -> ulx3s_sdram_controller.v -> 16-bitni SDR SDRAM

Kontroler upravlja activate/precharge sekvencama, CAS vremenom, refreshom,
byte-maskama i fizičkim sučeljem. Adapter prema potrebi koordinira i CPU/video
pristupe.

Memorijski profili
------------------

ULX3S 85F trenutačno koristi ``64m`` pri 50 MHz. ULX3S 12F zadano koristi
``32m`` pri 40 MHz i može odabrati ``64m`` kada su stvarna SDRAM populacija i
cijela konfiguracija prikladne.

Softverski profil ne zamjenjuje identifikaciju fizičke memorije. Upstream ULX3S
materijali opisuju više kapaciteta SDRAM-a. Kada je kapacitet bitan, provjerite
oznaku čipa, odgovarajuću shemu/BOM i alias testove memorije.

EBR nije SDRAM
--------------

EBR je interna FPGA memorija i može sadržavati rezidentni monitor preloaded u
bitstreamu. SDRAM je vanjski čip koji zahtijeva inicijalizaciju i refresh.
Monitor zato može prvo krenuti iz EBR-a, inicijalizirati SDRAM, a zatim u njega
učitati Doom i WAD.

Uspješna FPGA konfiguracija sama ne dokazuje ispravan SDRAM; monitorovi memory
testovi i Doom smoke testovi dio su hardverske kvalifikacije.
