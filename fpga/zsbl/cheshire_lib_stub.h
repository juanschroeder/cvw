///////////////////////////////////////////////////////////////////////
// sdhci_lib_stub.h
//
// Written: Juan Schroeder jcschroeder@gmail.com 5/30/2026
//
// Purpose: Mimic missing Cheshire dependencies for sdhci_boot.c
//
//
///////////////////////////////////////////////////////////////////////


#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define bzero(ptr, len) memset((ptr), 0, (len))

#ifndef MIN
#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#endif

#ifndef MAX
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#endif

static inline volatile uint8_t *reg8(uintptr_t base, uintptr_t offset) {
  return (volatile uint8_t *)(base + offset);
}

static inline volatile uint16_t *reg16(uintptr_t base, uintptr_t offset) {
  return (volatile uint16_t *)(base + offset);
}

static inline volatile uint32_t *reg32(uintptr_t base, uintptr_t offset) {
  return (volatile uint32_t *)(base + offset);
}

int sdhci_uart_printf(const char *fmt, ...);
void clint_spin_ticks(uint64_t ticks);

#define printf sdhci_uart_printf
