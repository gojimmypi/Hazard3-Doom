Exécuter Doom
=============

Chargement UART
---------------

Le flux de développement normal envoie un exécutable empaqueté ``.h3d`` au moniteur résident, puis envoie ``DOOM.WAD`` et lance l'application.

Le profil mémoire 64 Mio est le profil par défaut pour ULX3S 85F et ULX4M-LD 85F.

Commandes
---------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Touche
     - Action
   * - ``Esc``
     - Menu / retour.
   * - ``W`` / ``S``
     - Avancer/reculer ou monter/descendre dans un menu.
   * - ``A`` / ``D``
     - Tourner ou modifier une valeur de menu.
   * - ``Z`` / ``C``
     - Déplacement latéral gauche/droite.
   * - ``F`` ou ``Space``
     - Tirer.
   * - ``E``
     - Utiliser/ouvrir.
   * - ``M`` ou ``Tab``
     - Automap.
   * - ``P``
     - Pause.
   * - ``1`` à ``7``
     - Sélectionner une arme.
   * - ``Enter``
     - Sélectionner.
   * - ``Ctrl-X``
     - Quitter Doom et revenir au moniteur résident.

Chemin vidéo
------------

Doom effectue le rendu d'un écran de travail indexé 8 bits 320x200. Le chemin HDMI côté FPGA présente l'image indexée grâce à la palette matérielle et à la logique de scanout. Voir :doc:`../architecture/video` pour le chemin des données.

Capture d'écran Web Serial
--------------------------

Lorsque la console du navigateur confirme la capacité de capture d'écran, Doom
accepte la requête brute réservée et reporte la sérialisation jusqu'au prochain
``DG_DrawFrame()`` terminé. Cela évite de copier un framebuffer que Doom est
encore en train de modifier. Les builds standards envoient une source indexée
``320x200``. Le build de présentation optionnel ``400x240`` applique la même
expansion de source Doom que le chemin HDMI avant de transmettre la capture.

Le navigateur reçoit la palette et les pixels indexés, reconstruit le raster
HDMI ``1024x600`` annoncé et télécharge localement un PNG. Voir
:doc:`web-serial` pour la négociation de capacité, le format sur le fil
``H3SNIP1``, l'encodage de palette RGB332, les temps de transfert et la machine
d'états de réception du navigateur.

Son
---

Le son est actuellement simulé par des stubs dans l'étape documentée.
