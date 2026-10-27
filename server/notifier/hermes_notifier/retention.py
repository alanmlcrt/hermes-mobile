"""Purge bornée de ``/data`` selon ``retention`` du contrat.

La politique ne décide d'aucune durée : elle applique les TTL lus dans le
contrat partagé et ne journalise qu'un total, jamais un identifiant.
"""

from __future__ import annotations

import time
from typing import TYPE_CHECKING

from .contracts import Contracts
from .errors import StorageError
from .logs import EventLogger
from .store import PruneResult, Store

if TYPE_CHECKING:  # pragma: no cover
    from .health import HealthState


class RetentionPolicy:
    def __init__(
        self,
        store: Store,
        contracts: Contracts,
        logger: EventLogger,
        *,
        health: "HealthState | None" = None,
    ) -> None:
        self.store = store
        self.contracts = contracts
        self.logger = logger
        self.health = health
        self._last_prune = 0.0

    @property
    def interval_seconds(self) -> int:
        value = self.contracts.retention.prune_interval_seconds
        return value if value > 0 else 3600

    def due(self, now: float | None = None) -> bool:
        current = time.monotonic() if now is None else now
        return current - self._last_prune >= self.interval_seconds

    def prune(self) -> PruneResult:
        retention = self.contracts.retention
        try:
            result = self.store.prune(
                notified_ttl_seconds=retention.notified_ttl_seconds,
                expired_ttl_seconds=retention.expired_ttl_seconds,
                deduplication_ttl_seconds=retention.deduplication_ttl_seconds,
                outbox_max_age_seconds=retention.outbox_max_age_seconds,
            )
        except StorageError:
            if self.health is not None:
                self.health.record_storage_error()
            self.logger.error("storage.error", reason="prune")
            raise
        self._last_prune = time.monotonic()
        if result.total() > 0:
            self.logger.info("storage.pruned", count=result.total())
        return result

    def prune_if_due(self) -> PruneResult | None:
        return self.prune() if self.due() else None
