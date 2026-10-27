"""Dispatcher outbox : dry-run, retries, abandon et payload."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from hermes_notifier.contracts import Contracts
from hermes_notifier.credential import TokenCipher
from hermes_notifier.health import HealthState
from hermes_notifier.logs import EventLogger, Redactor
from hermes_notifier.outbox import (
    DeliveryError,
    DryRunTransport,
    InvalidTokenError,
    OutboxDispatcher,
    PermanentDeliveryError,
)
from hermes_notifier.payload import PayloadBuilder, PayloadInvalid
from hermes_notifier.store import Store

from . import support


class Clock:
    def __init__(self, value: int = 1_700_000_000) -> None:
        self.value = value

    def __call__(self) -> int:
        return self.value


class FailingTransport:
    def __init__(self, error: Exception) -> None:
        self.error = error
        self.calls = 0

    def send(self, payload, *, terminal: str, attempt: int) -> None:
        self.calls += 1
        raise self.error


class OutboxTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.clock = Clock()
        self.contracts = support.contracts()
        self.store = Store(
            Path(self._tmp.name) / "notifier.sqlite3",
            outcomes=self.contracts.outcomes,
            now=self.clock,
        )
        self.addCleanup(self.store.close)
        self.sub = support.subscription_id("outbox")
        self.session = "session-outbox"
        self.execution = self.contracts.execution_id(self.session, 4)
        self.cipher = TokenCipher(Path(self._tmp.name) / "token.key")
        self.store.register(
            self.sub,
            self.cipher.encrypt("fcm-token"),
            ttl_seconds=self.contracts.registered_ttl_seconds,
        )
        self.store.attach(
            self.sub,
            connection="http://hermes",
            session_id=self.session,
            profile="default",
            execution_id=self.execution,
            user_row_id=4,
            ttl_seconds=self.contracts.attached_ttl_seconds,
        )
        self.logger = EventLogger(Redactor())
        self.health = HealthState(
            self.contracts,
            environment="integration",
            dry_run=True,
            now=self.clock,
        )
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution,
            terminal="succeeded",
        )

    def dispatcher(self, transport=None, contracts=None):
        transport = transport or DryRunTransport(self.contracts)
        return OutboxDispatcher(
            self.store,
            contracts or self.contracts,
            self.cipher,
            transport,
            self.logger,
            health=self.health,
            now=self.clock,
        )

    def observer_contracts(self, **changes) -> Contracts:
        """Contrat identique avec une politique de retries modifiée."""

        tracking = copy.deepcopy(self.contracts.tracking)
        tracking["retries"]["observer"].update(changes)
        return Contracts(
            tracking,
            self.contracts.deployment,
            self.contracts.mapping,
            self.contracts.root,
        )

    def test_dry_run_livre_et_compte(self) -> None:
        transport = DryRunTransport(self.contracts)
        dispatcher = self.dispatcher(transport)
        pending = self.health.snapshot(self.store)["counters"]
        self.assertEqual(pending["outboxPending"], 1)
        self.assertEqual(dispatcher.dispatch_due(), 1)
        entry = self.store.outbox_rows()[0]
        self.assertEqual(entry.state, "delivered")
        self.assertEqual(entry.attempt, 0)
        self.assertEqual(self.store.counter("delivered"), 1)
        self.assertEqual(self.store.get_subscription(self.sub).state, "notified")
        delivered = self.health.snapshot(self.store)["counters"]
        self.assertEqual(delivered["outboxPending"], 0)
        self.assertEqual(delivered["delivered"], 1)
        records = transport.records
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0].outcome, "succeeded")
        self.assertEqual(records[0].terminal, "succeeded")
        self.assertEqual(records[0].attempt, 1)
        self.assertTrue(records[0].schema_valid)
        self.assertEqual(dispatcher.dispatch_due(), 0)

    def test_payload_contractuel_sans_identite(self) -> None:
        payload = PayloadBuilder(self.contracts).build(
            subscription_id=self.sub,
            outcome="failed",
            token="fcm-token",
        )
        data = payload.data
        self.assertEqual(set(data), {"subscriptionId", "outcome"})
        self.assertEqual(data["outcome"], "failed")
        self.assertEqual(
            payload.body["message"]["notification"],
            {"title": "Hermes", "body": "Hermes a échoué"},
        )
        text = payload.encoded().decode()
        self.assertNotIn(self.session, text)
        self.assertNotIn(self.execution, text)
        self.assertNotIn("fcm-token", json.dumps(data))
        self.assertLessEqual(payload.size_bytes, self.contracts.max_payload_bytes)
        for forbidden in self.contracts.payload["forbiddenDataFields"]:
            self.assertNotIn(forbidden, data)

    def test_payload_refuse_une_issue_inconnue(self) -> None:
        builder = PayloadBuilder(self.contracts)
        with self.assertRaises(PayloadInvalid):
            builder.build(subscription_id=self.sub, outcome="unknown", token="x")
        with self.assertRaises(PayloadInvalid):
            builder.build(subscription_id="court", outcome="succeeded", token="x")
        with self.assertRaises(PayloadInvalid):
            builder.build(subscription_id=self.sub, outcome="succeeded", token="")

    def test_retry_borne_garde_l_entree(self) -> None:
        transport = FailingTransport(DeliveryError("fcm.error"))
        dispatcher = self.dispatcher(transport)
        dispatcher.dispatch_due()
        entry = self.store.outbox_rows()[0]
        self.assertEqual(entry.state, "pending")
        self.assertEqual(entry.attempt, 1)
        self.assertEqual(self.store.counter("failed"), 1)
        self.assertGreater(entry.next_attempt_at, self.clock())
        for _ in range(self.contracts.observer_retries.max_attempts + 2):
            self.clock.value = entry.next_attempt_at
            dispatcher.dispatch_due()
            entry = self.store.outbox_rows()[0]
        self.assertEqual(entry.state, "pending")
        self.assertGreaterEqual(
            entry.attempt, self.contracts.observer_retries.max_attempts
        )
        self.assertEqual(self.store.counter("dropped"), 0)

    def test_token_invalide_supprime_l_abonnement(self) -> None:
        dispatcher = self.dispatcher(FailingTransport(InvalidTokenError()))
        dispatcher.dispatch_due()
        self.assertIsNone(self.store.get_subscription(self.sub))
        self.assertEqual(self.store.counter("invalidToken"), 1)
        self.assertEqual(self.store.outbox_rows(), [])

    def test_erreur_permanente_abandonne(self) -> None:
        dispatcher = self.dispatcher(FailingTransport(PermanentDeliveryError()))
        dispatcher.dispatch_due()
        self.assertEqual(self.store.outbox_rows()[0].state, "dropped")
        self.assertEqual(self.store.counter("dropped"), 1)
        self.assertEqual(self.store.counter("delivered"), 0)

    def test_abandon_apres_48h_sans_envoi(self) -> None:
        self.clock.value += self.contracts.retention.outbox_max_age_seconds + 1
        transport = DryRunTransport(self.contracts)
        dispatcher = self.dispatcher(transport)
        dispatcher.dispatch_due()
        self.assertEqual(self.store.outbox_rows()[0].state, "dropped")
        self.assertEqual(transport.records, ())
        self.assertEqual(self.store.counter("dropped"), 1)

    def test_delai_abandon_vient_du_contrat(self) -> None:
        self.clock.value += 11
        contracts = self.observer_contracts(dropAfterSeconds=10)
        transport = DryRunTransport(self.contracts)
        dispatcher = self.dispatcher(transport, contracts)
        dispatcher.dispatch_due()
        self.assertEqual(self.store.outbox_rows()[0].state, "dropped")
        self.assertEqual(transport.records, ())
        self.assertEqual(self.store.counter("dropped"), 1)

    def test_politique_drop_apres_max_attempts(self) -> None:
        contracts = self.observer_contracts(afterMaxAttempts="drop")
        transport = FailingTransport(DeliveryError("fcm.error"))
        dispatcher = self.dispatcher(transport, contracts)
        dispatcher.dispatch_due()
        entry = self.store.outbox_rows()[0]
        for _ in range(contracts.observer_retries.max_attempts - 1):
            self.clock.value = entry.next_attempt_at
            dispatcher.dispatch_due()
            entry = self.store.outbox_rows()[0]
            if entry.state != "pending":
                break
        self.assertEqual(entry.state, "dropped")
        self.assertEqual(self.store.counter("dropped"), 1)
        self.assertEqual(
            transport.calls, contracts.observer_retries.max_attempts
        )

    def test_abonnement_expire_est_abandonne(self) -> None:
        self.clock.value += self.contracts.attached_ttl_seconds + 1
        transport = DryRunTransport(self.contracts)
        dispatcher = self.dispatcher(transport)
        dispatcher.dispatch_due()
        self.assertEqual(self.store.outbox_rows()[0].state, "dropped")
        self.assertEqual(transport.records, ())
        self.assertEqual(self.store.get_subscription(self.sub).state, "expired")


if __name__ == "__main__":
    unittest.main()
