#!/usr/bin/env python3
"""Copie byte-identique des contrats partagés dans ``vendor/contracts``.

L'image de l'add-on ne dépend pas du dépôt mobile au runtime : elle embarque
ces trois fichiers. ``--check`` échoue si une copie a dérivé.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path

CONTRACTS = (
    "event-mapping.json",
    "notification-tracking.json",
    "notification-deployment.json",
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / "contracts"
TARGET = HERE / "vendor" / "contracts"


def sync(check: bool) -> int:
    missing = [name for name in CONTRACTS if not (SOURCE / name).is_file()]
    if missing:
        print(
            "contrats canoniques absents: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 2
    if check:
        diffs = []
        for name in CONTRACTS:
            source = SOURCE / name
            target = TARGET / name
            if not target.is_file():
                diffs.append(f"{name}: absent")
                continue
            if source.read_bytes() != target.read_bytes():
                diffs.append(
                    f"{name}: {_digest(source)} != {_digest(target)}"
                )
        if diffs:
            print("copies de contrats différentes:", file=sys.stderr)
            for line in diffs:
                print("  " + line, file=sys.stderr)
            return 1
        print("contrats vendorises identiques")
        return 0

    TARGET.mkdir(parents=True, exist_ok=True)
    for name in CONTRACTS:
        shutil.copyfile(SOURCE / name, TARGET / name)
    print("contrats copies: " + ", ".join(CONTRACTS))
    return 0


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="sync_contracts.py")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Vérifie sans écrire ; code 1 si une copie diffère.",
    )
    arguments = parser.parse_args(argv)
    return sync(arguments.check)


if __name__ == "__main__":
    raise SystemExit(main())
