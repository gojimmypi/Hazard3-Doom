#ifndef HAZARD3_SD_SPI_H
#define HAZARD3_SD_SPI_H

#include <stdint.h>

typedef struct hazard3_sd_card {
    uint32_t initialized;
    uint32_t high_capacity;
    uint32_t ocr;
} hazard3_sd_card_t;

int hazard3_sd_init(hazard3_sd_card_t* card);
int hazard3_sd_read_block(const hazard3_sd_card_t* card, uint32_t lba,
    uint8_t* block512);
void hazard3_sd_print_status(const hazard3_sd_card_t* card);

#endif
