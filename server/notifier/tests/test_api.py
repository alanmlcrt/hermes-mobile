"""API HTTP : routes, bearer, erreurs bornées et rate limit."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from hermes_notifier.api import NotificationApi, RateLimiter
from hermes_notifier.credential import BearerCredential, TokenCipher
from hermes_notifier.errors import StorageError
from hermes_notifier.health import HealthState
from hermes_notifier.logs import EventLogger, Redactor
from hermes_notifier.store import Store

from . import support


class ApiTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.clock = [1_700_000_000]

        def now() -> int:
            return self.clock[0]

        self.contracts = support.contracts()
        self.config, self.token = support.make_config(
            Path(self._tmp.name), "http://127.0.0.1:1"
        )
        self.store = Store(
            Path(self._tmp.name) / "notifier.sqlite3",
            outcomes=self.contracts.outcomes,
            now=now,
        )
        self.addCleanup(self.store.close)
        self.api = NotificationApi(
            self.config,
            self.contracts,
            self.store,
            TokenCipher(Path(self._tmp.name) / "token.key"),
            BearerCredential(self.config.bearer_hash, self.config.bearer_salt),
            HealthState(
                self.contracts,
                environment="integration",
                dry_run=True,
            ),
            EventLogger(Redactor()),
        )
        self.api.create_server()
        self.api.start()
        self.addCleanup(self.api.stop)
        self.base = f"http://127.0.0.1:{self.api.port}"

    def request(
        self,
        method: str,
        path: str,
        *,
        token: str | None = None,
        body: dict | None = None,
        headers: dict | None = None,
    ):
        return support.http_request(
            self.base,
            method,
            path,
            token=token,
            body=body,
            headers=headers,
        )

    def register(self, subscription: str, token: str = "device-token") -> None:
        status, _, _ = self.request(
            "POST",
            "/v1/subscriptions",
            token=self.token,
            body={"subscriptionId": subscription, "fcmToken": token},
        )
        self.assertIn(status, {200, 201})

    def attach(self, subscription: str, session: str, row: int):
        return self.request(
            "POST",
            f"/v1/subscriptions/{subscription}/attach",
            token=self.token,
            body={
                "sessionId": session,
                "profile": "default",
                "executionId": support.execution_id(session, row),
            },
        )

    # --- authentification ----------------------------------------------

    def test_toutes_les_routes_exigent_le_bearer(self) -> None:
        for method, path in (
            ("GET", "/v1/health"),
            ("POST", "/v1/subscriptions"),
            ("POST", f"/v1/subscriptions/{support.subscription_id()}/attach"),
            ("DELETE", f"/v1/subscriptions/{support.subscription_id()}"),
            ("GET", "/v1/inconnu"),
        ):
            status, _, raw = self.request(method, path)
            self.assertEqual(status, 401, (method, path))
            body = json.loads(raw)
            self.assertEqual(set(body), {"code", "message"})
            self.assertEqual(body["code"], "unauthorized")

    def test_mauvais_bearer_refuse(self) -> None:
        status, _, _ = self.request("GET", "/v1/health", token="faux")
        self.assertEqual(status, 401)

    # --- santé ----------------------------------------------------------

    def test_sante_authentifiee_bornee(self) -> None:
        status, headers, raw = self.request("GET", "/v1/health", token=self.token)
        self.assertEqual(status, 200)
        body = json.loads(raw)
        self.assertEqual(
            set(body), {"state", "reasons", "counters", "version", "checkedAt"}
        )
        self.assertIn(body["state"], {"ok", "degraded"})
        self.assertEqual(set(body["counters"]), set(self.contracts.health_counters))
        self.assertRegex(body["version"], r"^\d+\.\d+\.\d+$")
        self.assertRegex(body["checkedAt"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
        for forbidden in self.contracts.health_forbidden_fields:
            self.assertNotIn(forbidden, body)
        self.assertEqual(headers.get("cache-control"), "no-store")

    # --- enregistrement -------------------------------------------------

    def test_register_puis_idempotence(self) -> None:
        subscription = support.subscription_id("api")
        status, _, raw = self.request(
            "POST",
            "/v1/subscriptions",
            token=self.token,
            body={"subscriptionId": subscription, "fcmToken": "jeton-1"},
        )
        self.assertEqual(status, 201)
        self.assertEqual(json.loads(raw), {"state": "registered"})
        stored = self.store.get_subscription(subscription)
        assert stored is not None
        self.assertNotEqual(stored.token_ciphertext, b"jeton-1")
        self.assertEqual(self.api.cipher.decrypt(stored.token_ciphertext), "jeton-1")

        status, _, _ = self.request(
            "POST",
            "/v1/subscriptions",
            token=self.token,
            body={"subscriptionId": subscription, "fcmToken": "jeton-2"},
        )
        self.assertEqual(status, 200)
        stored = self.store.get_subscription(subscription)
        assert stored is not None
        self.assertEqual(self.api.cipher.decrypt(stored.token_ciphertext), "jeton-2")

    def test_register_refuse_les_corps_invalides(self) -> None:
        valid = support.subscription_id("api")
        cases = [
            {"subscriptionId": "court", "fcmToken": "x"},
            {"subscriptionId": valid, "fcmToken": ""},
            {"subscriptionId": valid, "fcmToken": 3},
            {"subscriptionId": valid},
            {"subscriptionId": valid, "fcmToken": "x", "profile": "default"},
            {"subscriptionId": valid, "fcmToken": "x", "fcmToken ": "y"},
        ]
        for body in cases:
            status, _, raw = self.request(
                "POST", "/v1/subscriptions", token=self.token, body=body
            )
            self.assertEqual(status, 400, body)
            self.assertEqual(json.loads(raw)["code"], "invalid-request")

    def test_corps_trop_long_est_refuse(self) -> None:
        status, _, _ = support.http_request(
            self.base,
            "POST",
            "/v1/subscriptions",
            token=self.token,
            headers={
                "Content-Type": "application/json",
                "Content-Length": str(32 * 1024),
            },
        )
        self.assertEqual(status, 400)

    # --- attache --------------------------------------------------------

    def test_attach_puis_doublon(self) -> None:
        subscription = support.subscription_id("attach")
        self.register(subscription)
        status, _, raw = self.attach(subscription, "session-api", 7)
        self.assertEqual(status, 202)
        self.assertEqual(json.loads(raw), {"state": "attached"})
        execution = self.store.execution(
            self.contracts.execution_id("session-api", 7)
        )
        assert execution is not None
        self.assertEqual(execution.profile, "default")
        self.assertEqual(execution.user_row_id, 7)

        status, _, _ = self.attach(subscription, "session-api", 7)
        self.assertEqual(status, 200)

    def test_attach_inconnu_gone_et_conflit(self) -> None:
        unknown = support.subscription_id("unknown")
        status, _, raw = self.attach(unknown, "session-api", 1)
        self.assertEqual(status, 404)
        self.assertEqual(json.loads(raw)["code"], "not-found")

        subscription = support.subscription_id("attach")
        self.register(subscription)
        self.assertEqual(self.attach(subscription, "session-api", 1)[0], 202)
        status, _, _ = self.attach(subscription, "session-api", 2)
        self.assertEqual(status, 400)

        other = support.subscription_id("other")
        self.register(other)
        status, _, _ = self.attach(other, "session-api", 1)
        self.assertEqual(status, 400)

        revoked = support.subscription_id("revoked")
        self.register(revoked)
        self.request("DELETE", f"/v1/subscriptions/{revoked}", token=self.token)
        status, _, _ = self.attach(revoked, "session-api", 9)
        self.assertEqual(status, 410)

    def test_attach_execution_id_invalide(self) -> None:
        subscription = support.subscription_id("attach")
        self.register(subscription)
        for execution in (
            "pas-du-base64!",
            support.execution_id("autre-session", 1),
            support.execution_id("session-api", 1) + "A",
        ):
            status, _, _ = self.request(
                "POST",
                f"/v1/subscriptions/{subscription}/attach",
                token=self.token,
                body={
                    "sessionId": "session-api",
                    "profile": None,
                    "executionId": execution,
                },
            )
            self.assertEqual(status, 400, execution)

    def test_attach_expire(self) -> None:
        subscription = support.subscription_id("expire")
        self.register(subscription)
        self.clock[0] += self.contracts.registered_ttl_seconds + 1
        status, _, raw = self.attach(subscription, "session-api", 1)
        self.assertEqual(status, 410)
        self.assertEqual(json.loads(raw)["code"], "gone")

    # --- révocation -----------------------------------------------------

    def test_revoke_est_idempotent(self) -> None:
        subscription = support.subscription_id("revoke")
        self.register(subscription)
        status, _, raw = self.request(
            "DELETE", f"/v1/subscriptions/{subscription}", token=self.token
        )
        self.assertEqual(status, 204)
        self.assertEqual(raw, b"")
        status, _, _ = self.request(
            "DELETE", f"/v1/subscriptions/{subscription}", token=self.token
        )
        self.assertEqual(status, 204)
        status, _, _ = self.request(
            "DELETE",
            f"/v1/subscriptions/{support.subscription_id('jamais')}",
            token=self.token,
        )
        self.assertEqual(status, 204)

    # --- erreurs et limites --------------------------------------------

    def test_erreurs_ne_contiennent_aucun_identifiant(self) -> None:
        subscription = support.subscription_id("secret")
        status, _, raw = self.attach(subscription, "session-secrete", 3)
        self.assertEqual(status, 404)
        text = raw.decode()
        for forbidden in ("secret", "session-secrete", "execution"):
            self.assertNotIn(forbidden, text)
        self.assertEqual(set(json.loads(raw)), {"code", "message"})

    def test_api_suit_le_contrat(self) -> None:
        """Les routes, statuts et codes exercés viennent des accesseurs."""

        codes = set(self.contracts.error_codes)
        health = self.contracts.endpoint("health")
        status, _, _ = self.request(health.method, health.path, token=self.token)
        self.assertIn(status, health.success_status)

        register = self.contracts.endpoint("register")
        subscription = support.subscription_id("contract")
        status, _, _ = self.request(
            register.method,
            register.path,
            token=self.token,
            body={"subscriptionId": subscription, "fcmToken": "jeton"},
        )
        self.assertIn(status, register.success_status)

        attach = self.contracts.endpoint("attach")
        attach_path = attach.path.replace("{subscriptionId}", subscription)
        body = {
            "sessionId": "session-contract",
            "profile": "default",
            "executionId": support.execution_id("session-contract", 1),
        }
        status, _, _ = self.request(
            attach.method, attach_path, token=self.token, body=body
        )
        self.assertIn(status, attach.success_status)

        revoke = self.contracts.endpoint("revoke")
        revoke_path = revoke.path.replace("{subscriptionId}", subscription)
        status, _, _ = self.request(
            revoke.method, revoke_path, token=self.token
        )
        self.assertIn(status, revoke.success_status)

        # Les erreurs suivent les statuts et l'énumération du contrat.
        unknown = support.subscription_id("unknown-contract")
        status, _, raw = self.request(
            attach.method,
            attach.path.replace("{subscriptionId}", unknown),
            token=self.token,
            body=body,
        )
        self.assertIn(status, attach.error_status)
        self.assertIn(json.loads(raw)["code"], codes)
        status, _, raw = self.request(health.method, health.path)
        self.assertIn(status, health.error_status)
        self.assertIn(json.loads(raw)["code"], codes)

    def test_erreur_stockage_devient_unavailable(self) -> None:
        subscription = support.subscription_id("storage")
        with mock.patch.object(
            self.store,
            "register",
            side_effect=StorageError("storage.write_failed"),
        ):
            status, _, raw = self.request(
                "POST",
                "/v1/subscriptions",
                token=self.token,
                body={"subscriptionId": subscription, "fcmToken": "jeton"},
            )
        self.assertEqual(status, 503)
        body = json.loads(raw)
        self.assertEqual(set(body), {"code", "message"})
        self.assertEqual(body["code"], "unavailable")
        self.assertNotIn("storage", raw.decode())

    def test_rate_limit_avec_retry_after(self) -> None:
        self.api.limiter = RateLimiter(2, now=lambda: 500.0)
        for _ in range(2):
            self.assertEqual(
                self.request("GET", "/v1/health", token=self.token)[0], 200
            )
        status, headers, raw = self.request(
            "GET", "/v1/health", token=self.token
        )
        self.assertEqual(status, 429)
        self.assertEqual(json.loads(raw)["code"], "rate-limited")
        self.assertIn("retry-after", headers)
        self.assertGreaterEqual(int(headers["retry-after"]), 1)

    def test_route_inconnue_est_404_sans_html(self) -> None:
        status, _, raw = self.request("GET", "/v1/inconnu", token=self.token)
        self.assertEqual(status, 404)
        self.assertEqual(json.loads(raw)["code"], "not-found")
        status, _, _ = self.request(
            "POST", "/v1/health", token=self.token, body={}
        )
        self.assertEqual(status, 404)


if __name__ == "__main__":
    unittest.main()
