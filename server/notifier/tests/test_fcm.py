"""Toutes les requêtes Google sont simulées, sans compte réel ni réseau."""
import json
import tempfile
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from hermes_notifier.fcm import FcmTransport
from hermes_notifier.outbox import DeliveryError, InvalidTokenError, PermanentDeliveryError
from hermes_notifier.payload import PayloadBuilder
from . import support


class FcmTest(unittest.TestCase):
    def setUp(self):
        self.credentials = Mock(valid=False, token="oauth-secret")
        self.session = Mock()
        self.response = Mock(status_code=200, content=b'{}')
        self.response.raw.read1.side_effect = [b'{}', b'']
        self.session.post.return_value = self.response
        self.auth = Mock()
        self.transport = FcmTransport(self.credentials, "synthetic-project", session=self.session, auth_request=self.auth)

    def payload(self, outcome="succeeded"):
        return PayloadBuilder(support.contracts()).build(
            subscription_id=support.subscription_id("fcm"), outcome=outcome, token="private-device")

    def test_trois_terminaux_payload_strict_et_oauth_renouvelable(self):
        for outcome in ("succeeded", "failed", "stopped"):
            self.transport.send(self.payload(outcome), terminal=outcome, attempt=1)
            _, kw = self.session.post.call_args
            self.assertEqual(kw["timeout"], 8.0)
            self.assertFalse(kw["allow_redirects"])
            body = json.loads(kw["data"])["message"]
            self.assertEqual(set(body["data"]), {"subscriptionId", "outcome"})
            self.assertEqual(body["data"]["outcome"], outcome)
            self.assertEqual(body["android"]["notification"]["channel_id"], "hermes_turn_complete")
            self.assertNotIn("executionId", body["data"])
        self.assertEqual(self.credentials.refresh.call_count, 3)
        self.credentials.valid = True
        self.transport.send(self.payload(), terminal="succeeded", attempt=1)
        self.assertEqual(self.credentials.refresh.call_count, 3)

    def test_erreurs_permanentes_transitoires_et_token_invalide(self):
        for status, expected in [(400, PermanentDeliveryError), (403, PermanentDeliveryError),
                                 (404, PermanentDeliveryError), (401, DeliveryError),
                                 (429, DeliveryError), (500, DeliveryError), (503, DeliveryError)]:
            self.response.status_code = status
            self.response.raw.read1.side_effect = [b'{"error":{"message":"secret brut"}}', b'']
            with self.assertRaises(expected) as caught:
                self.transport.send(self.payload(), terminal="succeeded", attempt=1)
            self.assertNotIn("secret", str(caught.exception))
        self.response.status_code = 404
        self.response.raw.read1.side_effect = [b'{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}', b'']
        with self.assertRaises(InvalidTokenError):
            self.transport.send(self.payload(), terminal="succeeded", attempt=1)

    def test_timeout_oauth_et_transport_ne_divulguent_rien(self):
        for target in (self.credentials.refresh, self.session.post):
            target.side_effect = RuntimeError("private-device oauth-secret contenu")
            with self.assertRaises(DeliveryError) as caught:
                self.transport.send(self.payload(), terminal="failed", attempt=1)
            self.assertEqual(str(caught.exception), "fcm.unavailable")
            self.assertTrue(caught.exception.__suppress_context__)
            target.side_effect = None

    def test_erreur_401_force_nouvel_oauth(self):
        self.response.status_code = 401
        with self.assertRaises(DeliveryError):
            self.transport.send(self.payload(), terminal="stopped", attempt=1)
        self.assertIsNone(self.credentials.token)

    def test_compte_synthetique_hors_depot_charge_sans_reseau(self):
        from cryptography.hazmat.primitives.asymmetric import rsa
        from cryptography.hazmat.primitives import serialization
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        data = {"type": "service_account", "project_id": "synthetic-project",
                "private_key_id": "synthetic", "client_email": "synthetic@synthetic-project.iam.gserviceaccount.com",
                "token_uri": "https://oauth2.googleapis.com/token",
                "private_key": key.private_bytes(serialization.Encoding.PEM,
                    serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "service-account.json"
            path.write_text(json.dumps(data))
            transport = FcmTransport.from_file(str(path))
            self.assertEqual(transport.credentials.project_id, "synthetic-project")
            self.assertIn("synthetic-project", transport.url)
            self.assertIsNone(transport.credentials.token)
            transport.session.close()

    def test_reponse_trickle_bornee_par_budget_global(self):
        self.response.status_code = 503
        self.response.raw.read1.side_effect = None
        self.response.raw.read1.return_value = b'x'
        with patch('hermes_notifier.fcm.time.monotonic', side_effect=[0, 1, 3, 4, 6, 7, 9]):
            with self.assertRaises(DeliveryError) as caught:
                self.transport.send(self.payload(), terminal="failed", attempt=1)
        self.assertEqual(str(caught.exception), 'fcm.unavailable')
        self.assertEqual(self.response.raw.read1.call_count, 3)
        self.response.close.assert_called_once()
