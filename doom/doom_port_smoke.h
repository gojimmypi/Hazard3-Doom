#ifndef DOOM_PORT_SMOKE_H
#define DOOM_PORT_SMOKE_H

#include <stdint.h>

int doom_port_smoke_run(void);
uint32_t doom_port_smoke_runs(void);
uint32_t doom_port_smoke_failures(void);
uint32_t doom_port_smoke_last_elapsed_ms(void);
uint32_t doom_port_smoke_last_heap_used(void);
int doom_port_smoke_last_passed(void);

#endif
