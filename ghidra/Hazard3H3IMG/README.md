# Hazard3 H3IMG Ghidra loader and MMIO analyzer

This Ghidra extension loads Hazard3-Doom `.h3img` application images directly
and annotates the current Hazard3-Doom APB/MMIO map for reverse-engineering and
training. It targets the current `H3I1` package format and Ghidra 12.1.x.

The loader is intentionally board-neutral. It uses the load, entry, and BSS
addresses stored in each H3IMG header instead of assuming a ULX3S/ULX4M board or
32 MiB/64 MiB memory profile.

## What the loader does

When a valid `.h3img` is imported, the loader:

- recognizes `H3I1` (`0x31493348` as the little-endian 32-bit magic value);
- validates the fixed 64-byte, version-1 header and reserved words;
- validates the package length and 32-bit address ranges;
- verifies the IEEE CRC32 over the payload before mapping it;
- selects Ghidra's `RISCV:LE:32:default` language with the `gcc` compiler spec;
- maps only the executable payload at the H3IMG load address;
- creates an uninitialized read/write BSS block when `bss_bytes` is nonzero;
- creates `h3img_image_start`, `h3img_entry`, and `h3img_bss` labels; and
- marks `h3img_entry` as an external entry point for analysis.

The payload block is read/write/execute because H3IMG is a flat application
container and does not carry ELF-style per-section permissions. The 64-byte
container header is not mapped into the RISC-V address space. Ghidra does not
execute the boot monitor or initialize BSS contents; it represents BSS as
uninitialized memory for static analysis.

## Hazard3-Doom MMIO analyzer

For programs imported by this H3IMG loader, the **Hazard3-Doom MMIO Map**
analyzer is enabled by default. It is intentionally separate from the container
loader so the H3IMG format remains board-neutral.

The analyzer creates read/write, non-executable, volatile APB blocks and defines
each known register as a 32-bit `dword` with an imported symbol and an EOL
comment. It is idempotent: rerunning analysis reuses matching blocks and labels
rather than duplicating them.

Current APB windows applied by the analyzer:

| CPU address | Block | Registers named by the analyzer |
| --- | --- | --- |
| `0x40000000` | `APB_TIMER` | `TIMER_CTRL`, `TIMER_MTIME`, `TIMER_MTIMEH`, `TIMER_MTIMECMP`, `TIMER_MTIMECMPH` |
| `0x40004000` | `APB_UART` | `UART_CSR`, `UART_DIV`, `UART_FSTAT`, `UART_TX`, `UART_RX` |
| `0x40008000` | `APB_GPIO` | `GPIO_OUT` |
| `0x40009000` | `APB_SAO` | command, status, TX/RX data, clock, timeout, GPIO, line-state, ID, version, owner |
| `0x4000a000` | `APB_SD` | `SD_CTRL`, `SD_CLKDIV`, `SD_DATA`, `SD_STATUS`, `SD_OWNER` |
| `0x4000c000` | `APB_VIDEO` | current `HAZARD3_VIDEO_*` status/control/palette/frame/build/direct-access registers |

The analyzer defines MMIO address ranges and register symbols, making direct
references easier to recognize during analysis. For example, `0x4000400c` is
labeled `UART_TX`, and addresses near `0x4000c000` have video register names.
Ghidra does not necessarily resolve computed or indirect accesses to these
registers automatically; some references require manual analysis.

## H3IMG header used by this loader

Defined in [doom_image_format.h](https://github.com/ulx3s/Hazard3-Doom/blob/main/doom/doom_image_format.h) is 
the `hazard3_doom_image_header_t` struct, which is used to represent the header of a Hazard3 image file.

All fields are little-endian 32-bit unsigned values.

| Offset | Field | Required value / meaning |
| --- | --- | --- |
| `0x00` | magic | `H3I1` / `0x31493348` |
| `0x04` | header bytes | `64` |
| `0x08` | format version | `1` |
| `0x0c` | flags | `1` (payload CRC32 present) |
| `0x10` | load address | payload destination address |
| `0x14` | image bytes | payload byte count |
| `0x18` | entry address | RISC-V entry point |
| `0x1c` | BSS address | start of zero/uninitialized storage |
| `0x20` | BSS bytes | BSS byte count |
| `0x24` | payload CRC32 | IEEE CRC32 of the payload |
| `0x28`-`0x3f` | reserved | all zero |

The loader also requires the entry point to be inside the payload and rejects a
nonempty BSS range that overlaps the payload.

## Requirements

Build the extension against the Ghidra installation that will load it.

For Ghidra 12.1.3 and 12.1.4, the required tool versions are:

- 64-bit Java Development Kit (JDK) 21;
- Gradle 8.5 or newer.

Both versions declare `application.java.min=21`,
`application.java.compiler=21`, and `application.gradle.min=8.5`. The maximum
Java and Gradle versions are left unspecified.

For another Ghidra release, check its requirements directly in
`Ghidra/application.properties` instead of assuming the same versions.

PowerShell example:

```powershell
$ghidra = "C:\Download\Ghidra\ghidra_12.1.3_PUBLIC"

Select-String `
    -Path "$ghidra\Ghidra\application.properties" `
    -Pattern '^application\.(java|gradle)\.(min|max|compiler)='
```

The Ghidra directory must also contain:

```text
Ghidra\application.properties
support\buildExtension.gradle
```

This extension is Java-only. Building it does not require Python, a C/C++
compiler, Visual Studio, an FPGA toolchain, or the RISC-V GCC toolchain.

### Install Java 21 on Windows

If Ghidra 12.1.x already launches successfully with a JDK 21 installation,
another Java installation is not required.

Otherwise, Microsoft OpenJDK 21 can be installed from PowerShell:

```powershell
winget install Microsoft.OpenJDK.21
```

Open a new PowerShell window after installation, then verify both the runtime
and compiler:

```powershell
java -version
javac -version
```

Both commands should report Java 21. If multiple JDKs are installed and Gradle
selects the wrong one, set `JAVA_HOME` to the JDK 21 installation directory and
put its `bin` directory first in `PATH`.

Example for the current PowerShell session:

```powershell
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

Adjust that path to the actual installed JDK directory.

### Install Gradle 8.5 on Windows

This repository does not include a Gradle Wrapper, so `gradle` must be
installed separately.

For a controlled Ghidra 12.1.x build, Gradle 8.5 can be installed directly
from the official Gradle distribution:

```powershell
$gradleVersion = "8.5"
$gradleZip = "$env:TEMP\gradle-$gradleVersion-bin.zip"

Invoke-WebRequest `
    "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip" `
    -OutFile $gradleZip

New-Item -ItemType Directory -Force C:\Gradle | Out-Null

Expand-Archive `
    -Path $gradleZip `
    -DestinationPath C:\Gradle `
    -Force

$env:GRADLE_HOME = "C:\Gradle\gradle-$gradleVersion"
$env:Path = "$env:GRADLE_HOME\bin;$env:Path"

gradle --version
```

For a permanent installation, add:

```text
C:\Gradle\gradle-8.5\bin
```

to the Windows user or system `PATH`.

A package-manager installation is also possible:

```powershell
winget install Gradle.Gradle
```

If using a package-manager version, verify with `gradle --version` that it
meets the minimum declared by the target Ghidra installation.

### Install requirements on Ubuntu or WSL

Install JDK 21 and the utilities needed to unpack Gradle:

```bash
sudo apt update
sudo apt install -y openjdk-21-jdk curl unzip
```

Verify Java:

```bash
java -version
javac -version
```

Install Gradle 8.5 under the current user's home directory:

```bash
gradle_version=8.5
gradle_zip="/tmp/gradle-${gradle_version}-bin.zip"

curl -L \
    "https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip" \
    -o "${gradle_zip}"

mkdir -p "${HOME}/.local/gradle"
unzip -q "${gradle_zip}" -d "${HOME}/.local/gradle"

export GRADLE_HOME="${HOME}/.local/gradle/gradle-${gradle_version}"
export PATH="${GRADLE_HOME}/bin:${PATH}"

gradle --version
```

Do not assume the Ubuntu `gradle` package is new enough. Check its version
before using it.

To keep this Gradle installation on `PATH`, add the `GRADLE_HOME` and `PATH`
exports above to the appropriate shell startup file.

## Build

### Windows PowerShell

From the Hazard3-Doom repository:

```powershell
cd C:\workspace\Hazard3-Doom\ghidra\Hazard3H3IMG

$env:GHIDRA_INSTALL_DIR = "C:\Download\Ghidra\ghidra_12.1.3_PUBLIC"

gradle buildExtension
```

Change `GHIDRA_INSTALL_DIR` when building for a different Ghidra installation.

Verify that the extension ZIP was produced:

```powershell
Get-ChildItem .\dist\*.zip
```

### Ubuntu or WSL

Using a Linux Ghidra installation:

```bash
cd ghidra/Hazard3H3IMG
export GHIDRA_INSTALL_DIR=/opt/ghidra_12.1.3_PUBLIC
gradle buildExtension
```

When building in WSL against the Windows Ghidra installation used in the
examples above, the corresponding mounted path is:

```bash
export GHIDRA_INSTALL_DIR=/mnt/c/Download/Ghidra/ghidra_12.1.3_PUBLIC
gradle buildExtension
```

The built extension ZIP is written under `dist/`.

### Build troubleshooting

If `gradle` is not recognized, Gradle is not installed or its `bin` directory
is not on `PATH`.

If the build reports an unsupported Java or Gradle version, compare:

```text
gradle --version
```

with the values in:

```text
<GHIDRA_INSTALL_DIR>/Ghidra/application.properties
```

If `GHIDRA_INSTALL_DIR` is reported as missing or invalid, confirm that it
points to the extracted Ghidra root directory, not to the `Ghidra` subdirectory
inside it.

## Install

In the Ghidra front end:

1. Open **File -> Install Extensions**.
2. Use the add button to select the ZIP produced under `dist/` if it is not
   already listed.
3. Enable **Hazard3H3IMG**.
4. Restart Ghidra when prompted.

## Import an H3IMG

Import a current Hazard3-Doom `.h3img` normally. For a recognized package,
Ghidra should offer **Hazard3 H3IMG** and select the 32-bit little-endian RISC-V
language automatically.

A typical image appears as:

```text
h3img_payload  load ... load+image_bytes-1   RWX
h3img_bss      bss  ... bss+bss_bytes-1      RW-
```

Start analysis from the generated `h3img_entry` symbol. Leave **Hazard3-Doom
MMIO Map** enabled in the analysis options to get the peripheral blocks and
register names automatically. String references such as `H3L READY`,
monitor-service messages, Doom startup messages, and named MMIO accesses make
useful reverse-engineering training exercises when present in the particular
application image.

## Scope

The loader handles only the H3IMG application container; the separate analyzer
adds the current Hazard3-Doom APB/MMIO map. The extension does not try to
reconstruct the original ELF section boundaries, debug information, function
names, or source-level symbols that were removed when the flat payload was
packaged. Keep the matching ELF as a reference artifact when training material
needs a ground-truth comparison.
