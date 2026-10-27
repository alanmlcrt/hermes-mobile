"""Credential bearer hash-only et chiffrement du token FCM.

Le bearer est généré hors du conteneur (CLI) puis seul son hash salé est
configuré. Le token FCM est chiffré au repos avec une clé de ``/data`` en 0600.
Rien de tout cela n'est journalisé.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import secrets
import sys
import threading
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken


class CredentialError(Exception):
    """Erreur de credential, sans secret dans le message."""


class TokenUnavailable(CredentialError):
    """Le token chiffré ne peut pas être relu (clé absente ou corrompue)."""


def generate_token(entropy_bits: int = 256) -> str:
    if entropy_bits < 128 or entropy_bits % 8:
        raise ValueError("entropy")
    return secrets.token_urlsafe(entropy_bits // 8)


def generate_salt(length: int = 32) -> str:
    if length < 16:
        raise ValueError("salt")
    return secrets.token_hex(length)


def compute_hash(token: str, salt_hex: str) -> str:
    try:
        salt = bytes.fromhex(salt_hex)
    except ValueError as exc:
        raise CredentialError("credential.salt") from exc
    if not token or not salt:
        raise CredentialError("credential.input")
    return hashlib.sha256(salt + token.encode("utf-8")).hexdigest()


def verify(token: str, expected_hash: str, salt_hex: str) -> bool:
    if not isinstance(token, str) or not token:
        return False
    if not isinstance(expected_hash, str) or not expected_hash.isascii():
        # ``compare_digest`` lève TypeError sur une chaîne non ASCII ; un
        # hash reçu par la CLI ne doit jamais faire planter la vérification.
        return False
    try:
        actual = compute_hash(token, salt_hex)
    except CredentialError:
        return False
    return hmac.compare_digest(actual, expected_hash)


class BearerCredential:
    """Vérifie ``Authorization: Bearer <token>`` en temps constant."""

    def __init__(self, expected_hash: str, salt_hex: str) -> None:
        self._hash = expected_hash
        self._salt = salt_hex

    def verify_header(self, header: object) -> bool:
        if not isinstance(header, str):
            return False
        scheme, separator, token = header.partition(" ")
        if separator != " " or scheme.lower() != "bearer":
            return False
        token = token.strip()
        if not token or " " in token:
            return False
        return verify(token, self._hash, self._salt)


class TokenCipher:
    """Chiffrement symétrique du token FCM, clé persistante en 0600."""

    def __init__(self, key_path: Path) -> None:
        self._path = Path(key_path)
        self._lock = threading.Lock()
        try:
            self._fernet = Fernet(self._load_or_create())
        except (ValueError, TypeError) as exc:
            raise CredentialError("credential.key_invalid") from exc

    def _load_or_create(self) -> bytes:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        with self._lock:
            if self._path.exists():
                data = self._path.read_bytes().strip()
                if not data:
                    raise CredentialError("credential.key_empty")
                # Fernet valide la clé à la construction.
                return data
            key = Fernet.generate_key()
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
            try:
                descriptor = os.open(self._path, flags, 0o600)
            except FileExistsError:
                return self._path.read_bytes().strip()
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(key)
            try:
                os.chmod(self._path, 0o600)
            except OSError:
                # Windows ne gère pas les modes POSIX ; le volume /data reste
                # la seule protection attendue.
                pass
            return key

    def encrypt(self, token: str) -> bytes:
        if not isinstance(token, str) or not token:
            raise CredentialError("credential.token")
        return self._fernet.encrypt(token.encode("utf-8"))

    def decrypt(self, blob: bytes) -> str:
        try:
            value = self._fernet.decrypt(blob)
        except (InvalidToken, TypeError, ValueError) as exc:
            raise TokenUnavailable("credential.token_unreadable") from exc
        try:
            return value.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise TokenUnavailable("credential.token_unreadable") from exc


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m hermes_notifier.credential",
        description="Génère ou vérifie le credential bearer de l'observateur.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    generate = sub.add_parser("generate", help="Génère token, sel et hash.")
    generate.add_argument("--json", action="store_true", help="Sortie JSON.")
    generate.add_argument(
        "--entropy-bits", type=int, default=256, help="Entropie du token (>=128)."
    )

    check = sub.add_parser("verify", help="Vérifie un token contre hash et sel.")
    check.add_argument("--token", required=True)
    check.add_argument("--hash", dest="expected_hash", required=True)
    check.add_argument("--salt", required=True)

    arguments = parser.parse_args(argv)

    if arguments.command == "generate":
        token = generate_token(arguments.entropy_bits)
        salt = generate_salt()
        digest = compute_hash(token, salt)
        if arguments.json:
            print(
                json.dumps(
                    {"token": token, "salt": salt, "hash": digest},
                    separators=(",", ":"),
                )
            )
        else:
            # Sortie destinée à l'opérateur, hors conteneur. Ne jamais coller
            # le token dans les options de l'add-on : seul le hash y va.
            print(f"token={token}")
            print(f"salt={salt}")
            print(f"hash={digest}")
        return 0

    if verify(arguments.token, arguments.expected_hash, arguments.salt):
        print("ok")
        return 0
    print("refusé", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
