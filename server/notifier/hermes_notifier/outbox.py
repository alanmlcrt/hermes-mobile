"""Dispatcher de l'outbox durable.

En 5.2 le seul transport est le dry-run : il valide le message dérivé du
contrat et enregistre ``outcome``, ``attempt``, ``schema-valid`` et
``terminal``. Aucun envoi FCM n'est effectué et aucun identifiant n'est
conservé dans les enregistrements de dry-run.
"""

from __future__ import annotations

import threading
import time
from collections import deque
from dataclasses import dataclass
from typing import TYPE_CHECKING, Callable, Protocol

from .contracts import Contracts
from .credential import TokenCipher, TokenUnavailable
from .errors import StorageError
from .health import HealthState
from .logs import EventLogger
from .payload import PayloadBuilder, PayloadError, PushPayload
from .store import OutboxEntry, Store

if TYPE_CHECKING:  # pragma: no cover
    from .config import Config


class DeliveryError(Exception):
    code = "fcm.error"
    retryable = True


class InvalidTokenError(DeliveryError):
    code = "fcm.invalid_token"
    retryable = False


class PermanentDeliveryError(DeliveryError):
    code = "fcm.permanent"
    retryable = False


@dataclass(frozen=True)
class DeliveryRecord:
    outcome: str
    attempt: int
    schema_valid: bool
    terminal: str


class DeliveryTransport(Protocol):
    def send(
        self, payload: PushPayload, *, terminal: str, attempt: int
    ) -> None: ...


class DryRunTransport:
    """Valide le message sans réseau et ne retient que des champs sûrs."""

    def __init__(self, contracts: Contracts) -> None:
        self.contracts = contracts
        self._lock = threading.Lock()
        # Le dry-run est un diagnostic : borner la mémoire évite qu'une
        # longue vie du conteneur ne conserve tous les envois simulés.
        self._records: deque[DeliveryRecord] = deque(maxlen=1000)

    @property
    def records(self) -> tuple[DeliveryRecord, ...]:
        with self._lock:
            return tuple(self._records)

    def send(self, payload: PushPayload, *, terminal: str, attempt: int) -> None:
        message = payload.body.get("message")
        if not isinstance(message, dict):
            raise PermanentDeliveryError("payload.invalid")
        if not self.contracts.validate_data(payload.data):
            raise PermanentDeliveryError("payload.data")
        notification = message.get("notification")
        if not isinstance(notification, dict) or not notification.get("body"):
            raise PermanentDeliveryError("payload.notification")
        if payload.size_bytes > self.contracts.max_payload_bytes:
            raise PermanentDeliveryError("payload.too_large")
        record = DeliveryRecord(
            outcome=payload.outcome,
            attempt=attempt,
            schema_valid=True,
            terminal=terminal,
        )
        with self._lock:
            self._records.append(record)


class OutboxDispatcher:
    def __init__(
        self,
        store: Store,
        contracts: Contracts,
        cipher: TokenCipher,
        transport: DeliveryTransport,
        logger: EventLogger,
        *,
        health: HealthState | None = None,
        now: Callable[[], int] | None = None,
    ) -> None:
        self.store = store
        self.contracts = contracts
        self.cipher = cipher
        self.transport = transport
        self.logger = logger
        self.health = health
        self._now = now or (lambda: int(time.time()))
        self._wake = threading.Event()
        self._stop = threading.Event()

    # --- boucle ---------------------------------------------------------

    def wake(self) -> None:
        self._wake.set()

    def stop(self) -> None:
        self._stop.set()
        self._wake.set()

    def run(self) -> None:
        while not self._stop.is_set():
            try:
                self.dispatch_due()
            except StorageError:
                if self.health is not None:
                    self.health.record_storage_error()
                self.logger.error("storage.error", reason="outbox")
            except Exception as error:  # pragma: no cover - garde-fou
                self.logger.exception_code("outbox.loop_error", error)
            self._wake.clear()
            if self._stop.is_set():
                break
            try:
                delay = self._delay()
            except StorageError:
                # Une lecture SQLite momentanément indisponible ne doit pas
                # tuer le thread : on réessaie au balayage suivant.
                if self.health is not None:
                    self.health.record_storage_error()
                self.logger.error("storage.error", reason="outbox_delay")
                delay = self._sweep_delay()
            self._wake.wait(delay)

    def _sweep_delay(self) -> float:
        sweep = float(self.contracts.observer_retries.sweep_interval_seconds)
        return min(max(1.0, sweep), 300.0)

    def _delay(self) -> float:
        sweep = self._sweep_delay()
        next_at = self.store.next_outbox_attempt_at()
        if next_at is None:
            return sweep
        return max(1.0, min(float(next_at - self._now()), sweep))

    # --- traitement -----------------------------------------------------

    def dispatch_due(self, limit: int = 32) -> int:
        processed = 0
        for entry in self.store.due_outbox(limit):
            if self._stop.is_set():
                break
            self._dispatch(entry)
            processed += 1
        return processed

    def _dispatch(self, entry: OutboxEntry) -> str:
        current = self.store.outbox_entry(entry.id)
        if current is None or current.state != "pending":
            return "skipped"

        retention = self.contracts.retention
        retries = self.contracts.observer_retries
        # Le contrat porte la règle d'abandon dans ``retries.dropAfterSeconds``
        # et la borne d'âge dans ``retention.outboxMaxAgeSeconds`` : les deux
        # valent 48 h, la première est autoritaire.
        max_age = retries.drop_after_seconds or retention.outbox_max_age_seconds
        age = self._now() - current.created_at
        if max_age > 0 and age >= max_age:
            self._drop(current, reason="age", expired_ttl_seconds=retention.expired_ttl_seconds)
            return "dropped"

        subscription = self.store.get_subscription(current.subscription_id)
        if (
            subscription is None
            or subscription.state not in {"registered", "attached"}
            or subscription.expires_at <= self._now()
        ):
            self._drop(current, reason="state", expired_ttl_seconds=retention.expired_ttl_seconds)
            return "dropped"

        try:
            token = self.cipher.decrypt(subscription.token_ciphertext)
        except TokenUnavailable:
            self.logger.warning("outbox.token_unavailable", attempt=current.attempt + 1)
            kept = self._retry(current, "credential.token_unreadable")
            return "retry" if kept else "dropped"

        try:
            payload = PayloadBuilder(self.contracts).build(
                subscription_id=current.subscription_id,
                outcome=current.terminal,
                token=token,
            )
        except PayloadError as error:
            # Un message invalide ne deviendra jamais valide : abandon borné.
            self.logger.error(
                "outbox.payload_invalid",
                reason=error.code,
                terminal=current.terminal,
            )
            self._drop(
                current,
                reason="payload",
                expired_ttl_seconds=retention.expired_ttl_seconds,
            )
            return "dropped"

        try:
            self.transport.send(
                payload, terminal=current.terminal, attempt=current.attempt + 1
            )
        except InvalidTokenError:
            self.store.invalidate_subscription(current.subscription_id)
            self.logger.warning(
                "outbox.invalid_token", terminal=current.terminal
            )
            return "invalid"
        except PermanentDeliveryError as error:
            self.logger.error(
                "outbox.delivery_permanent",
                reason=error.code,
                terminal=current.terminal,
            )
            self._drop(
                current,
                reason="delivery",
                expired_ttl_seconds=retention.expired_ttl_seconds,
            )
            return "dropped"
        except DeliveryError as error:
            if self.health is not None:
                self.health.record_fcm_error()
            kept = self._retry(current, error.code)
            return "retry" if kept else "dropped"
        except Exception as error:  # pragma: no cover - transport inattendu
            if self.health is not None:
                self.health.record_fcm_error()
            self.logger.exception_code("outbox.transport_error", error)
            kept = self._retry(current, "fcm.error")
            return "retry" if kept else "dropped"

        delivered = self.store.mark_delivered(
            current.id,
            notified_ttl_seconds=retention.notified_ttl_seconds,
        )
        if delivered:
            if self.health is not None:
                self.health.record_fcm_success()
            self.logger.info(
                "outbox.delivered",
                terminal=current.terminal,
                outcome=current.terminal,
                attempt=current.attempt + 1,
                schema_valid=True,
                status="delivered",
            )
            return "delivered"
        return "skipped"

    def _retry(self, entry: OutboxEntry, code: str) -> bool:
        attempt = entry.attempt + 1
        retries = self.contracts.observer_retries
        backoff = retries.backoff_seconds
        index = min(max(0, attempt - 1), len(backoff) - 1)
        delay = backoff[index]
        if attempt >= retries.max_attempts:
            if retries.after_max_attempts == "drop":
                self._drop(
                    entry,
                    reason="exhausted",
                    expired_ttl_seconds=self.contracts.retention.expired_ttl_seconds,
                )
                return False
            # ``keep-in-outbox`` (défaut) : on ralentit sans supprimer avant
            # ``dropAfterSeconds``.
            delay = max(delay, backoff[-1])
            self.logger.warning(
                "outbox.retry_exhausted",
                attempt=attempt,
                terminal=entry.terminal,
            )
        next_at = self._now() + int(delay)
        self.store.mark_retry(
            entry.id,
            next_attempt_at=next_at,
            error_code=code,
        )
        self.logger.warning(
            "outbox.retry",
            attempt=attempt,
            terminal=entry.terminal,
            reason=code,
        )
        return True

    def _drop(
        self,
        entry: OutboxEntry,
        *,
        reason: str,
        expired_ttl_seconds: int,
    ) -> None:
        dropped = self.store.mark_dropped(
            entry.id, expired_ttl_seconds=expired_ttl_seconds
        )
        if dropped:
            self.logger.warning(
                "outbox.dropped",
                reason=reason,
                terminal=entry.terminal,
            )
