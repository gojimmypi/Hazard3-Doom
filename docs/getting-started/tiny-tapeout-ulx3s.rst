Tiny Tapeout FPGA Builds on ULX3S
=================================

Hazard3-Doom also carries a small Tiny Tapeout-compatible project that is used
as a smoke test for the ULX3S Tiny Tapeout FPGA flow. This is separate from the
normal Hazard3-Doom FPGA build: the Tiny Tapeout flow wraps a ``tt_um_*`` user
module in a ULX3S-specific top level and builds that module for the ECP5 FPGA.
It does **not** synthesize the complete Hazard3 CPU, SDRAM controller, HDMI
framebuffer, resident monitor, and Doom application.

The ULX3S Tiny Tapeout support is currently developed in the ``experimental``
branches of these ULX3S-maintained forks:

* `ulx3s/tt-gds-action <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
  provides the reusable GitHub Action used by a Tiny Tapeout project workflow.
* `ulx3s/tt-support-tools <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
  contains the Python FPGA build tool, ULX3S wrapper, and ULX3S LPF constraints.

* `tt-fpga-ulx.yaml <https://github.com/ulx3s/Hazard3-Doom/blob/main/.github/workflows/tt-fpga-ulx.yaml>`_

.. admonition:: Experimental branch status
   :class: important

   The examples on this page deliberately use ``@experimental``. Do not change
   them to ``@main`` merely to make the workflow look conventional. The ULX3S
   support is still being integrated. When the ULX3S repositories publish the
   support on a stable branch or tag, update the action and support-tools refs
   together so the wrapper, command-line interface, and workflow stay matched.

What the two repositories do
----------------------------

The two repositories have different jobs.

``ulx3s/tt-gds-action``
   This is the GitHub Actions entry point. The ULX3S composite action is
   ``fpga/ulx3s/action.yml``. It checks out the support tools, installs their
   Python dependencies, creates the Tiny Tapeout user configuration, installs a
   pinned OSS CAD Suite, runs the ECP5 FPGA hardening step, and uploads the
   resulting build files as a workflow artifact.

``ulx3s/tt-support-tools``
   This is where the FPGA build implementation lives. ``tt_fpga.py`` reads the
   Tiny Tapeout project metadata, generates a board-specific wrapper, runs Yosys,
   nextpnr-ecp5, and ecppack, and writes the resulting ECP5 bitstream and logs
   under ``build/``.

This separation is useful when debugging. A workflow/YAML problem normally
belongs in the action layer; synthesis, wrapper, pin mapping, ECP5 device, or
place-and-route behavior normally belongs in the support-tools layer.

Required Tiny Tapeout project layout
------------------------------------

The flow expects the normal Tiny Tapeout project metadata and source layout. In
Hazard3-Doom the relevant files are:

.. code-block:: text

   info.yaml
   src/
       config.json
       project.v

``info.yaml`` is especially important. It supplies the ``top_module`` name and
the list of Verilog source files. The top module must use the Tiny Tapeout
``tt_um_*`` interface. Hazard3-Doom currently uses the small
``tt_um_ulx3s_example`` smoke-test module in ``src/project.v``.

The FPGA builder can be driven without ``info.yaml`` by supplying source and top
module options manually, but the repository workflow intentionally uses the
standard Tiny Tapeout metadata so the same project description remains useful
for the ASIC and FPGA flows.

GitHub Actions workflow
-----------------------

The ULX3S job used by Hazard3-Doom is:

.. code-block:: yaml

   fpga-ulx3s:
     runs-on: ubuntu-24.04
     steps:
       - name: checkout repo
         uses: actions/checkout@v7
         with:
           submodules: recursive

       - name: FPGA bitstream for TT ASIC Sim (ULX3S ECP5)
         uses: ulx3s/tt-gds-action/fpga/ulx3s@experimental
         with:
           ecp5-device: 85k
           lpf: tt/fpga/ulx3s/ulx3s_v20.lpf
           artifact-name: fpga_ulx3s_ecp5
           uart-enabled: true

The job can be placed alongside the usual Tiny Tapeout FPGA job. The current
Hazard3-Doom workflow also builds the iCE40 UP5K target using the corresponding
``fpga/ice40up5k`` action, so the same TT project is exercised through two FPGA
implementations.

Why recursive checkout is used
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``submodules: recursive`` checks out the project exactly as represented by the
repository, including any source dependencies represented as Git submodules.
The ULX3S action then performs its own checkout of ``tt-support-tools`` into a
working directory named ``tt``. Those are two separate checkouts:

#. the first checkout is the Tiny Tapeout project being built;
#. the second checkout supplies the Tiny Tapeout build tools.

Action inputs
-------------

``ecp5-device``
   Selects the ECP5 density passed to ``tt_fpga.py`` and then to nextpnr-ecp5.
   Hazard3-Doom uses ``85k`` for the ULX3S 85F board. The current support tool
   accepts ``12k``, ``25k``, ``45k``, and ``85k`` for ECP5 targets.

``lpf``
   Path to the Lattice Preference File containing the ULX3S physical pin and
   clock constraints. Hazard3-Doom explicitly selects
   ``tt/fpga/ulx3s/ulx3s_v20.lpf`` for this workflow. The reusable ULX3S action
   currently defaults to ``ulx3s_v316.lpf``, so keeping the LPF explicit avoids
   silently changing board constraints when the action default changes. The
   selected v20 file maps ``clk_25mhz`` to the board oscillator and constrains
   that port to 25 MHz in addition to mapping the LEDs, buttons, GPIO, and other
   board signals used by the wrapper.

``artifact-name``
   Base name of the GitHub Actions artifact. The action appends the selected
   ECP5 device, so the example produces an artifact named
   ``fpga_ulx3s_ecp5_85k``.

``uart-enabled``
   When ``true``, the action passes the ``UART_ENABLED`` Verilog define to the
   FPGA build. This enables the optional UART mapping in the ULX3S wrapper. Use
   ``false`` for a project that does not want that mapping.

The composite action also has ``tools-repo`` and ``tools-ref`` inputs. Their
current defaults are ``ulx3s/tt-support-tools`` and ``experimental``. They are
normally left alone so the action uses the matching ULX3S support-tools branch,
but they are useful for testing a development fork or a specific commit.

What the action runs
--------------------

The current ULX3S composite action performs these operations:

#. Check out ``ulx3s/tt-support-tools`` at the requested ``tools-ref`` into
   ``tt/``.
#. Set up Python 3.11 and install ``tt/requirements.txt``.
#. If the project has ``test/requirements.txt``, install those dependencies too.
#. Run ``tt/tt_tool.py --create-user-config`` so the support tools have the
   project top module and source configuration.
#. Install OSS CAD Suite using ``YosysHQ/setup-oss-cad-suite@v4``. The current
   experimental action pins the suite version to ``2026-04-26``.
#. Run the equivalent of the following ULX3S build command:

   .. code-block:: bash

      python tt/tt_fpga.py harden \
          --name tt_um_fpga_ecp5_85k \
          --fpga-target ulx3s-ecp5 \
          --ecp5-device 85k \
          --lpf tt/fpga/ulx3s/ulx3s_v20.lpf \
          --define UART_ENABLED

#. Upload the build products and supporting project files as a GitHub Actions
   artifact, even when a later step reports a failure.

The ``--define UART_ENABLED`` argument is included only when
``uart-enabled: true``.

Inside ``tt_fpga.py``
---------------------

For the ``ulx3s-ecp5`` target, ``tt_fpga.py`` generates
``src/_tt_fpga_top.v`` from the support-tools template
``fpga/ulx3s/tt_fpga_top_ulx3s.v``. The placeholder user module in that template
is replaced with the ``top_module`` from ``info.yaml``.

The generated wrapper is then synthesized together with the project sources.
The ECP5 flow is conceptually:

.. code-block:: text

   info.yaml + src/project.v
              |
              v
   generate src/_tt_fpga_top.v
              |
              v
       Yosys synth_ecp5
              |
              v
       build/<name>.json
              |
              v
         nextpnr-ecp5
              |
              v
      build/<name>.config
              |
              v
            ecppack
              |
              v
        build/<name>.bit

For the workflow example, the important files are normally:

.. code-block:: text

   build/01-synth.log
   build/02-nextpnr.log
   build/tt_um_fpga_ecp5_85k.json
   build/tt_um_fpga_ecp5_85k.config
   build/tt_um_fpga_ecp5_85k.bit

``01-synth.log`` is the first place to look for HDL, module, or synthesis
problems. ``02-nextpnr.log`` contains device utilization, placement/routing, and
timing information. The ``.bit`` file is the ULX3S ECP5 bitstream.

ULX3S wrapper behavior
----------------------

The current wrapper deliberately provides a simple, observable Tiny Tapeout test
environment:

* the ULX3S ``clk_25mhz`` oscillator drives the Tiny Tapeout ``clk`` input;
* ULX3S button 0 drives the active-low Tiny Tapeout ``rst_n`` input;
* Tiny Tapeout ``ena`` is held high;
* ``uo_out[7:0]`` is connected to the eight ULX3S LEDs;
* when ``UART_ENABLED`` is defined, ULX3S ``gp0`` is synchronized and mapped to
  Tiny Tapeout ``ui_in[3]``;
* when ``UART_ENABLED`` is defined, Tiny Tapeout ``uo_out[4]`` drives ULX3S
  ``gp1`` as the UART transmit path;
* ``uio_in`` is held at zero by this wrapper, although the project still exposes
  the normal Tiny Tapeout ``uio_out`` and ``uio_oe`` interface.

This mapping is why a simple TT project can be tested directly with LEDs,
buttons, and UART before moving on to ASIC hardening or a physical shuttle.

Running the same ULX3S flow locally
-----------------------------------

The GitHub Action is the easiest reproducible path, but the same support tools
can be run locally. From the root of a Tiny Tapeout project:

.. code-block:: bash

   git clone --branch experimental \
       https://github.com/ulx3s/tt-support-tools.git tt
   python3 -m pip install -r tt/requirements.txt
   python3 tt/tt_tool.py --create-user-config

Yosys, ``nextpnr-ecp5``, Project Trellis/``ecppack``, and their ECP5 device data
must also be available in ``PATH``. The GitHub Action supplies those through its
pinned OSS CAD Suite setup; a local build may use an equivalent installed OSS
CAD Suite.

Then run the same FPGA build explicitly:

.. code-block:: bash

   python3 tt/tt_fpga.py harden \
       --name tt_um_fpga_ecp5_85k \
       --fpga-target ulx3s-ecp5 \
       --ecp5-device 85k \
       --lpf tt/fpga/ulx3s/ulx3s_v20.lpf \
       --define UART_ENABLED

Omit ``--define UART_ENABLED`` to build without the optional UART mapping.

The support tool also accepts ``TT_FPGA_SEED`` and ``TT_FPGA_FREQ`` environment
variables, which are passed into the place-and-route flow. For normal project
validation, first use the defaults from the supported workflow rather than
changing routing parameters casually; if a project needs a different seed or
timing target, record those settings with the test results.

Programming the generated bitstream
-----------------------------------

The local or downloaded ``.bit`` file is a normal ULX3S ECP5 bitstream. With a
compatible ``fujprog`` installation, a volatile FPGA load can be performed with:

.. code-block:: bash

   fujprog build/tt_um_fpga_ecp5_85k.bit

The FPGA SRAM configuration is lost when board power is removed. This is usually
what you want for a Tiny Tapeout smoke test because it does not replace a
persistent flash image. See :doc:`programming` and :doc:`../user-guide/web-flasher`
for the Hazard3-Doom programming paths and USB-driver considerations.

Do not confuse ``tt_fpga.py harden`` with ``tt_fpga.py configure --upload``.
The current ``configure`` subcommand is part of the Tiny Tapeout database/breakout
configuration path and looks for a ``.bin`` image. The ULX3S ECP5 build described
here produces a ``.bit`` file; program that ECP5 bitstream with a ULX3S FPGA
programming tool.

Downloading and checking the GitHub artifact
--------------------------------------------

After the ``fpga-ulx3s`` job completes, open the workflow run and download the
``fpga_ulx3s_ecp5_85k`` artifact. The action is configured to include the
``build/`` directory plus the project ``docs/``, ``src/``, ``info.yaml``,
``LICENSE``, and selected LPF file. This makes the artifact useful for both
programming and diagnosing exactly what was built.

For a successful build, verify at minimum:

#. ``build/tt_um_fpga_ecp5_85k.bit`` exists and is non-empty;
#. ``build/01-synth.log`` shows the expected Tiny Tapeout top module;
#. ``build/02-nextpnr.log`` identifies the intended ECP5 device and has no
   routing failure;
#. the LPF in the artifact is the ULX3S constraint file expected by the workflow;
#. the GitHub Actions log shows the expected ``ulx3s/tt-gds-action`` and
   ``ulx3s/tt-support-tools`` refs.

Troubleshooting
---------------

``No project yaml, must specify ...``
   The builder did not find the expected ``info.yaml`` at the project root, or
   the command was run from the wrong directory. Use the normal TT project root
   or supply the source/top-module options explicitly.

``ulx3s-ecp5 requires --lpf ...``
   The ECP5 target needs a physical constraint file. Use the matching ULX3S LPF
   from the checked-out support-tools tree unless you are deliberately testing a
   different board revision or pin map.

Yosys cannot find the user module
   Check ``info.yaml`` ``top_module``, the ``source_files`` list, and
   ``build/01-synth.log``. Also inspect the generated ``src/_tt_fpga_top.v`` to
   confirm the placeholder was replaced with the expected ``tt_um_*`` module.

nextpnr reports pin or package errors
   Confirm ``ecp5-device`` and the LPF match the actual ULX3S board. Do not solve
   a board mismatch by deleting constraints.

UART does not respond
   Confirm ``uart-enabled: true`` was used and remember that the wrapper maps
   ``gp0`` into ``ui_in[3]`` and ``uo_out[4]`` out through ``gp1``. The Tiny
   Tapeout module itself must implement the corresponding receive/transmit
   behavior; enabling the wrapper does not add a UART core to the user design.

The workflow works but a manual build does not
   Compare tool versions first. The GitHub Action deliberately pins OSS CAD
   Suite and the ``experimental`` support-tools branch. A local Yosys,
   nextpnr-ecp5, or Project Trellis version can produce different results.

Related links
-------------

* `Hazard3-Doom ULX3S TT workflow <https://github.com/ulx3s/Hazard3-Doom/blob/main/.github/workflows/tt-fpga-ulx.yaml>`_
* `ULX3S tt-gds-action experimental branch <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
* `ULX3S tt-support-tools experimental branch <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
* `ULX3S Tiny Tapeout template <https://github.com/ulx3s/ttsky-verilog-template/tree/ulx3s>`_
* `ULX3S Tiny Tapeout Github Marketplace Action <https://github.com/marketplace/actions/tiny-tapeout-gds-action-for-the-ulx3s-and-ulx4m-ecp5-fpga>`_
