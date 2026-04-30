#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLY="${WALLY:-$(cd "$SCRIPT_DIR/.." && pwd)}"

CVWSOC_DEPLOY_DIR="${CVWSOC_DEPLOY_DIR:-/yocto/fpga/kas-cvwsoc/build/tmp/deploy/images/cvwsoc-virt}"
CVWSOC_PRELOAD_DIR="${CVWSOC_PRELOAD_DIR:-$WALLY/sim/verilator/preload/cvwsoc}"

QEMU_GDB_PORT="${QEMU_GDB_PORT:-1235}"
QEMU_RAM_MB="${QEMU_RAM_MB:-1024}"
QEMU_BIN="${QEMU_BIN:-qemu-system-riscv64}"
GDB_BIN="${GDB_BIN:-riscv64-unknown-elf-gdb}"
OBJCOPY_BIN="${OBJCOPY_BIN:-objcopy}"
DTC_BIN="${DTC_BIN:-dtc}"
UNLZ4_BIN="${UNLZ4_BIN:-unlz4}"
SNAPSHOT_AT_HANDOFF="${SNAPSHOT_AT_HANDOFF:-0}"
HANDOFF_PC="${HANDOFF_PC:-0x80200000}"
SKIP_GDB_DUMPS="${SKIP_GDB_DUMPS:-0}"

UBOOT_INCLUDE="${UBOOT_INCLUDE:-0}"
IMAGE_KIND="${IMAGE_KIND:-tiny}"
INITRD_EXT2="${INITRD_EXT2:-0}"

FW_JUMP_BIN="${FW_JUMP_BIN:-$CVWSOC_DEPLOY_DIR/fw_jump.bin}"
KERNEL_SRC="${KERNEL_SRC:-}"
INITRD_SRC="${INITRD_SRC:-}"
UBOOT_BIN="${UBOOT_BIN:-$CVWSOC_DEPLOY_DIR/u-boot.bin}"
UBOOT_DTB="${UBOOT_DTB:-$CVWSOC_DEPLOY_DIR/cvwsoc-virt.dtb}"
DTS_SRC="${DTS_SRC:-$WALLY/linux/devicetree/wally-virtsoc.dts}"

CPU_ARGS="${CPU_ARGS:-rva22s64,zicond=true,zfa=true,zfh=true,zcb=true,zbc=true,zkn=true,sstc=true,svadu=true,svnapot=true,pmp=on,debug=off}"
BOOTARGS="${BOOTARGS:-earlycon=uart8250,mmio,0x10000000 console=ttyS0,115200 ignore_loglevel loglevel=8 rdinit=/bin/busybox.nosuid -- sh}"
INITRD_ADDR="${INITRD_ADDR:-0x84200000}"
OPENSBI_DTB_ADDR="${OPENSBI_DTB_ADDR:-0x87000000}"
KERNEL_DTB_ADDR="${KERNEL_DTB_ADDR:-0x87000000}"
UBOOT_DTB_ADDR="${UBOOT_DTB_ADDR:-0x80350000}"
UBOOT_ADDR="${UBOOT_ADDR:-0x80200000}"
MODE_TAG="linux"
if [[ "$UBOOT_INCLUDE" != "0" ]]; then
  MODE_TAG="uboot"
fi
if [[ "$MODE_TAG" == "linux" ]]; then
  KERNEL_ADDR="${KERNEL_ADDR:-0x80200000}"
else
  KERNEL_ADDR="${KERNEL_ADDR:-0x80400000}"
fi

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

if [[ -z "$INITRD_SRC" ]]; then
  if [[ "$INITRD_EXT2" != "0" ]]; then
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
QEMU_INITRD="${QEMU_INITRD:-$CVWSOC_PRELOAD_DIR/initrd-qemu-cvwsoc-${MODE_TAG}.${QEMU_INITRD_EXT}}"
GENERATED_DTS="${GENERATED_DTS:-$CVWSOC_PRELOAD_DIR/wally-virtsoc-${MODE_TAG}.dts}"
GENERATED_DTB="${GENERATED_DTB:-$CVWSOC_PRELOAD_DIR/wally-virtsoc-${MODE_TAG}.dtb}"

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
require_cmd file "file tool"
require_cmd readlink "readlink tool"
require_cmd "$DTC_BIN" "dtc tool"
require_cmd python3 "python3 tool"

if [[ -z "$INITRD_SRC" ]]; then
  echo "Missing initrd image for IMAGE_KIND=$IMAGE_NAME in $CVWSOC_DEPLOY_DIR" >&2
  exit 1
fi
require_file "$INITRD_SRC" "initrd image"

if [[ "$MODE_TAG" == "uboot" ]]; then
  require_file "$UBOOT_BIN" "u-boot image"
  require_file "$UBOOT_DTB" "u-boot DTB"
fi

KERNEL_SRC_REAL="$(readlink -f "$KERNEL_SRC")"
KERNEL_FILE_DESC="$(file -Lb "$KERNEL_SRC_REAL")"
INITRD_SRC_REAL="$(readlink -f "$INITRD_SRC")"
INITRD_FILE_DESC="$(file -Lb "$INITRD_SRC_REAL")"

if [[ "$KERNEL_FILE_DESC" == *"LZ4 compressed data"* ]]; then
  require_cmd "$UNLZ4_BIN" "unlz4 tool"
  "$UNLZ4_BIN" -c "$KERNEL_SRC_REAL" > "$QEMU_KERNEL"
elif gzip -t "$KERNEL_SRC_REAL" >/dev/null 2>&1; then
  gzip -dc "$KERNEL_SRC_REAL" > "$QEMU_KERNEL"
else
  cp "$KERNEL_SRC_REAL" "$QEMU_KERNEL"
fi

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

INITRD_END_HEX="$(
python3 - <<'PY' "$INITRD_ADDR" "$QEMU_INITRD"
import os
import sys

start = int(sys.argv[1], 16)
size = os.path.getsize(sys.argv[2])
print(f"0x{start + size:08x}")
PY
)"

python3 - <<'PY' "$DTS_SRC" "$GENERATED_DTS" "$INITRD_ADDR" "$INITRD_END_HEX" "$BOOTARGS"
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]).read_text()
dst = pathlib.Path(sys.argv[2])
initrd_start = sys.argv[3]
initrd_end = sys.argv[4]
bootargs = sys.argv[5]

src = re.sub(r'linux,initrd-start\s*=\s*<0x[0-9a-fA-F]+>;', f'linux,initrd-start = <{initrd_start}>;', src)
src = re.sub(r'linux,initrd-end\s*=\s*<0x[0-9a-fA-F]+>;', f'linux,initrd-end = <{initrd_end}>;', src)
src = re.sub(r'bootargs\s*=\s*".*?";', f'bootargs = "{bootargs}";', src)
dst.write_text(src)
PY

"$DTC_BIN" -I dts -O dtb "$GENERATED_DTS" -o "$GENERATED_DTB"

if [[ "$SKIP_GDB_DUMPS" != "0" ]]; then
  echo "Prepared cvwsoc QEMU assets (${MODE_TAG}):"
  echo "  kernel   : $QEMU_KERNEL"
  echo "  initrd   : $QEMU_INITRD"
  echo "  dts      : $GENERATED_DTS"
  echo "  dtb      : $GENERATED_DTB"
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

if [[ "$MODE_TAG" == "linux" ]]; then
#   "$QEMU_BIN" \
#     -M virt -m "${QEMU_RAM_MB}M" -nographic \
#     -bios "$FW_JUMP_BIN" \
#     -kernel "$QEMU_KERNEL" \
#     -initrd "$QEMU_INITRD" \
#     -dtb "$GENERATED_DTB" \
#     -cpu "$CPU_ARGS" \
#     -gdb "tcp::${QEMU_GDB_PORT}" -S &
  "$QEMU_BIN" \
    -M virt -m "${QEMU_RAM_MB}M" -nographic \
    -bios "$FW_JUMP_BIN" \
    -dtb "$GENERATED_DTB" \
    -cpu "$CPU_ARGS" \
    -device loader,file="${QEMU_KERNEL}",addr="${KERNEL_ADDR}" \
    -device loader,file="${GENERATED_DTB}",addr="${KERNEL_DTB_ADDR}" \
    -device loader,file="${QEMU_INITRD}",addr="${INITRD_ADDR}" \
    -gdb "tcp::${QEMU_GDB_PORT}" -S &

#    -initrd "$QEMU_INITRD"

else
  "$QEMU_BIN" \
    -M virt -m "${QEMU_RAM_MB}M" -nographic \
    -bios "$FW_JUMP_BIN" \
    -dtb "$GENERATED_DTB" \
    -kernel "$UBOOT_BIN" \
    -cpu "$CPU_ARGS" \
    -device loader,file="${UBOOT_DTB}",addr="${UBOOT_DTB_ADDR}" \
    -device loader,file="${QEMU_KERNEL}",addr="${KERNEL_ADDR}" \
    -device loader,file="${GENERATED_DTB}",addr="${KERNEL_DTB_ADDR}" \
    -device loader,file="${QEMU_INITRD}",addr="${INITRD_ADDR}" \
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

truncate -s %8 "$RAW_BOOTMEM_FILE"
"$OBJCOPY_BIN" --reverse-bytes=8 -F binary "$RAW_BOOTMEM_FILE" "$BOOTMEM_FILE"

truncate -s %8 "$RAW_RAM_FILE"
"$OBJCOPY_BIN" --reverse-bytes=8 -F binary "$RAW_RAM_FILE" "$RAM_FILE"

rm -f "$RAW_RAM_FILE"

echo "Generated cvwsoc preload images (${MODE_TAG}):"
echo "  boot ROM : $BOOTMEM_FILE"
echo "  RAM      : $RAM_FILE"
echo "  kernel   : $QEMU_KERNEL"
echo "  initrd   : $QEMU_INITRD"
echo "  dts      : $GENERATED_DTS"
echo "  dtb      : $GENERATED_DTB"
echo "  image    : $IMAGE_NAME"
echo "  bootargs : $BOOTARGS"
echo "  addrs    : opensbi_dtb=${OPENSBI_DTB_ADDR} uboot=${UBOOT_ADDR} uboot_dtb=${UBOOT_DTB_ADDR} kernel=${KERNEL_ADDR} kernel_dtb=${KERNEL_DTB_ADDR} initrd=${INITRD_ADDR}"
