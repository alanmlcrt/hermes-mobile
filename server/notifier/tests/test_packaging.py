"""Packaging de l'add-on : HA, image, contrats vendorisés et CI."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

import yaml

from hermes_notifier import __version__

from . import support

ROOT = support.VENDOR.parents[3]
ADDON = ROOT / "server" / "notifier"


class PackagingTest(unittest.TestCase):
    def test_config_yaml_add_on(self) -> None:
        data = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
        self.assertEqual(data["name"], "Hermes Notifier")
        self.assertEqual(data["version"], __version__)
        self.assertEqual(data["slug"], "hermes_notifier")
        self.assertNotIn("ports", data)
        self.assertEqual(data["watchdog"], "tcp://[HOST]:[PORT:8787]")
        self.assertEqual(data["arch"], ["amd64", "aarch64"])
        # `/data` est toujours monté par le Supervisor : aucune entrée `map`
        # n'est nécessaire, et aucun autre chemin persistant n'est exposé.
        self.assertEqual(data["map"], [{"type": "share", "read_only": True}])
        self.assertEqual(data["startup"], "application")
        self.assertTrue(data["boot"] == "auto")
        self.assertFalse(data["init"])
        self.assertEqual(data["options"]["environment"], "integration")
        for key in ("bearer_hash", "bearer_salt", "fcm_enabled", "hermes_origin"):
            self.assertIn(key, data["schema"])

    def test_dockerfile_autonome_et_epingle(self) -> None:
        text = (ADDON / "Dockerfile").read_text(encoding="utf-8")
        # Supervisor >= 2026.04 ne passe plus BUILD_FROM par défaut : le
        # défaut du Dockerfile suffit, et le build HA peut toujours le piloter.
        self.assertIn("ARG BUILD_FROM=python:3.13-slim-bookworm", text)
        self.assertIn("FROM ${BUILD_FROM}", text)
        self.assertIn("COPY requirements.txt", text)
        self.assertIn("COPY hermes_notifier", text)
        self.assertIn("COPY vendor", text)
        self.assertIn("COPY run.sh", text)
        self.assertIn('CMD ["/run.sh"]', text)
        self.assertNotIn("ADD ", text)
        self.assertNotIn("curl", text)

    def test_run_sh_exec(self) -> None:
        text = (ADDON / "run.sh").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("#!/usr/bin/env sh"))
        self.assertIn("exec python -m hermes_notifier", text)

    def test_requirements_epinglees(self) -> None:
        text = (ADDON / "requirements.txt").read_text(encoding="utf-8")
        pins = {
            line.split("==")[0]: line.split("==")[1]
            for line in text.splitlines()
            if line.strip() and not line.startswith("#")
        }
        self.assertEqual(set(pins), {"cryptography", "websockets", "google-auth", "requests"})
        for value in pins.values():
            self.assertRegex(value, r"^\d+\.\d+(\.\d+)?$")
        self.assertIn("PyYAML==", (ADDON / "requirements-dev.txt").read_text())

    def test_repository_yaml(self) -> None:
        data = yaml.safe_load((ROOT / "repository.yaml").read_text(encoding="utf-8"))
        self.assertEqual(data["name"], "Hermes Mobile Add-ons")
        self.assertEqual(data["url"], "https://github.com/alanmlcrt/hermes-mobile")
        self.assertIn("maintainer", data)

    def test_contrats_vendorises_identiques(self) -> None:
        for name in (
            "event-mapping.json",
            "notification-tracking.json",
            "notification-deployment.json",
        ):
            self.assertEqual(
                (ROOT / "contracts" / name).read_bytes(),
                (ADDON / "vendor" / "contracts" / name).read_bytes(),
                name,
            )

    def test_sync_check(self) -> None:
        import sync_contracts

        self.assertEqual(sync_contracts.sync(True), 0)

    def test_watchdog_et_port_par_defaut(self) -> None:
        data = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
        match = re.fullmatch(r"tcp://\[HOST\]:\[PORT:(\d+)\]", data["watchdog"])
        assert match is not None
        from hermes_notifier.config import Config

        config = Config.load(options=data["options"], environ={})
        self.assertEqual(config.port, int(match.group(1)))
        self.assertEqual(config.port, 8787)
        self.assertNotIn("port", data["schema"])
        self.assertNotIn("ports", data)

    def test_schema_accepte_les_defauts_vides(self) -> None:
        data = yaml.safe_load((ADDON / "config.yaml").read_text(encoding="utf-8"))
        for key in ("bearer_hash", "bearer_salt"):
            self.assertEqual(data["options"][key], "")
            schema = re.fullmatch(r"match\((.*)\)", data["schema"][key])
            assert schema is not None
            pattern = re.compile(schema.group(1))
            self.assertTrue(pattern.match(data["options"][key]))
            self.assertFalse(pattern.match("abc"))

    def test_sync_detecte_derive_et_absence(self) -> None:
        import contextlib
        import io
        import tempfile
        from unittest import mock

        import sync_contracts

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            source = base / "contracts"
            target = base / "vendor"
            source.mkdir()
            target.mkdir()
            for name in sync_contracts.CONTRACTS:
                (source / name).write_text("{}", encoding="utf-8")
                (target / name).write_text("{}", encoding="utf-8")
            with mock.patch.object(sync_contracts, "SOURCE", source), mock.patch.object(
                sync_contracts, "TARGET", target
            ), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(sync_contracts.sync(True), 0)
                (target / sync_contracts.CONTRACTS[0]).write_text(
                    "derive", encoding="utf-8"
                )
                self.assertEqual(sync_contracts.sync(True), 1)
                (target / sync_contracts.CONTRACTS[0]).unlink()
                self.assertEqual(sync_contracts.sync(True), 1)
                (source / sync_contracts.CONTRACTS[0]).unlink()
                self.assertEqual(sync_contracts.sync(True), 2)

    def test_ci_build_et_smoke_docker(self) -> None:
        text = (ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("docker build", text)
        self.assertIn("server/notifier/Dockerfile", text)
        self.assertIn("python -m hermes_notifier --version", text)
        self.assertIn("Contracts.load", text)

    def test_ci_execute_les_tests_notifier(self) -> None:
        text = (ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("sync_contracts.py --check", text)
        self.assertIn("server/notifier/tests", text)
        self.assertIn("server/notifier/requirements.txt", text)


if __name__ == "__main__":
    unittest.main()
