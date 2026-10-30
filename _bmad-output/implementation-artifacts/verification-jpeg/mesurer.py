"""Lance la sonde dédiée sans journaliser la configuration locale."""
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[3]
environment = os.environ.copy()
for line in (root / "_bmad-output/implementation-artifacts/.hermes-mesure.env").read_text(encoding="utf-8-sig").splitlines():
    if line.strip() and not line.lstrip().startswith("#"):
        key, value = line.split("=", 1)
        environment[key.strip()] = value.strip().strip('"').strip("'")
base = "_bmad-output/implementation-artifacts/verification-jpeg/"
dart = Path.home() / "fvm/versions/3.47.7/bin/cache/dart-sdk/bin/dart.exe"
arguments = [str(dart), "run", "tool/mesure_pieces_jointes.dart",
             "--profil-de-test", "mesure-pieces-jointes",
             "--piece", "image=" + base + "synthetique-petit.jpg",
             "--piece", "image=" + base + "synthetique-borne.jpeg",
             "--surface", "image.attach_bytes", "--repetitions", "3",
             "--sortie", base + "mesure-jpeg.json"]
if "--diagnostic" in sys.argv:
    arguments = [str(dart), "run", base + "diagnostiquer.dart"]
kind = "diagnostic" if "--diagnostic" in sys.argv else "campagne"
with (root / base / "execution.log").open("a", encoding="utf-8") as log:
    header = f"{datetime.now(timezone.utc).isoformat()} {kind}\n"
    print(header, end="", flush=True)
    log.write(header)
    process = subprocess.Popen(arguments, cwd=root, env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, encoding="utf-8", errors="replace")
    for line in process.stdout:
        print(line, end="", flush=True)
        log.write(line)
        log.flush()
    code = process.wait()
    log.write(f"Code de sortie : {code}\n")
raise SystemExit(code)
