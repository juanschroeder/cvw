# VexiiRiscv in CVWSoC

The default RV32 and RV64 CPUs use the same balanced configuration with a
**16 KiB, four-way D-cache**. RTL generation is offline; FPGA and Verilator
builds consume `../VexiiRiscv.v` or `../VexiiRiscv64.v` through the shared
`../cvwsoc_cpu_vexiiriscv.sv` wrapper. LiteX is not a dependency.

## CPU configuration

| Feature | RV32 | RV64 |
|---|---|---|
| ISA | RV32IMAFDC, Zicsr/Zifencei/Zicntr/Zihpm, Zicbom | RV64 equivalent |
| Privilege / MMU | M/S/U, Sv32 | M/S/U, Sv39 |
| Hart / issue width | One hart, one decoder/execution lane | Same |
| Instruction cache | 8 KiB, 64 sets, two ways | Same |
| Write-back data cache | 16 KiB, 64 sets, four ways | Same |
| Cache line / CBO block | 64 bytes | Same |
| Bypassing / prediction | Integer and FP bypassing; BTB/GShare/RAS | Same |
| PMP | Eight entries, local CBO permission fix | Same |
| Memory interfaces | Three 64-bit AXI4 masters, 32-bit physical addresses | Same |
| Refill / writeback | One instruction refill; one data refill and writeback | Same |
| Store buffer / prefetch | Disabled | Same |
| Reset vector | `0x1000` | Same |

`--with-rvd` enables both F and D. Split A/C extension names are also reported;
RV32 includes Zcf, RV64 does not. No Zb*, Zcb, Zicond, Zicboz or Zicbop is enabled.
`--performance-counters 0` retains cycle/instret but no programmable HPM counters.
The pinned BTB/GShare/RAS defaults are 512 entries / 4 KiB / four return entries.
Integer bypass begins at stage 0 and FP bypass at stage 2.

## Sources, tools and patch

| Input | Pinned revision |
|---|---|
| [VexiiRiscv](https://github.com/SpinalHDL/VexiiRiscv) | `9f70315deb3390b283995c5b8f1bd38215ecf52b` |
| SpinalHDL submodule | `de72faf6062206a89b445e5cc07e32ed982712c8` |
| rvls submodule | `847ce99fd2b28a5c0ccb1ec2683311cf97a9fefc` |

Generation requires Git, Bash, Python 3, JDK 21 and sbt (tested with sbt 1.10.0 /
Scala 2.12.18). `generate.sh` clones its own `upstream/` checkout when not
present, checks the exact revision and initializes its submodules.
`VEXII_SOURCE` optionally selects another checkout at that same revision.
SpinalHDL is built from that source.

`patches/0001-zicbom-pmp-faults.patch` addresses upstream
[issue #206](https://github.com/SpinalHDL/VexiiRiscv/issues/206): denied CBOs must
raise store-class access faults and must not modify cache/memory state. The patch
checks CBO read permission, preserves access faults over retry and aborts denied
operations, while permitting read-only PMP memory.
This already includes the clean/flush correction associated with
[issue #90](https://github.com/SpinalHDL/VexiiRiscv/issues/90).

## Generate RTL

From the CVWSoC repository root:

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export JDK_JAVA_OPTIONS='-Xmx2g -XX:ActiveProcessorCount=4'
cpu="$PWD/addins/cvwsoc/cpu/vexiiriscv"
"$cpu/generate.sh" --xlen 32
"$cpu/generate.sh" --xlen 64
```

Both default to four D-cache ways. XLEN defaults to 32 when omitted.
`generate.sh` prefixes helper modules with `VexiiCVW_` / `Vexii64CVW_`, and names
the RV64 top `VexiiRiscv64`, avoiding collisions with existing VexRiscv RTL.
Separate manifests in `generated/` record dependency revisions, patch SHA,
the complete upstream command and output checksum.

The optional `--d-cache-ways 2` reproduces a previous **8 KiB** D-cache config;
it does not produce 16 KiB/two-way. MMU-enabled caches in this pin are limited to
64 sets. 
`--output-dir DIR` writes RTL/manifests, for example:

```bash
"$cpu/generate.sh" --xlen 64 --d-cache-ways 2 --output-dir /tmp/vexii-rv64-8k
```


## SoC integration

The wrapper connects instruction fetch, cached LSU and uncached LSU to the
existing `axi_mux` and `axi_id_remap`. The native ports omit ID signals with the selected
refill/writeback counts; the mux/remapper preserves source identity on the SoC's
two-bit AXI ID interface.
Increasing refill/writeback counts requires rechecking the native ID wiring.
AMO/LRSC use the cached LSU's internal implementation; no AXI ATOP is emitted.

This is a single-hart, non-coherent integration, not multi-agent atomic coherence.

PMA attributes follow normal cvwsoc setup:

| Physical region | LSU attribute / execution |
|---|---|
| `0x1000–0x27fff` | Uncached ROM/SRAM PMA coverage; executable; decoder rejects holes |
| CLINT `0x02000000–0x0200ffff`, PLIC `0x0c000000–0x0fffffff` | Uncached, non-executable |
| Peripherals `0x10000000–0x11ffffff`, optional `0x20000000–0x2003ffff` | Uncached, non-executable |
| DDR `0x80000000–0x83ffffff` | Cached, executable |
| DDR `0x84000000–0x840fffff` | **Uncached, non-executable**, preserved DMA window |
| DDR `0x84100000–0xbfffffff` | Cached, executable |

DMA using cached DDR requires cache maintenance and ordering. Zicbom provides
clean/flush/invalidate with a 64-byte block; S-mode requires `menvcfg.CBCFE` and
appropriate `CBIE` permissions from M-mode firmware. These bits are in the low
`menvcfg` CSR on both XLENs.


## Hardware results and status

At the time of integration of this CPU, measurements on Genesys 2, RV32 at 110 MHz give:

| CPU config | Doom without audio | Doom with audio |
|---|---:|---:|
| Previous 8 KiB/two-way D-cache | 29.71 FPS | 26.73 FPS |
| Selected 16 KiB/four-way D-cache | **38.19 FPS** | **34.08 FPS** |

There is a small resource usage increase between the two and basically unchanged CPU timing.

