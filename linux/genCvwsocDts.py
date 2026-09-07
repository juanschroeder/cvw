#!/usr/bin/env python3
"""Write a simulation wrapper around Yocto's deployed DTS; never edit the base."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--bootargs", required=True)
parser.add_argument("--mode", choices=("initrd", "none", "jffs2", "sdhci"), default="initrd")
parser.add_argument("--initrd-start", type=lambda s: int(s, 0), default=0)
parser.add_argument("--initrd-end", type=lambda s: int(s, 0), default=0)
parser.add_argument("--rootfs", type=Path)
parser.add_argument("--rootfs-address", type=lambda s: int(s, 0), default=0x8c000000)
parser.add_argument("--rootfs-compatible", default="mtd-ram")
parser.add_argument("--bank-width", type=lambda s: int(s, 0), default=1)
parser.add_argument("--erase-size", type=lambda s: int(s, 0), default=0x2000)
args = parser.parse_args()
source = args.source.resolve(strict=True)

def cells(value):
    if not 0 <= value < (1 << 64):
        parser.error("address/size must fit in 64 bits")
    return f"0x{value >> 32:x} 0x{value & 0xffffffff:x}"

# The deployed top-level source supplies /dts-v1/ and its relative includes.
text = f'/include/ {json.dumps(str(source))}\n\n'
text += '/ {\n  chosen {\n'
text += f'    bootargs = {json.dumps(args.bootargs)};\n'
if args.mode == "initrd":
    text += f'    linux,initrd-start = <{cells(args.initrd_start)}>;\n'
    text += f'    linux,initrd-end = <{cells(args.initrd_end)}>;\n'
else:
    text += '    /delete-property/ linux,initrd-start;\n'
    text += '    /delete-property/ linux,initrd-end;\n'
text += '  };\n'
if args.mode == "jffs2":
    if args.rootfs is None:
        parser.error("--rootfs is required for jffs2")
    reg = f"<{cells(args.rootfs_address)} {cells(args.rootfs.stat().st_size)}>"
    text += f'''
  romfs@{args.rootfs_address:x} {{
    compatible = {json.dumps(args.rootfs_compatible)};
    reg = {reg};
    bank-width = <{args.bank_width}>;
    erase-size = <{args.erase_size}>;
  }};
  reserved-memory {{
    #address-cells = <2>;
    #size-cells = <2>;
    ranges;
    rootfs@{args.rootfs_address:x} {{
      reg = {reg};
      no-map;
    }};
  }};
'''
text += '};\n'
if args.mode == "sdhci":
    text += '\n&{/soc/mmc@10090000} { status = "okay"; };\n'
args.output.parent.mkdir(parents=True, exist_ok=True)
if not args.output.exists() or args.output.read_text() != text:
    args.output.write_text(text)
