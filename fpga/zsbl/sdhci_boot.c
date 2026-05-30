///////////////////////////////////////////////////////////////////////
// sdhci_boot.c
//
// Written: Jacob Pease jacob.pease@okstate.edu 7/22/2024
// Modified: Juan Schroeder jcschroeder@gmail.com 5/30/2026
//
// Purpose: Main bootloader entry point for SDHCI case, using the
// sdhci repo's driver code (https://github.com/Freakness109/sdhci)
//
///////////////////////////////////////////////////////////////////////

#if (SDHCI_SUPPORTED == 1)

#include <stddef.h>
#include <stdint.h>

#include "boot.h"
#include "cheshire_lib_stub.h"
#include "gpt.h"
#include "riscv.h"
#include "uart.h"

#define SDHCI_BASE_ADDR         SDHCI_BASE
#define SD_BLOCK_SIZE           512
#define SDHCI_MAX_READ_BLOCKS   512

#include "sdhcvar.h"
#include "sdmmcvar.h"

//#define SDHCI_DEBUG         1
// global symbol in the sdhci repo libs, used to control logging verbosity
extern int sdhcdebug;
extern int sdmmcdebug;
extern int debug_funcs;

static struct sdmmc_softc sc;
static struct sdhc_host hp;
static u_char scratch[SD_BLOCK_SIZE];

static uint32_t read_mcycle32(void) {
  uint32_t cycles;

  __asm__ volatile ("csrr %0, mcycle" : "=r" (cycles));
  return cycles;
}

// getTime using floats
// static float getTime32(void) {
//   return (float)read_mcycle32() / SYSTEMCLOCK;
// }

// print_time using floats
// static void print_time32(void) {
//   print_uart("[");
//   set_status_fs();
//   print_uart_float(getTime32(), 5);
//   clear_status_fs();
//   print_uart("] ");
// }

static uint32_t get_time_ms32(void)
{
  return (uint32_t)(read_mcycle32() / (SYSTEMCLOCK / 1000));
}

static void print_time32(void)
{
  uint32_t ms = get_time_ms32();

  print_uart("[");
  println_with_int("", ms);   // or print_uint_decimal(ms)
  print_uart(" ms] ");
}

static int sdhci_init_card(void) {
  int ret;

  bzero(&sc, sizeof(sc));
  bzero(&hp, sizeof(hp));
  bzero(&scratch, sizeof(scratch));

  // logging verbosity of sdhci routines after init
#ifdef SDHCI_DEBUG
  sdhcdebug = 2;
  sdmmcdebug = 1;
  debug_funcs = 1;
#else
  sdhcdebug = 0;
  sdmmcdebug = 0;
  debug_funcs = 0;
#endif

  print_time();

  ret = sdhc_init(&hp, SDHCI_BASE_ADDR, 0, 0);
  if (ret != 0) {
    println_with_int("SDHCI init failed: 0x", ret);
    return -1;
  }


  sdmmc_init(&sc, &hp, scratch);
  if (!ISSET(sc.sc_flags, SMF_CARD_ATTACHED)) {
    println("SDHCI card attach failed.");
    return -1;
  }

  ret = sdhc_bus_clock(sc.sch, SDMMC_SDCLK_25MHZ, SDMMC_TIMING_LEGACY);
  if (ret != 0) {
    println_with_int("SDHCI clock setup failed: 0x", ret);
    return -1;
  }

  return 0;
}

static int sdhci_disk_read(BYTE *buf, LBA_t sector, UINT count) {
  UINT blocks_loaded = 0;
  int ret;

  print_uart("\r          Blocks loaded: ");
  print_uart("0");
  print_uart("/");
  print_uart_dec(count);

  while (blocks_loaded < count) {
    UINT blocks_this_read = count - blocks_loaded;
    if (blocks_this_read > SDHCI_MAX_READ_BLOCKS) {
      blocks_this_read = SDHCI_MAX_READ_BLOCKS;
    }

    ret = sdmmc_mem_read_block(&sc.sc_card, (int)(sector + blocks_loaded),
        buf + ((size_t)blocks_loaded * SD_BLOCK_SIZE),
        (size_t)blocks_this_read * SD_BLOCK_SIZE);
    if (ret != 0) {
      println_with_int("SDHCI disk_read failed: 0x", ret);
      return -1;
    }

    blocks_loaded += blocks_this_read;
    print_uart("\r          Blocks loaded: ");
    print_uart_dec(blocks_loaded);
    print_uart("/");
    print_uart_dec(count);
  }

  print_uart("\r\n");
  return 0;
}

int sdhci_load_partitions(void) {
  BYTE lba1_buf[SD_BLOCK_SIZE];
  BYTE lba2_buf[SD_BLOCK_SIZE];
  int ret;

  ret = sdhci_init_card();
  if (ret < 0) {
    return ret;
  }

  print_time32();
  println("Getting GPT information.");
  ret = sdhci_disk_read(lba1_buf, 1, 1);
  if (ret < 0) {
    return ret;
  }

  gpt_pth_t *lba1 = (gpt_pth_t *)lba1_buf;

  print_time32();
  println("Getting partition entries.");
  ret = sdhci_disk_read(lba2_buf, (LBA_t)lba1->partition_entries_lba, 1);
  if (ret < 0) {
    return ret;
  }

  partition_entries_t *fdt = (partition_entries_t *)(lba2_buf);
  partition_entries_t *opensbi = (partition_entries_t *)(lba2_buf + 128);
  partition_entries_t *kernel = (partition_entries_t *)(lba2_buf + 256);

  print_time32();
  println_with_int("Loading device tree at: 0x", FDT_ADDRESS);
  ret = sdhci_disk_read((BYTE *)FDT_ADDRESS, fdt->first_lba,
      fdt->last_lba - fdt->first_lba + 1);
  if (ret < 0) {
    print_uart("Failed to load device tree!\r\n");
    return -1;
  }

  print_time32();
  println_with_int("Loading OpenSBI at: 0x", OPENSBI_ADDRESS);
  ret = sdhci_disk_read((BYTE *)OPENSBI_ADDRESS, opensbi->first_lba,
      opensbi->last_lba - opensbi->first_lba + 1);
  if (ret < 0) {
    print_uart("Failed to load OpenSBI!\r\n");
    return -1;
  }

  print_time32();
  println_with_int("Loading Linux Kernel at: 0x", KERNEL_ADDRESS);
  ret = sdhci_disk_read((BYTE *)KERNEL_ADDRESS, kernel->first_lba,
      kernel->last_lba - kernel->first_lba + 1);
  if (ret < 0) {
    print_uart("Failed to load Linux!\r\n");
    return -1;
  }

  print_time32();
  println("Done! Flashing LEDs and jumping to OpenSBI...");

  return 0;
}

#endif
