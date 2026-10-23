/* Read-only candidate image inspection. Not a boot authorization policy.
 * The factory layout and a persistent application slot are NOT verified.
 */
#ifndef ULX5M_NORMAL_IMAGE_H
#define ULX5M_NORMAL_IMAGE_H

#include <stdint.h>

#define ULX5M_NORMAL_IMAGE_CANDIDATE_MIN 0x00200000u
#define ULX5M_NORMAL_IMAGE_HEADER_BYTES 32u
#define ULX5M_NORMAL_IMAGE_VERSION 1u
#define ULX5M_NORMAL_IMAGE_GATEMATE 1u

/* Return zero on success; no writes are supported by this interface. */
struct ulx5m_normal_image_reader {
    void *ctx;
    int (*read)(void *ctx, uint32_t address, uint8_t *data, unsigned length);
};

/* Integrity OK means the provisional U5IM wrapper and payload match.
 * It does NOT mean GateMate can configure from that payload, that the
 * address is a safe flash slot, or that execution/reconfiguration is allowed.
 */
enum ulx5m_normal_image_result {
    ULX5M_NORMAL_IMAGE_INTEGRITY_OK = 0,
    ULX5M_NORMAL_IMAGE_ABSENT = 1,
    ULX5M_NORMAL_IMAGE_BAD_HEADER = 2,
    ULX5M_NORMAL_IMAGE_BAD_RANGE = 3,
    ULX5M_NORMAL_IMAGE_BAD_PAYLOAD = 4,
    ULX5M_NORMAL_IMAGE_IO_ERROR = 5
};

struct ulx5m_normal_image_info {
    uint32_t header_address;
    uint32_t payload_address;
    uint32_t payload_bytes;
    uint32_t expected_crc32;
};

/* Candidate address must be in the upper 2 MiB, sector aligned. Read only. */
enum ulx5m_normal_image_result
ulx5m_normal_image_probe(const struct ulx5m_normal_image_reader *reader,
                         uint32_t candidate_address,
                         struct ulx5m_normal_image_info *info);

#endif
