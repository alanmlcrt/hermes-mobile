"""Observateur : terminal, erreur, rattrapage, troncature et redémarrage."""

from __future__ import annotations

import json
import logging
import tempfile
import time
import unittest
from pathlib import Path

from hermes_notifier.service import Service

from . import support


class _Capture(logging.Handler):
    def __init__(self) -> None:
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


class ObserverTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.fake = support.FakeHermes()
        self.fake.start()
        self.addCleanup(self.fake.stop)
        self.config, self.token = support.make_config(
            Path(self._tmp.name), self.fake.origin
        )
        self.service = Service(self.config, support.contracts())
        self.service.start()
        self.addCleanup(self._stop_service)
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        self._capture = _Capture()
        logger = logging.getLogger("hermes_notifier")
        logger.addHandler(self._capture)
        self.addCleanup(logger.removeHandler, self._capture)

    def _stop_service(self) -> None:
        if self.service is not None:
            self.service.stop()
            self.service = None

    def restart(self) -> None:
        self.service.stop()
        self.service = Service(self.config, support.contracts())
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"

    # --- helpers --------------------------------------------------------

    def register(self, subscription: str | None = None, token: str = "device") -> str:
        subscription = subscription or support.subscription_id("obs")
        status, _, _ = support.http_request(
            self.base,
            "POST",
            "/v1/subscriptions",
            token=self.token,
            body={"subscriptionId": subscription, "fcmToken": token},
        )
        self.assertIn(status, {200, 201})
        return subscription

    def attach(self, subscription: str, session: str, row: int) -> None:
        status, _, _ = support.http_request(
            self.base,
            "POST",
            f"/v1/subscriptions/{subscription}/attach",
            token=self.token,
            body={
                "sessionId": session,
                "profile": "default",
                "executionId": support.execution_id(session, row),
            },
        )
        self.assertEqual(status, 202)
        # Le curseur n'est écrit qu'à la fin du rattrapage initial : attendre
        # sa présence évite qu'un événement live soit aussi rejoué par
        # ``session.events.since``.
        self.assertTrue(self.wait(lambda: self.cursor(session) is not None))

    def wait(self, predicate, timeout: float = 8.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.03)
        return predicate()

    def outbox(self):
        return self.service.store.outbox_rows()

    def cursor(self, session: str):
        return self.service.store.get_cursor(
            connection=self.fake.origin,
            profile="default",
            session_id=session,
        )

    def stop_dispatcher(self) -> None:
        self.service.dispatcher.stop()

    # --- terminaux ------------------------------------------------------

    def test_terminal_succes_live(self) -> None:
        self.fake.add_session("s-live")
        subscription = self.register()
        self.attach(subscription, "s-live", 1)
        self.assertTrue(self.fake.wait_resumed("s-live"))
        self.assertTrue(self.fake.resume_calls[0].get("omit_messages") is True)

        self.fake.emit(
            "s-live",
            "message.complete",
            {
                "status": "complete",
                "persisted_turn": {"user_row_id": 1, "submission_id": "sub-1"},
            },
        )
        self.assertTrue(
            self.wait(lambda: len(self.outbox()) == 1)
        )
        entry = self.outbox()[0]
        self.assertEqual(entry.terminal, "succeeded")
        self.assertIn(entry.state, {"pending", "delivered"})
        self.assertTrue(
            self.wait(
                lambda: self.service.store.get_subscription(subscription).state
                == "notified"
            )
        )
        dedup = self.service.store.dedup_row(
            subscription, support.execution_id("s-live", 1), "succeeded"
        )
        assert dedup is not None
        self.assertEqual(dedup["seen_count"], 1)
        self.assertEqual(dedup["submission_id"], "sub-1")
        self.assertTrue(
            self.wait(lambda: self.service.store.counter("delivered") == 1)
        )

    def test_statut_inconnu_ne_notifie_pas(self) -> None:
        self.fake.add_session("s-unknown")
        subscription = self.register()
        self.attach(subscription, "s-unknown", 1)
        self.assertTrue(self.fake.wait_resumed("s-unknown"))
        self.fake.emit(
            "s-unknown",
            "message.complete",
            {"status": "inexistant", "persisted_turn": {"user_row_id": 1}},
        )
        time.sleep(0.4)
        self.assertEqual(self.outbox(), [])

    def test_message_complete_sans_persisted_turn_est_ignore(self) -> None:
        self.fake.add_session("s-row")
        subscription = self.register()
        self.attach(subscription, "s-row", 1)
        self.assertTrue(self.fake.wait_resumed("s-row"))
        self.fake.emit(
            "s-row", "message.complete", {"status": "complete"}
        )
        time.sleep(0.4)
        self.assertEqual(self.outbox(), [])

    def test_terminal_ancien_est_ignore(self) -> None:
        self.fake.add_session("s-old")
        subscription = self.register()
        self.attach(subscription, "s-old", 5)
        self.assertTrue(self.fake.wait_resumed("s-old"))
        self.fake.emit(
            "s-old",
            "message.complete",
            {"status": "complete", "persisted_turn": {"user_row_id": 4}},
        )
        time.sleep(0.4)
        self.assertEqual(self.outbox(), [])

    def test_doublon_et_premier_terminal(self) -> None:
        self.fake.add_session("s-double")
        subscription = self.register()
        self.attach(subscription, "s-double", 1)
        self.assertTrue(self.fake.wait_resumed("s-double"))
        self.stop_dispatcher()
        payload = {
            "status": "complete",
            "persisted_turn": {"user_row_id": 1},
        }
        self.fake.emit("s-double", "message.complete", payload)
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        self.fake.emit("s-double", "message.complete", payload)
        self.fake.emit(
            "s-double",
            "message.complete",
            {"status": "interrupted", "persisted_turn": {"user_row_id": 1}},
        )
        self.assertTrue(
            self.wait(
                lambda: (
                    (
                        self.service.store.dedup_row(
                            subscription,
                            support.execution_id("s-double", 1),
                            "succeeded",
                        )
                        or {}
                    ).get("seen_count")
                    == 2
                    and self.service.store.dedup_row(
                        subscription,
                        support.execution_id("s-double", 1),
                        "stopped",
                    )
                    is not None
                )
            )
        )
        rows = self.outbox()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].terminal, "succeeded")
        self.assertIsNotNone(
            self.service.store.dedup_row(
                subscription,
                support.execution_id("s-double", 1),
                "stopped",
            )
        )

    def test_error_unique_notifie_failed(self) -> None:
        self.fake.add_session("s-error")
        subscription = self.register()
        self.attach(subscription, "s-error", 1)
        self.assertTrue(self.fake.wait_resumed("s-error"))
        self.fake.emit("s-error", "error", {"message": "SYNTHETIC"})
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        self.assertEqual(self.outbox()[0].terminal, "failed")
        self.assertTrue(
            self.wait(
                lambda: self.service.store.get_subscription(subscription).state
                == "notified"
            )
        )

    def test_error_ambigue_est_ignore(self) -> None:
        self.fake.add_session("s-ambiguous")
        first = self.register(support.subscription_id("ambiguous-1"))
        second = self.register(support.subscription_id("ambiguous-2"))
        self.attach(first, "s-ambiguous", 1)
        self.attach(second, "s-ambiguous", 2)
        self.assertTrue(self.fake.wait_resumed("s-ambiguous"))
        self.fake.emit("s-ambiguous", "error", {"message": "SYNTHETIC"})
        time.sleep(0.6)
        self.assertEqual(self.outbox(), [])

    def test_error_apres_terminal_est_ignore(self) -> None:
        self.fake.add_session("s-after")
        subscription = self.register()
        self.attach(subscription, "s-after", 1)
        self.assertTrue(self.fake.wait_resumed("s-after"))
        self.stop_dispatcher()
        self.fake.emit(
            "s-after",
            "message.complete",
            {"status": "complete", "persisted_turn": {"user_row_id": 1}},
        )
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        self.fake.emit("s-after", "error", {"message": "SYNTHETIC"})
        time.sleep(0.5)
        self.assertEqual(len(self.outbox()), 1)
        self.assertEqual(
            self.service.store.error_candidates(session_ids=["s-after"]), []
        )

    # --- rattrapage -----------------------------------------------------

    def test_rattrapage_apres_redemarrage(self) -> None:
        self.fake.add_session("s-restart")
        subscription = self.register()
        self.attach(subscription, "s-restart", 1)
        self.assertTrue(self.fake.wait_resumed("s-restart"))
        self.fake.emit("s-restart", "message.start", {})
        self.assertTrue(
            self.wait(
                lambda: (self.cursor("s-restart") is not None)
                and self.cursor("s-restart").last_seen == 1
            )
        )
        cursor = self.cursor("s-restart")
        assert cursor is not None
        self.assertEqual(cursor.last_seen, 1)
        self.service.stop()

        self.fake.add_event(
            "s-restart",
            "message.complete",
            {
                "status": "complete",
                "persisted_turn": {"user_row_id": 1},
            },
        )
        self.service = Service(self.config, support.contracts())
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        self.assertTrue(
            self.wait(
                lambda: any(
                    call.get("last_seen") == 1 for call in self.fake.since_calls
                )
            )
        )
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        self.assertEqual(self.outbox()[0].terminal, "succeeded")
        self.assertTrue(
            self.wait(
                lambda: (self.cursor("s-restart") is not None)
                and self.cursor("s-restart").last_seen == 2
            )
        )

    def test_veille_reconstruite_avec_outbox_en_attente(self) -> None:
        self.fake.add_session("s-pending")
        subscription = self.register()
        self.attach(subscription, "s-pending", 1)
        execution_id = support.execution_id("s-pending", 1)
        if self.service.store is None or self.service.dispatcher is None:
            self.fail("service incomplet")
        self.stop_dispatcher()
        self.service.store.record_terminal(
            subscription_id=subscription,
            execution_id=execution_id,
            terminal="succeeded",
        )
        self.assertEqual(len(self.outbox()), 1)
        # Le terminal reste en attente : sans nouvelle veille, un doublon
        # tardif ne serait jamais observé après le redémarrage.
        entry = self.outbox()[0]
        self.service.store.mark_retry(
            entry.id,
            next_attempt_at=int(time.time()) + 3600,
            error_code="test",
        )
        resumes = len(self.fake.resume_calls)
        self.restart()
        self.assertTrue(
            self.wait(lambda: len(self.fake.resume_calls) > resumes)
        )
        self.assertEqual(self.outbox()[0].state, "pending")

    def test_sante_reflete_l_observateur(self) -> None:
        self.fake.add_session("s-health")
        subscription = self.register()
        self.attach(subscription, "s-health", 1)
        health = self.service.health
        assert health is not None
        # La veille partage l'état de santé de l'API : elle enregistre la
        # sonde, sans quoi ``hermes-unreachable`` ne serait jamais évalué.
        self.assertTrue(self.wait(lambda: health._watchers >= 1))  # noqa: SLF001
        health._last_hermes_success = time.monotonic() - 61  # noqa: SLF001
        status, _, raw = support.http_request(
            self.base, "GET", "/v1/health", token=self.token
        )
        self.assertEqual(status, 200)
        body = json.loads(raw)
        self.assertEqual(body["state"], "degraded")
        self.assertIn(
            {"reason": "hermes-unreachable", "thresholdSeconds": 60},
            body["reasons"],
        )

    def test_troncature_recharge_l_historique_et_exploite_le_terminal(self) -> None:
        self.fake.add_session("s-trunc")
        subscription = self.register()
        self.attach(subscription, "s-trunc", 1)
        self.assertTrue(self.fake.wait_resumed("s-trunc"))
        self.fake.emit("s-trunc", "message.start", {})
        self.assertTrue(
            self.wait(
                lambda: (self.cursor("s-trunc") is not None)
                and self.cursor("s-trunc").last_seen == 1
            )
        )
        self.service.stop()

        self.fake.sessions["s-trunc"].truncated = True
        self.fake.add_event(
            "s-trunc",
            "message.complete",
            {"status": "complete", "persisted_turn": {"user_row_id": 1}},
        )
        self.service = Service(self.config, support.contracts())
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        self.assertTrue(self.wait(lambda: bool(self.fake.history_calls)))
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        entries = self.outbox()
        self.assertEqual(entries[0].terminal, "succeeded")
        cursor = self.cursor("s-trunc")
        assert cursor is not None
        self.assertEqual(cursor.last_seen, 2)

    def test_changement_d_epoch_recharge_l_historique_et_exploite_le_terminal(self) -> None:
        self.fake.add_session("s-epoch")
        subscription = self.register()
        self.attach(subscription, "s-epoch", 1)
        self.assertTrue(self.fake.wait_resumed("s-epoch"))
        self.fake.emit("s-epoch", "message.start", {})
        self.assertTrue(
            self.wait(
                lambda: (self.cursor("s-epoch") is not None)
                and self.cursor("s-epoch").last_seen == 1
            )
        )
        self.service.stop()

        self.fake.set_epoch("epoch-2")
        self.fake.add_event(
            "s-epoch",
            "message.complete",
            {"status": "complete", "persisted_turn": {"user_row_id": 1}},
        )
        self.service = Service(self.config, support.contracts())
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        self.assertTrue(self.wait(lambda: bool(self.fake.history_calls)))
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        self.assertEqual(self.outbox()[0].terminal, "succeeded")
        self.assertTrue(
            self.wait(
                lambda: (self.cursor("s-epoch") is not None)
                and self.cursor("s-epoch").epoch == "epoch-2"
            )
        )

    def test_rejeu_borne_par_max_replay_events(self) -> None:
        self.fake.add_session("s-batch")
        subscription = self.register()
        self.attach(subscription, "s-batch", 1)
        self.service.stop()
        for _ in range(1005):
            self.fake.add_event("s-batch", "message.delta", {"text": "x"})
        self.service = Service(self.config, support.contracts())
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        self.assertTrue(
            self.wait(
                lambda: (self.cursor("s-batch") is not None)
                and self.cursor("s-batch").last_seen == 1005
            )
        )
        self.assertGreaterEqual(len(self.fake.since_calls), 2)

    def test_session_disparue_expire_apres_max_attempts(self) -> None:
        self.fake.add_session("s-gone", resume_error=True)
        subscription = self.register()
        self.service.stop()
        # Le helper ``attach`` attend un curseur que la session absente ne
        # produira jamais : attacher directement.
        self.service = Service(self.config, support.contracts())
        self.service.contracts.tracking["retries"]["observer"][
            "maxAttempts"
        ] = 1
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        status, _, _ = support.http_request(
            self.base,
            "POST",
            f"/v1/subscriptions/{subscription}/attach",
            token=self.token,
            body={
                "sessionId": "s-gone",
                "profile": "default",
                "executionId": support.execution_id("s-gone", 1),
            },
        )
        self.assertEqual(status, 202)
        execution_id = support.execution_id("s-gone", 1)
        self.assertTrue(
            self.wait(
                lambda: (
                    self.service.store is not None
                    and self.service.store.execution(execution_id) is not None
                    and self.service.store.execution(execution_id).state
                    == "expired"
                )
            )
        )

    def test_since_non_retryable_expire(self) -> None:
        self.fake.add_session("s-invalid", invalid_since=True)
        subscription = self.register()
        self.service.contracts.tracking["retries"]["observer"][
            "maxAttempts"
        ] = 1
        status, _, _ = support.http_request(
            self.base,
            "POST",
            f"/v1/subscriptions/{subscription}/attach",
            token=self.token,
            body={
                "sessionId": "s-invalid",
                "profile": "default",
                "executionId": support.execution_id("s-invalid", 1),
            },
        )
        self.assertEqual(status, 202)
        execution_id = support.execution_id("s-invalid", 1)
        self.assertTrue(
            self.wait(
                lambda: (
                    self.service.store is not None
                    and self.service.store.execution(execution_id) is not None
                    and self.service.store.execution(execution_id).state
                    == "expired"
                )
            )
        )

    def test_since_absent_replie_sur_historique(self) -> None:
        self.fake.add_session("s-nosince", since_error=-32601)
        subscription = self.register()
        status, _, _ = support.http_request(
            self.base,
            "POST",
            f"/v1/subscriptions/{subscription}/attach",
            token=self.token,
            body={
                "sessionId": "s-nosince",
                "profile": "default",
                "executionId": support.execution_id("s-nosince", 1),
            },
        )
        self.assertEqual(status, 202)
        self.assertTrue(self.wait(lambda: bool(self.fake.history_calls)))
        execution_id = support.execution_id("s-nosince", 1)
        self.assertEqual(
            self.service.store.execution(execution_id).state, "attached"
        )

    def test_epoch_absent_declenche_l_historique(self) -> None:
        self.fake.add_session("s-noepoch")
        self.fake.set_epoch(None)  # type: ignore[arg-type]
        subscription = self.register()
        status, _, _ = support.http_request(
            self.base,
            "POST",
            f"/v1/subscriptions/{subscription}/attach",
            token=self.token,
            body={
                "sessionId": "s-noepoch",
                "profile": "default",
                "executionId": support.execution_id("s-noepoch", 1),
            },
        )
        self.assertEqual(status, 202)
        self.assertTrue(self.wait(lambda: bool(self.fake.history_calls)))

    def test_curseur_sans_epoch_recharge_l_historique(self) -> None:
        self.fake.add_session("s-cursor-noepoch")
        subscription = self.register()
        self.service.stop()
        self.service = Service(self.config, support.contracts())
        self.service.prepare()
        assert self.service.store is not None
        self.service.store.set_cursor(
            connection=self.fake.origin,
            profile="default",
            session_id="s-cursor-noepoch",
            last_seen=1,
            latest_seq=1,
            epoch=None,
        )
        self.service.start()
        self.base = f"http://127.0.0.1:{self.service.api.port}"
        self.attach(subscription, "s-cursor-noepoch", 1)
        # Un curseur sans epoch ne permet pas de comparer les séquences :
        # l'historique est rechargé au lieu de faire confiance au rejeu.
        self.assertTrue(self.wait(lambda: bool(self.fake.history_calls)))
        self.assertEqual(self.outbox(), [])

    def test_repli_sans_omit_messages(self) -> None:
        self.fake.add_session("s-fallback", omit_error=True)
        subscription = self.register()
        self.attach(subscription, "s-fallback", 1)
        self.assertTrue(
            self.wait(lambda: len(self.fake.resume_calls) >= 2)
        )
        self.assertIs(self.fake.resume_calls[0].get("omit_messages"), True)
        self.assertNotIn("omit_messages", self.fake.resume_calls[1])

    def test_journalisation_sans_identifiant(self) -> None:
        self.fake.add_session("s-log")
        subscription = self.register()
        self.attach(subscription, "s-log", 1)
        self.assertTrue(self.fake.wait_resumed("s-log"))
        self.fake.emit(
            "s-log",
            "message.complete",
            {"status": "complete", "persisted_turn": {"user_row_id": 1}},
        )
        self.assertTrue(self.wait(lambda: len(self.outbox()) == 1))
        text = "\n".join(
            record.getMessage() for record in self._capture.records
        )
        self.assertTrue(text)
        for forbidden in (subscription, "s-log", support.execution_id("s-log", 1), "device"):
            self.assertNotIn(forbidden, text)
        self.assertNotIn("SYNTHETIC", text)

    def _captured_records(self):
        return self._capture.records


if __name__ == "__main__":
    unittest.main()
