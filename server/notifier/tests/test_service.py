"""Cycle de vie du service : CLI de production, redémarrage et purge."""

from __future__ import annotations

import io
import json
import tempfile
import threading
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from hermes_notifier import __version__
from hermes_notifier.credential import compute_hash, generate_salt, generate_token
from hermes_notifier.service import Service, main
from hermes_notifier.store import Store

from . import support


class ServiceLifecycleTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.contracts = support.contracts()
        self.config, self.token = support.make_config(
            Path(self._tmp.name), "http://127.0.0.1:1"
        )
        self.service: Service | None = None

    def tearDown(self) -> None:
        if self.service is not None:
            self.service.stop()

    # --- CLI ------------------------------------------------------------

    def test_version(self) -> None:
        out = io.StringIO()
        with redirect_stdout(out):
            code = main(["--version"])
        self.assertEqual(code, 0)
        self.assertEqual(out.getvalue().strip(), __version__)

    def test_check_affiche_un_resume_sans_secret(self) -> None:
        token = generate_token()
        salt = generate_salt()
        options = {
            "environment": "integration",
            "hermes_origin": "http://127.0.0.1:1",
            "hermes_username": "hermes",
            "hermes_password": "mot-de-passe-synthetique",
            "hermes_profile": "default",
            "bearer_hash": compute_hash(token, salt),
            "bearer_salt": salt,
            "fcm_enabled": False,
            "log_level": "info",
            "rate_limit_per_minute": 120,
            "port": 0,
        }
        path = Path(self._tmp.name) / "options.json"
        path.write_text(json.dumps(options), encoding="utf-8")
        out = io.StringIO()
        with redirect_stdout(out):
            code = main(["--check", "--options", str(path)])
        self.assertEqual(code, 0)
        summary = json.loads(out.getvalue())
        self.assertTrue(summary["ok"])
        for secret in (token, salt, options["bearer_hash"], "mot-de-passe-synthetique"):
            self.assertNotIn(secret, out.getvalue())

    # --- cycle de vie ---------------------------------------------------

    def test_run_s_arrete_sur_stop(self) -> None:
        results: list[int] = []
        thread = threading.Thread(
            target=lambda: results.append(self.service.run())  # type: ignore[union-attr]
        )
        self.service = Service(self.config, self.contracts)
        thread.start()
        self.assertTrue(
            self.wait(lambda: self.service is not None and self.service.api is not None)
        )
        self.service._stop.set()  # noqa: SLF001 - arrêt coopératif testé
        thread.join(15.0)
        self.assertFalse(thread.is_alive())
        self.assertEqual(results, [0])
        self.assertFalse(self.service._started)
        self.assertIsNone(self.service.store)

    def test_stop_puis_start_reconstruit_les_composants(self) -> None:
        self.service = Service(self.config, self.contracts)
        self.service.start()
        first_port = self.service.api.port
        self.service.stop()
        self.service.start()
        self.assertIsNotNone(self.service.api)
        assert self.service.api is not None
        self.assertTrue(self.service.api.port > 0)
        status, _, raw = support.http_request(
            f"http://127.0.0.1:{self.service.api.port}",
            "GET",
            "/v1/health",
            token=self.token,
        )
        self.assertEqual(status, 200)
        self.assertIn(json.loads(raw)["state"], {"ok", "degraded"})
        self.assertNotEqual(first_port, 0)

    def test_demarrage_purge_les_etats_perimes(self) -> None:
        data = self.config.data_path(self.contracts)
        data.mkdir(parents=True, exist_ok=True)
        clock = int(time.time()) - 100
        seed = Store(
            data / "notifier.sqlite3",
            outcomes=self.contracts.outcomes,
            now=lambda: clock,
        )
        subscription = support.subscription_id("purge")
        try:
            seed.register(subscription, b"token", ttl_seconds=10)
        finally:
            seed.close()

        self.service = Service(self.config, self.contracts)
        self.service.start()
        assert self.service.store is not None
        stored = self.service.store.get_subscription(subscription)
        assert stored is not None
        self.assertEqual(stored.state, "expired")
        self.assertEqual(self.service.store.counter("expired"), 1)

    # --- helpers --------------------------------------------------------

    def wait(self, predicate, timeout: float = 8.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.03)
        return predicate()


if __name__ == "__main__":
    unittest.main()
