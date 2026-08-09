#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

void coremark_uart_send_char(char c);

#define COREMARK_DIAG __attribute__((section(".coremark_diag.text")))

static COREMARK_DIAG int emit_char(char c)
{
    coremark_uart_send_char(c);
    return 1;
}

static COREMARK_DIAG int emit_string(const char *s)
{
    int count = 0;
    if (s == NULL) {
        s = "(null)";
    }
    while (*s != '\0') {
        count += emit_char(*s++);
    }
    return count;
}

static COREMARK_DIAG int emit_unsigned32(uint32_t value, unsigned int base, int width, char pad)
{
    char digits[16];
    int used = 0;
    int count = 0;

    do {
        uint32_t digit = value % base;
        digits[used++] = (char)(digit < 10u ? ('0' + digit) : ('a' + digit - 10u));
        value /= base;
    } while (value != 0u);

    while (used < width) {
        count += emit_char(pad);
        --width;
    }
    while (used > 0) {
        count += emit_char(digits[--used]);
    }
    return count;
}

static COREMARK_DIAG uint64_t divide_unsigned64(
    uint64_t value,
    uint32_t divisor,
    uint32_t *remainder_out)
{
    uint64_t quotient = 0u;
    uint32_t remainder = 0u;
    unsigned int bit;

    for (bit = 0u; bit < 64u; ++bit) {
        remainder = (remainder << 1) | (uint32_t)(value >> 63);
        value <<= 1;
        quotient <<= 1;
        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= 1u;
        }
    }

    *remainder_out = remainder;
    return quotient;
}

static COREMARK_DIAG int emit_unsigned64(uint64_t value, unsigned int base, int width, char pad)
{
    char digits[32];
    int used = 0;
    int count = 0;

    do {
        uint32_t digit;
        value = divide_unsigned64(value, base, &digit);
        digits[used++] = (char)(digit < 10u ? ('0' + digit) : ('a' + digit - 10u));
    } while (value != 0u);

    while (used < width) {
        count += emit_char(pad);
        --width;
    }
    while (used > 0) {
        count += emit_char(digits[--used]);
    }
    return count;
}

COREMARK_DIAG int ee_printf(const char *fmt, ...)
{
    va_list args;
    int count = 0;

    va_start(args, fmt);
    while (*fmt != '\0') {
        int width = 0;
        char pad = ' ';
        int long_count = 0;
        char spec;

        if (*fmt != '%') {
            count += emit_char(*fmt++);
            continue;
        }
        ++fmt;
        if (*fmt == '%') {
            count += emit_char(*fmt++);
            continue;
        }
        if (*fmt == '0') {
            pad = '0';
            ++fmt;
        }
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            ++fmt;
        }
        while (*fmt == 'l' && long_count < 2) {
            ++long_count;
            ++fmt;
        }
        spec = *fmt;
        if (spec != '\0') {
            ++fmt;
        }

        switch (spec) {
        case 'c':
            count += emit_char((char)va_arg(args, int));
            break;
        case 's':
            count += emit_string(va_arg(args, const char *));
            break;
        case 'd': {
            if (long_count >= 2) {
                int64_t value = va_arg(args, long long);
                uint64_t magnitude;
                if (value < 0) {
                    count += emit_char('-');
                    magnitude = (uint64_t)(-(value + 1)) + 1u;
                } else {
                    magnitude = (uint64_t)value;
                }
                count += emit_unsigned64(magnitude, 10u, width, pad);
            } else {
                int32_t value = long_count == 1 ?
                    (int32_t)va_arg(args, long) : (int32_t)va_arg(args, int);
                uint32_t magnitude;
                if (value < 0) {
                    count += emit_char('-');
                    magnitude = (uint32_t)(-(value + 1)) + 1u;
                } else {
                    magnitude = (uint32_t)value;
                }
                count += emit_unsigned32(magnitude, 10u, width, pad);
            }
            break;
        }
        case 'u':
            if (long_count >= 2) {
                count += emit_unsigned64(va_arg(args, unsigned long long), 10u, width, pad);
            } else {
                uint32_t value = long_count == 1 ?
                    (uint32_t)va_arg(args, unsigned long) : va_arg(args, unsigned int);
                count += emit_unsigned32(value, 10u, width, pad);
            }
            break;
        case 'x':
            if (long_count >= 2) {
                count += emit_unsigned64(va_arg(args, unsigned long long), 16u, width, pad);
            } else {
                uint32_t value = long_count == 1 ?
                    (uint32_t)va_arg(args, unsigned long) : va_arg(args, unsigned int);
                count += emit_unsigned32(value, 16u, width, pad);
            }
            break;
        default:
            count += emit_char('%');
            if (spec != '\0') {
                count += emit_char(spec);
            }
            break;
        }
    }
    va_end(args);
    return count;
}
