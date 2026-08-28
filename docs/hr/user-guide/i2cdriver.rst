I2CDriver HDMI sučelje
======================

Hazard3-Doom uključuje interaktivno I2C dijagnostičko sučelje nadahnuto
`I2CDriverom <https://github.com/jamesbowman/i2cdriver>`_ Jamesa Bowmana.
Izvorni I2CDriver firmware napisan je u MyForthu. Hazard3-Doom ponovno koristi
postojeći FPGA SAO I2C kontroler projekta za transakcije na sabirnici i prikazuje
sučelje u stilu I2CDrivera preko postojećeg 320x200 indeksiranog HDMI puta.

Značajku prvenstveno implementiraju:

.. code-block:: text

   src/i2cdriver_hdmi.c
   src/i2cdriver_hdmi.h
   src/sao_console.c

Rezidentni monitor mora se ponovno izgraditi i učitati nakon promjene tih
datoteka. Za softverske promjene I2CDriver HDMI-ja nije potrebna ponovna sinteza
FPGA-a sve dok aktivni bitstream već pruža kompatibilni SAO most i izravno
indeksirano HDMI sučelje.

Pokretanje sučelja
------------------

Najprije se vratite u rezidentni monitor. Ako Doom radi, pritisnite ``Ctrl-X``.
Zatim unesite jednu od naredbi:

.. code-block:: text

   i2c gui

ili:

.. code-block:: text

   sao gui

Uspješno pokretanje ispisuje:

.. code-block:: text

   Starting I2CDriver HDMI...
   I2CDriver HDMI active. S scan, P probe, R read, W write, X recover, 1/4 speed, C clear, Q exit.

HDMI prikaz prelazi na zaslon Hazard3 I2CDrivera. Dok je sučelje aktivno, UART
tipke upravljaju HDMI aplikacijom umjesto uobičajenim naredbenim retkom monitora.

Kontrole
--------

.. list-table::
   :header-rows: 1
   :widths: 10 22 68

   * - Tipka
     - Operacija
     - Opis
   * - ``S``
     - Skeniranje
     - Ispituje uobičajene 7-bitne I2C adrese od ``0x08`` do ``0x77``. Adrese koje odgovore zagrijavaju se na karti adresa. Trenutačna implementacija zadržava logički trag ispitivanja posljednje adrese koja je vratila ACK.
   * - ``P``
     - Ispitivanje
     - Traži jednu 7-bitnu heksadecimalnu adresu i provjerava vraća li ACK.
   * - ``R``
     - Čitanje registra
     - Traži adresu uređaja i 8-bitni registar, zatim izvodi čitanje jednog bajta registra uz ponovljeni START.
   * - ``W``
     - Pisanje registra
     - Traži adresu uređaja, 8-bitni registar i jedan podatkovni bajt, zatim zapisuje taj registar.
   * - ``X``
     - Oporavak
     - Pokreće operaciju oporavka sabirnice u FPGA SAO mostu. Upotrijebite je kada SDA/SCL ili ciljni uređaj izgledaju zaglavljeni.
   * - ``1``
     - 100 kHz
     - Odabire uobičajenu I2C brzinu sabirnice od 100 kHz.
   * - ``4``
     - 400 kHz
     - Odabire fast-mode postavku. Uz Hazard3 sistemski takt od 50 MHz, cjelobrojni djelitelj daje približno 403 kHz.
   * - ``C``
     - Brisanje
     - Briše toplinsku kartu, povijest transakcija i logički trag. Time se ne resetira priključeni I2C uređaj.
   * - ``Q``
     - Izlaz
     - Vraća upravljanje UART-om rezidentnom monitoru i vraća SAO sabirnicu na 100 kHz.
   * - ``Ctrl-X``
     - Izlaz
     - Alternativna tipka za izlaz dok je GUI aktivan.
   * - ``Esc``
     - Odustani/izlaz
     - Odustaje od upita za operand. Kada nema aktivnog upita, ``Esc`` zatvara GUI.

Heksadecimalni upiti
--------------------

``P``, ``R`` i ``W`` prikupljaju heksadecimalne operande izravno u HDMI
korisničkom sučelju. Nemojte unositi prefiks ``0x``.

Ispitivanje adrese ``0x54``:

.. code-block:: text

   P
   54
   Enter

Čitanje registra ``0x00`` s uređaja ``0x54``:

.. code-block:: text

   R
   5400
   Enter

Pisanje vrijednosti ``0x80`` u registar ``0x04`` na uređaju ``0x54``:

.. code-block:: text

   W
   540480
   Enter

Tijekom unosa operanada Backspace/Delete uređuje unos, Enter izvršava potpunu
naredbu, a Esc je poništava.

.. warning::

   ``W`` mijenja stanje priključenog uređaja. Prije pisanja pogledajte
   dokumentaciju registara ciljnog uređaja. Čitanje također može imati nuspojave
   na uređajima s registrima tipa read-to-clear ili FIFO.

Toplinska karta adresa
----------------------

Toplinska karta vizualno pokriva cijeli 7-bitni adresni prostor, ali uobičajeni
raspon skeniranja je od ``0x08`` do ``0x77``. Adrese izvan tog raspona rezervirane
su ili na drugi način neprikladne za uobičajeno skeniranje.

Adresa koja vrati ACK dobiva maksimalnu toplinu koja zatim postupno blijedi.
Tako su nedavno aktivni uređaji uočljivi bez trajnog označavanja zastarjelih
odgovora.

Uređaj izvan raspona skeniranja i dalje se može izričito ispitati ako to dopušta
osnovni SAO probe API. Nemojte pretpostaviti da će se uređaj na rezerviranoj
adresi pojaviti u rezultatima skeniranja ``S``.

Dnevnik transakcija
-------------------

Dnevnik transakcija na desnoj strani bilježi nedavne GUI operacije, uključujući
ispitivanje, čitanje, pisanje, oporavak, skeniranje i promjenu brzine. Dnevnik je
lokalno dijagnostičko stanje; ``C`` ga briše bez promjene priključenog uređaja.

Logički trag
------------

Donji HDMI panel prikazuje SDA i SCL kao **logički trag transakcije**.
Taj trag sintetiziran je iz transakcija koje Hazard3 pokrene preko SAO mosta.
Koristan je za vizualizaciju strukture protokola, primjerice:

.. code-block:: text

   START
   address + WRITE     ACK
   register            ACK
   repeated START
   address + READ      ACK
   data                master NACK
   STOP

Za skeniranje ``S`` trenutačna implementacija zadržava trag ispitivanja posljednje
adrese koja je vratila ACK. Ako jedan uređaj odgovori na ``0x54``, zadržani trag
skeniranja prikazuje START, adresni bajt ``0xA8`` s ACK-om i STOP.

Trag **nije električno snimanje bridova SDA/SCL-a**. API SAO-a visoke razine
također javlja ukupni rezultat transakcije, a ne točnu fazu bajta koja je
uzrokovala NACK, pa neuspjeli višebajtni logički trag ne može uvijek odrediti
točnu ACK poziciju koja je zakazala.

Stanje pasivnog snimanja
------------------------

Izvorni I2CDriver ima vremenski osjetljivu implementaciju pasivnog snimanja u
``firmware/capture.fs``. Hazard3-Doom trenutačno ne implementira odgovarajući
pasivni sniffer u softveru.

Pravi pasivni analizator trebao bi biti implementiran kao FPGA logika koja
uzorkuje SDA i SCL neovisno o Hazard3 CPU-u i smješta dekodirane događaje/vremenske
oznake u FIFO. HDMI C sučelje zatim može prikazati te snimljene podatke. Dok takav
FIFO ne postoji, podnožje namjerno opisuje prikaz kao inicirani promet, a ne kao
pasivno snimanje.

Oporavak sabirnice
------------------

``X`` poziva postojeću operaciju oporavka SAO mosta umjesto ručnog bit-banganja
SDA/SCL-a iz C-a. Tako električno vremensko upravljanje i vlasništvo ostaju u
FPGA kontroleru sabirnice.

Upotrijebite oporavak kada je uređaj prekinut usred transakcije, SDA ostane
nisko ili sabirnica prestane odgovarati nakon priključivanja dok je sustav uključen.
Ispravna sabirnica obično ne zahtijeva oporavak.

HDMI prikaz
-----------

Sučelje iscrtava indeksirani okvir 320x200 i prenosi ga u neaktivni interni EBR
framebuffer putem izravnog HDMI registarskog puta. Softver odabire banku suprotnu
aktivnom internom framebufferu, a zatim traži zamjenu tijekom vertical blankinga.
To je isti koncept dvostrukog međuspremnika koji koristi brzi Doom prikazni put.

Izlazak iz GUI-ja ne rekonstruira okvir koji je bio vidljiv prije ulaska.
Posljednji okvir analizatora može ostati na HDMI-ju sve dok Doom ili druga
video-operacija monitora ne prikaže novi okvir. UART naredbeni redak monitora
mjerodavan je znak da je GUI završen.

Web Serial snimka zaslona
-------------------------

Web Serial konzola u pregledniku može snimiti trenutačni I2CDriver HDMI zaslon
kada aktivni GUI implementira dogovor o mogućnosti snimke zaslona. GUI presreće
rezervirane kontrolne bajtove prije uobičajene obrade tipki/upita, pa se zahtjev
za zaslonom ne tumači kao I2C naredba.

Trenutačni izvori snimke zaslona mogu se serijalizirati kao ``320x200`` ili
``400x240``. Svaki ``H3SNIP1`` piksel je 8-bitni indeks palete. Najprije se šalje
16 stavki GUI palete, a preostale stavke palete su nula.

Pogledajte :doc:`web-serial` za točan upit sposobnosti ``0x1c``, ``0x06`` ACK,
zahtjev za snimanje ``0x1d``, veličine payloada, RGB332 format, ponašanje timeouta
i rekonstrukciju PNG-a.

Tijek izgradnje i ispitivanja
-----------------------------

Za softverske promjene implementacije I2CDriver HDMI-ja:

.. code-block:: bash

   ./scripts/build.sh
   ./scripts/load-firmware.sh ./build/hazard3-boot-monitor.elf

Prije ispitivanja GUI-ja potvrdite uobičajeni SAO put:

.. code-block:: text

   sao info
   sao scan
   i2c gui

Koristan slijed provjere unutar GUI-ja je:

.. code-block:: text

   S
   P 54 Enter
   4
   S
   1
   Q

Zamijenite ``54`` poznatim uređajem na priključenoj SAO sabirnici.

Ako se ``i2c gui`` prijavi kao nepoznata naredba, pločica pokreće stariji
rezidentni monitor čak i ako noviji ELF monitora postoji na disku. Ponovno
izgradite i učitajte ``build/hazard3-boot-monitor.elf`` prije otklanjanja
poteškoća u samom GUI-ju.

Odnos prema izvornom I2CDriveru
-------------------------------

Ova značajka prenosi koristan model interakcije umjesto prevođenja svake
hardverski specifične funkcije iz originalne pločice. Verzija Hazard3-Dooma
trenutačno obuhvaća aktivno master skeniranje, ispitivanje, jednobajtno čitanje
i pisanje registara, toplinsku aktivnost, povijest transakcija, logičke tragove,
oporavak sabirnice i odabir 100/400 kHz.

Hardverski specifična analogna mjerenja izvornog I2CDrivera, hardver s
preklopivim pull-up otpornicima, binarni host protokol i pravo pasivno snimanje
nisu implicitno dostupni kroz ovo C sučelje.

I2CDriver se distribuira pod BSD 3-Clause licencom. Sačuvajte materijale projekta
za atribuciju/licenciranje trećih strana pri kopiranju ili redistribuciji koda
izvedenog iz njega.
