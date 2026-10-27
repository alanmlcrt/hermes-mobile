"""Configuration, environnements et credential hash-only."""

from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from hermes_notifier.config import Config
from hermes_notifier.credential import (
    BearerCredential,
    CredentialError,
    TokenCipher,
    TokenUnavailable,
    compute_hash,
    generate_salt,
    generate_token,
    main as credential_main,
    verify,
)
from hermes_notifier.errors import ConfigError
from hermes_notifier.service import Service

from . import support


def options(**overrides):
    token = generate_token()
    salt = generate_salt()
    base = {
        "environment": "integration",
        "hermes_origin": "http://127.0.0.1:1",
        "hermes_username": "hermes",
        "hermes_password": "secret",
        "hermes_profile": "default",
        "bearer_hash": compute_hash(token, salt),
        "bearer_salt": salt,
        "fcm_enabled": False,
        "log_level": "info",
        "rate_limit_per_minute": 120,
    }
    base.update(overrides)
    return base, token


class ConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contracts = support.contracts()

    def test_options_et_environnement(self) -> None:
        raw, token = options()
        config = Config.load(
            options=raw,
            environ={
                "HERMES_NOTIFIER_DATA_DIR": "C:/data",
                "HERMES_NOTIFIER_PORT": "9999",
            },
        )
        config.validate(self.contracts)
        self.assertEqual(config.environment, "integration")
        self.assertEqual(config.port, 9999)
        self.assertTrue(
            BearerCredential(config.bearer_hash, config.bearer_salt).verify_header(
                f"Bearer {token}"
            )
        )
        summary = config.summary(self.contracts)
        self.assertNotIn("token", summary)
        self.assertNotIn("password", summary)

    def test_aucun_secret_en_clair(self) -> None:
        raw, _ = options(bearer="clair")
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={})
        raw, _ = options(token="clair")
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={})
        raw, _ = options()
        with self.assertRaises(ConfigError):
            Config.load(
                options=raw,
                environ={"HERMES_NOTIFIER_BEARER": "clair"},
            )

    def test_origine_stricte(self) -> None:
        for origin in (
            "",
            "ftp://hermes",
            "http://user:pass@hermes",
            "http://hermes/?x=1",
            "http://hermes/#fragment",
        ):
            raw, _ = options(hermes_origin=origin)
            with self.assertRaises(ConfigError, msg=origin):
                Config.load(options=raw, environ={}).validate(self.contracts)

    def test_hash_et_sel_valides(self) -> None:
        raw, _ = options(bearer_hash="abc")
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)
        raw, _ = options(bearer_salt="abc")
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)
        raw, _ = options(bearer_salt="zz" * 32)
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)

    def test_environnement_inconnu_ou_non_isole(self) -> None:
        raw, _ = options(environment="production")
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)

    def test_integration_verrouillee_en_dry_run(self) -> None:
        raw, _ = options(fcm_enabled=True)
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)

    def test_personal_refuse_sans_firebase(self) -> None:
        raw, _ = options(environment="personal", fcm_enabled=False)
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)
        raw, _ = options(environment="personal", fcm_enabled=True)
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)

    def test_personal_refuse_par_le_service_meme_complet(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            account = Path(directory) / "service-account.json"
            account.write_text("{}", encoding="utf-8")
            raw, _ = options(
                environment="personal",
                fcm_enabled=True,
                fcm_service_account=str(account),
            )
            config = Config.load(options=raw, environ={})
            service = Service(config, self.contracts)
            with self.assertRaises(ConfigError):
                service.check()

    def test_fixtures_et_isolation_des_chemins(self) -> None:
        raw, _ = options(environment="fixtures")
        config = Config.load(options=raw, environ={})
        config.validate(self.contracts)
        self.assertEqual(
            config.data_path(self.contracts).name, "notifier-registry-fixtures"
        )
        self.assertNotEqual(
            config.data_path(self.contracts),
            Config.load(
                options=options(environment="integration")[0], environ={}
            ).data_path(self.contracts),
        )

    def test_options_fichier_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "options.json"
            raw, _ = options()
            path.write_text(json.dumps(raw), encoding="utf-8")
            config = Config.load(options_path=path, environ={})
            config.validate(self.contracts)
            self.assertEqual(config.environment, "integration")

    def test_log_level_invalide(self) -> None:
        raw, _ = options(log_level="trace")
        with self.assertRaises(ConfigError):
            Config.load(options=raw, environ={}).validate(self.contracts)


class CredentialTest(unittest.TestCase):
    def test_generation_et_verification(self) -> None:
        token = generate_token()
        salt = generate_salt()
        digest = compute_hash(token, salt)
        self.assertTrue(verify(token, digest, salt))
        self.assertFalse(verify(token + "x", digest, salt))
        self.assertFalse(verify("", digest, salt))
        self.assertFalse(verify(token, digest, "pas-hex"))

    def test_cli_generation_et_verification(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(credential_main(["generate", "--json"]), 0)
        values = json.loads(output.getvalue())
        self.assertTrue(verify(values["token"], values["hash"], values["salt"]))
        self.assertEqual(
            credential_main(
                [
                    "verify",
                    "--token",
                    values["token"],
                    "--hash",
                    values["hash"],
                    "--salt",
                    values["salt"],
                ]
            ),
            0,
        )
        self.assertNotEqual(
            credential_main(
                [
                    "verify",
                    "--token",
                    "faux",
                    "--hash",
                    values["hash"],
                    "--salt",
                    values["salt"],
                ]
            ),
            0,
        )

    def test_chiffrement_du_token_au_repos(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "token.key"
            cipher = TokenCipher(path)
            blob = cipher.encrypt("fcm-clair")
            self.assertNotIn(b"fcm-clair", blob)
            self.assertEqual(cipher.decrypt(blob), "fcm-clair")
            self.assertEqual(path.read_bytes(), path.read_bytes().strip())
            if os.name == "posix":
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(TokenUnavailable):
                TokenCipher(path).decrypt(blob[:-2] + b"xx")

    def test_cle_absente_ou_vide(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "token.key"
            path.write_bytes(b"")
            with self.assertRaises(CredentialError):
                TokenCipher(path)
            path.write_bytes(b"pas-une-cle")
            with self.assertRaises(CredentialError):
                TokenCipher(path)

    def test_entropie_et_sel_bornes(self) -> None:
        with self.assertRaises(ValueError):
            generate_token(64)
        with self.assertRaises(ValueError):
            generate_token(129)
        with self.assertRaises(ValueError):
            generate_salt(8)
        with self.assertRaises(CredentialError):
            compute_hash("", generate_salt())


if __name__ == "__main__":
    unittest.main()
