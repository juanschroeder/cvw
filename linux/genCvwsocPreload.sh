#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLY="${WALLY:-$(cd "$SCRIPT_DIR/.." && pwd)}"

CVWSOC_DEPLOY_DIR="${CVWSOC_DEPLOY_DIR:-/yocto/fpga/kas-cvwsoc/build/tmp/deploy/images/cvwsoc-virt}"
CVWSOC_PRELOAD_DIR="${CVWSOC_PRELOAD_DIR:-$WALLY/sim/verilator/preload/cvwsoc}"

QEMU_GDB_PORT="${QEMU_GDB_PORT:-1235}"
QEMU_RAM_MB="${QEMU_RAM_MB:-1024}"
CVWSOC_XLEN="${CVWSOC_XLEN:-64}"
CVWSOC_BUS_WIDTH="${CVWSOC_BUS_WIDTH:-64}"
PRELOAD_WORD_BYTES="${PRELOAD_WORD_BYTES:-$((CVWSOC_BUS_WIDTH / 8))}"
QEMU_BIN="${QEMU_BIN:-qemu-system-riscv${CVWSOC_XLEN}}"
GDB_BIN="${GDB_BIN:-riscv64-unknown-elf-gdb}"
OBJCOPY_BIN="${OBJCOPY_BIN:-objcopy}"
DTC_BIN="${DTC_BIN:-dtc}"
UNLZ4_BIN="${UNLZ4_BIN:-unlz4}"
SNAPSHOT_AT_HANDOFF="${SNAPSHOT_AT_HANDOFF:-0}"
HANDOFF_PC="${HANDOFF_PC:-0x80200000}"
SKIP_GDB_DUMPS="${SKIP_GDB_DUMPS:-0}"
SKIP_INITRD="${SKIP_INITRD:-0}"

UBOOT_INCLUDE="${UBOOT_INCLUDE:-0}"
IMAGE_KIND="${IMAGE_KIND:-tiny}"
INITRD_EXT2="${INITRD_EXT2:-0}"
ROOTFS_MODE="${ROOTFS_MODE:-initrd}"
ROOTFS_ADDR="${ROOTFS_ADDR:-0x8C000000}"
ROOTFS_COMPATIBLE="${ROOTFS_COMPATIBLE:-mtd-ram}"
ROOTFS_DTS_SIZE="${ROOTFS_DTS_SIZE:-0x400000}"
ROOTFS_BANK_WIDTH="${ROOTFS_BANK_WIDTH:-1}"
ROOTFS_ERASE_SIZE="${ROOTFS_ERASE_SIZE:-0x2000}"

FW_JUMP_BIN="${FW_JUMP_BIN:-$CVWSOC_DEPLOY_DIR/fw_jump.bin}"
KERNEL_SRC="${KERNEL_SRC:-}"
INITRD_SRC="${INITRD_SRC:-}"
UBOOT_BIN="${UBOOT_BIN:-$CVWSOC_DEPLOY_DIR/u-boot.bin}"
UBOOT_DTB="${UBOOT_DTB:-$CVWSOC_DEPLOY_DIR/cvwsoc-virt.dtb}"
DTS_SRC="${DTS_SRC:-$WALLY/linux/devicetree/wally-virtsoc.dts}"

if [[ "${CVWSOC_XLEN}" == "32" ]]; then
  CPU_ARGS="${CPU_ARGS:-rv32,pmp=on,debug=off}"
else
  CPU_ARGS="${CPU_ARGS:-rva22s64,zicond=true,zfa=true,zfh=true,zcb=true,zbc=true,zkn=true,sstc=true,svadu=true,svnapot=true,pmp=on,debug=off}"
fi
BOOTARGS="${BOOTARGS:-earlycon=uart8250,mmio,0x10000000 console=ttyS0,115200 ignore_loglevel loglevel=8 rdinit=/bin/busybox.nosuid -- sh}"
INITRD_ADDR="${INITRD_ADDR:-0x84200000}"
OPENSBI_DTB_ADDR="${OPENSBI_DTB_ADDR:-0x87000000}"
KERNEL_DTB_ADDR="${KERNEL_DTB_ADDR:-0x87000000}"
UBOOT_DTB_ADDR="${UBOOT_DTB_ADDR:-0x80350000}"
UBOOT_ADDR="${UBOOT_ADDR:-0x80200000}"
UBOOT_STUB_BIN="${UBOOT_STUB_BIN:-$CVWSOC_PRELOAD_DIR/uboot-replacement-stub-rv${CVWSOC_XLEN}.bin}"
MODE_TAG="linux"
if [[ "$UBOOT_INCLUDE" != "0" ]]; then
  MODE_TAG="uboot"
fi
KERNEL_ADDR="${KERNEL_ADDR:-0x80400000}"

IMAGE_NAME="$IMAGE_KIND"
case "${IMAGE_KIND,,}" in
  ""|tiny)
    IMAGE_NAME="tiny"
    ;;
  full|doom)
    IMAGE_NAME="doom"
    ;;
esac

if [[ -z "$KERNEL_SRC" ]]; then
  if [[ -e "$CVWSOC_DEPLOY_DIR/Image.lz4.orig" ]]; then
    KERNEL_SRC="$CVWSOC_DEPLOY_DIR/Image.lz4.orig"
  elif [[ -f "$CVWSOC_DEPLOY_DIR/Image.lz4" ]]; then
    KERNEL_SRC="$CVWSOC_DEPLOY_DIR/Image.lz4"
  else
    KERNEL_SRC="$CVWSOC_DEPLOY_DIR/linux.bin"
  fi
fi

if [[ "$SKIP_INITRD" == "0" && -z "$INITRD_SRC" ]]; then
  if [[ "$ROOTFS_MODE" == "jffs2" ]]; then
    INITRD_SRC="$(ls -1t "$CVWSOC_DEPLOY_DIR"/cvwsoc-image-"$IMAGE_NAME"-*.rootfs.jffs2 "$CVWSOC_DEPLOY_DIR"/cvwsoc-image-"$IMAGE_NAME"-*.rootfs-*.jffs2 2>/dev/null | head -n1 || true)"
  elif [[ "$INITRD_EXT2" != "0" ]]; then
    INITRD_SRC="$(ls -1t "$CVWSOC_DEPLOY_DIR"/cvwsoc-image-"$IMAGE_NAME"-*.rootfs.ext2 2>/dev/null | head -n1 || true)"
  else
    INITRD_SRC="$(ls -1t "$CVWSOC_DEPLOY_DIR"/cvwsoc-image-"$IMAGE_NAME"-*.rootfs.cpio 2>/dev/null | head -n1 || true)"
    if [[ -z "$INITRD_SRC" ]]; then
      INITRD_SRC="$(ls -1t "$CVWSOC_DEPLOY_DIR"/cvwsoc-image-"$IMAGE_NAME"-*.rootfs.cpio.gz 2>/dev/null | head -n1 || true)"
    fi
  fi
fi

QEMU_KERNEL="${QEMU_KERNEL:-$CVWSOC_PRELOAD_DIR/linux-qemu-cvwsoc-${MODE_TAG}.bin}"
QEMU_INITRD_EXT="cpio"
if [[ "$INITRD_EXT2" != "0" ]]; then
  QEMU_INITRD_EXT="ext2"
fi
if [[ "$ROOTFS_MODE" == "jffs2" ]]; then
  QEMU_INITRD_EXT="jffs2"
fi
QEMU_INITRD="${QEMU_INITRD:-$CVWSOC_PRELOAD_DIR/initrd-qemu-cvwsoc-${MODE_TAG}.${QEMU_INITRD_EXT}}"
GENERATED_DTS="${GENERATED_DTS:-$CVWSOC_PRELOAD_DIR/wally-virtsoc-${MODE_TAG}.dts}"
GENERATED_DTB="${GENERATED_DTB:-$CVWSOC_PRELOAD_DIR/wally-virtsoc-${MODE_TAG}.dtb}"
EXTERNAL_DTB="${EXTERNAL_DTB:-}"

RAW_BOOTMEM_FILE="${RAW_BOOTMEM_FILE:-$CVWSOC_PRELOAD_DIR/bootmemGDB-cvwsoc-${MODE_TAG}.bin}"
BOOTMEM_FILE="${BOOTMEM_FILE:-$CVWSOC_PRELOAD_DIR/bootmem-cvwsoc-${MODE_TAG}.bin}"
RAW_RAM_FILE="${RAW_RAM_FILE:-$CVWSOC_PRELOAD_DIR/ramGDB-cvwsoc-${MODE_TAG}.bin}"
RAM_FILE="${RAM_FILE:-$CVWSOC_PRELOAD_DIR/ram-cvwsoc-${MODE_TAG}.bin}"

RAM_BASE=0x80000000
RAM_SIZE_BYTES=$((QEMU_RAM_MB * 1024 * 1024))
RAM_END=$(printf "0x%x" $((RAM_BASE + RAM_SIZE_BYTES - 1)))

require_file() {
  local path="$1"
  local name="$2"
  if [[ ! -f "$path" ]]; then
    echo "Missing $name: $path" >&2
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  local name="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing $name: $cmd" >&2
    exit 1
  fi
}

mkdir -p "$CVWSOC_PRELOAD_DIR"

require_file "$FW_JUMP_BIN" "OpenSBI fw_jump"
require_file "$KERNEL_SRC" "kernel image"
require_file "$DTS_SRC" "simulation DTS"
if [[ -n "$EXTERNAL_DTB" ]]; then
  require_file "$EXTERNAL_DTB" "external DTB"
fi
require_cmd file "file tool"
require_cmd readlink "readlink tool"
require_cmd "$DTC_BIN" "dtc tool"
require_cmd python3 "python3 tool"
case "$PRELOAD_WORD_BYTES" in
  4|8)
    ;;
  *)
    echo "Unsupported PRELOAD_WORD_BYTES=$PRELOAD_WORD_BYTES; expected 4 or 8" >&2
    exit 1
    ;;
esac

if [[ "$SKIP_INITRD" == "0" ]]; then
  if [[ -z "$INITRD_SRC" ]]; then
    echo "Missing initrd image for IMAGE_KIND=$IMAGE_NAME in $CVWSOC_DEPLOY_DIR" >&2
    exit 1
  fi
  require_file "$INITRD_SRC" "initrd image"
fi

if [[ "$MODE_TAG" == "linux" ]]; then
  require_file "$UBOOT_STUB_BIN" "u-boot replacement stub"
else
  require_file "$UBOOT_BIN" "u-boot image"
  require_file "$UBOOT_DTB" "u-boot DTB"
fi

KERNEL_SRC_REAL="$(readlink -f "$KERNEL_SRC")"
KERNEL_FILE_DESC="$(file -Lb "$KERNEL_SRC_REAL")"

if [[ "$KERNEL_FILE_DESC" == *"LZ4 compressed data"* ]]; then
  require_cmd "$UNLZ4_BIN" "unlz4 tool"
  "$UNLZ4_BIN" -c "$KERNEL_SRC_REAL" > "$QEMU_KERNEL"
elif gzip -t "$KERNEL_SRC_REAL" >/dev/null 2>&1; then
  gzip -dc "$KERNEL_SRC_REAL" > "$QEMU_KERNEL"
else
  cp "$KERNEL_SRC_REAL" "$QEMU_KERNEL"
fi

if [[ "$SKIP_INITRD" == "0" ]]; then
  INITRD_SRC_REAL="$(readlink -f "$INITRD_SRC")"
  INITRD_FILE_DESC="$(file -Lb "$INITRD_SRC_REAL")"
  if [[ "$INITRD_FILE_DESC" == *"gzip compressed data"* ]]; then
    gzip -dc "$INITRD_SRC_REAL" > "$QEMU_INITRD"
  else
    cp "$INITRD_SRC_REAL" "$QEMU_INITRD"
  fi

  if [[ "$INITRD_FILE_DESC" == *"ext2 filesystem data"* ]]; then
    if [[ "$BOOTARGS" != *"rootfstype=ext2"* ]]; then
      BOOTARGS="$(echo "$BOOTARGS" | sed 's,rdinit=/bin/busybox.nosuid -- sh,,')"
      BOOTARGS=" ${BOOTARGS} root=/dev/ram0 rootfstype=ext2 init=/bin/busybox.nosuid -- sh"
    fi
  fi
fi

INITRD_END_HEX="$INITRD_ADDR"
if [[ "$SKIP_INITRD" == "0" ]]; then
  INITRD_END_HEX="$(
python3 - <<'PY' "$INITRD_ADDR" "$QEMU_INITRD"
import os
import sys

start = int(sys.argv[1], 16)
size = os.path.getsize(sys.argv[2])
print(f"0x{start + size:08x}")
PY
)"
fi

python3 - <<'PY' "$DTS_SRC" "$GENERATED_DTS" "$INITRD_ADDR" "$INITRD_END_HEX" "$BOOTARGS" "$ROOTFS_MODE" "$ROOTFS_ADDR" "$QEMU_INITRD" "$ROOTFS_COMPATIBLE" "$ROOTFS_DTS_SIZE" "$ROOTFS_BANK_WIDTH" "$ROOTFS_ERASE_SIZE" "$SKIP_INITRD"
import os
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]).read_text()
dst = pathlib.Path(sys.argv[2])
initrd_start = sys.argv[3]
initrd_end = sys.argv[4]
bootargs = sys.argv[5]
rootfs_mode = sys.argv[6]
rootfs_addr = int(sys.argv[7], 16)
skip_initrd = sys.argv[13] != "0"
rootfs_compatible = sys.argv[9]
rootfs_dts_size = sys.argv[10]
rootfs_bank_width = sys.argv[11]
rootfs_erase_size = sys.argv[12]
rootfs_size = 0
if not skip_initrd:
    rootfs_size = os.path.getsize(sys.argv[8])
    if rootfs_dts_size:
        rootfs_size = int(rootfs_dts_size, 0)
    else:
        rootfs_size = max(rootfs_size, os.path.getsize(sys.argv[8]))

if skip_initrd:
    src = re.sub(r'\n\s*linux,initrd-start\s*=\s*<0x[0-9a-fA-F]+>;', '', src)
    src = re.sub(r'\n\s*linux,initrd-end\s*=\s*<0x[0-9a-fA-F]+>;', '', src)
elif rootfs_mode == "jffs2":
    src = re.sub(r'\n\s*linux,initrd-start\s*=\s*<0x[0-9a-fA-F]+>;', '', src)
    src = re.sub(r'\n\s*linux,initrd-end\s*=\s*<0x[0-9a-fA-F]+>;', '', src)
    rootfs_node = f'''

  romfs@{rootfs_addr:x} {{
    compatible = "{rootfs_compatible}";
    reg = <0x{rootfs_addr >> 32:x} 0x{rootfs_addr & 0xffffffff:08x} 0x0 0x{rootfs_size:x}>;
    bank-width = <{rootfs_bank_width}>;
    erase-size = <{rootfs_erase_size}>;
  }};
'''
    rootfs_reserved_node = f'''

    romfs_reserved: rootfs@{rootfs_addr:x} {{
      reg = <0x{rootfs_addr >> 32:x} 0x{rootfs_addr & 0xffffffff:08x} 0x0 0x{rootfs_size:x}>;
      no-map;
    }};
'''
    reserved_node = f'''

  reserved-memory {{
    #address-cells = <2>;
    #size-cells = <2>;
    ranges;

    romfs_reserved: rootfs@{rootfs_addr:x} {{
      reg = <0x{rootfs_addr >> 32:x} 0x{rootfs_addr & 0xffffffff:08x} 0x0 0x{rootfs_size:x}>;
      no-map;
    }};
  }};
'''
    if re.search(r'\n\s*(?:romfs|rootfs)@[0-9a-fA-F]+\s*\{.*?\n\s*\};', src, flags=re.S):
        src = re.sub(r'\n\s*(?:romfs|rootfs)@[0-9a-fA-F]+\s*\{.*?\n\s*\};', rootfs_node.rstrip(), src, flags=re.S)
    else:
        src = re.sub(r'\n\s*soc\s*\{', rootfs_node + '\n  soc {', src, count=1)
    reserved_close_re = r'\n\s*\};(?=\n\s*cpus\s*\{)'
    if re.search(r'\n\s*reserved-memory\s*\{', src) and re.search(reserved_close_re, src):
        src = re.sub(reserved_close_re, rootfs_reserved_node.rstrip() + '\n  };', src, count=1)
    else:
        src = re.sub(r'\n\s*soc\s*\{', reserved_node + '\n  soc {', src, count=1)
else:
    src = re.sub(r'linux,initrd-start\s*=\s*<0x[0-9a-fA-F]+>;', f'linux,initrd-start = <{initrd_start}>;', src)
    src = re.sub(r'linux,initrd-end\s*=\s*<0x[0-9a-fA-F]+>;', f'linux,initrd-end = <{initrd_end}>;', src)
src = re.sub(r'bootargs\s*=\s*".*?";', f'bootargs = "{bootargs}";', src)
dst.write_text(src)
PY

"$DTC_BIN" -I dts -O dtb "$GENERATED_DTS" -o "$GENERATED_DTB"
if [[ -n "$EXTERNAL_DTB" ]]; then
  cp "$EXTERNAL_DTB" "$GENERATED_DTB"
fi

if [[ "$SKIP_GDB_DUMPS" != "0" ]]; then
  echo "Prepared cvwsoc QEMU assets (${MODE_TAG}):"
  echo "  kernel   : $QEMU_KERNEL"
  if [[ "$SKIP_INITRD" == "0" ]]; then echo "  initrd   : $QEMU_INITRD"; fi
  echo "  dts      : $GENERATED_DTS"
  echo "  dtb      : $GENERATED_DTB"
  if [[ "$MODE_TAG" == "linux" ]]; then
    echo "  stub     : $UBOOT_STUB_BIN"
  fi
  echo "  image    : $IMAGE_NAME"
  echo "  bootargs : $BOOTARGS"
  exit 0
fi

require_cmd "$QEMU_BIN" "QEMU"
require_cmd "$GDB_BIN" "GDB"
require_cmd "$OBJCOPY_BIN" "objcopy"

rm -f "$RAW_BOOTMEM_FILE" "$BOOTMEM_FILE" "$RAW_RAM_FILE" "$RAM_FILE"

cleanup() {
  if [[ -n "${QEMU_PID:-}" ]]; then
    kill "$QEMU_PID" >/dev/null 2>&1 || true
    wait "$QEMU_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

INITRD_LOADER_ARGS=()
if [[ "$SKIP_INITRD" == "0" ]]; then
  ROOTFS_LOADER_ADDR="$INITRD_ADDR"
  if [[ "$ROOTFS_MODE" == "jffs2" ]]; then
    ROOTFS_LOADER_ADDR="$ROOTFS_ADDR"
  fi
  INITRD_LOADER_ARGS=(-device loader,file="${QEMU_INITRD}",addr="${ROOTFS_LOADER_ADDR}",force-raw=on)
fi

if [[ "$MODE_TAG" == "linux" ]]; then
  "$QEMU_BIN" \
    -M virt -m "${QEMU_RAM_MB}M" -nographic \
    -bios "$FW_JUMP_BIN" \
    -dtb "$GENERATED_DTB" \
    -cpu "$CPU_ARGS" \
    -device loader,file="${UBOOT_STUB_BIN}",addr="${UBOOT_ADDR}",force-raw=on \
    -device loader,file="${QEMU_KERNEL}",addr="${KERNEL_ADDR}" \
    -device loader,file="${GENERATED_DTB}",addr="${KERNEL_DTB_ADDR}" \
    "${INITRD_LOADER_ARGS[@]}" \
    -gdb "tcp::${QEMU_GDB_PORT}" -S &

else
  "$QEMU_BIN" \
    -M virt -m "${QEMU_RAM_MB}M" -nographic \
    -bios "$FW_JUMP_BIN" \
    -dtb "$GENERATED_DTB" \
    -cpu "$CPU_ARGS" \
    -device loader,file="${UBOOT_BIN}",addr="${UBOOT_ADDR}",force-raw=on \
    -device loader,file="${UBOOT_DTB}",addr="${UBOOT_DTB_ADDR}" \
    -device loader,file="${QEMU_KERNEL}",addr="${KERNEL_ADDR}" \
    -device loader,file="${GENERATED_DTB}",addr="${KERNEL_DTB_ADDR}" \
    "${INITRD_LOADER_ARGS[@]}" \
    -gdb "tcp::${QEMU_GDB_PORT}" -S &
fi
QEMU_PID=$!

sleep 1

GDB_EXTRA_ARGS=()
if [[ "$SNAPSHOT_AT_HANDOFF" != "0" ]]; then
  GDB_EXTRA_ARGS+=(-ex "b *${HANDOFF_PC}")
  GDB_EXTRA_ARGS+=(-ex "c")
fi

"$GDB_BIN" -batch \
  -ex "set tcp connect-timeout 15" \
  -ex "target remote :${QEMU_GDB_PORT}" \
  -ex "maintenance packet Qqemu.PhyMemMode:1" \
  "${GDB_EXTRA_ARGS[@]}" \
  -ex "printf \"Creating ${RAW_BOOTMEM_FILE}\n\"" \
  -ex "dump binary memory ${RAW_BOOTMEM_FILE} 0x1000 0x1fff" \
  -ex "printf \"Creating ${RAW_RAM_FILE}\n\"" \
  -ex "dump binary memory ${RAW_RAM_FILE} ${RAM_BASE} ${RAM_END}" \
  -ex "kill"

truncate -s "%${PRELOAD_WORD_BYTES}" "$RAW_BOOTMEM_FILE"
"$OBJCOPY_BIN" --reverse-bytes="${PRELOAD_WORD_BYTES}" -F binary "$RAW_BOOTMEM_FILE" "$BOOTMEM_FILE"

truncate -s "%${PRELOAD_WORD_BYTES}" "$RAW_RAM_FILE"
"$OBJCOPY_BIN" --reverse-bytes="${PRELOAD_WORD_BYTES}" -F binary "$RAW_RAM_FILE" "$RAM_FILE"

if [[ "$ROOTFS_MODE" == "jffs2" && "$SKIP_INITRD" == "0" ]]; then
  python3 - <<'PY' "$RAM_FILE" "$QEMU_INITRD" "$RAM_BASE" "$ROOTFS_ADDR" "$PRELOAD_WORD_BYTES"
import pathlib
import sys

ram_path = pathlib.Path(sys.argv[1])
rootfs_path = pathlib.Path(sys.argv[2])
ram_base = int(sys.argv[3], 0)
rootfs_addr = int(sys.argv[4], 0)
word_bytes = int(sys.argv[5], 0)
offset = rootfs_addr - ram_base
rootfs = rootfs_path.read_bytes()
if offset < 0:
    raise SystemExit(f"rootfs address 0x{rootfs_addr:x} is below RAM base 0x{ram_base:x}")

with ram_path.open("rb") as f:
    f.seek(offset)
    stored = f.read(len(rootfs))

restored = bytearray()
for idx in range(0, len(stored), word_bytes):
    restored.extend(stored[idx:idx + word_bytes][::-1])
restored = bytes(restored[:len(rootfs)])

if restored != rootfs:
    raise SystemExit(
        f"{ram_path}: rootfs mismatch at offset 0x{offset:x} "
        f"(phys 0x{rootfs_addr:x}); expected {rootfs[:8]!r}, got {restored[:8]!r}"
    )
print(f"Verified rootfs preload at offset 0x{offset:x} (phys 0x{rootfs_addr:x}, {len(rootfs)} bytes)")
PY
fi

rm -f "$RAW_RAM_FILE"

echo "Generated cvwsoc preload images (${MODE_TAG}):"
echo "  boot ROM : $BOOTMEM_FILE"
echo "  RAM      : $RAM_FILE"
echo "  kernel   : $QEMU_KERNEL"
if [[ "$SKIP_INITRD" == "0" ]]; then echo "  initrd   : $QEMU_INITRD"; fi
echo "  dts      : $GENERATED_DTS"
echo "  dtb      : $GENERATED_DTB"
if [[ "$MODE_TAG" == "linux" ]]; then
  echo "  stub     : $UBOOT_STUB_BIN"
fi
echo "  image    : $IMAGE_NAME"
echo "  xlen     : $CVWSOC_XLEN"
echo "  word     : $PRELOAD_WORD_BYTES bytes"
echo "  bootargs : $BOOTARGS"
echo "  rootfs   : $ROOTFS_MODE"
echo "  addrs    : opensbi_dtb=${OPENSBI_DTB_ADDR} uboot=${UBOOT_ADDR} uboot_dtb=${UBOOT_DTB_ADDR} kernel=${KERNEL_ADDR} kernel_dtb=${KERNEL_DTB_ADDR} initrd=${INITRD_ADDR} rootfs=${ROOTFS_ADDR}"
