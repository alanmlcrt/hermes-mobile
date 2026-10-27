"""Registre, attachements, outbox, déduplication, curseurs et purge."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from hermes_notifier.contracts import Contracts
from hermes_notifier.errors import Conflict, Gone, NotFound
from hermes_notifier.store import Store

from . import support


class Clock:
    def __init__(self, value: int = 1_700_000_000) -> None:
        self.value = value

    def __call__(self) -> int:
        return self.value

    def advance(self, seconds: int) -> None:
        self.value += seconds


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.clock = Clock()
        self.contracts: Contracts = support.contracts()
        self.store = Store(
            Path(self._tmp.name) / "notifier.sqlite3",
            outcomes=self.contracts.outcomes,
            now=self.clock,
        )
        self.addCleanup(self.store.close)
        self.sub = support.subscription_id("store")
        self.session = "session-store"
        self.execution_id = self.contracts.execution_id(self.session, 1)
        self.store.register(
            self.sub,
            b"ciphertext",
            ttl_seconds=self.contracts.registered_ttl_seconds,
        )

    def attach(self, row: int = 1, *, subscription: str | None = None, session: str | None = None) -> str:
        subscription = subscription or self.sub
        session = session or self.session
        return self.store.attach(
            subscription,
            connection="http://hermes",
            session_id=session,
            profile="default",
            execution_id=self.contracts.execution_id(session, row),
            user_row_id=row,
            ttl_seconds=self.contracts.attached_ttl_seconds,
        )

    # --- registre -------------------------------------------------------

    def test_register_puis_rotation_sans_409(self) -> None:
        subscription = support.subscription_id("rotation")
        created = self.store.register(
            subscription, b"first", ttl_seconds=self.contracts.registered_ttl_seconds
        )
        self.assertTrue(created)
        again = self.store.register(
            subscription, b"second", ttl_seconds=self.contracts.registered_ttl_seconds
        )
        self.assertFalse(again)
        stored = self.store.get_subscription(subscription)
        assert stored is not None
        self.assertEqual(stored.token_ciphertext, b"second")
        self.assertEqual(stored.state, "registered")

    def test_revoke_idempotent_et_tombstone(self) -> None:
        self.assertTrue(self.store.revoke(self.sub))
        self.assertFalse(self.store.revoke(self.sub))
        self.assertIsNone(self.store.get_subscription(self.sub))
        self.assertTrue(self.store.revoked(self.sub))
        self.assertEqual(self.store.counter("revoked"), 1)
        self.store.register(
            self.sub, b"token", ttl_seconds=self.contracts.registered_ttl_seconds
        )
        self.assertFalse(self.store.revoked(self.sub))

    def test_attach_inconnu_ou_revoque(self) -> None:
        with self.assertRaises(NotFound):
            self.attach(subscription=support.subscription_id("unknown"))
        self.store.revoke(self.sub)
        with self.assertRaises(Gone):
            self.attach()

    def test_attach_expire_est_gone(self) -> None:
        self.clock.advance(self.contracts.registered_ttl_seconds + 1)
        with self.assertRaises(Gone):
            self.attach()
        self.assertEqual(self.store.counter("expired"), 1)

    def test_reattach_reactivates_expired_execution(self) -> None:
        self.assertEqual(self.attach(), "created")
        self.clock.advance(self.contracts.attached_ttl_seconds + 1)
        with self.assertRaises(Gone):
            self.attach()
        # Le mobile ré-enregistre le même identifiant, puis ré-attache : la
        # veille doit repartir au lieu de répondre « duplicate » sans watcher.
        self.store.register(
            self.sub, b"token", ttl_seconds=self.contracts.registered_ttl_seconds
        )
        self.assertEqual(self.attach(), "created")
        execution = self.store.execution(self.execution_id)
        assert execution is not None
        self.assertEqual(execution.state, "attached")

    def test_attach_duplicate_et_conflits(self) -> None:
        self.assertEqual(self.attach(), "created")
        self.assertEqual(self.attach(), "duplicate")
        with self.assertRaises(Conflict):
            self.attach(row=2)
        other = support.subscription_id("other")
        self.store.register(
            other, b"token", ttl_seconds=self.contracts.registered_ttl_seconds
        )
        with self.assertRaises(Conflict):
            self.attach(row=1, subscription=other)

    # --- terminaux ------------------------------------------------------

    def test_terminal_une_entree_et_dedup(self) -> None:
        self.attach()
        result = self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="succeeded",
            submission_id="sub-1",
        )
        self.assertEqual(result, "enqueued")
        rows = self.store.outbox_rows()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].terminal, "succeeded")
        self.assertEqual(rows[0].state, "pending")
        dedup = self.store.dedup_row(self.sub, self.execution_id, "succeeded")
        assert dedup is not None
        self.assertEqual(dedup["seen_count"], 1)
        self.assertEqual(dedup["submission_id"], "sub-1")

        again = self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="succeeded",
            submission_id="sub-1",
        )
        self.assertEqual(again, "duplicate")
        self.assertEqual(len(self.store.outbox_rows()), 1)
        dedup = self.store.dedup_row(self.sub, self.execution_id, "succeeded")
        assert dedup is not None
        self.assertEqual(dedup["seen_count"], 2)

    def test_premier_terminal_gagne(self) -> None:
        self.attach()
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="succeeded",
        )
        second = self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="stopped",
        )
        self.assertEqual(second, "duplicate")
        rows = self.store.outbox_rows()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].terminal, "succeeded")
        self.assertIsNotNone(
            self.store.dedup_row(self.sub, self.execution_id, "stopped")
        )

    def test_terminal_apres_livraison_reste_unique(self) -> None:
        self.attach()
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="succeeded",
        )
        entry = self.store.outbox_rows()[0]
        self.assertTrue(
            self.store.mark_delivered(
                entry.id,
                notified_ttl_seconds=self.contracts.retention.notified_ttl_seconds,
            )
        )
        self.assertEqual(
            self.store.record_terminal(
                subscription_id=self.sub,
                execution_id=self.execution_id,
                terminal="failed",
            ),
            "duplicate",
        )
        self.assertEqual(len(self.store.outbox_rows()), 1)

    def test_terminal_hors_execution_est_ignore(self) -> None:
        self.attach()
        self.assertEqual(
            self.store.record_terminal(
                subscription_id=self.sub,
                execution_id=self.contracts.execution_id(self.session, 99),
                terminal="succeeded",
            ),
            "unmatched",
        )
        with self.assertRaises(ValueError):
            self.store.record_terminal(
                subscription_id=self.sub,
                execution_id=self.execution_id,
                terminal="unknown",
            )

    # --- files d'attente ------------------------------------------------

    def test_active_executions_exclut_l_outbox(self) -> None:
        self.attach()
        self.assertEqual(len(self.store.active_executions()), 1)
        self.assertEqual(len(self.store.watch_executions()), 1)
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="failed",
        )
        self.assertEqual(self.store.active_executions(), [])
        self.assertEqual(len(self.store.watch_executions()), 1)
        self.assertEqual(len(self.store.error_candidates(session_ids=[self.session])), 0)
        entry = self.store.outbox_rows()[0]
        self.store.mark_delivered(
            entry.id,
            notified_ttl_seconds=self.contracts.retention.notified_ttl_seconds,
        )
        self.assertEqual(self.store.watch_executions(), [])

    def test_candidates_error_et_terminal(self) -> None:
        self.attach()
        self.assertEqual(
            len(self.store.find_terminal_candidates(session_ids=[self.session], user_row_id=1)),
            1,
        )
        self.assertEqual(
            len(self.store.find_terminal_candidates(session_ids=[self.session], user_row_id=2)),
            0,
        )
        self.assertEqual(
            len(self.store.error_candidates(session_ids=[self.session])), 1
        )

    def test_curseur_persiste(self) -> None:
        self.attach()
        self.store.set_cursor(
            connection="http://hermes",
            profile="default",
            session_id=self.session,
            last_seen=9,
            latest_seq=12,
            epoch="epoch-1",
        )
        cursor = self.store.get_cursor(
            connection="http://hermes", profile="default", session_id=self.session
        )
        assert cursor is not None
        self.assertEqual(cursor.last_seen, 9)
        self.assertEqual(cursor.latest_seq, 12)
        self.assertEqual(cursor.epoch, "epoch-1")
        self.store.revoke(self.sub)
        self.assertEqual(self.store.cursor_rows(), [])

    # --- purge ----------------------------------------------------------

    def test_purge_borne_les_etats(self) -> None:
        self.attach()
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="succeeded",
        )
        entry = self.store.outbox_rows()[0]
        self.store.mark_delivered(
            entry.id,
            notified_ttl_seconds=self.contracts.retention.notified_ttl_seconds,
        )
        self.clock.advance(self.contracts.retention.deduplication_ttl_seconds + 1)
        result = self.store.prune(
            notified_ttl_seconds=self.contracts.retention.notified_ttl_seconds,
            expired_ttl_seconds=self.contracts.retention.expired_ttl_seconds,
            deduplication_ttl_seconds=self.contracts.retention.deduplication_ttl_seconds,
            outbox_max_age_seconds=self.contracts.retention.outbox_max_age_seconds,
        )
        self.assertGreater(result.total(), 0)
        self.assertIsNone(self.store.get_subscription(self.sub))
        self.assertEqual(self.store.outbox_rows(), [])
        self.assertEqual(self.store.dedup_row(self.sub, self.execution_id, "succeeded"), None)

    def test_purge_abandonne_apres_48h(self) -> None:
        self.attach()
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="failed",
        )
        self.clock.advance(self.contracts.retention.outbox_max_age_seconds + 1)
        result = self.store.prune(
            notified_ttl_seconds=self.contracts.retention.notified_ttl_seconds,
            expired_ttl_seconds=self.contracts.retention.expired_ttl_seconds,
            deduplication_ttl_seconds=self.contracts.retention.deduplication_ttl_seconds,
            outbox_max_age_seconds=self.contracts.retention.outbox_max_age_seconds,
        )
        self.assertEqual(result.dropped, 1)
        self.assertEqual(self.store.counter("dropped"), 1)
        row = self.store.outbox_rows()[0]
        self.assertEqual(row.state, "dropped")

    def test_mark_retry_et_drop(self) -> None:
        self.attach()
        self.store.record_terminal(
            subscription_id=self.sub,
            execution_id=self.execution_id,
            terminal="stopped",
        )
        entry = self.store.outbox_rows()[0]
        self.assertTrue(
            self.store.mark_retry(
                entry.id, next_attempt_at=self.clock() + 5, error_code="fcm.error"
            )
        )
        self.assertEqual(self.store.counter("failed"), 1)
        self.assertEqual(self.store.outbox_entry(entry.id).attempt, 1)
        self.assertTrue(
            self.store.mark_dropped(
                entry.id,
                expired_ttl_seconds=self.contracts.retention.expired_ttl_seconds,
            )
        )
        self.assertEqual(self.store.counter("dropped"), 1)
        self.assertEqual(self.store.outbox_entry(entry.id).state, "dropped")


if __name__ == "__main__":
    unittest.main()
