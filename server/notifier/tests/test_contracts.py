"""Contrats : mapping autoritaire, exécution et validations."""

from __future__ import annotations

import base64
import unittest

from hermes_notifier.errors import ContractError

from . import support


class ContractsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contracts = support.contracts()

    def test_mapping_est_la_seule_source_des_terminaux(self) -> None:
        cases = {
            ("message.complete", "complete"): "succeeded",
            ("message.complete", "error"): "failed",
            ("message.complete", "interrupted"): "stopped",
            ("error", None): "failed",
        }
        for (event, status), expected in cases.items():
            payload = {} if status is None else {"status": status}
            self.assertEqual(
                self.contracts.resolve_terminal(event, payload), expected
            )

    def test_statut_absent_ou_inconnu_ne_notifie_jamais(self) -> None:
        for payload in ({}, {"status": None}, {"status": "unknown"}, {"status": 3}):
            self.assertIsNone(
                self.contracts.resolve_terminal("message.complete", payload)
            )
        self.assertIsNone(self.contracts.resolve_terminal("message.start", {}))
        self.assertIsNone(self.contracts.resolve_terminal("unknown", {}))
        self.assertIsNone(self.contracts.resolve_terminal("message.complete", None))

    def test_execution_id_est_base64url_scoped_par_session(self) -> None:
        expected = base64.urlsafe_b64encode(b"a1b2c3d4:42").rstrip(b"=").decode()
        self.assertEqual(self.contracts.execution_id("a1b2c3d4", 42), expected)
        self.assertEqual(self.contracts.execution_row(expected, "a1b2c3d4"), 42)

    def test_execution_id_refuse_une_autre_session(self) -> None:
        value = self.contracts.execution_id("session-a", 7)
        with self.assertRaises(ValueError):
            self.contracts.execution_row(value, "session-b")
        with self.assertRaises(ValueError):
            self.contracts.execution_id("", 7)
        with self.assertRaises(ValueError):
            self.contracts.execution_id("session", True)
        with self.assertRaises(ValueError):
            self.contracts.execution_row("pas-du-base64url!*", "session")

    def test_subscription_id_opaque_borne(self) -> None:
        valid = "A" * self.contracts.subscription_min_length
        self.assertTrue(self.contracts.valid_subscription_id(valid))
        self.assertFalse(
            self.contracts.valid_subscription_id("A" * (self.contracts.subscription_min_length - 1))
        )
        self.assertFalse(
            self.contracts.valid_subscription_id("A" * (self.contracts.subscription_max_length + 1))
        )
        self.assertFalse(self.contracts.valid_subscription_id(valid + "+"))
        self.assertFalse(self.contracts.valid_subscription_id(None))

    def test_valeurs_du_contrat_sont_lues_non_recopiees(self) -> None:
        self.assertEqual(self.contracts.registered_ttl_seconds, 86400)
        self.assertEqual(self.contracts.attached_ttl_seconds, 604800)
        self.assertEqual(self.contracts.retention.outbox_max_age_seconds, 172800)
        self.assertEqual(self.contracts.observer_retries.max_attempts, 5)
        self.assertIn("outbox-backlog", {rule.reason for rule in self.contracts.degraded_when})
        self.assertEqual(self.contracts.endpoint("health").path, "/v1/health")
        self.assertEqual(self.contracts.endpoint("register").path, "/v1/subscriptions")
        self.assertEqual(self.contracts.endpoint("revoke").method, "DELETE")

    def test_environnements_isoles(self) -> None:
        names = set(self.contracts.environment_records)
        self.assertEqual(names, {"fixtures", "integration", "personal"})
        for name in names:
            self.assertTrue(self.contracts.environment(name).isolated)
        self.assertTrue(self.contracts.environment("integration").dry_run_locked)

    def test_allowlists_lecture_seule(self) -> None:
        allowed = self.contracts.allowed_rpc
        self.assertIn("session.events.since", allowed)
        self.assertIn("session.history", allowed)
        self.assertNotIn("prompt.submit", allowed)
        self.assertNotIn("session.interrupt", allowed)
        self.assertNotIn("file.attach", allowed)
        self.assertTrue(self.contracts.allowed_rpc & self.contracts.forbidden_rpc == set())
        self.assertEqual(
            self.contracts.allowed_rest,
            frozenset(
                {
                    "POST /auth/password-login",
                    "POST /auth/native/refresh",
                    "POST /api/auth/ws-ticket",
                    "GET /api/profiles",
                }
            ),
        )

    def test_un_contrat_incoherent_est_refuse(self) -> None:
        tracking = dict(self.contracts.tracking)
        tracking["mapping"] = {
            **tracking["mapping"],
            "authoritative": False,
        }
        with self.assertRaises(ContractError):
            type(self.contracts)(
                tracking,
                self.contracts.deployment,
                self.contracts.mapping,
                self.contracts.root,
            )

    def test_copie_vendorisee_est_identique(self) -> None:
        root = support.VENDOR.parents[3] / "contracts"
        for name in (
            "event-mapping.json",
            "notification-tracking.json",
            "notification-deployment.json",
        ):
            self.assertEqual(
                (root / name).read_bytes(),
                (support.VENDOR / name).read_bytes(),
                name,
            )


if __name__ == "__main__":
    unittest.main()
