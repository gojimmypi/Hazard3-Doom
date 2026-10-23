Hardverske bilješke za ULX5M-GS V005
====================================

Ove bilješke odnose se na Intergalaktik ULX5M-GS V005 s FPGA sklopom
Cologne Chip GateMate CCGM1A1. Dokumentiraju električna ograničenja i
hardverska opažanja važna za razvoj porta Hazard3-Doom. Ne zamjenjuju shemu
pločice ni podatkovni list FPGA-a. Prije primjene na drugi primjerak
provjerite reviziju stvarno sastavljene pločice.

.. warning:: Napon istočne banke prelazi dopuštenu granicu GateMatea

   Proizvođač pločice ULX5M-GS usmeno je potvrdio da ispitivana pločica V005,
   napajana putem USB-a, koristi **3,3 V na GateMate banci EA**. To je podatak
   koji je dao proizvođač pločice, a ne neovisno mjerenje VDD_EA niti
   odobrenje proizvođača FPGA sklopa.

   Cologne Chip DS1001 (rujan 2026.), tablica 4.5, navodi **2,7 V** kao
   najveći radni VDDIO za jednostruke GPIO signale. Tablica 4.1 navodi
   **2,75 V** kao apsolutnu najveću granicu VDDIO. Napajanje VDD_EA od 3,3 V
   prema tome prelazi obje granice. Uspješan rad GPIO-a ili USB-a ne
   potvrđuje usklađenost sa specifikacijom, kao što ni očekivanje proizvođača
   pločice da će raditi ne mijenja ograničenja FPGA-a. Pouzdanost i vijek
   trajanja pri 3,3 V ovdje nisu potvrđeni.

   Nemojte priključivati dodatne 3,3 V izlazne sklopove uz pretpostavku da je
   FPGA tolerantan na 3,3 V. Nemojte mijenjati mostiće napajanja ili postavke
   regulatora bez provjere sheme V005 i svih periferija na banci EA.
   Pretvarač razina na signalima sam po sebi ne rješava napajanje **VDD_EA**
   koje prelazi dopuštenu granicu.

GPIO naponske domene i dokazi
-----------------------------

Nemojte pretpostaviti da sve ULX5M GPIO banke imaju isti napon napajanja.
README repozitorija pločice navodi zadani GPIO napon od 1,8 V, no ta opća
izjava ne utvrđuje napon svake banke na konkretnoj ispitivanoj V005 pločici.

.. list-table:: Opaženi naponi ULX5M-GS V005 (listopad 2026.)
   :header-rows: 1
   :widths: 16 16 38 30

   * - Napajanje ili sučelje
     - Prijavljeni napon
     - Dokaz
     - Ograničenje zaključka
   * - ``VDD_EA`` (istočna banka EA)
     - 3,3 V
     - Usmena potvrda proizvođača za pločicu napajanu putem USB-a
     - Nije neovisno izmjeren na VDD_EA; prelazi granice DS1001
   * - ``VDD_EB`` (istočna banka EB)
     - Oko 1,8 V
     - Prijavljeno mjerenje multimetrom na ispitivanoj pločici
     - Odvojeno napajanje od EA; ne vrijedi nužno za svaku pločicu
   * - ``VDD_WA`` (konfiguracijska/JTAG banka)
     - 1,8 V na shemi V005
     - JTAG shema povezuje ``VDD_WA`` s ``+1V8``; na JTAG pinskim signalima
       načina rada opaženo je oko 1,8 V
     - Tigard JTAG radio je s 1,8 V logikom; napajanje samog FPGA priključka
       nije izravno mjereno
   * - Ostale GPIO banke
     - Ovdje nije utvrđeno
     - Provjeriti shemu revizije i ugrađene regulatore
     - Ne zaključivati 1,8 V ili 3,3 V samo prema oznakama konektora

DS1001 za jednostruke ulaze navodi raspon od ``-0,4 V`` do
``VDDIO + 0,4 V`` (tablica 4.5). Na banci napajanoj s 1,8 V izravni ulaz
od 3,3 V izlazi iz tog raspona. Prije spajanja vanjske logike provjerite
stvarni napon napajanja i primijenite odgovarajuće sučelje. Za periferije
od 3,3 V pogledajte Cologne Chip vodič UG1003 za prilagodbu razina; primjeri
pretpostavljaju da je napajanje GateMatea unutar propisanih granica.

USB-C priključak
----------------

Eksperimentalna implementacija USB uređaja koristi sljedeće EA pinove:

.. list-table:: USB pinovi u portu ULX5M-GS
   :header-rows: 1
   :widths: 24 26 50

   * - Funkcija
     - GateMate signal
     - Napomena
   * - USB D+
     - ``IO_EA_A1``
     - Prijavljeno napajanje EA je 3,3 V; iz toga ne slijedi točan napon
       na D+ vodu
   * - USB D-
     - ``IO_EA_B1``
     - Dijeli banku EA i njen VDDIO
   * - Upravljanje USB priključenjem
     - ``IO_EA_A2``
     - U trenutnoj USB probi upravlja pull-up otpornikom

Oscilator od 25 MHz na pločici referencija je eksperimentalnom USB PLL-u.
Jedna ranija proba proizvodila je približno 47,9167 MHz za nominalni
USB takt od 48 MHz. Konfiguracija PLL-a, postignuti Fmax nakon usmjeravanja,
točnost USB takta i integritet signala zasebna su pitanja: prolaz vremenske
analize ne dokazuje usklađenost USB signala ni pouzdanu enumeraciju.

U listopadu 2026. USB proba učitana u FPGA SRAM preko JTAG-a uspješno se
enumerirala u Windowsu. Kasniji razvoj endpointa nula sa SERV procesorom
također se enumerirao, ali ponavljani zahtjevi za USB deskriptorima ponekad
su zakazali nakon prethodno uspješnih prijenosa. Uzrok nije pouzdano
povezan sa SERV jezgrom, USB RTL-om, timingom ni naponima pločice. Takvi
povremeni kvarovi ne dokazuju ni da je VDD_EA od 3,3 V siguran, ni da
je on uzrok problema. Pogledajte :doc:`../../user-guide/bootloader`
za ranije probe ispitane na hardveru i njihova ograničenja.

JTAG i konfiguracija
--------------------

Shema V005 vodi GateMate JTAG signale preko Raspberry Pi 40-pinskog
konektora (GPIO12/16/20/21; fizički pinovi 32/36/38/40), sa serijskim
otpornicima od 200 oma. Konfiguracijska/JTAG banka ``WA`` na shemi ima
napajanje od 1,8 V. Tigard s odvojenim napajanjem konfiguriran je za
1,8 V I/O; ``VTGT`` ostavite odspojen i spojite zajednički GND.

.. figure:: ../../images/ulx5m-gs-jtag.png
   :alt: ULX5M-GS V005 konfiguracijska i JTAG shema s napajanjem od 1,8 V

   Izvadak sheme konfiguracije/JTAG-a V005. ``VDD_WA`` spojen je na
   ``+1V8``; ``JTAG_TCK``, ``JTAG_TMS``, ``JTAG_TDI`` i ``JTAG_TDO``
   odvojeni su od EA pinova za USB.

Pločica ima i šest JTAG kontaktnih pločica na prednjoj strani. Odgovarajući
konektor nije pouzdano identificiran; ne pretpostavljajte standardni razmak
od 0,1 inča ni SOP/SC70 otisak samo prema fotografijama. Prije lemljenja
adaptera provjerite točne dimenzije, redoslijed pinova, mehaničko
učvršćenje i GND. Pogledajte :doc:`../../user-guide/bootloader`
za ispitani Tigard postupak i :doc:`../../troubleshooting`
za obvezni postupak oporavka hladnim pokretanjem.

Konfiguracijski flash i stanje razvoja
--------------------------------------

SPI flash ispitivane pločice vratio je JEDEC ID ``1f 42 16`` (AT25QL321,
4 MiB). Postojeći dijagnostički alat projekta može čitati flash bez upisa;
izvorna slika spremljena je u dijelovima od 64 KiB. ULX5M port i dalje
je eksperimentalan: programiranje FPGA SRAM-a putem JTAG-a ne stvara trajni
DFU bootloader, a isključivanje napajanja uklanja pokrenutu sliku.
Nemojte primjenjivati ULX4M raspored flasha ili naredbe za oporavak na ULX5M.

Izvori i provjera revizija
--------------------------

* `Intergalaktik ULX5M-GS hardverski repozitorij
  <https://github.com/intergalaktik/ulx5m-gs>`_ - izvori V005, shema i
  izjava o zadanom naponu.
* `Cologne Chip DS1001, podatkovni list GateMate FPGA
  <https://colognechip.com/docs/ds1001-gatemate1-datasheet-latest.pdf>`_ -
  rujan 2026.; tablice 4.1 i 4.5 (ograničenja napajanja i GPIO-a).
* `Cologne Chip UG1003, vodič za povezivanje s 3,3 V periferijama
  <https://www.colognechip.com/docs/ug1003-gatemate1-level-shifting-latest.pdf>`_
  - kolovoz 2025.; odjeljak 1 i primjeri povezivanja.

Datoteka ``docs/ds1001-gatemate1-datasheet-latest.pdf`` u ovom repozitoriju
kopija je iz **siječnja 2023.**, usprkos nazivu. Ovdje navedene granice
ponovno su provjerene prema proizvođačevu DS1001 iz **rujna 2026.**
Za aktualne granice slijedite poveznicu na proizvođačev dokument umjesto
da pretpostavite kako je lokalna kopija najnovija.

Development record (English translation pending)
------------------------------------------------

.. toctree::
   :maxdepth: 1

   bringup
