"""QR d'appairage sans secret. Dépendance : qrcode==8.2 (sortie SVG)."""
import argparse
from pathlib import Path
from urllib.parse import urlencode, urlsplit, urlunsplit


def pairing_link(value: str) -> str:
    origin = urlsplit(value.strip())
    host = origin.hostname or ""
    if (
        not host or origin.username is not None or origin.password is not None
        or origin.path not in ("", "/") or "?" in value or "#" in value
        or any(c.isspace() for c in host) or "%" in host
        or (origin.port is not None and not 1 <= origin.port <= 65535)
        or not (origin.scheme == "https" or (
            origin.scheme == "http" and host.endswith(".ts.net")
            and len(host) > len(".ts.net")))
    ):
        raise ValueError("Origine invalide : HTTPS ou HTTP sur un sous-domaine ts.net uniquement.")
    clean = urlunsplit((origin.scheme, origin.netloc, "", "", ""))
    return "hermes-mobile://pair?" + urlencode({"url": clean})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("origin")
    parser.add_argument("--output", type=Path, default=Path("pairing.svg"))
    args = parser.parse_args()
    try:
        link = pairing_link(args.origin)
    except ValueError:
        parser.error("Origine invalide. Aucun QR généré.")
    import qrcode
    import qrcode.image.svg
    image = qrcode.make(link, image_factory=qrcode.image.svg.SvgPathImage)
    image.save(args.output)
    print(link)
    print(f"QR créé : {args.output}")


if __name__ == "__main__":
    main()
