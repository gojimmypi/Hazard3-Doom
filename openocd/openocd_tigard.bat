REM -----------------------------------------------------------------------------
REM File:        openocd_tigard.bat
REM Path:        openocd/openocd_tigard.bat
REM
REM Project:     Hazard3-Doom
REM Purpose:     Launch the Tigard-oriented OpenOCD configuration used for
REM              ULX4M Hazard3 debug from Windows.
REM
REM Copyright (c) 2026 gojimmypi
REM
REM Licensed under the Apache License, Version 2.0.
REM
REM SPDX-License-Identifier: Apache-2.0
REM
REM This software is provided under the terms of the applicable license.
REM See LICENSES/Apache-2.0.txt for the complete license terms.
REM See LICENSING.md for project licensing policy and scope.
REM -----------------------------------------------------------------------------


C:\SysGCC\esp32-master\tools\openocd-esp32\v0.12.0-esp32-20240318\openocd-esp32\bin\openocd ^
    -d2 ^
    -f C:\workspace\hazard3\example_soc\ulx4m-openocd-tigard-fixed.cfg