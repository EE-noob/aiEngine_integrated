#ifndef PICOSOC_BSP_H
#define PICOSOC_BSP_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PICOSOC_UART_CLKDIV_ADDR 0x02000004u
#define PICOSOC_UART_DATA_ADDR   0x02000008u

#ifndef PICOSOC_UART_CLKDIV
#define PICOSOC_UART_CLKDIV 8u
#endif

#define reg_uart_clkdiv (*(volatile uint32_t *)PICOSOC_UART_CLKDIV_ADDR)
#define reg_uart_data   (*(volatile uint32_t *)PICOSOC_UART_DATA_ADDR)

void picosoc_uart_init(void);
int putchar(int ch);
int puts(const char *str);
int printf(const char *fmt, ...);
void print(const char *str);
void print_hex(uint32_t value, int digits);
void print_dec(uint32_t value);

#ifdef __cplusplus
}
#endif

#endif
