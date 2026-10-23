/* Bounded normal-image read/transport. Integrity is NOT authorization. */
#ifndef ULX5M_NORMAL_BOOT_H
#define ULX5M_NORMAL_BOOT_H
#include <stdint.h>
#include "ulx5m_normal_image.h"

#define ULX5M_NORMAL_BOOT_SLOT 0x00200000u
#define ULX5M_NORMAL_BOOT_MAX_BYTES 0x001fff00u

enum ulx5m_normal_boot_result {
    ULX5M_BOOT_DFU_SELECTED = 0,
    ULX5M_BOOT_NO_IMAGE = 1,
    ULX5M_BOOT_INVALID = 2,
    ULX5M_BOOT_VALID_BLOCKED = 3,
    ULX5M_BOOT_STREAM_ERROR = 4,
    ULX5M_BOOT_STREAM_COMPLETE = 5
};

struct ulx5m_normal_boot_transport {
    void *ctx;
    int (*prepare)(void *ctx, uint32_t bytes);
    int (*send)(void *ctx, uint8_t byte);
    int (*finish)(void *ctx);
    void (*abort)(void *ctx);
};

/* All operations are read-only except the explicit configuration transport.
 * authorize_stream is an external policy gate, never inferred from U5IM.
 * With authorize_stream==0 no transport callback is ever invoked.
 */
enum ulx5m_normal_boot_result
ulx5m_normal_boot_run(const struct ulx5m_normal_image_reader *reader,
                      const struct ulx5m_normal_boot_transport *transport,
                      int dfu_selected, int authorize_stream);
#endif
