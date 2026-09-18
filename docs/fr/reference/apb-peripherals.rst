Espace d'adressage des peripheriques APB
========================================

Hazard3-Doom expose ses peripheriques SoC a faible debit par un bus APB 32 bits
place derriere le bus systeme AHB-L de Hazard3. Les chargements et stockages CPU
dans la region ``0x40000000`` traversent le pont AHB-vers-APB puis sont decodes
par le separateur APB de
``third_party/Hazard3/example_soc/soc/example_soc.v``.

Les adresses de cette page appartiennent a l'integration SoC de Hazard3-Doom.
Elles ne sont pas des adresses architecturales RISC-V et ne sont pas imposees
par le CPU Hazard3.

Fenetres du decodeur APB
------------------------

Le separateur APB expose actuellement six esclaves :

.. list-table::
   :header-rows: 1
   :widths: 20 20 20 40

   * - Peripherique
     - Base CPU
     - Fenetre du decodeur
     - Interface RTL / logiciel
   * - Timer RISC-V
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
   * - SPI micro-SD
     - ``0x4000A000``
     - ``0x4000A000-0x4000AFFF``
     - ``apb_sd_spi.v``
   * - HDMI/video
     - ``0x4000C000``
     - ``0x4000C000-0x4000FFFF``
     - ``doom/hazard3_video.h`` et le bloc APB HDMI

Les fenetres du decodeur sont plus grandes que les ensembles de registres
implementes. Une adresse situee dans une fenetre decodee ne signifie pas qu'un
registre existe a cette adresse. Le logiciel doit utiliser uniquement les
offsets documentes ci-dessous.

La plage ``0x4000B000-0x4000BFFF`` n'est affectee a aucun peripherique par le
separateur APB actuel.

Acces MMIO commun
-----------------

Les exemples autonomes utilisent un acces 32 bits volatile simple :

.. code-block:: c

   #include <stdint.h>

   #define MMIO32(address) \
       (*(volatile uint32_t *)(uintptr_t)(address))

Les definitions partagees des exemples se trouvent dans
``examples/common/hazard3_apb.h``. Une definition centralisee reduit le risque
de divergence entre les exemples et la carte RTL.

Timer RISC-V - 0x40000000
-------------------------

Le timer fournit un compteur ``mtime`` 64 bits et un comparateur ``mtimecmp``
64 bits sur le bus APB 32 bits. Hazard3-Doom fournit un tick d'une microseconde,
donc ``mtime`` compte les microsecondes lorsque le hart s'execute. Le compteur
s'arrete lorsque le hart est arrete par le debogueur.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Adresse
     - Registre
     - Description
   * - ``0x00``
     - ``0x40000000``
     - ``CTRL``
     - Le bit 0 active le timer. Il est actif apres reset.
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

Pour lire une valeur 64 bits coherente, verifiez que le mot haut n'a pas change
autour de la lecture du mot bas :

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

Lors d'une mise a jour de ``mtimecmp``, ecrivez d'abord ``0xFFFFFFFF`` dans le
mot haut si une comparaison intermediaire intempestive serait genante, puis le
mot bas et enfin le mot haut definitif.

UART - 0x40004000
-----------------

L'UART est le peripherique ``uart_mini`` de Hazard3-libfpga. Il fournit de petits
FIFO TX/RX, un diviseur fractionnaire, des interruptions optionnelles, CTS et un
mode loopback.

.. list-table::
   :header-rows: 1
   :widths: 18 20 20 42

   * - Offset
     - Adresse
     - Registre
     - Champs importants
   * - ``0x00``
     - ``0x40004000``
     - ``CSR``
     - bit 0 EN, bit 1 BUSY, bit 2 TXIE, bit 3 RXIE, bit 4 CTSEN, bit 8 LOOPBACK.
   * - ``0x04``
     - ``0x40004004``
     - ``DIV``
     - bits 13:4 partie entiere, bits 3:0 partie fractionnaire.
   * - ``0x08``
     - ``0x40004008``
     - ``FSTAT``
     - Etats niveau/plein/vide/erreur des FIFO TX et RX.
   * - ``0x0C``
     - ``0x4000400C``
     - ``TX``
     - Une ecriture des bits 7:0 pousse un octet dans le FIFO TX.
   * - ``0x10``
     - ``0x40004010``
     - ``RX``
     - Une lecture des bits 7:0 renvoie et retire un octet du FIFO RX.

``FSTAT`` utilise les champs suivants :

.. code-block:: text

    7:0   TXLEVEL
    8     TXFULL
    9     TXEMPTY
   10     TXOVER       sticky, ecrire 1 pour effacer
   11     TXUNDER      sticky, ecrire 1 pour effacer
   23:16  RXLEVEL
   24     RXFULL
   25     RXEMPTY
   26     RXOVER       sticky, ecrire 1 pour effacer
   27     RXUNDER      sticky, ecrire 1 pour effacer

Avec le sur-echantillonnage normal 8x, le registre diviseur est une valeur a
virgule fixe avec quatre bits fractionnaires :

.. code-block:: text

   baud ~= sys_clk / (8 * DIV)
   DIV_register = round((sys_clk * 16) / (baud * 8))

Le chemin de lecture actuellement genere dans ``uart_regs.v`` renvoie la valeur
de reset du diviseur plutot que la valeur programmee. Le logiciel ne doit donc
pas utiliser la lecture de ``DIV`` pour verifier l'ecriture du debit.

Transmission bloquante minimale :

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

Le bloc GPIO contient actuellement un seul registre de sortie 8 bits.

.. list-table::
   :header-rows: 1
   :widths: 18 20 20 42

   * - Offset
     - Adresse
     - Registre
     - Description
   * - ``0x00``
     - ``0x40008000``
     - ``GPIO_OUT``
     - Les bits 7:0 pilotent ``gpio_out[7:0]``; la lecture renvoie la valeur memorisee.

Seul l'octet bas d'une ecriture est conserve :

.. code-block:: c

   MMIO32(0x40008000u) = 0x55u;

Le wrapper de carte determine ce que chaque bit ``gpio_out`` pilote reellement
sur une cible FPGA donnee.

SAO I2C/GPIO - 0x40009000
-------------------------

Le peripherique SAO combine un moteur I2C pilote par logiciel, deux GPIO SAO,
l'etat brut des lignes, des registres d'identification et l'etat de propriete
ESP32/Hazard3.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Adresse
     - Registre
     - Description
   * - ``0x00``
     - ``0x40009000``
     - ``COMMAND``
     - Ecrire une commande I2C bas niveau.
   * - ``0x04``
     - ``0x40009004``
     - ``STATUS``
     - Resultat I2C, lignes, GPIO et propriete.
   * - ``0x08``
     - ``0x40009008``
     - ``TXDATA``
     - Octet utilise par une commande WRITE.
   * - ``0x0C``
     - ``0x4000900C``
     - ``RXDATA``
     - Dernier octet recu.
   * - ``0x10``
     - ``0x40009010``
     - ``CLKDIV``
     - Diviseur de timing I2C 16 bits.
   * - ``0x14``
     - ``0x40009014``
     - ``TIMEOUT``
     - Timeout clock-stretch en cycles d'horloge systeme.
   * - ``0x18``
     - ``0x40009018``
     - ``GPIO``
     - Sorties/OE GPIO SAO et etat des entrees synchronisees.
   * - ``0x1C``
     - ``0x4000901C``
     - ``LINES``
     - Etat synchronise brut SDA, SCL, GPIO1 et GPIO2.
   * - ``0x20``
     - ``0x40009020``
     - ``ID``
     - ``0x53414F31`` (ASCII ``SAO1``).
   * - ``0x24``
     - ``0x40009024``
     - ``VERSION``
     - Version actuelle ``0x00020100`` = 2.1.0.
   * - ``0x28``
     - ``0x40009028``
     - ``OWNER``
     - bit 0 proprietaire ESP, bit 1 requete ESP.

Valeurs de ``COMMAND`` :

.. code-block:: text

   1 START
   2 STOP
   3 WRITE
   4 READ_ACK
   5 READ_NACK
   6 RECOVER
   7 ABORT

Bits de ``STATUS`` :

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

``DONE``, ``TIMEOUT``, ``REJECTED`` et ``RECOVERED`` sont sticky. Ecrire un 1
dans le bit correspondant de ``STATUS`` efface le drapeau sticky.

Le diviseur I2C de reset est choisi a partir de l'horloge systeme pour viser
environ 100 kHz. Le timeout clock-stretch de reset est de 10 ms.

SPI micro-SD - 0x4000A000
-------------------------

Le peripherique micro-SD est un petit maitre SPI mode 0 pilote par logiciel. Il
travaille MSB en premier et n'a volontairement ni FIFO ni DMA.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Adresse
     - Registre
     - Description
   * - ``0x00``
     - ``0x4000A000``
     - ``CTRL``
     - bit 0 = ``CS_n``; 1 deselectionne la carte.
   * - ``0x04``
     - ``0x4000A004``
     - ``CLKDIV``
     - Diviseur de demi-periode SPI 16 bits.
   * - ``0x08``
     - ``0x4000A008``
     - ``DATA``
     - Ecrire l'octet bas lance un transfert; lire l'octet bas donne la donnee recue.
   * - ``0x0C``
     - ``0x4000A00C``
     - ``STATUS``
     - bit 0 BUSY.

Horloge SPI :

.. code-block:: text

   SCLK = sys_clk / (2 * (CLKDIV + 1))

A 50 MHz, la valeur de reset 124 donne 200 kHz pour l'initialisation. La fenetre
APB existe meme si ``SD_SPI_ENABLE`` vaut false; dans ce cas l'integration
desactivee renvoie zero et laisse les sorties SD inactives.

Exemple de transfert d'un octet :

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

Ne lancez pas de transferts arbitraires lorsqu'un autre composant logiciel
utilise la carte ou pendant la validation du partage SD ESP32/FPGA sur ULX3S.

HDMI/video - 0x4000C000
-----------------------

Le bloc APB video controle et rapporte l'etat du chemin HDMI/video. Les pixels
du framebuffer ne resident pas dans cette fenetre APB; ils se trouvent dans la
reservation video de la memoire externe documentee dans
:doc:`../architecture/memory-map`.

.. list-table::
   :header-rows: 1
   :widths: 18 20 24 38

   * - Offset
     - Adresse
     - Registre
     - Description
   * - ``0x00``
     - ``0x4000C000``
     - ``STATUS``
     - Etat mode, framebuffer, DMA et capacites.
   * - ``0x04``
     - ``0x4000C004``
     - ``CONTROL``
     - Controle indexed/buffer/present/direct/resolution.
   * - ``0x08``
     - ``0x4000C008``
     - ``PALETTE_INDEX``
     - Selection d'entree de palette.
   * - ``0x0C``
     - ``0x4000C00C``
     - ``PALETTE_DATA``
     - Donnee de palette.
   * - ``0x10``
     - ``0x4000C010``
     - ``FRAME_COUNT``
     - Compteur de trames.
   * - ``0x14``
     - ``0x4000C014``
     - ``DMA_CYCLES``
     - Compteur diagnostique de cycles DMA.
   * - ``0x18``
     - ``0x4000C018``
     - ``PRESENT_COUNT``
     - Nombre de presentations terminees.
   * - ``0x1C``
     - ``0x4000C01C``
     - ``FPGA_BUILD_ID``
     - Identifiant carte/build FPGA.
   * - ``0x20``
     - ``0x4000C020``
     - ``DDR_STATUS``
     - Etat controleur/adaptateur de memoire externe.
   * - ``0x24``
     - ``0x4000C024``
     - ``DDR_CORE_BUILD_ID``
     - Identifiant du coeur memoire externe.
   * - ``0x28``
     - ``0x4000C028``
     - ``DDR_ADAPTER_BUILD_ID``
     - Identifiant de l'adaptateur memoire Hazard3.
   * - ``0x2C``
     - ``0x4000C02C``
     - ``DIRECT_ADDRESS``
     - Adresse/controle d'ecriture video directe.
   * - ``0x30``
     - ``0x4000C030``
     - ``DIRECT_DATA``
     - Donnee d'ecriture video directe.

Bits importants de ``STATUS`` :

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

``CONTROL`` utilise actuellement :

.. code-block:: text

   0 INDEXED
   1 BUFFER1
   2 PRESENT
   3 DIRECT
   4 HIGH_RES
   5 GUI_RES

Utilisez ``doom/hazard3_video.h`` comme source de verite pour les bits video
visibles par logiciel et la disposition des framebuffers associes.

Exemples APB autonomes
----------------------

Deux exemples bare-metal sont fournis dans ``examples/``. Ils ne sont lies ni
au moniteur resident ni a Doom.

``examples/apb-register-dump``
   Initialise l'UART et affiche un instantane non destructif des six
   peripheriques APB. Il ne lance aucune transaction SAO ou SD, ne modifie pas
   les sorties GPIO et ne change pas l'etat video.

``examples/apb-uart-timer``
   Demontre activement le timer et l'UART. Il active le timer, lit ``mtime``,
   attend un million de ticks d'une microseconde, affiche le temps ecoule puis
   passe en echo UART
   jusqu'a la reception de ``q`` ou ``Q``.

Les deux exemples partagent les definitions de registres et le demarrage minimal
dans ``examples/common/``. Chaque exemple peut etre compile independamment.

Compiler les exemples
^^^^^^^^^^^^^^^^^^^^^^

Depuis Bash ou WSL a la racine du depot :

.. code-block:: bash

   make -C examples

Ou pour un seul exemple :

.. code-block:: bash

   make -C examples/apb-register-dump
   make -C examples/apb-uart-timer

Le build suppose par defaut une horloge systeme Hazard3 de 50 MHz et un UART a
115200 bauds. Pour une cible 40 MHz telle que les profils ULX4M-LD ou
ULX3S 12F normaux :

.. code-block:: bash

   make -C examples SYS_CLK_HZ=40000000

Les makefiles suivent les memes conventions de toolchain que le projet
principal. Ils honorent d'abord ``TOOLCHAIN_PREFIX``, acceptent aussi
``CROSS_COMPILE``, reconnaissent l'ancien emplacement
``/opt/riscv/bin/riscv32-unknown-elf-`` et utilisent sinon
``riscv-none-elf-*`` dans ``PATH``. L'installateur complet normal place le
compilateur xPack dans ``PATH``. Une installation locale sous
``bin/riscv-gcc`` reste disponible comme solution de compatibilite. Les outils
Windows ``.exe`` sont detectes automatiquement lorsque leur chemin est visible
depuis Bash/WSL; ``EXEEXT=.exe`` peut aussi etre defini explicitement.

Chaque exemple produit ``.elf``, ``.bin``, ``.map`` et ``.lst`` dans son
repertoire local ``build/``. Ces fichiers generes ne doivent pas etre commits.

Execution avec OpenOCD/GDB
^^^^^^^^^^^^^^^^^^^^^^^^^^

Les exemples sont lies a ``0x20100000``, debut normal de la fenetre executable
Doom. Cela les garde hors du moniteur resident et fonctionne avec les profils
logiciels 32 MiB et 64 MiB.

Le controleur de memoire externe doit deja etre initialise. Demarrez le moniteur
resident normal, verifiez que la memoire externe est prete, lancez la session
OpenOCD Hazard3 normale, puis connectez GDB sans reset de l'FPGA ou du hart.

Pour ``apb-register-dump`` :

.. code-block:: text

   riscv-none-elf-gdb examples/apb-register-dump/build/apb-register-dump.elf
   (gdb) target extended-remote :3333
   (gdb) monitor halt
   (gdb) load
   (gdb) set $pc = _start
   (gdb) continue

Utilisez la meme sequence avec l'autre ELF. Comme l'exemple remplace
l'executable normal a ``0x20100000``, rechargez Doom avant de le relancer.

.. important::

   N'effectuez pas de reset cible juste avant le chargement. Un reset peut
   ramener le systeme avant l'initialisation SDRAM/DDR alors que ces ELF
   s'executent en memoire externe.

Fichiers source de reference
----------------------------

Lors d'une modification du SoC, verifiez cette page et
``examples/common/hazard3_apb.h`` par rapport aux implementations suivantes :

* ``third_party/Hazard3/example_soc/soc/example_soc.v`` - decodeur APB.
* ``third_party/Hazard3/example_soc/soc/peri/hazard3_riscv_timer.v`` - timer.
* ``third_party/Hazard3/example_soc/libfpga/peris/uart/uart_regs.v`` - registres UART.
* ``third_party/Hazard3/example_soc/soc/apb_gpio.v`` - GPIO.
* ``third_party/Hazard3/example_soc/soc/apb_sao_bridge.v`` - SAO.
* ``third_party/Hazard3/example_soc/soc/apb_sd_spi.v`` - SPI SD.
* ``doom/hazard3_video.h`` - definitions video visibles par logiciel.
