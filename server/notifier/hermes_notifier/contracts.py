"""Chargement et validation des contrats partagés.

``contracts/event-mapping.json`` reste la seule source des terminaux. Les
valeurs de TTL, seuils de santé, retries, libellés FCM, endpoints et allowlists
sont lues dans les copies vendorisées ; aucun de ces nombres n'est recopié dans
le code métier.
"""

from __future__ import annotations

import base64
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Final, Mapping

from .errors import ContractError

DEFAULT_VENDOR_DIR: Final = (
    Path(__file__).resolve().parent.parent / "vendor" / "contracts"
)


@dataclass(frozen=True)
class Endpoint:
    name: str
    method: str
    path: str
    body: tuple[str, ...]
    success_status: tuple[int, ...]
    error_status: tuple[int, ...]


@dataclass(frozen=True)
class Environment:
    name: str
    purpose: str
    credential_ref: str
    registry_ref: str
    origin_ref: str
    fcm_transport: str
    firebase_project: bool
    isolated: bool
    dry_run_locked: bool = False
    status: str | None = None


@dataclass(frozen=True)
class ObserverRetries:
    max_attempts: int
    backoff_seconds: tuple[int, ...]
    sweep_interval_seconds: int
    drop_after_seconds: int
    after_max_attempts: str


@dataclass(frozen=True)
class Retention:
    notified_ttl_seconds: int
    expired_ttl_seconds: int
    deduplication_ttl_seconds: int
    outbox_max_age_seconds: int
    prune_interval_seconds: int


@dataclass(frozen=True)
class HealthRule:
    reason: str
    threshold_seconds: int | None = None
    threshold: int | None = None
    except_environment: str | None = None


class Contracts:
    """Vue validée des trois contrats.

    Le constructeur valide la cohérence minimale : trois terminaux, mapping
    autoritaire, sources résolues, environnements isolés et allowlists
    disjointes. Une incohérence lève :class:`ContractError` sans recopier de
    contenu.
    """

    def __init__(
        self,
        tracking: Mapping[str, Any],
        deployment: Mapping[str, Any],
        mapping: Mapping[str, Any],
        root: Path,
    ) -> None:
        self.tracking = dict(tracking)
        self.deployment = dict(deployment)
        self.mapping = dict(mapping)
        self.root = Path(root)
        self._validate()

    @classmethod
    def load(cls, root: Path | None = None) -> "Contracts":
        root = Path(root) if root is not None else DEFAULT_VENDOR_DIR
        try:
            tracking = _read_json(root / "notification-tracking.json")
            deployment = _read_json(root / "notification-deployment.json")
            mapping = _read_json(root / "event-mapping.json")
        except OSError as exc:
            raise ContractError("contract.read_failed") from exc
        except json.JSONDecodeError as exc:
            raise ContractError("contract.invalid_json") from exc
        return cls(tracking, deployment, mapping, root)

    # --- validation -----------------------------------------------------

    def _validate(self) -> None:
        if self.tracking.get("schemaVersion") != 1:
            raise ContractError("contract.schema_version")
        if self.deployment.get("contract") != "contracts/notification-tracking.json":
            raise ContractError("contract.deployment_reference")

        mapping_ref = self.tracking.get("mapping") or {}
        if mapping_ref.get("path") != "contracts/event-mapping.json":
            raise ContractError("contract.mapping_reference")
        if mapping_ref.get("authoritative") is not True:
            raise ContractError("contract.mapping_not_authoritative")
        if mapping_ref.get("fallback") != self.mapping.get("fallback"):
            raise ContractError("contract.mapping_fallback")

        outcomes = self.outcomes
        if outcomes != {"succeeded", "failed", "stopped"}:
            raise ContractError("contract.outcomes")
        terminal_values = set(
            (self.tracking.get("deduplication") or {}).get("terminalValues") or []
        )
        if terminal_values != outcomes:
            raise ContractError("contract.dedup_outcomes")
        payload_outcomes = set(
            (self.tracking.get("payload") or {}).get("outcomeValues") or []
        )
        if payload_outcomes != outcomes:
            raise ContractError("contract.payload_outcomes")

        # Chaque source déclarée doit être résolue par le mapping partagé et
        # chaque terminal du mapping doit avoir une source. Un statut absent
        # ou inconnu ne résout rien.
        declared: dict[tuple[str, str | None], str] = {}
        for terminal in self.tracking.get("terminals") or []:
            outcome = terminal.get("outcome")
            for source in terminal.get("sources") or []:
                event = source.get("event")
                status = source.get("status")
                if not isinstance(event, str) or outcome not in outcomes:
                    raise ContractError("contract.terminal_source")
                key = (event, status)
                if key in declared:
                    raise ContractError("contract.terminal_duplicate")
                declared[key] = outcome
                resolved = self._resolve_from_mapping(event, {"status": status})
                if resolved != outcome:
                    raise ContractError("contract.terminal_mismatch")

        events = self.mapping.get("events") or {}
        if not isinstance(events, dict):
            raise ContractError("contract.mapping_events")
        fallback = self.mapping.get("fallback")
        if fallback not in events:
            raise ContractError("contract.mapping_fallback_entry")
        if (events[fallback] or {}).get("terminal") is True:
            raise ContractError("contract.mapping_fallback_terminal")

        for event, entry in events.items():
            if not isinstance(entry, dict):
                raise ContractError("contract.mapping_entry")
            if entry.get("effect") != "terminal" or entry.get("terminal") is not True:
                continue
            status_map = entry.get("statusMap")
            if status_map is not None:
                if not isinstance(status_map, dict):
                    raise ContractError("contract.status_map")
                for status, outcome in status_map.items():
                    if declared.get((event, status)) != outcome:
                        raise ContractError("contract.terminal_uncovered")
            else:
                outcome = entry.get("workState")
                if declared.get((event, None)) != outcome:
                    raise ContractError("contract.terminal_uncovered")

        # Tout terminal déclaré doit exister dans le mapping comme terminal.
        for event, status in declared:
            entry = events.get(event)
            if not isinstance(entry, dict):
                raise ContractError("contract.terminal_event_missing")
            if entry.get("effect") != "terminal" or entry.get("terminal") is not True:
                raise ContractError("contract.terminal_event_not_terminal")
            if status is not None:
                if status not in (entry.get("statusMap") or {}):
                    raise ContractError("contract.terminal_status_missing")

        # Endpoints figés.
        endpoints = self.tracking.get("endpoints") or {}
        if endpoints.get("basePath") != "/v1":
            raise ContractError("contract.base_path")
        for name in ("register", "attach", "revoke", "health"):
            entry = endpoints.get(name)
            if not isinstance(entry, dict):
                raise ContractError("contract.endpoint_missing")
            if entry.get("auth") != "bearer":
                raise ContractError("contract.endpoint_auth")

        # Auth hash-only, comparaison constante.
        auth = self.tracking.get("auth") or {}
        if auth.get("serverStorage") != "hash-only":
            raise ContractError("contract.auth_storage")
        if auth.get("hash") != "sha-256" or auth.get("comparison") != "constant-time":
            raise ContractError("contract.auth_hash")
        if auth.get("queryStringAllowed") is not False:
            raise ContractError("contract.auth_query")

        # Environnements isolés et transports connus.
        names = set()
        for environment in self.deployment.get("environments") or []:
            name = environment.get("name")
            if not isinstance(name, str) or name in names:
                raise ContractError("contract.environment")
            names.add(name)
            if environment.get("isolated") is not True:
                raise ContractError("contract.environment_isolated")
            if environment.get("fcmTransport") not in {"dry-run", "fcm-http-v1"}:
                raise ContractError("contract.environment_transport")
        if names != {"fixtures", "integration", "personal"}:
            raise ContractError("contract.environments")

        # Allowlist RPC/REST.
        access = self.deployment.get("hermesAccess") or {}
        allowed = set(access.get("allowedRpc") or [])
        forbidden = set(access.get("forbiddenRpc") or [])
        if not allowed or allowed & forbidden:
            raise ContractError("contract.rpc_allowlist")
        for route in access.get("allowedRest") or []:
            if not re.match(r"^(GET|POST) /[^\s]+$", route):
                raise ContractError("contract.rest_allowlist")

        # Payload strict et libellés complets.
        payload = self.tracking.get("payload") or {}
        if payload.get("dataFields") != ["subscriptionId", "outcome"]:
            raise ContractError("contract.payload_fields")
        body_by_outcome = (payload.get("notification") or {}).get(
            "bodyByOutcome"
        ) or {}
        if set(body_by_outcome) != outcomes:
            raise ContractError("contract.payload_labels")
        if payload.get("messageKind") != "notification-and-data":
            raise ContractError("contract.payload_kind")

        # Santé : un seuil par raison.
        for rule in self.degraded_when:
            if rule.threshold is None and rule.threshold_seconds is None:
                raise ContractError("contract.health_threshold")
            if rule.threshold is not None and rule.threshold <= 0:
                raise ContractError("contract.health_threshold")
            if rule.threshold_seconds is not None and rule.threshold_seconds < 0:
                raise ContractError("contract.health_threshold")

    def _resolve_from_mapping(
        self, event_type: str, payload: Mapping[str, Any]
    ) -> str | None:
        events = self.mapping.get("events") or {}
        entry = events.get(event_type)
        if entry is None:
            entry = events.get(self.mapping.get("fallback"))
        if not isinstance(entry, dict):
            return None
        if entry.get("effect") != "terminal" or entry.get("terminal") is not True:
            return None
        status_map = entry.get("statusMap")
        if status_map is not None:
            status = payload.get("status")
            if not isinstance(status, str):
                return None
            outcome = status_map.get(status)
        else:
            outcome = entry.get("workState")
        return outcome if outcome in self.outcomes else None

    # --- terminaux ------------------------------------------------------

    @property
    def outcomes(self) -> set[str]:
        return {
            terminal.get("outcome")
            for terminal in self.tracking.get("terminals") or []
            if isinstance(terminal, dict)
        }

    def resolve_terminal(
        self, event_type: str, payload: Mapping[str, Any] | None
    ) -> str | None:
        """Issue notifiable, ou ``None`` si l'événement n'est pas terminal.

        Un statut absent ou inconnu, un ``workState`` inconnu, un événement
        absent du mapping ou un payload non-objet ne notifient jamais.
        """

        if not isinstance(payload, Mapping):
            return None
        return self._resolve_from_mapping(event_type, payload)

    def is_terminal_event(self, event_type: str) -> bool:
        entry = (self.mapping.get("events") or {}).get(event_type)
        return bool(
            isinstance(entry, dict)
            and entry.get("effect") == "terminal"
            and entry.get("terminal") is True
        )

    # --- registre / exécution -----------------------------------------

    @property
    def registry(self) -> Mapping[str, Any]:
        return self.tracking.get("registry") or {}

    @property
    def subscription_min_length(self) -> int:
        return int(self.registry.get("minLength", 22))

    @property
    def subscription_max_length(self) -> int:
        return int(self.registry.get("maxLength", 128))

    def valid_subscription_id(self, value: object) -> bool:
        if not isinstance(value, str):
            return False
        if not re.fullmatch(
            rf"[A-Za-z0-9_-]{{{self.subscription_min_length},"
            rf"{self.subscription_max_length}}}",
            value,
        ):
            return False
        return True

    def execution_id(self, session_id: str, user_row_id: int) -> str:
        """``base64url(session_id + ':' + user_row_id)`` sans padding."""

        if not isinstance(session_id, str) or not session_id:
            raise ValueError("session")
        if isinstance(user_row_id, bool) or not isinstance(user_row_id, int):
            raise ValueError("row")
        raw = f"{session_id}:{user_row_id}".encode("utf-8")
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")

    def execution_row(self, execution_id: str, session_id: str) -> int:
        """Décode et vérifie un ``executionId`` reçu à l'attache."""

        if not isinstance(execution_id, str) or not isinstance(session_id, str):
            raise ValueError("execution")
        try:
            padded = execution_id + "=" * (-len(execution_id) % 4)
            raw = base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8")
        except (ValueError, UnicodeDecodeError) as exc:
            raise ValueError("execution") from exc
        if ":" not in raw:
            raise ValueError("execution")
        session, row_text = raw.rsplit(":", 1)
        if session != session_id:
            raise ValueError("execution")
        try:
            row = int(row_text)
        except ValueError as exc:
            raise ValueError("execution") from exc
        if row < 0:
            raise ValueError("execution")
        return row

    # --- TTL / retries / rétention -------------------------------------

    @property
    def registered_ttl_seconds(self) -> int:
        return int(self.registry.get("ttlSeconds", 0))

    @property
    def attached_ttl_seconds(self) -> int:
        return int(self.registry.get("attachedTtlSeconds", 0))

    @property
    def retention(self) -> Retention:
        retention = self.tracking.get("retention") or {}
        return Retention(
            notified_ttl_seconds=int(retention.get("notifiedTtlSeconds", 0)),
            expired_ttl_seconds=int(retention.get("expiredTtlSeconds", 0)),
            deduplication_ttl_seconds=int(
                retention.get("deduplicationTtlSeconds", 0)
            ),
            outbox_max_age_seconds=int(retention.get("outboxMaxAgeSeconds", 0)),
            prune_interval_seconds=int(retention.get("pruneIntervalSeconds", 0)),
        )

    @property
    def observer_retries(self) -> ObserverRetries:
        retries = ((self.tracking.get("retries") or {}).get("observer")) or {}
        raw_backoff = retries.get("backoffMs") or []
        backoff = tuple(max(1, int(value) // 1000) for value in raw_backoff)
        return ObserverRetries(
            max_attempts=int(retries.get("maxAttempts", 5)),
            backoff_seconds=backoff or (1, 5, 30, 300),
            sweep_interval_seconds=int(retries.get("sweepIntervalSeconds", 300)),
            drop_after_seconds=int(retries.get("dropAfterSeconds", 172800)),
            after_max_attempts=str(retries.get("afterMaxAttempts", "keep-in-outbox")),
        )

    @property
    def max_replay_events(self) -> int:
        return int((self.tracking.get("catchUp") or {}).get("maxReplayEvents", 1000))

    # --- payload --------------------------------------------------------

    @property
    def payload(self) -> Mapping[str, Any]:
        return self.tracking.get("payload") or {}

    @property
    def data_fields(self) -> tuple[str, ...]:
        return tuple(self.payload.get("dataFields") or ())

    @property
    def notification_title(self) -> str:
        return str((self.payload.get("notification") or {}).get("title", ""))

    def notification_body(self, outcome: str) -> str:
        bodies = (self.payload.get("notification") or {}).get("bodyByOutcome") or {}
        return str(bodies.get(outcome, ""))

    @property
    def android(self) -> Mapping[str, Any]:
        return self.payload.get("android") or {}

    @property
    def max_payload_bytes(self) -> int:
        return int(self.payload.get("maxBytes", 1024))

    def validate_data(self, data: Mapping[str, Any]) -> bool:
        if set(data) != set(self.data_fields):
            return False
        if any(not isinstance(value, str) for value in data.values()):
            return False
        return data.get("outcome") in self.outcomes

    # --- endpoints ------------------------------------------------------

    @property
    def endpoints(self) -> Mapping[str, Mapping[str, Any]]:
        return self.tracking.get("endpoints") or {}

    def endpoint(self, name: str) -> Endpoint:
        entry = self.endpoints.get(name)
        if not isinstance(entry, dict):
            raise ContractError("contract.endpoint_missing")
        return Endpoint(
            name=name,
            method=str(entry.get("method")),
            path=str(entry.get("path")),
            body=tuple(entry.get("body") or ()),
            success_status=tuple(int(value) for value in entry.get("successStatus") or ()),
            error_status=tuple(int(value) for value in entry.get("errorStatus") or ()),
        )

    # --- auth / errors / logs ------------------------------------------

    @property
    def auth(self) -> Mapping[str, Any]:
        return self.tracking.get("auth") or {}

    @property
    def error_codes(self) -> frozenset[str]:
        return frozenset((self.tracking.get("errors") or {}).get("codes") or ())

    @property
    def logging(self) -> Mapping[str, Any]:
        return self.tracking.get("logging") or {}

    @property
    def health_settings(self) -> Mapping[str, Any]:
        return self.tracking.get("health") or {}

    @property
    def degraded_when(self) -> tuple[HealthRule, ...]:
        rules = []
        for entry in self.health_settings.get("degradedWhen") or []:
            rules.append(
                HealthRule(
                    reason=str(entry.get("reason")),
                    threshold_seconds=(
                        int(entry["thresholdSeconds"])
                        if entry.get("thresholdSeconds") is not None
                        else None
                    ),
                    threshold=(
                        int(entry["threshold"]) if entry.get("threshold") is not None else None
                    ),
                    except_environment=entry.get("exceptEnvironment"),
                )
            )
        return tuple(rules)

    @property
    def health_counters(self) -> tuple[str, ...]:
        return tuple(self.health_settings.get("counters") or ())

    @property
    def health_forbidden_fields(self) -> tuple[str, ...]:
        return tuple(self.health_settings.get("forbiddenFields") or ())

    # --- déploiement ----------------------------------------------------

    @property
    def environment_records(self) -> dict[str, Environment]:
        result: dict[str, Environment] = {}
        for entry in self.deployment.get("environments") or []:
            environment = Environment(
                name=str(entry.get("name")),
                purpose=str(entry.get("purpose", "")),
                credential_ref=str(entry.get("credentialRef", "")),
                registry_ref=str(entry.get("registryRef", "")),
                origin_ref=str(entry.get("originRef", "")),
                fcm_transport=str(entry.get("fcmTransport", "")),
                firebase_project=bool(entry.get("firebaseProject")),
                isolated=bool(entry.get("isolated")),
                dry_run_locked=bool(entry.get("dryRunLocked")),
                status=entry.get("status"),
            )
            result[environment.name] = environment
        return result

    def environment(self, name: str) -> Environment:
        environments = self.environment_records
        if name not in environments:
            raise ContractError("contract.environment_unknown")
        return environments[name]

    @property
    def allowed_rpc(self) -> frozenset[str]:
        return frozenset(
            (self.deployment.get("hermesAccess") or {}).get("allowedRpc") or ()
        )

    @property
    def forbidden_rpc(self) -> frozenset[str]:
        return frozenset(
            (self.deployment.get("hermesAccess") or {}).get("forbiddenRpc") or ()
        )

    @property
    def allowed_rest(self) -> frozenset[str]:
        return frozenset(
            (self.deployment.get("hermesAccess") or {}).get("allowedRest") or ()
        )

    @property
    def runtime_listen(self) -> Mapping[str, Any]:
        return ((self.deployment.get("runtime") or {}).get("listen")) or {}

    @property
    def runtime_origin(self) -> Mapping[str, Any]:
        return ((self.deployment.get("runtime") or {}).get("origin")) or {}

    @property
    def fcm(self) -> Mapping[str, Any]:
        return self.deployment.get("fcm") or {}

    @property
    def fcm_dry_run(self) -> Mapping[str, Any]:
        return self.fcm.get("dryRun") or {}


def _read_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ContractError("contract.root_object")
    return data
