"""État de santé borné, dérivé des seuils du contrat.

Le service ne renvoie que ``state``, ``reasons``, ``counters``, ``version`` et
``checkedAt``. Aucun identifiant de suivi, contenu ou secret ne peut y entrer :
les raisons viennent des règles du contrat et les compteurs de SQLite.
"""

from __future__ import annotations

import threading
import time
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Any, Callable, Mapping

from . import __version__
from .errors import StorageError

if TYPE_CHECKING:  # pragma: no cover - import de type uniquement
    from .contracts import Contracts
    from .store import Store


class HealthState:
    def __init__(
        self,
        contracts: "Contracts",
        *,
        environment: str,
        dry_run: bool,
        version: str = __version__,
        now: Callable[[], float] | None = None,
    ) -> None:
        self.contracts = contracts
        self.environment = environment
        self.dry_run = bool(dry_run)
        self.version = version
        self._now = now or time.monotonic
        self._clock = (
            (lambda: datetime.now(timezone.utc))
            if now is None
            else (lambda: datetime.fromtimestamp(now(), tz=timezone.utc))
        )
        self._lock = threading.Lock()
        self._last_hermes_success: float | None = None
        self._last_fcm_error: float | None = None
        self._last_storage_error: float | None = None
        self._watchers = 0

    # --- signaux --------------------------------------------------------

    def record_hermes_success(self) -> None:
        with self._lock:
            self._last_hermes_success = self._now()

    def record_fcm_error(self) -> None:
        with self._lock:
            self._last_fcm_error = self._now()

    def record_fcm_success(self) -> None:
        with self._lock:
            self._last_fcm_error = None

    def record_storage_error(self) -> None:
        with self._lock:
            self._last_storage_error = self._now()

    def record_storage_success(self) -> None:
        """Efface une erreur de stockage dès qu'une lecture réussit.

        Sans cet effacement, la moindre erreur SQLite transitoire figerait la
        santé en ``storage-error`` jusqu'au redémarrage.
        """

        with self._lock:
            self._last_storage_error = None

    def set_watchers(self, count: int) -> None:
        with self._lock:
            self._watchers = max(0, int(count))

    def reset(self) -> None:
        """Réinitialise les signaux volatils (tests / redémarrage logique)."""

        with self._lock:
            self._last_hermes_success = None
            self._last_fcm_error = None
            self._last_storage_error = None
            self._watchers = 0

    # --- instantané -----------------------------------------------------

    def snapshot(self, store: "Store") -> dict[str, Any]:
        try:
            counters = store.counters_snapshot()
        except StorageError:
            # Une base momentanément illisible ne doit pas transformer la
            # sonde en 500 : elle devient un état dégradé borné.
            self.record_storage_error()
            counters = {}
        else:
            # La sonde est elle-même une lecture : son succès prouve que le
            # stockage est revenu et doit lever la dégradation.
            self.record_storage_success()
        now = self._now()
        with self._lock:
            last_hermes = self._last_hermes_success
            last_fcm = self._last_fcm_error
            last_storage = self._last_storage_error
            watchers = self._watchers

        reasons: list[dict[str, int | str]] = []
        for rule in self.contracts.degraded_when:
            if rule.except_environment == self.environment:
                continue
            if rule.reason == "fcm-unavailable" and self.dry_run:
                # Aucun transport FCM réel n'existe en 5.2.
                continue
            observed = False
            if rule.reason == "hermes-unreachable":
                if watchers > 0:
                    age = _age(now, last_hermes)
                    observed = age >= float(rule.threshold_seconds or 0)
            elif rule.reason == "outbox-backlog":
                observed = int(counters.get("outboxPending", 0)) > int(
                    rule.threshold or 0
                )
            elif rule.reason == "fcm-unavailable":
                if last_fcm is not None:
                    observed = _age(now, last_fcm) >= float(
                        rule.threshold_seconds or 0
                    )
            elif rule.reason == "storage-error":
                observed = last_storage is not None
            else:
                # Une règle inconnue ne peut pas être évaluée ; le contrat
                # actuel n'en contient pas.
                continue
            if observed:
                reason: dict[str, int | str] = {"reason": rule.reason}
                if rule.threshold_seconds is not None:
                    reason["thresholdSeconds"] = rule.threshold_seconds
                if rule.threshold is not None:
                    reason["threshold"] = rule.threshold
                reasons.append(reason)

        checked = self._clock().replace(microsecond=0).isoformat()
        if checked.endswith("+00:00"):
            checked = checked[:-6] + "Z"

        response: dict[str, Any] = {
            "state": "degraded" if reasons else "ok",
            "reasons": reasons,
            "counters": {
                name: int(counters.get(name, 0))
                for name in self.contracts.health_counters
            },
            "version": self.version,
            "checkedAt": checked,
        }
        forbidden = set(self.contracts.health_forbidden_fields)
        if forbidden & set(response):
            raise RuntimeError("health.forbidden")
        return response


def _age(now: float, since: float | None) -> float:
    if since is None:
        return float("inf")
    return max(0.0, now - since)
