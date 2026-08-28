Pipeline vidéo
==============

Le pipeline vidéo est une fonctionnalité du SoC Hazard3-Doom/ULX3S autour du
processeur ; il ne fait pas partie du cœur CPU Hazard3 amont. Le CPU produit les
données du framebuffer avec des opérations mémoire ordinaires, tandis que le
matériel du projet transforme ces données en signal d'affichage.

Doom conserve son moteur de rendu indexé natif. Le projet n'impose pas au jeu de produire un framebuffer RGB complet en logiciel.

Pipeline
--------

#. Doom effectue le rendu d'une image indexée 8 bits 320x200 dans le tampon écran du projet.
#. Le logiciel écrit l'image indexée terminée dans le framebuffer EBR interne inactif via le chemin direct des registres vidéo.
#. Les framebuffers internes sont permutés pendant le blanking vertical.
#. Une palette matérielle convertit les pixels indexés pour le scanout HDMI.

Géométrie de sortie
-------------------

La sortie 1024x600 documentée met à l'échelle l'image indexée native 320x200 de Doom sur toute la dalle. L'échelle verticale est exactement 3x (200 vers 600 lignes), tandis que l'échelle horizontale est fractionnaire afin d'utiliser les 1024 pixels de sortie.

Pourquoi des couleurs indexées ?
--------------------------------

Conserver la représentation indexée native réduit le trafic mémoire logiciel et permet d'effectuer la conversion de palette dans une logique FPGA dédiée.

Registres vidéo
---------------

Le bloc de registres de contrôle HDMI/vidéo commence à :

.. code-block:: text

   0x4000C000

Chemin de capture d'écran Web Serial
------------------------------------

La fonction de capture d'écran Web Serial se situe volontairement au-dessus de
l'encodeur HDMI physique. Elle ne capture pas le TMDS et ne dépend pas d'un
chemin général de lecture de l'EBR. Une application active prise en charge
sérialise son image source indexée et la palette RGB332 sur l'UART avec le
protocole ``H3SNIP1``. Le navigateur reconstruit ensuite le raster ``1024x600``
annoncé avec une correspondance de source par plus proche voisin et encode le
PNG localement.

Cela maintient une charge utile sur le fil compacte par rapport à un framebuffer
RGB complet et permet au même parseur du navigateur d'accepter des sources Doom
et I2C GUI de géométries différentes. Voir :doc:`../user-guide/web-serial` pour
le protocole complet.

Utilisateurs non-Doom du chemin vidéo
-------------------------------------

Le moniteur résident peut également utiliser le chemin EBR indexé direct pour
les diagnostics. L'interface :doc:`../user-guide/i2cdriver` effectue le rendu
de son propre écran indexé 320x200, écrit le framebuffer interne inactif et
demande une permutation au blanking vertical sans modifier DoomGeneric.
