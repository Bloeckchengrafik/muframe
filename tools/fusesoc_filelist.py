#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

import yaml


HDL_FILE_TYPES = {
    "verilogSource",
    "verilogSource-95",
    "verilogSource-2001",
    "verilogSource-2005",
    "systemVerilogSource",
    "systemVerilogSource-3.0",
    "systemVerilogSource-3.1",
    "systemVerilogSource-3.1a",
    "systemVerilogSource-2005",
    "systemVerilogSource-2009",
    "systemVerilogSource-2012",
    "systemVerilogSource-2017",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("edam", type=Path)
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("verible.filelist"),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    edam_path = args.edam.resolve()

    with edam_path.open() as f:
        edam = yaml.safe_load(f)

    # FuseSoC/Edalize paths are relative to the EDAM work directory.
    work_root = edam_path.parent

    files: list[Path] = []

    for entry in edam.get("files", []):
        if entry.get("file_type") not in HDL_FILE_TYPES:
            continue

        # Headers are reached through `include and should not be
        # parsed as standalone compilation units.
        # if entry.get("is_include_file", False):
            # continue

        name = entry.get("name")
        if not name:
            continue

        path = Path(name)

        if not path.is_absolute():
            path = work_root / path

        files.append(path.resolve())

    files = list(dict.fromkeys(files))

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w") as f:
        for path in files:
            print(path, file=f)

    print(f"{args.output}: wrote {len(files)} files")


if __name__ == "__main__":
    main()
