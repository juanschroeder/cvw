/* u-boot replacement stub for direct-Linux boot.
 *
 * OpenSBI always hands off to the next-stage slot at 0x80200000.
 * In u-boot mode, u-boot occupies this slot. In direct-Linux mode,
 * this stub occupies the same slot and jumps to the real kernel.
 *
 * Load address:  0x80200000
 * Target Linux:  0x80400000
 *
 * OpenSBI passes:
 *   a0 = hartid
 *   a1 = dtb pointer
 *
 * Do not clobber a0/a1.
 */

    .section .text, "ax"
    .option push
    .option norvc
    .globl _start
    .align 2

_start:
    auipc t0, 0x200
    jalr  zero, 0(t0)

    .option pop
