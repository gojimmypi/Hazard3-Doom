Vanjska sučelja i proširenje
============================

Dva CM4-kompatibilna konektora prenose napajanje i mnoge signale između modula
i carrier pločice. "CM4 kompatibilno" treba shvatiti prvenstveno kao mehanički,
konektorski i signalni cilj; ne znači da Raspberry Pi softver ili svaka funkcija
CM4 carrier pločice automatski radi s FPGA-om.

Ethernet
--------

Objavljene ULX4M varijante uključuju Ethernet, ali PHY ovisi o reviziji i
izvoru. Crowd Supply navodi ``KSZ9031RNXCA`` za promovirane LS i LD
konfiguracije, dok starija LS dokumentacija navodi ``LAN8720A``. Hazard3-Doom se
trenutačno ne oslanja na Ethernet za Doom, monitor, programiranje ili debug.

CSI/DSI i SerDes
----------------

Upstream izvori opisuju camera/display konektore te SerDes rute prema PCIe x1 i
drugim konektorima. Neke veze koriste obični FPGA I/O kao "fake differential",
a druge zahtijevaju ECP5 varijantu koja stvarno ima SerDes i odgovarajuću PCB
reviziju.

Prije uporabe provjerite ugrađeni FPGA i PCB reviziju. Trenutačni
``LFE5UM-85F-8BG381C`` je SerDes-capable klasa, ali Doom SoC ne zahtijeva PCIe
ni drugi SerDes periferni blok.

GPIO, tipke, DIP i LED
----------------------

Javni opisi za reprezentativne konfiguracije navode GPIO, tri tipke, dva DIP
prekidača i osam LED-ica. Trenutačni LD top-level izlaže osam LED izlaza i prije
DDR inicijalizacije koristi ih za bring-up status: heartbeat, PLL lock,
inicijalizaciju, user clock i aktivnost adaptera. Trenutačni LS top-level izlaže
četiri LED izlaza.

UART i JTAG
-----------

UART je najjednostavniji softverski dijagnostički put za monitor, zapise, prijenos slika
i Web Serial. ULX4M LPF datoteke mapiraju odabrane UART pinove na FTDI put
modula/nosive pločice koji koristi podržana konfiguracija. Pogledajte
:doc:`pinout-and-revisions` za raspored pinova ULX4M-LD nosive pločice i napomene
o revizijama. JTAG je komplementaran za zaustavljanje i izvođenje korak po korak,
registre, memoriju i otklanjanje pogrešaka na razini izvornog koda.

Napajanje
---------

Upstream dokumentacija navodi najmanje 500 mA i opisuje različite načine
napajanja ovisno o carrier pločici. Upute zato trebaju imenovati carrier i
provjeriti ulazno napajanje, FPGA/memory railove, I/O bank napone i stvarnu
funkciju svakog pina. Oblik konektora sam po sebi ne jamči električnu
kompatibilnost.

Pretpostavke o napajanju i nosećoj pločici
------------------------------------------

Izvorna ULX4M dokumentacija navodi da modul zahtijeva najmanje 500 mA i opisuje
različite rasporede napajanja na nosećim pločicama. Noseće pločice mogu različito
voditi USB i 5 V, pa upute za uključivanje moraju navesti konkretnu noseću
pločicu umjesto pretpostavke da se svaka baza kompatibilna s CM4 ponaša jednako.

Pri radu s hardverom provjerite:

* predviđeno ulazno napajanje i put napajanja na nosećoj pločici;
* jesu li prisutni svi potrebni naponski vodovi za FPGA i memoriju;
* napone I/O banaka prije spajanja vanjskog hardvera; i
* je li pin priključka ulaz, izlaz, zajednički signal ili naponski vod.
