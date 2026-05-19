#!/usr/bin/env python3
"""Check that the OpenXC7 uncore data RAM BRAMs are not synthesized empty.

Yosys packs each 64-bit data.mem word across RAMB36E1 INIT bit planes, so the
original 64-bit hex words generally do not appear verbatim in the JSON.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

UNCORERAM = "wallypipelinedsoc.uncoregen.uncore.ram.ram.memory.ram.RAM"


def is_nonzero_init(value: str) -> bool:
    return any(ch not in "0xX" for ch in value)


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} <synth.json> <data.mem>", file=sys.stderr)
        return 2

    json_path = Path(sys.argv[1])
    data_path = Path(sys.argv[2])

    data_words = [
        line.strip()
        for line in data_path.read_text().splitlines()
        if line.strip() and int(line.strip(), 16) != 0
    ]

    design = json.loads(json_path.read_text())
    top = design["modules"].get("fpgaTopXc7Genesys2SoC")
    if top is None:
        print("ERROR: fpgaTopXc7Genesys2SoC not found in JSON", file=sys.stderr)
        return 1

    ram_cells = {
        name: cell
        for name, cell in top.get("cells", {}).items()
        if name.startswith(UNCORERAM) and cell.get("type") == "RAMB36E1"
    }
    if not ram_cells:
        print("ERROR: no uncore RAM RAMB36E1 cells found", file=sys.stderr)
        return 1

    init_fields = 0
    nonzero_fields = 0
    for cell in ram_cells.values():
        for key, value in cell.get("parameters", {}).items():
            if key.startswith("INIT_") and len(value) > 1:
                init_fields += 1
                if is_nonzero_init(value):
                    nonzero_fields += 1

    print(f"data.mem nonzero words: {len(data_words)}")
    print(f"uncore RAMB36E1 cells: {len(ram_cells)}")
    print(f"uncore RAM INIT fields: {nonzero_fields}/{init_fields} nonzero")

    if data_words and nonzero_fields == 0:
        print("ERROR: data.mem has nonzero words, but synthesized uncore RAM INITs are all zero")
        return 1

    print("OK: synthesized uncore RAM has nonzero INIT content")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
