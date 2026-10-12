Statička analiza u Ghidri
=========================

Projekt sadrži proširenje za Ghidru za analizu izvršnih H3IMG datoteka.
Proširenje uključuje učitavač H3IMG datoteka i analizator memorijski
mapiranih ulazno-izlaznih registara (MMIO). Ghidra ne pokreće FPGA ni monitor.

Izvorni kod i instalacija
-------------------------

Izvorni kod i upute za izgradnju i instalaciju nalaze se u
`ghidra/Hazard3H3IMG <https://github.com/ulx3s/Hazard3-Doom/tree/develop/ghidra/Hazard3H3IMG>`_.
U datoteci ``README.md`` provjerite podržane verzije Ghidre i Jave. Koristite
proširenje kompatibilno s instaliranom verzijom Ghidre.

Uvoz H3IMG datoteke
-------------------

1. Instalirajte proširenje i ponovno pokrenite Ghidru ako je potrebno.
2. Izradite ili otvorite Ghidra projekt.
3. Odaberite **File > Import File** i datoteku ``.h3img``.
4. Po potrebi odaberite H3IMG učitavač te provjerite RISC-V arhitekturu i
   raspored memorije.
5. Otvorite program u CodeBrowseru i pokrenite analizu.
6. Provjerite ulaznu adresu, učitanu memoriju i BSS područje.

H3IMG sadrži zaglavlje od 64 bajta i izvršne podatke. Vidi
:doc:`../reference/h3img-format`. Učitavač prikazuje BSS kao
neinicijaliziranu memoriju i ne izvršava monitor.

MMIO analiza
------------

U opcijama analize uključite MMIO analizator. On definira raspone adresa i
nazive registara, ali ne mora prepoznati svaki posredni pristup ili adresu
sastavljenu od više RISC-V instrukcija. Dio referenci treba ručno provjeriti.

Adrese registara navedene su u :doc:`../reference/apb-peripherals` i
:doc:`../architecture/memory-map`.

Ograničenja
-----------

* Ghidra izvodi statičku analizu. Za rad s aktivnim hardverom vidi
  :doc:`jtag-debugging`.
* H3IMG nije ELF i ne sadrži ELF simbole ni DWARF podatke. Za analizu sa
  simbolima sačuvajte odgovarajuću ELF datoteku.
* MMIO adrese moraju odgovarati verziji FPGA dizajna i programa.
* Doom IWAD zasebna je datoteka, nije dio H3IMG slike.
