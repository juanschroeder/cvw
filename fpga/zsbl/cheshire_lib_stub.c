#if (SDHCI_SUPPORTED == 1)

#include <stdarg.h>
#include <stdint.h>

#include "cheshire_lib_stub.h"
#include "riscv.h"
#include "uart.h"

extern void write_serial(char a);

static void sdhci_uart_put_hex(uint64_t value, int min_digits, int prefix) {
  char digits[16];
  int n = 0;

  if (prefix) {
    print_uart("0x");
  }

  do {
    uint8_t digit = value & 0xf;
    digits[n++] = digit < 10 ? '0' + digit : 'a' + digit - 10;
    value >>= 4;
  } while (value != 0 || n < min_digits);

  while (n > 0) {
    write_serial(digits[--n]);
  }
}

static void sdhci_uart_put_dec(int value) {
  if (value < 0) {
    write_serial('-');
    print_uart_dec((uint64_t)-value);
  } else {
    print_uart_dec((uint64_t)value);
  }
}

int sdhci_uart_printf(const char *fmt, ...) {
  va_list ap;

  va_start(ap, fmt);
  while (*fmt != '\0') {
    int alternate = 0;
    int width = 0;

    if (*fmt != '%') {
      if (*fmt == '\n') {
        write_serial('\r');
      }
      write_serial(*fmt++);
      continue;
    }

    fmt++;
    if (*fmt == '#') {
      alternate = 1;
      fmt++;
    }
    if (*fmt == '0') {
      fmt++;
    }
    while (*fmt >= '0' && *fmt <= '9') {
      width = width * 10 + (*fmt - '0');
      fmt++;
    }

    switch (*fmt) {
      case 's':
        print_uart(va_arg(ap, const char *));
        break;
      case 'd':
        sdhci_uart_put_dec(va_arg(ap, int));
        break;
      case 'u':
        print_uart_dec((uint64_t)va_arg(ap, unsigned int));
        break;
      case 'x':
        sdhci_uart_put_hex((uint32_t)va_arg(ap, uint32_t),
            width > 0 ? width : 1, alternate);
        break;
      case 'p':
        sdhci_uart_put_hex((uintptr_t)va_arg(ap, void *), 1, 1);
        break;
      case 'b':
        sdhci_uart_put_hex((uint32_t)va_arg(ap, uint32_t), 1, 1);
        (void)va_arg(ap, const char *);
        break;
      case '%':
        write_serial('%');
        break;
      default:
        write_serial('%');
        write_serial(*fmt);
        break;
    }
    fmt++;
  }
  va_end(ap);
  return 0;
}

void clint_spin_ticks(uint64_t ticks) {
  uint64_t start = read_mcycle();

  while ((read_mcycle() - start) < ticks) {}
}

#endif
