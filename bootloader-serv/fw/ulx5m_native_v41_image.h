/* Read-only validation of the v41 raw GateMate bitstream at 0x201000.
 * This is an exact-image diagnostic, not a general-purpose image manifest.
 */
#ifndef ULX5M_NATIVE_V41_IMAGE_H
#define ULX5M_NATIVE_V41_IMAGE_H
#include <stdint.h>
#include "ulx5m_normal_image.h"

#define ULX5M_V41_NATIVE_ADDR 0x00201000u
#define ULX5M_V41_NATIVE_BYTES 3026u
#define ULX5M_V41_NATIVE_SECTOR_BYTES 4096u
#define ULX5M_V41_NATIVE_CRC32 0x3377f62bu

enum ulx5m_v41_probe_result {
    ULX5M_V41_STAY_DFU_BTN2 = 0,
    ULX5M_V41_BAD_READER = 1,
    ULX5M_V41_READ_ERROR = 2,
    ULX5M_V41_INVALID_IMAGE = 3,
    ULX5M_V41_VERIFIED_ONLY = 4
};

/* Uses only the supplied read callback, at exactly 0x201000..0x201fff.
 * BTN2 is the STARTUP-LATCHED state. No callback is used when BTN2 is held.
 * A verified result DOES NOT request/authorize a configuration handoff.
 */
enum ulx5m_v41_probe_result
ulx5m_v41_native_probe(const struct ulx5m_normal_image_reader *reader,
                       int btn2_selected_latched, uint32_t *image_crc32);
#endif
