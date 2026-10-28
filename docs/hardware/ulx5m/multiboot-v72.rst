ULX5M-GS v72: Verified Runtime Secondary Boot (October 28, 2026)
================================================================

.. important::

   This page documents a successful **isolated** hardware experiment on
   ULX5M-GS V005. The v72 primary does not implement USB DFU. The production
   SERV/BTN2 bootloader is **not yet complete**. Preserve the v63c restore
   files, original full-flash backups and the exact v72 candidate.

Hardware acceptance evidence
----------------------------

The v72c installer reported both independent 4 MiB baseline reads equal to
SHA-256 ``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``.
It verified exactly one GateMate JTAG IDCODE ``0x20000001``, flash JEDEC
``1f 42 16`` and the complete post-write flash image. Only the first 64 KiB
of the primary was replaced; the verified v41 secondary application remained
at ``0x201000``. The backed-up v63c first block and full chip were retained.

After power-off, switching SW1 to OFF/OFF (SPI-active), leaving BTN2 released
and powering on, the user saw D6 lit and D7 blinking, followed by D0 blinking
and D1-D7 walking. The walking pattern identifies execution of the known v41
application, not merely a successful command write or a simulated RECFG.
No SRAM/JTAG FPGA configuration was involved in that SPI-active boot.

.. list-table:: Hardware and image fingerprints
   :header-rows: 1
   :widths: 37 63

   * - Item
     - Verified value
   * - v72 primary size
     - 14,987 bytes
   * - v72 primary SHA-256
     - ``839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0``
   * - v72 image-derived command SHA-256
     - ``8fbec9715a209dac2dc35dc6b517972b9d64dcdc5a7b4437fac7731a0d2849e4``
   * - v72c first 64 KiB candidate SHA-256
     - ``b31d6b84b9fd849007da4aae23010fd1f98efa000a74aab7336a495eb5699fdc``
   * - v63c pre-install full-flash SHA-256
     - ``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``
   * - v72 installed full-flash SHA-256
     - ``56d10293b68afbf21c353c7733a0a5d39a97c20d3f5a9c87b0335a09c7f36397``
   * - Secondary v41 sector SHA-256
     - ``28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee``
   * - v72c recovery session
     - ``build-ulx5m-gs/v72c-registered-ab-20261028T193955726442Z-508``
   * - Tools and route
     - OSS CAD Suite 2026-07-20; 25 MHz target, 79.26 MHz routed maximum;
       seed 302, CCGM1A1

The session's original ``state.json`` says that runtime takeover was untested;
that reflects its state at installation time. The subsequent power-on LED
observation established the hardware result. Do not silently rewrite the
historical state file to claim an automated hardware verification.

What the failed and successful probes demonstrate
-------------------------------------------------

.. list-table:: Controlled hardware comparisons
   :header-rows: 1
   :widths: 13 53 34

   * - Variant
     - Distinguishing property
     - Hardware result
   * - v65
     - Minimal SPI-active RECFG, without six West-A GPIO inputs
     - Secondary boot PASS
   * - v66
     - Six configuration-flash pins allocated as input-only user GPIO
     - Secondary boot FAIL
   * - v67
     - v66 routed design, packed configuration status ownership bit cleared
     - Secondary boot PASS
   * - v68
     - Runtime bank-status update preceding RECFG
     - Secondary boot FAIL
   * - v70
     - Exact TinyDFU-derived 27-byte command, shorter quiet wait and
       different output registration
     - Secondary boot FAIL
   * - v72
     - Registered command/data/valid control plus documented tail and
       TinyDFU-style post-command wait
     - Secondary boot PASS

The comparison establishes that a correct CRC and status payload are not
sufficient by themselves. It does **not** identify one unique v70 timing
fault. Do not shorten the known-good v72 sequence without a separate test.

Proven command and controller sequence
--------------------------------------

The final command used on v72 was generated from its **packed image's own**
configuration-status records. The 27 bytes were:

.. code-block:: text

   DB 0C B8 7E 17 10 00 20 04 01 00 00 00 00 00 00
   5D 31 00 00 00 00 33 00 00 00 00

That command is a reproducibility reference **only for the v72 image**. It
must not be hardcoded for the final 48 MHz SERV bitstream. The TinyDFU-derived
transform clears the relevant configuration-control and user-I/O ownership
bits, enables required autonomous-clock flags and recalculates both CRCs.
The packed final image must be re-audited against the embedded ROM.

The v72 ``CC_CFG_CTRL`` sequencer uses registered ``EN``, ``VALID`` and
``DATA`` with an EN lead of at least three clocks, at least one idle clock
between valid bytes, at least eight EN-high clocks after the final byte,
then a 16-count EN-low quiet interval before asserting ``RECFG``. Cologne
Chip UG1001 section 7.6 documents the EN lead, interbyte gap and EN-high
postamble. TinyDFU supplies the complementary registered FSM and quiet-wait
reference. The successful hardware test proves this combined sequence works
on this board, not that each individual interval is minimal.

Production integration boundary
-------------------------------

The current SERV firmware already has a read-only v41 native-sector probe
(``fw/ulx5m_spi_active_boot.c``), flash-release callback and Wishbone ARM/BOOT
requests. The Wishbone RTL in ``rtl/ulx5m_spi_active_reboot_wb.v`` currently
wires ``CC_CFG_CTRL`` as **RECFG only** (CLK/EN/VALID/DATA tied low). It must
be replaced with the proven v72 registered command sequence, without changing
the public ARM/BOOT status interface or removing the firmware's flash-sector
CRC validation. A write to BOOT is *request accepted*, not proof of takeover.

Sequence required for the integrated build:

#. Keep the exact existing BTN2 startup latch: BTN2 held while powering up
   selects DFU, and releasing it after enumeration must **not** disable DFU.
   The normal path must never issue a runtime command in latched DFU mode.
#. In normal mode, retain the current native-v41 read-only integrity gate
   for the secondary at ``0x201000``; do not confuse the older U5IM test
   wrapper at ``0x200000`` with the raw v41 bitstream entry point.
#. Wait for flash controller idle and physically release all six flash pins
   from fabric drivers before issuing the configuration command. Keep the
   existing ARM/BOOT Wishbone protocol; the new FSM runs only after BOOT.
#. Bring the v72 registered byte-stream FSM into the Wishbone peripheral.
   Clock it from the **actual** integrated controller clock (nominal 48 MHz),
   not v72's 25 MHz probe clock. Model status and fail-closed reset behavior.
#. Produce a final packed primary with ``--reconfig`` and
   ``--bootaddr 2101248`` (``0x201000``). Generate the 27-byte ROM from
   that exact final packed image. Iterate synthesis, place/route, pack and
   derived-command verification to a bounded, exact fixed point. Reject
   stale ROM, CRC mismatch, wrong boot address, pin-ownership regressions,
   missing clock bits and a failure to converge.
#. Test the integrated Wishbone handshake, pin tri-state timing, EN/VALID
   waveform, final packed ROM, full native sector read, DFU mode isolation
   and USB behavior. Route locally at **48 MHz** using the pinned toolchain;
   the minimal 25 MHz v72 pass does not qualify this design.
#. Keep the full v63c and v72 flash backups, use the established guarded
   JTAG install/verify/restore flow for any candidate and change no protected
   secondary sectors. Physical acceptance requires both an ordinary cold
   normal boot into walking LEDs and BTN2-held cold boot to persistent
   ``1D50:614B`` DFU **after releasing BTN2**, followed by read-only sector
   checks and deliberately authorized DFU write tests.

This is an engineering integration plan, **not** authorization to program a
combined candidate. v72 has no DFU, and no combined 48 MHz candidate is
qualified yet. If retaining the v72 probe for additional measurements, do
not claim USB recovery. Restore the exact v63c primary through the saved
JTAG recovery session before returning to ordinary DFU development.

References
----------

* `TinyDFU ULX5M source <https://github.com/pu-cc/tinydfu-bootloader/tree/master/boards/ulx5m>`_
  (``mkcmd.py`` and the registered controller in ``tinydfu_ulx5m.v``).
* `Cologne Chip UG1001 section 7.6 <https://www.colognechip.com/docs/ug1001-gatemate1-primitives-library-latest.pdf>`_
  (``CC_CFG_CTRL`` constraints).
* Local v72 source, test and toolchain artifacts under ``bootloader-serv/``;
  local v72c session ``manifest.json`` and independently observed LED result.


v73 integrated SERV/DFU follow-up (2026-10-28)
----------------------------------------------

The v72 primary may remain installed while the v73 combined candidate is
built offline; restoring v63c is not necessary for development. v72 has no
USB DFU, so recovery still depends on JTAG until an integrated candidate
passes both physical acceptance modes. The v73 build reproduces the known
registered status command using the **final combined SERV primary**, not the
v72 ROM, and packs only an experimental candidate. Do not flash it until a
new SHA-pinned A/B installer is qualified against the current v72 flash state.
See ``bootloader-serv/README_ULX5M_GS_V73_INTEGRATION_20261028.md`` for
local build and acceptance steps.
