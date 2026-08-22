# OpenOCD / xPack notice

Hazard3-Doom documentation and logs identify a bundled `bin/openocd.exe`; a
recorded run shows an xPack OpenOCD distribution layout.

Upstream OpenOCD:
https://github.com/openocd-org/openocd

xPack OpenOCD distribution:
https://xpack-dev-tools.github.io/openocd-xpack/

Current OpenOCD source identifies GPL-2.0-or-later. The xPack project is
maintained by Liviu Ionescu and documents that its binary archives include the
licenses for their bundled open-source components under `distro-info/licenses`.

For a redistributed xPack executable, do not ship only a generic GPL file.
Preserve the complete license/notice set from the exact xPack archive used,
record the version and SHA-256, and satisfy applicable source-availability
requirements for the OpenOCD binary and any other copyleft components.

`GPL-2.0.txt` is included as a license reference, but exact "or later" grants
and component notices remain controlled by the matching source/archive.
