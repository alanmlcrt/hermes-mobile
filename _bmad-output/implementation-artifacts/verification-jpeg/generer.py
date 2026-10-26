"""Corpus JPEG synthétique reproductible ; aucune photographie personnelle."""
from hashlib import sha256
from io import BytesIO
from pathlib import Path
import json
import random

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
target = 20_965_448
randomizer = random.Random(20261026)
manifest = []
for name, size in [("synthetique-petit.jpg", (320, 240)),
                   ("synthetique-borne.jpeg", (4096, 4096))]:
    if size[0] == 320:
        image = Image.new("RGB", size, "white")
    else:
        image = Image.frombytes("RGB", size, randomizer.randbytes(size[0] * size[1] * 3))
    ImageDraw.Draw(image).text((12, 12), "TEST SYNTHETIQUE JPEG", fill="black")
    exif = Image.Exif()
    exif[274] = 1
    stream = BytesIO()
    image.save(stream, format="JPEG", quality=90, exif=exif)
    data = stream.getvalue()
    if size[0] == 4096:
        # Segments COM JPEG valides avant EOI, pour atteindre la borne exacte.
        remaining = target - len(data)
        assert remaining >= 4
        segments = []
        while remaining:
            length = min(remaining, 65537)
            if 0 < remaining - length < 4:
                length -= 4 - (remaining - length)
            payload = b"TEST SYNTHETIQUE " * ((length - 4) // 17 + 1)
            segments.append(b"\xff\xfe" + (length - 2).to_bytes(2, "big") + payload[:length - 4])
            remaining -= length
        data = data[:-2] + b"".join(segments) + data[-2:]
        assert len(data) == target
    path = root / name
    path.write_bytes(data)
    with Image.open(path) as decoded:
        decoded.load()
        assert decoded.size == size and decoded.format == "JPEG"
        assert decoded.getexif()[274] == 1
    manifest.append({"file": name, "bytes": len(data), "width": size[0],
                     "height": size[1], "exifOrientation": 1,
                     "sha256": sha256(data).hexdigest()})
(root / "corpus.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("Deux JPEG synthetiques generes et decodes ; borne exacte verifiee.")
