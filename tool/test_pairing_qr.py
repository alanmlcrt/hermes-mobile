"""Vérifications du lien QR et de la confidentialité des erreurs CLI."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from generate_pairing_qr import pairing_link


class PairingQrTests(unittest.TestCase):
    def test_origines_autorisees(self):
        for origin in ("http://desktop.example.ts.net:9119", "https://desktop.example.com"):
            link = urlsplit(pairing_link(origin))
            self.assertEqual((link.scheme, link.netloc), ("hermes-mobile", "pair"))
            self.assertEqual(parse_qs(link.query), {"url": [origin]})

    def test_origines_refusees(self):
        for origin in ("http://ts.net", "http://localhost:9119", "http://foo.ts.net.evil",
                       "https://user:secret@example.com", "https://@example.com",
                       "https://example.com/path", "https://example.com?secret=x",
                       "https://example.com#secret", "https://example.com?",
                       "ftp://example.com", "https://example.com:99999"):
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                pairing_link(origin)

    def test_erreur_cli_sans_secret_ni_fichier(self):
        with tempfile.TemporaryDirectory(prefix="hermes-qr-") as directory:
            output = Path(directory) / "forbidden.svg"
            result = subprocess.run([sys.executable, str(Path(__file__).with_name("generate_pairing_qr.py")),
                                     "https://user:SYNTHETIC_SECRET@example.com", "--output", str(output)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertNotIn("SYNTHETIC_SECRET", result.stderr + result.stdout)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
