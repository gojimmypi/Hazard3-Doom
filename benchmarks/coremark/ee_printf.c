#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

void coremark_uart_send_char(char c);

static int emit_char(char c)
{
    coremark_uart_send_char(c);
    return 1;
}

static int emit_string(const char *s)
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

static int emit_unsigned(unsigned long value, unsigned int base, int width, char pad)
{
    char digits[16];
    int used = 0;
    int count = 0;

    do {
        unsigned long digit = value % base;
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

int ee_printf(const char *fmt, ...)
{
    va_list args;
    int count = 0;

    va_start(args, fmt);
    while (*fmt != '\0') {
        int width = 0;
        char pad = ' ';
        int long_arg = 0;
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
        if (*fmt == 'l') {
            long_arg = 1;
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
            long value = long_arg ? va_arg(args, long) : (long)va_arg(args, int);
            unsigned long magnitude;
            if (value < 0) {
                count += emit_char('-');
                magnitude = (unsigned long)(-(value + 1L)) + 1u;
            } else {
                magnitude = (unsigned long)value;
            }
            count += emit_unsigned(magnitude, 10u, width, pad);
            break;
        }
        case 'u':
            count += emit_unsigned(long_arg ? va_arg(args, unsigned long)
                                            : (unsigned long)va_arg(args, unsigned int),
                                   10u, width, pad);
            break;
        case 'x':
            count += emit_unsigned(long_arg ? va_arg(args, unsigned long)
                                            : (unsigned long)va_arg(args, unsigned int),
                                   16u, width, pad);
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
