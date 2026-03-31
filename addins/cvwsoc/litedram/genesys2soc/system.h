#ifndef __SYSTEM_H
#define __SYSTEM_H

//#define CONFIG_CLOCK_FREQUENCY 200000000
#define CONFIG_CLOCK_FREQUENCY 100000000
#define CONFIG_CPU_NOP "nop"

// FIXME!!
//static inline void flush_cpu_icache(void) {}
static inline void flush_cpu_icache(void) { __asm__ volatile("fence.i" ::: "memory"); }
static inline void flush_cpu_dcache(void) {}

#endif
