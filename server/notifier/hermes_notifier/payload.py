"""Message FCM ``notification + data`` dérivé du contrat.

Le bloc ``data`` ne contient que ``subscriptionId`` et ``outcome``. Le libellé
visible vient de ``payload.notification.bodyByOutcome`` ; aucun texte Hermes,
aucun chemin, aucune identité d'exécution n'entre dans le message.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Mapping

from .contracts import Contracts


class PayloadError(Exception):
    """Message non constructible ; le code est sûr à journaliser."""

    code = "payload.invalid"


class PayloadTooLarge(PayloadError):
    code = "payload.too_large"


class PayloadInvalid(PayloadError):
    code = "payload.invalid"


@dataclass(frozen=True)
class PushPayload:
    body: Mapping[str, Any]
    outcome: str
    subscription_id: str
    size_bytes: int

    @property
    def data(self) -> Mapping[str, str]:
        return self.body["message"]["data"]

    def encoded(self) -> bytes:
        return json.dumps(
            self.body, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")


class PayloadBuilder:
    def __init__(self, contracts: Contracts) -> None:
        self.contracts = contracts

    def build(
        self, *, subscription_id: str, outcome: str, token: str
    ) -> PushPayload:
        if outcome not in self.contracts.outcomes:
            raise PayloadInvalid("payload.outcome")
        if not self.contracts.valid_subscription_id(subscription_id):
            raise PayloadInvalid("payload.subscription")
        if not isinstance(token, str) or not token:
            raise PayloadInvalid("payload.token")

        data = {"subscriptionId": subscription_id, "outcome": outcome}
        if not self.contracts.validate_data(data):
            raise PayloadInvalid("payload.data")
        forbidden = set(self.contracts.payload.get("forbiddenDataFields") or ())
        if set(data) & forbidden:
            raise PayloadInvalid("payload.data")

        title = self.contracts.notification_title
        body = self.contracts.notification_body(outcome)
        if not title or not body:
            raise PayloadInvalid("payload.label")

        try:
            android = self._android(subscription_id, outcome)
        except (KeyError, IndexError, ValueError) as exc:
            # Un modèle du contrat avec un placeholder inconnu ne doit pas
            # produire un KeyError brut qui serait retenté pendant 48 h.
            raise PayloadInvalid("payload.template") from exc
        message: dict[str, Any] = {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": data,
        }
        if android:
            message["android"] = android

        wrapper = {"message": message}
        # ``maxBytes`` du contrat borne ``notification + data`` : le token
        # FCM est un champ de routage hors message et ne doit pas faire
        # abandonner un payload pourtant valide.
        measured = {
            "message": {
                key: value for key, value in message.items() if key != "token"
            }
        }
        size = len(
            json.dumps(
                measured, separators=(",", ":"), ensure_ascii=False
            ).encode("utf-8")
        )
        if size > self.contracts.max_payload_bytes:
            raise PayloadTooLarge("payload.too_large")
        return PushPayload(
            body=wrapper,
            outcome=outcome,
            subscription_id=subscription_id,
            size_bytes=size,
        )

    def _android(self, subscription_id: str, outcome: str) -> dict[str, Any]:
        source = self.contracts.android
        if not source:
            return {}
        notification: dict[str, Any] = {}
        channel = source.get("channelId")
        if isinstance(channel, str) and channel:
            notification["channel_id"] = channel
        priority = source.get("notificationPriority")
        if isinstance(priority, str) and priority:
            notification["notification_priority"] = _android_priority(priority)
        if source.get("defaultSound") is True:
            notification["sound"] = "default"
        tag = source.get("notificationTagTemplate")
        if isinstance(tag, str) and tag:
            notification["tag"] = tag.format(
                subscriptionId=subscription_id, outcome=outcome
            )
        android: dict[str, Any] = {}
        if notification:
            android["notification"] = notification
        transport_priority = source.get("priority")
        if transport_priority in {"normal", "high"}:
            android["priority"] = transport_priority
        ttl = source.get("ttlSeconds")
        if isinstance(ttl, int) and ttl > 0:
            android["ttl"] = f"{ttl}s"
        collapse = source.get("collapseKeyTemplate")
        if isinstance(collapse, str) and collapse:
            android["collapse_key"] = collapse.format(subscriptionId=subscription_id)
        return android


def _android_priority(value: str) -> str:
    known = {
        "min": "PRIORITY_MIN",
        "low": "PRIORITY_LOW",
        "default": "PRIORITY_DEFAULT",
        "high": "PRIORITY_HIGH",
        "max": "PRIORITY_MAX",
    }
    return known.get(value.lower(), "PRIORITY_DEFAULT")
