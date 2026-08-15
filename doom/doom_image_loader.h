#ifndef DOOM_IMAGE_LOADER_H
#define DOOM_IMAGE_LOADER_H

#include <stdint.h>

typedef int (*doom_image_stream_read_fn)(void* context, void* buffer,
    uint32_t byte_count);

int doom_image_loader_receive(void);
int doom_image_loader_load_stream(doom_image_stream_read_fn read_fn,
    void* context);
int doom_image_loader_launch(void);
void doom_image_loader_invalidate(void);
void doom_image_loader_print_status(void);
uint32_t doom_image_loader_receive_runs(void);
uint32_t doom_image_loader_receive_failures(void);
uint32_t doom_image_loader_launch_runs(void);
uint32_t doom_image_loader_launch_failures(void);
int doom_image_loader_is_loaded(void);

#endif
