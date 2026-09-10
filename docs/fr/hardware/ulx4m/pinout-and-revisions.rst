Contraintes de broches, schémas et révisions
=============================================

Un nom de signal devient du matériel réel au travers d'une chaîne d'artefacts :

.. code-block:: text

   net du schéma -> piste PCB / bille FPGA -> contrainte LPF
      -> port Verilog top-level -> module/périphérique -> comportement logiciel

Une sortie appelée ``sd_clk`` n'est donc la bonne horloge SD que si le LPF
correspondant la place sur la bille reliée à la bonne piste de la révision PCB.

Fichiers importants
-------------------

.. code-block:: text

   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld_v002.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ls.lpf
   bootloader/data/top-ulx4m-v002.lpf

Le LPF contient non seulement les emplacements, mais aussi les normes d'E/S,
terminaisons, informations d'horloge et réglages différentiels. Il faut le
considérer comme une documentation matérielle exécutable.

Discipline de révision
----------------------

Pour chaque carte ULX4M, enregistrez : variante LS/LD, révision PCB, référence
complète du FPGA et population mémoire. Deux cartes « ULX4M-LD » peuvent exiger
des profils DDR3 différents.

Lorsque des sources amont se contredisent, conservez le désaccord et recherchez
sa cause : prototype, révision ancienne, BOM alternatif, branche différente ou
retard documentaire. Crowd Supply, par exemple, décrit une LD Micron
``MT41K512M16HA-125`` 1 GiB, tandis qu'un manuel amont mentionne
``MT41K256M16TW-107`` 512 MiB; Hazard3-Doom prend aussi en charge un profil
Alliance ``AS4C256M16D3``.

Références locales
------------------

:download:`Schémas ULX4M (copie locale) <ULX4M-LS-v0.0.3.pdf>`

:download:`Fiche Alliance AS4C256M16D3 (copie locale) <../../AllianceMemory_4G_DDR3_AS4C256M16D3C_May2020_Rev1.1_Final.pdf>`

Avant de changer une broche
---------------------------

#. Identifier la variante et la révision exactes.
#. Retrouver le signal dans le schéma correspondant.
#. Confirmer la bille FPGA et la banque d'E/S.
#. Vérifier tension et norme d'E/S.
#. Modifier le bon LPF.
#. Vérifier direction et largeur du port Verilog.
#. Construire et examiner les avertissements.
#. Tester la fonction sur le matériel réel.
#. Vérifier la propriété des bus partagés.
#. Enregistrer la révision/profil ayant servi à la validation.
