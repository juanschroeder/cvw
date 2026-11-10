#!/usr/bin/env bash
set -euo pipefail

xlen=32
d_cache_ways=4
output_dir=

while [[ $# -gt 0 ]]; do
    case "$1" in
        --xlen)
            xlen=${2:?Missing value for --xlen}
            shift 2
            ;;
        --d-cache-ways)
            d_cache_ways=${2:?Missing value for --d-cache-ways}
            shift 2
            ;;
        --output-dir)
            output_dir=${2:?Missing value for --output-dir}
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--xlen 32|64] [--d-cache-ways 2|4] [--output-dir DIR]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (use --help)" >&2
            exit 2
            ;;
    esac
done

if [[ $xlen != 32 && $xlen != 64 ]]; then
    echo "XLEN must be 32 or 64" >&2
    exit 2
fi
if [[ $d_cache_ways != 2 && $d_cache_ways != 4 ]]; then
    echo "D-cache ways must be 2 or 4" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cpu_dir=$(cd "$script_dir/.." && pwd)
source_dir=${VEXII_SOURCE:-$script_dir/upstream}
revision=9f70315deb3390b283995c5b8f1bd38215ecf52b
patch_file="$script_dir/patches/0001-zicbom-pmp-faults.patch"

# Submodule commits come from the pinned superproject, not installed SpinalHDL.
if [[ ! -e $source_dir/.git ]]; then
    git clone https://github.com/SpinalHDL/VexiiRiscv.git "$source_dir"
    git -C "$source_dir" checkout --detach "$revision"
fi
source_dir=$(cd "$source_dir" && pwd)
if [[ $(git -C "$source_dir" rev-parse HEAD) != "$revision" ]]; then
    echo "Expected VexiiRiscv revision $revision in $source_dir" >&2
    exit 1
fi
git -C "$source_dir" submodule update --init ext/SpinalHDL ext/rvls

# Accept an already-applied patch, otherwise check before modifying the checkout.
if ! git -C "$source_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
    git -C "$source_dir" apply --check "$patch_file"
    git -C "$source_dir" apply "$patch_file"
fi

generator_args=(
    --xlen "$xlen"
    --physical-width 32
    --reset-vector 4096
    --with-rvm
    --with-rva
    --with-rvd
    --with-rvc
    --with-rvZcbm
    --with-supervisor
    --with-rdtime
    --performance-counters 0
    --pmp-size 8
    --with-fetch-l1
    --fetch-l1-sets 64
    --fetch-l1-ways 2
    --fetch-l1-refill-count 1
    --fetch-l1-mem-data-width-min 64
    --fetch-axi4
    --with-lsu-l1
    --lsu-l1-sets 64
    --lsu-l1-ways "$d_cache_ways"
    --lsu-l1-refill-count 1
    --lsu-l1-writeback-count 1
    --lsu-l1-mem-data-width-min 64
    --lsu-l1-axi4
    --lsu-axi4
    --with-whiteboxer-outputs
    --region "base=00001000,size=00020000,main=0,exe=1"
    --region "base=00021000,size=00007000,main=0,exe=1"
    --region "base=02000000,size=00010000,main=0,exe=0"
    --region "base=0c000000,size=04000000,main=0,exe=0"
    --region "base=10000000,size=02000000,main=0,exe=0"
    --region "base=20000000,size=00040000,main=0,exe=0"
    --region "base=80000000,size=04000000,main=1,exe=1"
    --region "base=84000000,size=00100000,main=0,exe=0"
    --region "base=84100000,size=3bf00000,main=1,exe=1"
    --allow-bypass-from 0
    --with-btb
    --with-gshare
    --with-ras
)

module_name=VexiiRiscv
manifest_name=manifest.txt
if [[ $xlen == 64 ]]; then
    module_name=VexiiRiscv64
    manifest_name=manifest-rv64.txt
fi
output_dir=${output_dir:-$cpu_dir}
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
manifest_dir=$output_dir
if [[ $output_dir == "$cpu_dir" ]]; then
    manifest_dir="$script_dir/generated"
fi
mkdir -p "$manifest_dir"

cd "$source_dir"
SPINALHDL_FROM_SOURCE=1 SPINALHDL_PATH="$source_dir/ext/SpinalHDL" \
    sbt "runMain vexiiriscv.Generate ${generator_args[*]}"
# All CPU RTL can be loaded together; helper names must remain distinct.
python3 - "$source_dir/VexiiRiscv.v" "$output_dir/$module_name.v" "$xlen" <<'PYTHON'
import re
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:3])
xlen = sys.argv[3]
prefix = "VexiiCVW_" if xlen == "32" else "Vexii64CVW_"
rtl = source.read_text()
helpers = set(re.findall(r"^module\s+(\w+)", rtl, re.M)) - {"VexiiRiscv"}
pattern = r"\b(?:" + "|".join(sorted(helpers)) + r")\b"
rtl = re.sub(pattern, lambda match: prefix + match.group(0), rtl)
if xlen == "64":
    rtl = re.sub(r"\bVexiiRiscv\b", "VexiiRiscv64", rtl)
target.write_text(rtl)
PYTHON

{
    echo "VexiiRiscv $revision"
    git submodule status ext/SpinalHDL ext/rvls
    (cd "$script_dir" && sha256sum patches/0001-zicbom-pmp-faults.patch)
    printf '%s\n' "runMain vexiiriscv.Generate ${generator_args[*]}"
    (cd "$output_dir" && sha256sum "$module_name.v")
    echo "D-cache: 64 sets, $d_cache_ways ways, 64-byte lines"
} > "$manifest_dir/$manifest_name"

echo "RTL: $output_dir/$module_name.v"
echo "Manifest: $manifest_dir/$manifest_name"
