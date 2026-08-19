/* SPDX-License-Identifier: Apache-2.0 */
#ifndef HAZARD3_I2CDRIVER_HDMI_H
#define HAZARD3_I2CDRIVER_HDMI_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Run the I2CDriver-inspired interactive HDMI application.
 *
 * The application uses the existing Hazard3 SAO APB I2C master and the
 * indexed HDMI presentation path. The 320x200 mode retains the compact legacy
 * layout, while supported 400x240 bitstreams use a native higher-detail GUI.
 * It returns when the user presses Q, Escape, or Ctrl-X.
 */
void hazard3_i2cdriver_hdmi_run(void);

#ifdef __cplusplus
}
#endif

#endif
