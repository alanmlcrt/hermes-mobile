"""Santé : états, raisons avec seuils et compteurs bornés."""

from __future__ import annotations

import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from hermes_notifier import __version__
from hermes_notifier.errors import StorageError
from hermes_notifier.health import HealthState
from hermes_notifier.store import Store

from . import support


class HealthTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.contracts = support.contracts()
        self.now = [1_700_000_000.0]
        self.store = Store(
            Path(self._tmp.name) / "notifier.sqlite3",
            outcomes=self.contracts.outcomes,
            now=lambda: int(self.now[0]),
        )
        self.addCleanup(self.store.close)

    def state(self, *, environment: str = "integration", dry_run: bool = True):
        return HealthState(
            self.contracts,
            environment=environment,
            dry_run=dry_run,
            now=lambda: self.now[0],
        )

    def test_ok_avec_champs_exacts_et_compteurs(self) -> None:
        response = self.state().snapshot(self.store)
        self.assertEqual(response["state"], "ok")
        self.assertEqual(response["reasons"], [])
        self.assertEqual(set(response["counters"]), set(self.contracts.health_counters))
        self.assertTrue(all(value == 0 for value in response["counters"].values()))
        self.assertEqual(response["version"], __version__)
        self.assertRegex(
            response["checkedAt"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"
        )
        parsed = datetime.fromisoformat(response["checkedAt"].replace("Z", "+00:00"))
        self.assertIsNotNone(parsed.tzinfo)

    def test_hermes_injoignable_avec_seuil(self) -> None:
        health = self.state()
        self.assertEqual(health.snapshot(self.store)["state"], "ok")
        health.set_watchers(1)
        response = health.snapshot(self.store)
        self.assertEqual(response["state"], "degraded")
        self.assertEqual(
            response["reasons"],
            [{"reason": "hermes-unreachable", "thresholdSeconds": 60}],
        )
        health.record_hermes_success()
        self.assertEqual(health.snapshot(self.store)["state"], "ok")
        self.now[0] += 61
        response = health.snapshot(self.store)
        self.assertEqual(response["state"], "degraded")
        self.assertEqual(response["reasons"][0]["thresholdSeconds"], 60)

    def test_backlog_outbox_avec_seuil(self) -> None:
        health = self.state()
        for index in range(51):
            subscription = support.subscription_id(f"backlog-{index}")
            self.store.register(
                subscription, b"token", ttl_seconds=self.contracts.registered_ttl_seconds
            )
            session = f"session-{index}"
            execution = self.contracts.execution_id(session, index)
            self.store.attach(
                subscription,
                connection="http://hermes",
                session_id=session,
                profile="default",
                execution_id=execution,
                user_row_id=index,
                ttl_seconds=self.contracts.attached_ttl_seconds,
            )
            self.store.record_terminal(
                subscription_id=subscription,
                execution_id=execution,
                terminal="succeeded",
            )
        response = health.snapshot(self.store)
        self.assertEqual(response["state"], "degraded")
        self.assertEqual(
            response["reasons"],
            [{"reason": "outbox-backlog", "threshold": 50}],
        )
        self.assertEqual(response["counters"]["outboxPending"], 51)

    def test_erreur_stockage_puis_retour_a_ok(self) -> None:
        health = self.state()
        with mock.patch.object(
            self.store,
            "counters_snapshot",
            side_effect=StorageError("lecture"),
        ):
            response = health.snapshot(self.store)
        self.assertEqual(response["state"], "degraded")
        self.assertEqual(
            response["reasons"], [{"reason": "storage-error", "thresholdSeconds": 0}]
        )
        # La sonde suivante réussit : la dégradation est levée sans redémarrage.
        response = health.snapshot(self.store)
        self.assertEqual(response["state"], "ok")
        self.assertEqual(response["reasons"], [])

    def test_fcm_ignore_en_dry_run(self) -> None:
        health = self.state(dry_run=True)
        health.record_fcm_error()
        self.now[0] += 1000
        self.assertEqual(health.snapshot(self.store)["reasons"], [])
        health = self.state(environment="personal", dry_run=False)
        health.record_fcm_error()
        self.now[0] += 301
        response = health.snapshot(self.store)
        self.assertEqual(
            response["reasons"],
            [{"reason": "fcm-unavailable", "thresholdSeconds": 300}],
        )
        health.record_fcm_success()
        self.assertEqual(health.snapshot(self.store)["reasons"], [])

    def test_aucun_champ_interdit(self) -> None:
        response = self.state().snapshot(self.store)
        forbidden = set(self.contracts.health_forbidden_fields)
        self.assertEqual(forbidden & set(response), set())
        self.assertEqual(
            forbidden & set(response["counters"]), set()
        )


if __name__ == "__main__":
    unittest.main()
