# Hazard3-Doom attribution and acknowledgements

Hazard3-Doom exists because of a large chain of open hardware, open source,
standards, tools, documentation, testing, reverse engineering, educational
work, and community support. This file is intentionally broader than a minimum
legal NOTICE file. It gives credit both to direct code/hardware contributors
and to people/projects whose work made Hazard3-Doom practical, testable,
understandable, or accessible.

This is not a statement that every person or organization named below owns
copyright in Hazard3-Doom. It is also not a statement that any of them endorses
Hazard3-Doom. For legal obligations, see `LICENSES/`, source-file headers,
submodule license files, binary-package notices, and Git history.

No finite file can name every contributor to every transitive project. All
contributors to every linked upstream repository are therefore explicitly
acknowledged by reference even when not individually named below. If somebody
has been missed, adding their credit is welcomed.

## Hazard3-Doom project

- gojimmypi - Hazard3-Doom development and integration work, including monitor,
  Doom port, FPGA/board integration, build/test tooling, Web Serial/WebUSB
  interfaces, documentation, debugging, and project maintenance reflected in
  repository history.
- The `ulx3s` GitHub organization and ULX3S community - project hosting,
  collaboration, hardware ecosystem, testing, examples, and upstream forks.
- Every Hazard3-Doom commit author, reviewer, issue reporter, tester,
  documentation contributor, pull-request author, fork maintainer, and user who
  supplied reproducible test results or hardware observations.
- Automated project-maintenance services such as GitHub Dependabot where their
  commits/pull requests appear in history.

Project repository:
https://github.com/ulx3s/Hazard3-Doom

## Hazard3 processor and SoC

Hazard3-Doom runs on Hazard3, a compact three-stage RISC-V processor with debug
support.

- Luke Wren (`Wren6991`) - creator and primary upstream author of Hazard3 and
  its processor/debug RTL and example SoC infrastructure.
- All Hazard3 contributors and reviewers.
- The `ulx3s/Hazard3` fork contributors who developed and maintained the
  ULX3S/ULX4M Doom-oriented hardware integration.
- gojimmypi - `ulx-doom`/board-integration contributions appearing in the fork
  history.

Upstream: https://github.com/Wren6991/Hazard3
Compatible fork: https://github.com/ulx3s/Hazard3/tree/ulx-doom

Hazard3's recursive development/test ecosystem has included Wren6991/libfpga,
Wren6991/fpgascripts, riscv-formal, Embench, RISC-V Architectural Tests,
riscv-tests, and other projects pinned by particular Hazard3 revisions. Their
complete contributor communities are acknowledged by reference.

## RISC-V ecosystem

- RISC-V International and the specification authors, working groups,
  reviewers, implementers, educators, and compatibility-test contributors
  behind the ISA, privileged architecture, debug specification, architectural
  tests, and related standards used by Hazard3.
- RISC-V software/toolchain maintainers, including the riscv-collab GNU
  toolchain integration community.
- GCC, GNU Binutils, GDB, Newlib, glibc/musl and other GNU/toolchain component
  communities where used by a selected build.
- The Free Software Foundation and GNU project communities that develop and
  steward GCC, GDB, Binutils, GNU licenses, and associated runtime exceptions.
- Sysprogs and its toolchain/distribution maintainers where Hazard3-Doom's
  Windows quick-start files originated from a Sysprogs package.

Bundled toolchains are multi-license distributions; see
`LICENSES/RISC-V-GNU-Toolchain-NOTICE.md`.

## DOOM and DoomGeneric

Hazard3-Doom is possible because id Software released the DOOM engine source
and later communities made it increasingly portable.

- id Software - original DOOM development and source release.
- John Carmack - engine programming and the 1997 source release.
- John Romero - programming, design, tools, and level design.
- Dave Taylor - programming/software engineering.
- Michael Abrash - programming/software engineering credited on the DOS
  release.
- Adrian Carmack and Kevin Cloud - graphics/artwork.
- Sandy Petersen - design and level design.
- Shawn C. Green - design, level design, testing/support and development
  support.
- Tom A. Hall - early creative direction/concept work.
- Robert "Bobby" Prince - original music and sound effects.
- Paul Radek - sound/audio driver work.
- Gregor Punchatz - model development.
- Don Ivan Punchatz - cover illustration.
- Jay Wilbur - business/production leadership.
- American McGee, Tim Willits, and John W. Anderson - later original-era DOOM
  level/design contributions associated with Ultimate DOOM lineage.
- Every other id Software employee, tester, porter, release engineer, and
  contributor associated with the DOOM source and its supported platforms.
- `ozkl` and all DoomGeneric contributors - portable interface consumed by
  Hazard3-Doom.
- `maximevince` and fbDOOM contributors - lineage identified by DoomGeneric.
- The broader free-software DOOM port community that preserved compatibility
  knowledge and maintained the released engine across platforms.

Official source release: https://github.com/id-Software/DOOM
DoomGeneric: https://github.com/ozkl/doomgeneric

DOOM game data, artwork, audio, names, logos, and trademarks remain distinct
from the GPL engine source. Hazard3-Doom does not claim ownership of them.

## I2CDriver inspiration

- James Bowman - creator of I2CDriver and the interaction/display concepts that
  inspired the Hazard3-Doom I2CDriver-style HDMI interface.
- Excamera Labs and the I2CDriver project/community.
- Everyone who contributed to or documented I2CDriver.

Upstream: https://github.com/jamesbowman/i2cdriver

I2CDriver is independent of Hazard3-Doom. This acknowledgement does not imply
that James Bowman or Excamera Labs sponsors, approves, certifies, or endorses
Hazard3-Doom. See `LICENSES/I2CDriver-NOTICE.md`.

## CoreMark benchmark

- Embedded Microprocessor Benchmark Consortium (EEMBC) - CoreMark benchmark and
  benchmark stewardship.
- Alan Anderson - ADI.
- Adhikary Rajiv - ADI.
- Elena Stohr - ARM.
- Ian Rickards - ARM.
- Andrew Pickard - ARM.
- Trent Parker - Cavium.
- Shay Gal-On - EEMBC.
- Markus Levy - EEMBC.
- Peter Torelli - EEMBC.
- Ron Olson - IBM.
- Eyal Barzilay - MIPS.
- Jens Eltze - NEC.
- Hirohiko Ono - NEC.
- Ulrich Drees - NEC.
- Frank Roscheda - NEC.
- Rob Cosaro - NXP.
- Shumpei Kawasaki - Renesas.
- All later CoreMark maintainers, reviewers, port authors, and test
  contributors.

Upstream: https://github.com/eembc/coremark

CoreMark is an EEMBC trademark and has separate acceptable-use/trademark
terms. See `LICENSES/CoreMark-NOTICE.md` before publishing modified benchmark
results.

## ULX3S hardware and community

- Davor Jadrijevic (`emard`) - ULX3S board designer and long-time maintainer.
- Radiona / Zagreb Makerspace - ULX3S development, manufacturing, community,
  education, and open-hardware stewardship.
- FER (University of Zagreb Faculty of Electrical Engineering and Computing) -
  educational collaboration and predecessor-board context.
- Koncar-INEM - collaboration associated with original ULX3S development.
- Marko Zec - ULX2S predecessor work and earlier educational hardware lineage.
- Everyone who designed revisions, assembled boards, tested hardware, wrote
  examples, documented peripherals, answered questions, and funded/supported
  ULX3S.

Hardware: https://github.com/emard/ulx3s

## ULX4M hardware and community

- Intergalaktik d.o.o. and the Intergalaktik open-hardware team.
- Radiona and the ULX3S/ULX4M community.
- Goran Mahovlic.
- Deborah Hustic.
- Damir Prizmic.
- gojimmypi.
- Davor Jadrijevic (`emard`).
- Marko Jovanovic.
- Boris Vidosevic.
- Marvin Sinister.
- Igor Brkic.
- Mato Ilijic.
- Zvonimir Domazet.
- NLnet Foundation - funding/support acknowledged by ULX4M.
- Contributors to TrellisBoard, OrangeCrab, Antmicro ECP5 designs,
  ButterStick, and other reference open-hardware projects cited by ULX4M.

Hardware: https://github.com/intergalaktik/ulx4m

## HAD2019 / ULX3S / ULX4M DFU bootloader

The ULX3S/ULX4M DFU bootloader lineage comes from the Hackaday Supercon
2019 badge bootloader and subsequent ULX board adaptations. Principal authors
and contributors identified from the source headers and Git history include:

- Sylvain Munaut (`smunaut`) - original Hackaday Supercon 2019 badge
  bootloader author and principal original copyright holder. His bootloader
  firmware files carry LGPL v3-or-later notices, and much of the associated
  bootloader RTL carries BSD 3-Clause notices.
- Jeroen Domburg (`Spritetm`) - author of multiple commits in the original
  bootloader history, including DFU, flash-selection, and bootloader-protection
  changes.
- Lawrie Griffiths (`lawrie`) - contributor to the ULX3S fork/adaptation and
  later bootloader changes.
- Davor Jadrijevic (`emard`) - extensive ULX3S and ULX4M bootloader
  adaptation, integration, maintenance, and board-specific work.
- Clifford Wolf - author/copyright holder of the PicoRV32 core included by the
  upstream bootloader.
- Michal Ludvig - author/copyright holder of the `mini-printf.c` implementation
  included by the upstream bootloader firmware.
- All other contributors recorded in the upstream repositories and their Git
  histories are acknowledged by reference.

Upstream lineage and source:

- https://github.com/smunaut/had2019-playground/tree/master/projects/bootloader
- https://github.com/lawrie/had2019-playground/tree/master/projects/bootloader
- https://github.com/emard/had2019-playground/tree/master/projects/bootloader

The upstream repository applies licenses per project/file rather than one
blanket license. Preserve the original source-file headers and see
`LICENSES/HAD2019-Bootloader-NOTICE.md` for the bootloader licensing summary
and bundled license texts.

## FPGA silicon, USB, and board-component ecosystem

- Lattice Semiconductor - ECP5 FPGA family used by principal targets.
- Espressif Systems - ESP32 platform present on relevant ULX boards and bridge
  workflows.
- FTDI - FT231X/related USB bridge devices and technical documentation used by
  ULX3S host/JTAG/UART workflows.
- USB Implementers Forum and USB specification contributors.
- SD Association and SD-card ecosystem contributors.
- JEDEC and memory-device standards contributors relevant to SDRAM/DDR3 and
  device identification.
- Manufacturers/authors of SPI flash, oscillators, connectors, level shifters,
  regulators, memory devices, and peripheral specifications used by ULX boards.

Vendor acknowledgement is descriptive and does not imply endorsement.

## Open FPGA toolchain

### Yosys

- Claire Xenia Wolf - creator/original principal author; current source carries
  her copyrights.
- YosysHQ and the complete Yosys contributor community.
- Authors of ABC and other third-party synthesis libraries integrated with the
  Yosys flow.

https://github.com/YosysHQ/yosys

### nextpnr

- Claire Xenia Wolf.
- Miodrag Milanovic.
- David Shah and other architecture/backend contributors.
- YosysHQ and all nextpnr contributors.

https://github.com/YosysHQ/nextpnr

### Project Trellis / prjtrellis

- Project Trellis authors and YosysHQ for documenting Lattice ECP5 bitstreams
  and enabling an open ECP5 flow.
- `tinyfpga` - credited upstream for inspiration and ECP5 hardware donations.
- Tim Ansell (`mithro`) - credited upstream for the project name and initial
  support.
- `q3k`, `emard`, and `tinyfpga` - credited upstream for ECP5 hardware used in
  testing/demonstrations.
- All Project Trellis code, database, documentation, reverse-engineering,
  fuzzing, and hardware-test contributors.

https://github.com/YosysHQ/prjtrellis

Project Trellis code and database have distinct licensing; see the exact
upstream tree and `LICENSES/Web-Flasher-Provenance-NOTICE.md`.

### Other HDL/synthesis/simulation/verification tools

Credit also goes to Icarus Verilog, Verilator, SymbiYosys, formal-solver
projects, GNU Make, Bash, ShellCheck, CMake, Ninja, Project IceStorm for iCE40
workflows, and every maintainer/contributor behind the exact versions used.

## FPGA programming, JTAG, USB, and Windows utility ecosystem

### fujprog / ujprog

- Marko Zec - original ujprog author.
- EMARD / Davor Jadrijevic - fujprog contributions credited upstream.
- gojimmypi - fujprog contributions credited upstream.
- kost - fujprog maintainer/contributor.
- all other fujprog and ujprog contributors.

https://github.com/kost/fujprog

fujprog also directly informed Hazard3-Doom's FT231X WebUSB JTAG behavior; see
`LICENSES/Web-Flasher-Provenance-NOTICE.md`.

### openFPGALoader

- Gwenhael Goavec-Merou - principal author/maintainer identified by upstream.
- All openFPGALoader board, protocol, cable, parser, documentation, test, and
  integration contributors.

https://github.com/trabucayre/openFPGALoader

### dfu-util

- Weston Schmidt and Harald Welte - original dfu-util authors for the OpenMoko
  project, as credited by upstream documentation.
- OpenMoko, Inc. - copyright holder identified in portions of the upstream
  source.
- Tormod Volden and Stefan Schmidt - long-time dfu-util maintainers and
  developers.
- All other dfu-util contributors and packagers represented by the exact
  upstream release/source history used for the bundled Windows utilities.

https://dfu-util.sourceforge.net/
https://sourceforge.net/projects/dfu-util/

Hazard3-Doom redistributes `dfu-prefix.exe`, `dfu-suffix.exe`, `dfu-util.exe`,
and `dfu-util-static.exe`; see `LICENSES/dfu-util-NOTICE.md` and the preserved
upstream GPL text in `LICENSES/dfu-util-COPYING.txt`.

### OpenOCD and xPack OpenOCD

- The OpenOCD project, maintainers, driver/target authors, reviewers, and users.
- RISC-V OpenOCD contributors and RISC-V debug integration maintainers.
- Liviu Ionescu and xPack contributors for the cross-platform OpenOCD binary
  distribution used in recorded Hazard3-Doom Windows workflows.

https://github.com/openocd-org/openocd
https://xpack-dev-tools.github.io/openocd-xpack/

### PuTTY

- Simon Tatham - primary author/maintainer.
- Robert de Bath, Joris van Rantwijk, Delian Delchev, Andreas Schultz, Jeroen
  Massar, Wez Furlong, Nicolas Barry, Justin Bradford, Ben Harris, Malcolm
  Smith, Ahmad Khalifa, Markus Kuhn, Colin Watson, Christopher Staite, Lorenz
  Diener, Christian Brabandt, Jeff Smith, Pavel Kryukov, Maxim Kuznetsov,
  Svyatoslav Kuzmich, Nico Williams, Viktor Dukhovni, Josh Dersch, Lars
  Brinkhoff, CORE SDI S.A., and all other PuTTY contributors.

### Zadig / libwdi

- Pete Batard / Akeo - Zadig and libwdi author/maintainer.
- libwdi contributors.
- Theodore Ts'o and the Kerberos Team - configuration/profile parsing credits
  carried by current Zadig upstream.
- Stephen J. Gowdy and USB ID Repository contributors.
- Martin Prikryl / WinSCP - dialog-design inspiration credited upstream.

### libusb

- Johannes Erdfelt, Daniel Drake, Pete Batard, Nathan Hjelm, Chris Dickens,
  Tormod Volden, Sylvain Fasel, Sean McBride, Xiaofan Chen, Hans de Goede,
  Ludovic Rousseau, and all other libusb contributors.
- Contributors to Windows backends and referenced antecedent work, including
  Stephan Meyer/libusb-win32, Alan Ott/HIDAPI, Red Hat/UsbDk contributors, and
  others identified by exact source headers.

https://github.com/libusb/libusb

### libftdi

- Intra2net AG and the libftdi developer community.
- Thomas Jarosch and other long-time maintainers/contributors.
- Earlier and current authors identified in exact libftdi source headers.

https://www.intra2net.com/en/developer/libftdi/

### Drivers and browser USB/serial standards

- Microsoft WinUSB developers and Windows USB-driver platform teams.
- libusbK/libusb-win32 communities where those drivers/APIs are used.
- W3C/Web Platform/browser contributors behind WebUSB and Web Serial.
- Chromium/Chrome, Microsoft Edge, and other browser implementers whose APIs
  make direct browser hardware interaction possible.

## Browser WebUSB flasher technical lineage

Hazard3-Doom's browser flasher is specifically indebted to:

- Project Trellis ECP5 bitstream/programming knowledge;
- fujprog's proven ULX3S/FT231X JTAG behavior;
- FTDI synchronous-bit-bang and USB/UART documentation;
- libftdi behavior/documentation used as an implementation reference;
- WebUSB implementers and browser USB-stack maintainers.

This is technical attribution, not a claim that these projects endorse the
flasher. Source-level derivation must be reviewed separately as described in
`LICENSES/Web-Flasher-Provenance-NOTICE.md`.

## Python, image generation, web, and documentation ecosystem

- Python Software Foundation and Python contributors.
- pyserial authors and contributors.
- Pillow/PIL maintainers where repository scripts use Pillow to generate
  images/assets.
- DejaVu font authors and maintainers where scripts render text using installed
  DejaVu Sans Mono fonts. Rendering with a system font is distinguished from
  redistributing the font file itself.
- Sphinx authors and contributors.
- Read the Docs and its maintainers.
- Git and its contributor community.
- GitHub, GitHub Actions, and maintainers of reusable Actions used by CI.
- Browser-engine and Web Platform contributors whose APIs enable the web UI.
- Authors of any JavaScript, CSS, font, image, or other web dependency actually
  copied into `web/` or docs; copied assets must retain their exact notices.

## Windows and development tooling

- Microsoft Visual Studio, Windows SDK/tooling, and related debugger/build
  components used in Windows workflows.
- Microsoft WSL teams and Linux distribution maintainers supporting mixed
  Windows/Linux FPGA development.
- Sysprogs VisualGDB developers for Visual Studio embedded/GDB integration used
  by project configurations.
- Sysprogs toolchain maintainers where bundled Windows RISC-V files originated
  from their distributions.
- GCC, Clang/LLVM, MSVC, CMake, Ninja, Make, shell environments, package
  maintainers, and all other development tools used to produce/test releases.
- OpenAI/ChatGPT - interactive design, code-review, documentation, licensing
  inventory, and development assistance used during parts of project work;
  human maintainers remain responsible for reviewed project changes.

## Tiny Tapeout and educational open-silicon ecosystem

- Tiny Tapeout and all maintainers, template authors, shuttle partners,
  educators, sponsors, and community contributors.
- Matt Venn and Uri Shaked, among prominent Tiny Tapeout project/community
  contributors, plus the full contributor community by reference.
- Open-source HDL educators, FPGA tutorial authors, RISC-V educators, and
  community members whose explanations make projects like Hazard3-Doom useful
  as learning material.

## Simple Add-On and embedded peripheral community

- The Simple Add-On (SAO) community and badge/hardware hackers who developed and
  popularized small interoperable add-ons and conventions.
- Authors of I2C peripheral documentation, open hardware examples, and test
  devices used to validate SAO/I2C support.
- I2C, SPI, UART, FAT/filesystem, HDMI/DVI/TMDS, JTAG, SVF, USB, SD, and memory
  standards communities and implementation authors underlying the interfaces.

Names of standards/interfaces are descriptive. Their marks belong to their
respective owners.

## Documentation, testing, manufacturing, and community help

Credit also belongs to people who never authored a line in the main repository
but improved the project by:

- manufacturing or assembling open FPGA boards;
- testing bitstreams and firmware on real board revisions;
- reporting timing, placement, routing, video, SD, UART, I2C, USB, browser, or
  toolchain issues;
- publishing schematics, pinouts, device errata, programming notes, and
  measurement results;
- maintaining synthesis/device databases and reverse-engineering bitstreams;
- maintaining compilers, debuggers, operating systems, browsers, package
  repositories, CI runners, documentation hosts, and mirrors;
- reviewing patches and documenting regressions;
- preserving historical DOOM compatibility/source knowledge;
- funding or donating hardware, infrastructure, time, or test equipment;
- answering questions in issue trackers, forums, chats, conferences, and maker
  communities;
- making low-cost open FPGA/RISC-V systems accessible to students and hobbyists.

All of those contributions are part of Hazard3-Doom's practical lineage even
where no direct copyright relationship exists.

## No endorsement or affiliation

Attribution is gratitude and provenance, not endorsement. Unless explicitly
stated by the named party, none of the people, companies, foundations,
communities, standards bodies, projects, or trademark owners listed here
sponsors, endorses, certifies, or is affiliated with Hazard3-Doom.

All trademarks, service marks, product names, logos, and project names remain
the property of their respective owners.

## Keeping this file complete

When adding any third-party source, HDL, patch, example, binary, firmware,
benchmark, artwork, font, JavaScript library, protocol implementation, board
support, generated-data source, or development tool copied into a release,
update this file and `LICENSES/` in the same change.

For projects with many contributors, their upstream Git history and contributor
list are incorporated into this acknowledgement by reference. A missing name
should be added rather than treated as evidence that the person's contribution
is unappreciated.
