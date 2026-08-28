/* -----------------------------------------------------------------------------
 * File:        sao_console.c
 * Path:        src/sao_console.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Implement resident monitor console commands for SAO/I2C control
 *              and diagnostics.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the Apache License, Version 2.0.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * This software is provided under the terms of the applicable license.
 * See LICENSES/Apache-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */

#include "sao_console.h"

#include <stddef.h>
#include <stdint.h>

#include "doom/hazard3_sao.h"
#include "i2cdriver_hdmi.h"

#define SAO_CONSOLE_LINE_BYTES 64u
#define SAO_SCAN_CAPACITY      112u
#define SAO_I2C_HZ             100000u

static hazard3_sao_console_putc_fn console_putc;
static hazard3_sao_console_puts_fn console_puts;
static char console_line[SAO_CONSOLE_LINE_BYTES];
static size_t console_line_length;
static int console_line_active;
static int console_swallow_lf;

static int ascii_space(char value)
{
    return value == ' ' || value == '\t';
}

static char ascii_lower(char value)
{
    if (value >= 'A' && value <= 'Z') {
        return (char)(value - 'A' + 'a');
    }
    return value;
}

static int string_equal_ci(const char* left, const char* right)
{
    while (*left != '\0' && *right != '\0') {
        if (ascii_lower(*left) != ascii_lower(*right)) {
            return 0;
        }
        ++left;
        ++right;
    }
    return *left == '\0' && *right == '\0';
}

static int hex_digit(char value)
{
    value = ascii_lower(value);
    if (value >= '0' && value <= '9') {
        return value - '0';
    }
    if (value >= 'a' && value <= 'f') {
        return value - 'a' + 10;
    }
    return -1;
}

/* Monitor operands are hexadecimal by default; an optional 0x prefix is accepted. */
static int parse_hex_byte(const char* text, uint8_t* value)
{
    unsigned int result = 0u;
    unsigned int digits = 0u;
    int digit;

    if (text == NULL || value == NULL || *text == '\0') {
        return 0;
    }
    if (text[0] == '0' && ascii_lower(text[1]) == 'x') {
        text += 2;
    }
    while (*text != '\0') {
        digit = hex_digit(*text++);
        if (digit < 0 || digits >= 2u) {
            return 0;
        }
        result = (result << 4) | (unsigned int)digit;
        ++digits;
    }
    if (digits == 0u) {
        return 0;
    }
    *value = (uint8_t)result;
    return 1;
}

static void put_hex8(uint8_t value)
{
    static const char digits[] = "0123456789ABCDEF";

    console_puts("0x");
    console_putc((uint8_t)digits[(value >> 4) & 0x0fu]);
    console_putc((uint8_t)digits[value & 0x0fu]);
}

static void put_hex32(uint32_t value)
{
    static const char digits[] = "0123456789ABCDEF";
    int shift;

    console_puts("0x");
    for (shift = 28; shift >= 0; shift -= 4) {
        console_putc((uint8_t)digits[(value >> (uint32_t)shift) & 0x0fu]);
    }
}

static void put_uint(size_t value)
{
    char buffer[12];
    size_t count = 0u;

    if (value == 0u) {
        console_putc((uint8_t)'0');
        return;
    }
    while (value != 0u && count < sizeof(buffer)) {
        buffer[count++] = (char)('0' + (value % 10u));
        value /= 10u;
    }
    while (count != 0u) {
        console_putc((uint8_t)buffer[--count]);
    }
}

static const char* result_name(int rc)
{
    switch (rc) {
    case HAZARD3_SAO_OK:
        return "OK";
    case HAZARD3_SAO_ERR_TIMEOUT:
        return "TIMEOUT";
    case HAZARD3_SAO_ERR_NACK:
        return "NACK";
    case HAZARD3_SAO_ERR_REJECTED:
        return "REJECTED";
    case HAZARD3_SAO_ERR_ARGUMENT:
        return "ARGUMENT";
    default:
        return "ERROR";
    }
}

static size_t tokenize(char* line, char* argv[], size_t capacity)
{
    size_t argc = 0u;
    char* cursor = line;

    while (*cursor != '\0') {
        while (ascii_space(*cursor)) {
            ++cursor;
        }
        if (*cursor == '\0') {
            break;
        }
        if (argc >= capacity) {
            return capacity + 1u;
        }
        argv[argc++] = cursor;
        while (*cursor != '\0' && !ascii_space(*cursor)) {
            ++cursor;
        }
        if (*cursor != '\0') {
            *cursor++ = '\0';
        }
    }
    return argc;
}

static void print_usage(void)
{
    console_puts("Usage:\r\n");
    console_puts("  sao info\r\n");
    console_puts("  sao gui\r\n");
    console_puts("  sao recover\r\n");
    console_puts("  sao scan\r\n");
    console_puts("  sao probe <addr>\r\n");
    console_puts("  sao read <addr> <reg>\r\n");
    console_puts("  sao write <addr> <reg> <value>\r\n");
    console_puts("  i2c scan\r\n");
    console_puts("  i2c gui\r\n");
    console_puts("Operands are hexadecimal; 0x prefix is optional.\r\n");
}

static void command_info(void)
{
    uint32_t id = hazard3_sao_bridge_id();
    uint32_t version = hazard3_sao_bridge_version();

    console_puts("SAO bridge id=");
    put_hex32(id);
    console_puts(" version=");
    put_hex32(version);
    console_puts(" status=");
    put_hex32(hazard3_sao_status());
    console_puts(" i2c=100000 Hz\r\n");
    if (id != HAZARD3_SAO_BRIDGE_ID) {
        console_puts("WARNING: expected bridge ID 0x53414F31 (SAO1).\r\n");
    }
}

static void command_gui(void)
{
    console_puts("Starting I2CDriver HDMI...\r\n");
    hazard3_i2cdriver_hdmi_run();
    console_puts("I2CDriver HDMI returned to monitor.\r\n");
}

static void command_scan(void)
{
    uint8_t addresses[SAO_SCAN_CAPACITY];
    size_t count;
    size_t shown;
    size_t i;

    console_puts("Scanning I2C 0x08..0x77...\r\n");
    count = hazard3_sao_scan(addresses, sizeof(addresses));
    shown = count < sizeof(addresses) ? count : sizeof(addresses);
    for (i = 0u; i < shown; ++i) {
        console_puts("  ACK ");
        put_hex8(addresses[i]);
        console_puts("\r\n");
    }
    put_uint(count);
    console_puts(count == 1u ? " device found\r\n" : " devices found\r\n");
}

static int execute_sao(size_t argc, char* argv[])
{
    uint8_t address;
    uint8_t reg;
    uint8_t value;
    int rc;

    if (argc == 2u && string_equal_ci(argv[1], "gui")) {
        command_gui();
        return 1;
    }
    if (argc == 2u && string_equal_ci(argv[1], "info")) {
        command_info();
        return 1;
    }
    if (argc == 2u && string_equal_ci(argv[1], "recover")) {
        rc = hazard3_sao_recover();
        console_puts("SAO recover: ");
        console_puts(result_name(rc));
        console_puts(" status=");
        put_hex32(hazard3_sao_status());
        console_puts("\r\n");
        return 1;
    }
    if (argc == 2u && string_equal_ci(argv[1], "scan")) {
        command_scan();
        return 1;
    }
    if (argc == 3u && string_equal_ci(argv[1], "probe")) {
        if (!parse_hex_byte(argv[2], &address) || address > 0x7fu) {
            print_usage();
            return 1;
        }
        rc = hazard3_sao_probe(address);
        console_puts("SAO probe ");
        put_hex8(address);
        console_puts(": ");
        console_puts(result_name(rc));
        console_puts(" status=");
        put_hex32(hazard3_sao_status());
        console_puts("\r\n");
        return 1;
    }
    if (argc == 4u && string_equal_ci(argv[1], "read")) {
        if (!parse_hex_byte(argv[2], &address) || address > 0x7fu ||
            !parse_hex_byte(argv[3], &reg)) {
            print_usage();
            return 1;
        }
        value = 0u;
        rc = hazard3_sao_read_reg8(address, reg, &value);
        console_puts("SAO read addr=");
        put_hex8(address);
        console_puts(" reg=");
        put_hex8(reg);
        console_puts(": ");
        if (rc == HAZARD3_SAO_OK) {
            put_hex8(value);
        } else {
            console_puts(result_name(rc));
        }
        console_puts("\r\n");
        return 1;
    }
    if (argc == 5u && string_equal_ci(argv[1], "write")) {
        if (!parse_hex_byte(argv[2], &address) || address > 0x7fu ||
            !parse_hex_byte(argv[3], &reg) ||
            !parse_hex_byte(argv[4], &value)) {
            print_usage();
            return 1;
        }
        rc = hazard3_sao_write_reg8(address, reg, value);
        console_puts("SAO write addr=");
        put_hex8(address);
        console_puts(" reg=");
        put_hex8(reg);
        console_puts(" value=");
        put_hex8(value);
        console_puts(": ");
        console_puts(result_name(rc));
        console_puts("\r\n");
        return 1;
    }
    return 0;
}

static void execute_line(char* line)
{
    char* argv[5];
    size_t argc = tokenize(line, argv, sizeof(argv) / sizeof(argv[0]));

    if (argc == 2u && string_equal_ci(argv[0], "i2c")) {
        if (string_equal_ci(argv[1], "scan")) {
            command_scan();
            return;
        }
        if (string_equal_ci(argv[1], "gui")) {
            command_gui();
            return;
        }
    }
    if (argc <= sizeof(argv) / sizeof(argv[0]) && argc != 0u &&
        string_equal_ci(argv[0], "sao") && execute_sao(argc, argv)) {
        return;
    }
    console_puts("Unknown SAO/I2C command.\r\n");
    print_usage();
}

void hazard3_sao_console_init(
    hazard3_sao_console_putc_fn putc_fn,
    hazard3_sao_console_puts_fn puts_fn,
    uint32_t sys_clk_hz)
{
    console_putc = putc_fn;
    console_puts = puts_fn;
    console_line_length = 0u;
    console_line_active = 0;
    console_swallow_lf = 0;

    if (hazard3_sao_bridge_id() == HAZARD3_SAO_BRIDGE_ID) {
        hazard3_sao_init(sys_clk_hz, SAO_I2C_HZ);
    }
}

void hazard3_sao_console_print_help(void)
{
    console_puts("  sao info                 bridge ID/version/status\r\n");
    console_puts("  sao gui                  I2CDriver-style HDMI interface\r\n");
    console_puts("  sao recover              I2C bus recovery\r\n");
    console_puts("  sao scan                 scan I2C addresses 0x08..0x77\r\n");
    console_puts("  sao probe <addr>         probe one 7-bit I2C address\r\n");
    console_puts("  sao read <addr> <reg>    read one 8-bit register\r\n");
    console_puts("  sao write <a> <r> <v>    write one 8-bit register\r\n");
    console_puts("  i2c scan                 alias for sao scan\r\n");
    console_puts("  i2c gui                  alias for sao gui\r\n");
}

int hazard3_sao_console_feed(uint8_t received)
{
    if (console_swallow_lf != 0) {
        console_swallow_lf = 0;
        if (received == (uint8_t)'\n') {
            return HAZARD3_SAO_CONSOLE_CONSUMED;
        }
    }

    if (console_line_active == 0) {
        if (received != (uint8_t)'s' && received != (uint8_t)'S' &&
            received != (uint8_t)'i' && received != (uint8_t)'I') {
            return HAZARD3_SAO_CONSOLE_NOT_CONSUMED;
        }
        console_line_active = 1;
        console_line_length = 1u;
        console_line[0] = (char)received;
        console_putc(received);
        return HAZARD3_SAO_CONSOLE_CONSUMED;
    }

    if (received == (uint8_t)'\r' || received == (uint8_t)'\n') {
        int status_command;

        console_line[console_line_length] = '\0';
        status_command = console_line_length == 1u &&
            ascii_lower(console_line[0]) == 's';
        console_line_active = 0;
        console_line_length = 0u;
        if (received == (uint8_t)'\r') {
            console_swallow_lf = 1;
        }
        if (status_command) {
            return HAZARD3_SAO_CONSOLE_STATUS;
        }
        console_puts("\r\n");
        execute_line(console_line);
        console_puts("> ");
        return HAZARD3_SAO_CONSOLE_CONSUMED;
    }

    if (received == 0x08u || received == 0x7fu) {
        if (console_line_length > 1u) {
            --console_line_length;
            console_puts("\b \b");
        }
        return HAZARD3_SAO_CONSOLE_CONSUMED;
    }

    if (console_line_length + 1u >= sizeof(console_line)) {
        console_puts("\r\nSAO/I2C command too long.\r\n> ");
        console_line_active = 0;
        console_line_length = 0u;
        return HAZARD3_SAO_CONSOLE_CONSUMED;
    }

    console_line[console_line_length++] = (char)received;
    console_putc(received);
    return HAZARD3_SAO_CONSOLE_CONSUMED;
}
