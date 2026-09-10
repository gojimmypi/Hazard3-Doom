Hardverski vodiči
==================

Hazard3-Doom zamišljen je tako da ga se može istraživati od softvera sve do
same pločice. Ove stranice opisuju fizičke FPGA platforme, komponente oko FPGA-a
i način na koji one postaju resursi koje Hazard3-Doom može koristiti.

Vodiči nadopunjuju izvornu dokumentaciju pločica. Ne zamjenjuju sheme, BOM,
datasheetove ni bilješke o revizijama. Cilj im je povezati fizički hardver s
Verilogom, ograničenjima, memorijskim kontrolerima, firmwareom i alatima za
otklanjanje pogrešaka u ovom projektu.

.. toctree::
   :maxdepth: 2

   ulx3s/index
   ulx4m/index

Zašto hardverski vodič?
-----------------------

Sam naziv pločice skriva više važnih slojeva. FPGA dizajn mora znati točan FPGA
paket, ugrađenu memoriju, pin svakog signala, potreban I/O standard, izvor
satova i sučelja koja su stvarno spojena na konektore. Softver zatim dodaje nova
pitanja: koji kontroler upravlja hardverom, gdje se nalazi u memorijskoj mapi i
što je doista potvrđeno na fizičkoj pločici.

Kada javni opis pločice, upstream shema i stvarno sastavljena pločica nisu
usklađeni, vodič tu razliku bilježi umjesto da tiho izabere samo jedan izvor.
