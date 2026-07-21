#ifndef SDRAM_EXEC_TEST_H
#define SDRAM_EXEC_TEST_H

#include <stdint.h>

int sdram_exec_test_run(void);
void sdram_exec_test_note_timer_pc(uint32_t mepc);

uint32_t sdram_exec_test_runs(void);
uint32_t sdram_exec_test_failures(void);
uint32_t sdram_exec_test_last_elapsed_ms(void);
uint32_t sdram_exec_test_last_timer_hits(void);
uint32_t sdram_exec_test_last_result(void);
uint32_t sdram_exec_test_last_expected(void);
uint32_t sdram_exec_test_payload_bytes(void);
int sdram_exec_test_last_passed(void);

#endif
