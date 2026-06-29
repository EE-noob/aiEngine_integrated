#include "picosoc_bsp.h"

#include <stdarg.h>

static int g_uart_initialized;

void picosoc_uart_init(void)
{
    if (!g_uart_initialized) {
        reg_uart_clkdiv = PICOSOC_UART_CLKDIV;
        g_uart_initialized = 1;
    }
}

int putchar(int ch)
{
    picosoc_uart_init();
    if (ch == '\n') {
        putchar('\r');
    }
    reg_uart_data = (uint32_t)(uint8_t)ch;
    return ch;
}

void print(const char *str)
{
    if (str == 0) {
        return;
    }
    while (*str != 0) {
        putchar((unsigned char)*str);
        str++;
    }
}

int puts(const char *str)
{
    print(str);
    putchar('\n');
    return 0;
}

static int print_unsigned(uint32_t value, uint32_t base, int min_width,
                          char pad, int uppercase)
{
    char buffer[32];
    const char *digits = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";
    int count = 0;
    int pos = 0;

    do {
        buffer[pos++] = digits[value % base];
        value /= base;
    } while (value != 0u);

    while (pos < min_width) {
        putchar(pad);
        count++;
        min_width--;
    }

    while (pos > 0) {
        putchar(buffer[--pos]);
        count++;
    }

    return count;
}

void print_hex(uint32_t value, int digits)
{
    (void)print_unsigned(value, 16u, digits, '0', 0);
}

void print_dec(uint32_t value)
{
    (void)print_unsigned(value, 10u, 0, ' ', 0);
}

static int vprintf_small(const char *fmt, va_list ap)
{
    int count = 0;

    while (*fmt != 0) {
        char pad = ' ';
        int width = 0;
        int long_arg = 0;
        char spec;

        if (*fmt != '%') {
            putchar((unsigned char)*fmt++);
            count++;
            continue;
        }

        fmt++;
        if (*fmt == '%') {
            putchar('%');
            fmt++;
            count++;
            continue;
        }

        if (*fmt == '0') {
            pad = '0';
            fmt++;
        }

        while ((*fmt >= '0') && (*fmt <= '9')) {
            width = (width * 10) + (*fmt - '0');
            fmt++;
        }

        if (*fmt == 'l') {
            long_arg = 1;
            fmt++;
            if (*fmt == 'l') {
                fmt++;
            }
        }

        spec = *fmt++;
        switch (spec) {
        case 'c': {
            int ch = va_arg(ap, int);
            putchar(ch);
            count++;
            break;
        }
        case 's': {
            const char *str = va_arg(ap, const char *);
            if (str == 0) {
                str = "(null)";
            }
            while (*str != 0) {
                putchar((unsigned char)*str++);
                count++;
            }
            break;
        }
        case 'd':
        case 'i': {
            int32_t value = long_arg ? (int32_t)va_arg(ap, long) : va_arg(ap, int);
            uint32_t magnitude;
            if (value < 0) {
                putchar('-');
                count++;
                magnitude = (uint32_t)(-value);
            } else {
                magnitude = (uint32_t)value;
            }
            count += print_unsigned(magnitude, 10u, width, pad, 0);
            break;
        }
        case 'u': {
            uint32_t value = long_arg ? (uint32_t)va_arg(ap, unsigned long) :
                                        va_arg(ap, unsigned int);
            count += print_unsigned(value, 10u, width, pad, 0);
            break;
        }
        case 'x':
        case 'X': {
            uint32_t value = long_arg ? (uint32_t)va_arg(ap, unsigned long) :
                                        va_arg(ap, unsigned int);
            count += print_unsigned(value, 16u, width, pad, spec == 'X');
            break;
        }
        case 'p': {
            uint32_t value = (uint32_t)(uintptr_t)va_arg(ap, void *);
            print("0x");
            count += 2;
            count += print_unsigned(value, 16u, 8, '0', 0);
            break;
        }
        default:
            putchar('%');
            putchar(spec);
            count += 2;
            break;
        }
    }

    return count;
}

int printf(const char *fmt, ...)
{
    int count;
    va_list ap;

    va_start(ap, fmt);
    count = vprintf_small(fmt, ap);
    va_end(ap);

    return count;
}
