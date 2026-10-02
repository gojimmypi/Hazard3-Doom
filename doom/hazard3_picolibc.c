/* -----------------------------------------------------------------------------
 * File:        hazard3_picolibc.c
 * Path:        doom/hazard3_picolibc.c
 *
 * Project:     Hazard3-Doom
 * Purpose:     Adapt the existing Newlib-style syscall layer to Picolibc's
 *              POSIX syscall names and tinystdio console globals.
 *
 * Copyright (c) 2026 gojimmypi
 *
 * Licensed under the GNU General Public License, version 2 or later.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * This software is provided WITHOUT ANY WARRANTY.
 * See LICENSES/GPL-2.0.txt for the complete license terms.
 * See LICENSING.md for project licensing policy and scope.
 * -------------------------------------------------------------------------- */
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/types.h>

void* _sbrk(ptrdiff_t increment);
int _close(int file);
int _fstat(int file, struct stat* status);
int _gettimeofday(struct timeval* time_value, void* timezone_value);
int _isatty(int file);
int _kill(int process_id, int signal_number);
off_t _lseek(int file, off_t offset, int direction);
int _open(const char* path, int flags, ...);
ssize_t _read(int file, void* buffer, size_t byte_count);
int _stat(const char* path, struct stat* status);
clock_t _times(struct tms* times_buffer);
int _unlink(const char* path);
ssize_t _write(int file, const void* buffer, size_t byte_count);

static int hazard3_picolibc_console_putc(char character, FILE* stream)
{
    const uint8_t byte = (uint8_t)(unsigned char)character;
    ssize_t written;

    (void)stream;
    written = _write(1, &byte, 1u);
    if (written == 1) {
        return (unsigned char)character;
    }
    return _FDEV_ERR;
}

static int hazard3_picolibc_console_getc(FILE* stream)
{
    uint8_t byte;
    ssize_t received;

    (void)stream;
    for (;;) {
        received = _read(0, &byte, 1u);
        if (received == 1) {
            return (int)byte;
        }
        if (received < 0) {
            return _FDEV_ERR;
        }
    }
}

static FILE hazard3_picolibc_stdin = FDEV_SETUP_STREAM(
    NULL,
    hazard3_picolibc_console_getc,
    NULL,
    _FDEV_SETUP_READ);
static FILE hazard3_picolibc_stdout = FDEV_SETUP_STREAM(
    hazard3_picolibc_console_putc,
    NULL,
    NULL,
    _FDEV_SETUP_WRITE);
static FILE hazard3_picolibc_stderr = FDEV_SETUP_STREAM(
    hazard3_picolibc_console_putc,
    NULL,
    NULL,
    _FDEV_SETUP_WRITE);

FILE *const stdin = &hazard3_picolibc_stdin;
FILE *const stdout = &hazard3_picolibc_stdout;
FILE *const stderr = &hazard3_picolibc_stderr;

void* sbrk(intptr_t increment)
{
    return _sbrk((ptrdiff_t)increment);
}

int close(int file)
{
    return _close(file);
}

int fstat(int file, struct stat* status)
{
    return _fstat(file, status);
}

int gettimeofday(struct timeval* time_value, void* timezone_value)
{
    return _gettimeofday(time_value, timezone_value);
}

int isatty(int file)
{
    return _isatty(file);
}

int kill(int process_id, int signal_number)
{
    return _kill(process_id, signal_number);
}

off_t lseek(int file, off_t offset, int direction)
{
    return _lseek(file, offset, direction);
}

int open(const char* path, int flags, ...)
{
    return _open(path, flags);
}

ssize_t read(int file, void* buffer, size_t byte_count)
{
    return _read(file, buffer, byte_count);
}

int stat(const char* path, struct stat* status)
{
    return _stat(path, status);
}

clock_t times(struct tms* times_buffer)
{
    return _times(times_buffer);
}

int unlink(const char* path)
{
    return _unlink(path);
}

int rename(const char* old_path, const char* new_path)
{
    (void)old_path;
    (void)new_path;
    errno = EROFS;
    return -1;
}

ssize_t write(int file, const void* buffer, size_t byte_count)
{
    return _write(file, buffer, byte_count);
}
