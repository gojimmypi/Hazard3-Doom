Flasher FPGA WebUSB
===================

Hazard3-Doom comprend un programmateur FPGA ULX3S dans l'application ``web/``.
Il programme directement le FPGA ECP5 via l'interface JTAG FT231X ``US1`` de
l'ULX3S à l'aide de WebUSB.

Le flasher est distinct de la console UART :

.. code-block:: text

   Browser
     |
     +-- Web Serial --> UART adapter --> Hazard3 monitor / Doom console
     |
     +-- WebUSB -----> ULX3S US1 FT231X --> ECP5 JTAG --> FPGA SRAM

L'implémentation actuelle programme **uniquement la SRAM du FPGA**. L'image
sélectionnée démarre immédiatement après la programmation, mais elle est
volatile et disparaît lorsque la carte n'est plus alimentée. Le flasher du
navigateur n'efface ni ne réécrit la flash SPI de configuration de l'ULX3S.

Le flasher web convient donc pour tester un bitstream Hazard3-Doom nouvellement
construit avant d'envisager une mise à jour persistante de la flash.

.. figure:: ../images/Flash-from-WebUSB.png
   :alt: Flasher web FPGA Hazard3-Doom programmant une image ECP5 ULX3S via WebUSB.
   :width: 800px

   Le flasher web FPGA utilise WebUSB pour le JTAG ULX3S tandis que le reste de
   la page conserve la console Web Serial existante.

Prérequis
---------

Utilisez un navigateur récent basé sur Chromium, comme Chrome ou Edge. WebUSB
nécessite un contexte sécurisé ; servez donc la page via HTTPS ou depuis
``localhost``.

Pour le développement local, démarrez un serveur simple depuis le répertoire
``web/`` du dépôt :

.. code-block:: bash

   cd web
   python3 -m http.server 8000

Ouvrez ensuite :

.. code-block:: text

   http://localhost:8000/

Le navigateur communique directement avec le périphérique USB sélectionné. Les
données de l'image FPGA et du JTAG ne sont pas téléversées vers un serveur web.

Compatibilité des pilotes USB sous Windows
------------------------------------------

Le connecteur ``US1`` de l'ULX3S expose le FT231X embarqué utilisé pour le JTAG.
Sous Windows, le pilote associé à ce FT231X détermine quels outils USB côté hôte
peuvent l'ouvrir. Cela est distinct de l'adaptateur USB-UART externe utilisé par
la console Web Serial Hazard3-Doom.

Le tableau ci-dessous récapitule les combinaisons utilisées par le workflow
ULX3S Hazard3-Doom actuel. ``OpenOCD`` désigne un build avec le pilote
d'adaptateur ``ft232r`` et un backend Windows libusb, comme le build xPack
utilisé par ce projet.

.. raw:: html

    <table class="compat-table">
        <thead>
            <tr>       <th>Outil / chemin</th>                                                             <th>WinUSB</th>                                  <th>FTDI VCP/D2XX</th>                                                             <th>libusbK</th></tr>
        </thead>
        <tbody>
            <tr><td>OpenOCD (JTAG FT231X ULX3S)</td>            <td><span class="compat-dot compat-yes"> </span>Fonctionne</td> <td><span class="compat-dot compat-no">  </span>Non</td>                   <td><span class="compat-dot compat-yes"> </span>Fonctionne</td></tr>
            <tr><td>GDB via OpenOCD</td>                        <td><span class="compat-dot compat-yes"> </span>Fonctionne</td> <td><span class="compat-dot compat-no">  </span>Pas de transport OpenOCD</td> <td><span class="compat-dot compat-yes"> </span>Fonctionne</td></tr>
            <tr><td>Flasher FPGA/JTAG WebUSB Hazard3-Doom</td>  <td><span class="compat-dot compat-yes"> </span>Fonctionne</td> <td><span class="compat-dot compat-no">  </span>Non</td>                   <td><span class="compat-dot compat-no">  </span>Non</td></tr>
            <tr><td>fujprog Windows / outils FTDI D2XX</td>     <td><span class="compat-dot compat-no">  </span>Non</td>        <td><span class="compat-dot compat-yes"> </span>Fonctionne</td>            <td><span class="compat-dot compat-no">  </span>Non</td></tr>
            <tr><td>UART Web Serial Hazard3-Doom (adaptateur externe
                    CH340/CH341, CP210x, FTDI UART, etc.)</td> <td><span class="compat-dot compat-na">  </span>N/A</td>         <td><span class="compat-dot compat-na">  </span>N/A</td>                    <td><span class="compat-dot compat-na">  </span>N/A</td></tr>
            <tr><td>PuTTY / UART normal par port COM
                    sur l'adaptateur externe</td>              <td><span class="compat-dot compat-na">  </span>N/A</td>         <td><span class="compat-dot compat-na">  </span>N/A</td>                    <td><span class="compat-dot compat-na">  </span>N/A</td></tr>
        </tbody>
    </table>

Pour le développement Hazard3-Doom, **WinUSB est l'association FT231X ULX3S la
plus pratique lorsque la programmation WebUSB dans le navigateur et OpenOCD/GDB
sont tous deux nécessaires**. Le chemin OpenOCD ``ft232r`` actuel a été validé
avec WinUSB ; libusbK reste une option valide pour OpenOCD, mais ne convient pas
au flasher WebUSB du navigateur.

Le pilote FTDI VCP/D2XX normal reste nécessaire à ``fujprog`` sous Windows et
aux autres applications qui utilisent directement le pilote/API propriétaire
FTDI. Modifier l'association du FT231X ne réinitialise pas le FPGA déjà
configuré.

Une incompatibilité typique du pilote WebUSB est :

.. code-block:: text

   ERROR: Failed to execute 'open' on 'USBDevice': Access denied.

Le flasher reconnaît le cas d'accès refusé sous Windows et journalise une
indication concernant le pilote WinUSB plutôt que de le traiter comme une panne
JTAG.

.. figure:: ../images/WebUSB-USBDevice-Access-Denied.png
   :alt: Flasher WebUSB Hazard3-Doom affichant USBDevice Access denied avant installation de WinUSB.
   :width: 780px

   L'accès refusé par ``USBDevice.open()`` survient avant le début du JTAG. Sous
   Windows, vérifiez l'association de pilote du FT231X avant d'étudier le FPGA
   ou le câblage JTAG.

Une façon de sélectionner WinUSB consiste à utiliser Zadig :

#. Connectez le connecteur USB ``US1`` de l'ULX3S.
#. Fermez ``fujprog``, OpenOCD, ``openFPGALoader`` et les autres programmes susceptibles de posséder déjà le FT231X.
#. Démarrez Zadig et activez **Options -> List All Devices** si nécessaire.
#. Sélectionnez le périphérique FTDI ULX3S. Confirmez qu'il s'agit bien de l'interface ULX3S voulue avant de remplacer un pilote.
#. Sélectionnez **WinUSB** comme pilote de remplacement et installez-le.
#. Débranchez puis rebranchez ``US1`` avant de revenir au navigateur.

.. figure:: ../images/Zadig-FTDI-to-WinUSB.png
   :alt: Zadig configuré pour remplacer le pilote FTDI ULX3S par WinUSB.
   :width: 580px

   Exemple de sélection Zadig pour un FT231X ULX3S. Vérifiez le périphérique
   sélectionné avant de remplacer son pilote.

.. warning::

   Réassocier le FT231X modifie l'API USB Windows qui peut revendiquer
   l'interface. Les logiciels qui attendent spécifiquement FTDI VCP/D2XX
   cesseront de fonctionner sur cette interface jusqu'à restauration du pilote
   FTDI. Cela **n'empêche pas** l'adaptateur USB-UART externe séparé de continuer
   à fournir la console Web Serial Hazard3-Doom.

Pour restaurer le pilote FTDI normal de ``US1``, utilisez le Gestionnaire de
périphériques Windows pour remettre le pilote du périphérique USB ULX3S sur le
pilote FTDI installé, ou réinstallez le paquet FTDI VCP/D2XX approprié.

.. figure:: ../images/Windows-set-default-USB-from-WinUSB.png
   :alt: Commande Mettre à jour le pilote du Gestionnaire de périphériques Windows pour un périphérique ULX3S utilisant WinUSB.
   :width: 620px

   Le Gestionnaire de périphériques peut restaurer le pilote FTDI normal
   lorsqu'une application FTDI VCP/D2XX telle que ``fujprog`` sous Windows est
   nécessaire.

Programmer un fichier ``.bit``
------------------------------

Le flux Hazard3-Doom normal accepte directement le fichier ECP5 ``.bit`` produit
par le build FPGA. Aucune conversion manuelle n'est nécessaire.

Pour le build ULX3S standard, l'image est généralement :

.. code-block:: text

   build/fpga_ulx3s.bit

Pour la programmer :

#. Construisez ou obtenez le bitstream destiné à la variante FPGA ULX3S voulue.
#. Ouvrez l'application web Hazard3-Doom et développez **FPGA web flasher**.
#. Sélectionnez le fichier ``.bit``.
#. Cliquez sur **Connect ULX3S USB** et sélectionnez le périphérique FTDI ULX3S connecté à ``US1``.
#. Cliquez sur **Probe JTAG**.
#. Confirmez que le périphérique ECP5 détecté est bien le FPGA attendu.
#. Cliquez sur **Program FPGA SRAM**.
#. Attendez que l'indicateur de progression et le journal du flasher signalent la fin avec succès.

Une session 85F réussie contient des messages similaires à :

.. code-block:: text

   INFO: Converted fpga_ulx3s.bit to the Project Trellis ECP5 SRAM SVF sequence for LFE5U-85F.
   INFO: Loaded fpga_ulx3s.bit: 1,018 programming commands.
   INFO: Connected to ULX3S FPGA ...
   OK: JTAG probe found LFE5U-85F (0x41113043).
   INFO: Programming fpga_ulx3s.bit into LFE5U-85F FPGA SRAM...
   OK: Programming stream completed successfully in ... s (1,018 commands).

Après une configuration SRAM réussie, la nouvelle image FPGA démarre
immédiatement. Si elle contient le système Hazard3-Doom normal, le moniteur
résident et le workflow Doom peuvent ensuite continuer normalement.

Identification de la cible et contrôles de sécurité
---------------------------------------------------

Le navigateur sonde l'identifiant JTAG physique de l'ECP5 avant la
programmation. Le flasher actuel reconnaît :

.. list-table::
   :header-rows: 1
   :widths: 35 35

   * - FPGA
     - JTAG IDCODE
   * - LFE5U-12F
     - ``0x21111043``
   * - LFE5U-25F
     - ``0x41111043``
   * - LFE5U-45F
     - ``0x41112043``
   * - LFE5U-85F
     - ``0x41113043``

Pour un fichier ``.bit``, le navigateur extrait aussi l'identifiant de cible
ECP5 incorporé au bitstream. Juste avant la programmation, il sonde de nouveau
la carte et refuse de continuer si la cible du bitstream et le FPGA physique ne
correspondent pas.

Ce contrôle repose volontairement sur l'identifiant JTAG ECP5 plutôt que sur la
chaîne de produit USB du FT231X. Une description EEPROM FT231X peut identifier
la carte comme, par exemple, ``ULX3S FPGA 12K`` alors que l'identifiant JTAG
physique de l'ECP5 indique un 85F. Pour les décisions de programmation,
l'identifiant JTAG fait autorité.

Fonctionnement de la programmation ``.bit``
-------------------------------------------

Project Trellis fournit normalement ``tools/bit_to_svf.py`` pour convertir un
bitstream ECP5 en séquence JTAG Serial Vector Format (SVF) nécessaire à la
configuration SRAM. Hazard3-Doom effectue cette conversion dans le navigateur,
ce qui permet de sélectionner directement la sortie du build.

La conversion côté navigateur comprend :

* l'extraction de l'IDCODE ECP5 depuis le bitstream ;
* la séquence de configuration ECP5 Project Trellis ;
* l'inversion des bits requise par la représentation SVF/JTAG ;
* des blocs de programmation ``SDR`` de 8000 bits maximum ;
* les opérations d'état et de vérification ECP5 ; et
* la séquence finale qui démarre l'image FPGA configurée.

Le flux généré est ensuite exécuté par la machine d'états JTAG du navigateur via
l'interface synchronous bit-bang du FT231X.

Fichiers SVF prégénérés
-----------------------

Le flasher accepte également un fichier ``.svf``. Cela est utile pour les tests,
l'interopérabilité ou la comparaison du comportement du navigateur avec
d'autres outils JTAG.

Project Trellis peut générer un flux équivalent de programmation SRAM ECP5 avec :

.. code-block:: bash

   python3 /path/to/prjtrellis/tools/bit_to_svf.py \
       build/fpga_ulx3s.bit \
       build/fpga_ulx3s.svf

Le navigateur implémente les opérations SVF requises par la séquence normale de
programmation SRAM ECP5 de Project Trellis. Les commandes non prises en charge
arrêtent la programmation avec une erreur explicite au lieu d'être ignorées
silencieusement.

Transport JTAG
--------------

Le programmateur WebUSB suit le mapping synchronous bit-bang FT231X ULX3S
utilisé par ``fujprog`` :

.. code-block:: text

   TCK  0x20
   TMS  0x40
   TDI  0x80
   TDO  0x08

Le transport utilise le mode synchronous bit-bang du FT231X. L'implémentation
tient compte du pipeline de réception FTDI lors de l'échantillonnage de TDO ;
c'est important car une erreur d'un cycle décale l'IDCODE ECP5 renvoyé.

Le navigateur applique également les comparaisons SVF ``TDO``/``MASK`` pendant
la programmation. Un échec de comparaison arrête le flux et est signalé dans le
journal du flasher.

Contrôles du journal du flasher
-------------------------------

Le flasher FPGA possède son propre journal, indépendant du terminal UART.

* **Auto-scroll** suit les nouveaux messages de programmation par défaut. Décochez l'option pour examiner les sorties précédentes pendant que la programmation continue.
* **Copy log** copie le journal complet actuel dans le presse-papiers.
* **Clear log** efface l'historique affiché sans déconnecter l'USB, réinitialiser la progression ni interrompre une opération JTAG active.
* La zone de journal possède une barre de défilement verticale et peut être redimensionnée verticalement.

Dépannage
---------

``USBDevice.open(): Access denied``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sous Windows, cela signifie normalement que le FT231X utilise encore le pilote
FTDI VCP/D2XX au lieu de WinUSB, ou qu'un autre processus possède déjà
l'interface USB. Installez/sélectionnez WinUSB pour le FT231X ULX3S voulu,
débranchez/rebranchez ``US1`` puis réessayez. Si WinUSB est déjà installé,
fermez d'abord les autres programmes USB/JTAG.

Voir :ref:`webusb-access-denied` pour la procédure de dépannage condensée.

Identifiant JTAG non reconnu ou décalé
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Une sonde saine doit renvoyer l'un des IDCODE ECP5 connus du tableau ci-dessus.
Si la valeur renvoyée n'est pas reconnue :

* déconnectez les autres logiciels JTAG ;
* débranchez/rebranchez ``US1`` ;
* reconnectez le navigateur et sondez de nouveau ; et
* confirmez que le fichier ``web/flasher.js`` actuel est servi, plutôt qu'une copie obsolète mise en cache par le navigateur.

Ne programmez pas d'image lorsque la cible JTAG physique ne peut pas être
identifiée.

Incompatibilité de cible du bitstream
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Si le navigateur indique que la carte et l'image ciblent des périphériques ECP5
différents, ne contournez pas le contrôle. Reconstruisez ou sélectionnez le
bitstream destiné à la carte physique.

La programmation se termine et la nouvelle image démarre
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

C'est le résultat attendu. La programmation de la SRAM FPGA est volatile ; un
cycle d'alimentation ramène donc le FPGA à la configuration stockée dans la
flash SPI persistante.

Configuration persistante
-------------------------

Le flasher WebUSB n'écrit volontairement **pas** dans la flash SPI persistante.
Une mise à jour persistante a un coût de récupération plus élevé qu'un
chargement SRAM temporaire et doit rester un workflow séparé avec confirmation
explicite.

Voir :doc:`../getting-started/programming` pour la distinction entre chargement
FPGA temporaire et configuration de démarrage persistante.

Références d'implémentation
---------------------------

* `Manuel ULX3S <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `fujprog <https://github.com/kost/fujprog>`_
* `Project Trellis <https://github.com/YosysHQ/prjtrellis>`_
* `API WebUSB <https://developer.mozilla.org/en-US/docs/Web/API/WebUSB_API>`_
