#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/types.h>

#include "hazard3_platform.h"

#define MEMORY_WAD_FILE_DESCRIPTOR 3

static uint32_t memory_wad_position;
static int memory_wad_is_open;

static int path_matches_wad(const char* path)
{
    const char* wad_name = hazard3_wad_name();
    const char* base_name = path;
    if (path == (const char*)0 || wad_name == (const char*)0 ||
        hazard3_wad_bytes() == 0u) {
        return 0;
    }
    for (const char* cursor = path; *cursor != '\0'; ++cursor) {
        if (*cursor == '/' || *cursor == '\\') {
            base_name = cursor + 1;
        }
    }
    return strcmp(base_name, wad_name) == 0;
}

static void fill_wad_stat(struct stat* status)
{
    memset(status, 0, sizeof(*status));
    status->st_mode = S_IFREG | S_IRUSR;
    status->st_size = (off_t)hazard3_wad_bytes();
    status->st_nlink = 1;
}

void* _sbrk(ptrdiff_t increment)
{
    void* previous_break = hazard3_sbrk(increment);
    if (previous_break == (void*)(intptr_t)-1) {
        errno = ENOMEM;
    }
    return previous_break;
}

void _init(void) {}
void _fini(void) {}

int _execve(const char* path, char* const argv[], char* const envp[])
{
    (void)path; (void)argv; (void)envp; errno = ENOSYS; return -1;
}
int _fork(void) { errno = ENOSYS; return -1; }
int _link(const char* existing_path, const char* new_path)
{
    (void)existing_path; (void)new_path; errno = ENOSYS; return -1;
}

int _mkdir(const char* path, mode_t mode)
{
    (void)path; (void)mode; errno = ENOSYS; return -1;
}

int mkdir(const char* path, mode_t mode)
{
    return _mkdir(path, mode);
}
int _wait(int* status) { (void)status; errno = ECHILD; return -1; }

int _close(int file)
{
    if (file == MEMORY_WAD_FILE_DESCRIPTOR && memory_wad_is_open != 0) {
        memory_wad_is_open = 0;
        memory_wad_position = 0u;
        return 0;
    }
    errno = EBADF;
    return -1;
}

void _exit(int status)
{
    hazard3_console_puts("\r\nDoom image exited, status=");
    hazard3_console_put_hex32((uint32_t)status);
    hazard3_console_puts("\r\n");
    for (;;) { __asm__ volatile ("wfi"); }
}

int _fstat(int file, struct stat* status)
{
    if (status == (struct stat*)0) {
        errno = EINVAL;
        return -1;
    }
    if (file == MEMORY_WAD_FILE_DESCRIPTOR && memory_wad_is_open != 0) {
        fill_wad_stat(status);
        return 0;
    }
    if (file >= 0 && file <= 2) {
        memset(status, 0, sizeof(*status));
        status->st_mode = S_IFCHR;
        status->st_nlink = 1;
        return 0;
    }
    errno = EBADF;
    return -1;
}
int _getpid(void) { return 1; }

int _gettimeofday(struct timeval* time_value, void* timezone_value)
{
    uint32_t milliseconds;
    (void)timezone_value;
    if (time_value == (struct timeval*)0) { errno = EINVAL; return -1; }
    milliseconds = hazard3_ticks_ms();
    time_value->tv_sec = (time_t)(milliseconds / 1000u);
    time_value->tv_usec = (suseconds_t)((milliseconds % 1000u) * 1000u);
    return 0;
}

int _isatty(int file) { return file >= 0 && file <= 2; }
int _kill(int process_id, int signal_number)
{
    (void)process_id; (void)signal_number; errno = EINVAL; return -1;
}

off_t _lseek(int file, off_t offset, int direction)
{
    int64_t base;
    int64_t next_position;
    if (file != MEMORY_WAD_FILE_DESCRIPTOR || memory_wad_is_open == 0) {
        errno = ESPIPE;
        return (off_t)-1;
    }
    switch (direction) {
    case SEEK_SET:
        base = 0;
        break;
    case SEEK_CUR:
        base = (int64_t)memory_wad_position;
        break;
    case SEEK_END:
        base = (int64_t)hazard3_wad_bytes();
        break;
    default:
        errno = EINVAL;
        return (off_t)-1;
    }
    next_position = base + (int64_t)offset;
    if (next_position < 0 ||
        (uint64_t)next_position > (uint64_t)hazard3_wad_bytes()) {
        errno = EINVAL;
        return (off_t)-1;
    }
    memory_wad_position = (uint32_t)next_position;
    return (off_t)memory_wad_position;
}

int _open(const char* path, int flags, ...)
{
    if (!path_matches_wad(path)) {
        errno = ENOENT;
        return -1;
    }
    if ((flags & O_ACCMODE) != O_RDONLY) {
        errno = EROFS;
        return -1;
    }
    if (memory_wad_is_open != 0) {
        errno = EMFILE;
        return -1;
    }
    memory_wad_is_open = 1;
    memory_wad_position = 0u;
    return MEMORY_WAD_FILE_DESCRIPTOR;
}

ssize_t _read(int file, void* buffer, size_t byte_count)
{
    if (buffer == (void*)0) {
        errno = EINVAL;
        return -1;
    }
    if (file == MEMORY_WAD_FILE_DESCRIPTOR && memory_wad_is_open != 0) {
        uint32_t remaining = hazard3_wad_bytes() - memory_wad_position;
        size_t copy_count = byte_count;
        if (copy_count > (size_t)remaining) {
            copy_count = (size_t)remaining;
        }
        memcpy(
            buffer,
            (const void*)(uintptr_t)(hazard3_wad_base() + memory_wad_position),
            copy_count);
        memory_wad_position += (uint32_t)copy_count;
        return (ssize_t)copy_count;
    }
    if (file == 0) {
        uint8_t* bytes = (uint8_t*)buffer;
        size_t received = 0u;
        while (received < byte_count) {
            uint8_t value;
            if (!hazard3_console_getc_nonblocking(&value)) {
                break;
            }
            bytes[received++] = value;
        }
        return (ssize_t)received;
    }
    errno = EBADF;
    return -1;
}

int _stat(const char* path, struct stat* status)
{
    if (status == (struct stat*)0) {
        errno = EINVAL;
        return -1;
    }
    if (path_matches_wad(path)) {
        fill_wad_stat(status);
        return 0;
    }
    errno = ENOENT;
    return -1;
}

clock_t _times(struct tms* times_buffer)
{
    uint32_t milliseconds = hazard3_ticks_ms();
    if (times_buffer != (struct tms*)0) {
        times_buffer->tms_utime = (clock_t)milliseconds;
        times_buffer->tms_stime = 0;
        times_buffer->tms_cutime = 0;
        times_buffer->tms_cstime = 0;
    }
    return (clock_t)milliseconds;
}

int _unlink(const char* path) { (void)path; errno = ENOENT; return -1; }

ssize_t _write(int file, const void* buffer, size_t byte_count)
{
    const uint8_t* bytes = (const uint8_t*)buffer;
    if ((file != 1 && file != 2) || buffer == (const void*)0) {
        errno = EBADF; return -1;
    }
    for (size_t index = 0u; index < byte_count; ++index) {
        hazard3_console_putc(bytes[index]);
    }
    return (ssize_t)byte_count;
}
