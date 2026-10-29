"""Observateur des fins de travail Hermes.

Une veille par couple ``(profil, session)`` : ``session.resume`` avec
``omit_messages`` (repli sans l'option), puis ``session.events.since`` depuis
le curseur durable. ``truncated`` ou un changement d'epoch impose
``session.history`` : aucun succès n'est alors déduit d'un rejeu incomplet.
Le terminal n'est rapproché que par ``session_id`` + ``persisted_turn.user_row_id``
et le premier terminal gagne.
"""

from __future__ import annotations

import asyncio
import threading
from dataclasses import dataclass
from typing import Any, Callable, Mapping, Sequence

from ..config import Config
from ..contracts import Contracts
from ..errors import StorageError
from ..health import HealthState
from ..logs import EventLogger, Redactor
from ..store import Execution, Store
from .rpc import (
    GatewayRpc,
    HermesError,
    HermesRpcError,
    HermesSession,
)


@dataclass(frozen=True)
class WatchKey:
    profile: str
    session_id: str


@dataclass(frozen=True)
class SinceResult:
    events: tuple[Mapping[str, Any], ...]
    latest_seq: int
    truncated: bool
    epoch: str | None


class _SessionGone(Exception):
    """La session n'existe plus après les tentatives bornées."""


# Codes JSON-RPC du gateway Hermes utiles à la reprise.
# -32004 du contrat ; 4007 « session not found » du gateway réel (essai 5.5).
_RPC_SESSION_NOT_FOUND = frozenset({-32004, 4007})
_RPC_INVALID_PARAMS = -32602
_RPC_METHOD_NOT_FOUND = -32601
_RPC_TRANSIENT = frozenset({-32603, -32000, -32001})


def _rpc_error(error: HermesRpcError) -> HermesError:
    """Conserve une erreur RPC, en marquant les pannes serveur retryables."""

    if error.rpc_code in _RPC_TRANSIENT:
        return HermesError(
            "hermes.rpc_error",
            retryable=True,
            rpc_code=error.rpc_code,
        )
    return error


def _catch_up_unavailable(error: HermesError) -> bool:
    """Vrai seulement si ``session.events.since`` n'existe pas côté Hermes."""

    if error.code == "hermes.not_found":
        return True
    return (
        isinstance(error, HermesRpcError)
        and error.rpc_code == _RPC_METHOD_NOT_FOUND
    )


class Observer:
    def __init__(
        self,
        config: Config,
        contracts: Contracts,
        store: Store,
        session: HermesSession,
        logger: EventLogger,
        *,
        health: HealthState | None = None,
        redactor: Redactor | None = None,
        on_terminal: Callable[[], None] | None = None,
        backoff_seconds: Sequence[int] | None = None,
    ) -> None:
        self.config = config
        self.contracts = contracts
        self.store = store
        self.session = session
        self.logger = logger
        self.health = health
        self.redactor = redactor
        self.on_terminal = on_terminal
        self.backoff = tuple(
            backoff_seconds or contracts.observer_retries.backoff_seconds
        ) or (1, 5, 30, 300)
        self.origin = config.hermes_origin

        self._thread: threading.Thread | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._tasks: dict[WatchKey, asyncio.Task[None]] = {}
        self._wake_event: asyncio.Event | None = None
        self._stop = threading.Event()
        self._started = False

    # --- cycle de vie ---------------------------------------------------

    def start(self) -> None:
        if self._started:
            return
        self._stop.clear()
        self._started = True
        self._thread = threading.Thread(
            target=self._thread_main,
            name="hermes-observer",
            daemon=True,
        )
        self._thread.start()

    def stop(self, timeout: float = 10.0) -> None:
        self._stop.set()
        loop = self._loop
        if loop is not None:
            try:
                loop.call_soon_threadsafe(self._signal_wake)
            except RuntimeError:
                pass
        thread = self._thread
        if thread is not None:
            thread.join(timeout)
        self._started = False

    def wake(self) -> None:
        loop = self._loop
        if loop is None:
            return
        try:
            loop.call_soon_threadsafe(self._signal_wake)
        except RuntimeError:
            return

    def _signal_wake(self) -> None:
        if self._wake_event is not None:
            self._wake_event.set()

    def _thread_main(self) -> None:
        try:
            asyncio.run(self._main())
        except Exception as error:  # pragma: no cover - garde-fou
            self.logger.exception_code("observer.loop_error", error)

    async def _main(self) -> None:
        self._loop = asyncio.get_running_loop()
        self._wake_event = asyncio.Event()
        try:
            while not self._stop.is_set():
                try:
                    self._reconcile()
                except Exception as error:  # pragma: no cover - garde-fou
                    # Une erreur de lecture imprévue ne doit pas tuer la
                    # supervision : la boucle suivante retente.
                    self.logger.exception_code("observer.loop_error", error)
                if self._stop.is_set():
                    break
                try:
                    await asyncio.wait_for(self._wake_event.wait(), 5.0)
                except asyncio.TimeoutError:
                    pass
                self._wake_event.clear()
        finally:
            for task in self._tasks.values():
                task.cancel()
            if self._tasks:
                await asyncio.gather(
                    *self._tasks.values(), return_exceptions=True
                )
            self._tasks.clear()
            if self.health is not None:
                self.health.set_watchers(0)
            self._loop = None

    # --- supervision ----------------------------------------------------

    def _reconcile(self) -> None:
        groups: dict[WatchKey, dict[str, Execution]] = {}
        keep: set[WatchKey] = set()
        try:
            active = self.store.active_executions()
            watching = self.store.watch_executions()
        except StorageError:
            if self.health is not None:
                self.health.record_storage_error()
            self.logger.error("storage.error", reason="observer")
            return

        def add(execution: Execution) -> None:
            if execution.connection != self.origin:
                return
            key = WatchKey(
                profile=execution.profile, session_id=execution.session_id
            )
            keep.add(key)
            groups.setdefault(key, {})[execution.execution_id] = execution

        # Les exécutions sans entrée outbox ouvrent une veille ; celles qui
        # attendent encore une livraison doivent aussi retrouver la leur après
        # un redémarrage, sinon un terminal tardif est perdu.
        for execution in active:
            add(execution)
        for execution in watching:
            add(execution)

        for key in list(self._tasks):
            task = self._tasks[key]
            if key not in keep or task.done():
                if task.done() and not task.cancelled():
                    error = task.exception()
                    if error is not None:
                        self.logger.exception_code("observer.watch_error", error)
                if not task.done():
                    task.cancel()
                self._tasks.pop(key, None)

        for key in groups:
            if key not in self._tasks:
                self._tasks[key] = asyncio.create_task(
                    self._watch(key), name="hermes-watch"
                )

        if self.health is not None:
            self.health.set_watchers(len(self._tasks))

    # --- veille ---------------------------------------------------------

    async def _watch(self, key: WatchKey) -> None:
        failures = 0
        session_failures = 0
        max_attempts = max(1, self.contracts.observer_retries.max_attempts)
        while not self._stop.is_set():
            try:
                active = self._has_active(key)
            except StorageError:
                if self.health is not None:
                    self.health.record_storage_error()
                self.logger.error("storage.error", reason="observer_cycle")
                await self._sleep(self._delay(failures))
                failures += 1
                continue
            if not active:
                return
            try:
                outcome = await self._run_session(key)
            except _SessionGone:
                session_failures += 1
                if session_failures >= max_attempts:
                    self._expire_key(key)
                    return
                delay = self._delay(session_failures - 1)
                self.logger.warning(
                    "observer.session_retry",
                    attempt=session_failures,
                    reason="session",
                )
                await self._sleep(delay)
                continue
            except HermesError as error:
                if not getattr(error, "retryable", True):
                    # Erreur de protocole ou de configuration : réessayer à
                    # l'infini ne peut pas guérir, on borne puis on expire.
                    session_failures += 1
                    if session_failures >= max_attempts:
                        self._expire_key(key)
                        return
                    self.logger.warning(
                        "observer.unreachable",
                        attempt=session_failures,
                        reason=error.code,
                        # Code JSON-RPC numérique, sans contenu : diagnostic 5.5.
                        rpc_code=getattr(error, "rpc_code", None),
                    )
                    await self._sleep(self._delay(session_failures - 1))
                    continue
                failures += 1
                self.logger.warning(
                    "observer.unreachable",
                    attempt=failures,
                    reason=error.code,
                    rpc_code=getattr(error, "rpc_code", None),
                )
                await self._sleep(self._delay(failures - 1))
                continue
            except StorageError:
                failures += 1
                if self.health is not None:
                    self.health.record_storage_error()
                self.logger.error("storage.error", reason="observer_cycle")
                await self._sleep(self._delay(failures - 1))
                continue
            except asyncio.CancelledError:
                raise
            except Exception as error:  # pragma: no cover - garde-fou
                failures += 1
                self.logger.exception_code("observer.cycle_error", error)
                await self._sleep(self._delay(failures - 1))
                continue

            failures = 0
            session_failures = 0
            if outcome == "done":
                return
            # Socket fermée proprement : reprise rapide, sans attendre le
            # backoff maximal.
            await self._sleep(self._delay(0))

    async def _run_session(self, key: WatchKey) -> str:
        if not self._has_active(key):
            return "done"
        if self.redactor is not None:
            self.redactor.add(key.session_id)
            if key.profile:
                self.redactor.add(key.profile)

        ticket = await self.session.ws_ticket()
        rpc = await GatewayRpc.connect(
            self.origin,
            ticket,
            self.contracts,
            timeout=15.0,
            logger=self.logger,
        )
        try:
            epoch = await rpc.wait_ready()
            await rpc.announce_capabilities()
            result = await self._resume(rpc, key)
            runtime = result.get("session_id")
            if not isinstance(runtime, str) or not runtime:
                raise HermesError("hermes.invalid_resume", retryable=False)
            if self.redactor is not None:
                self.redactor.add(runtime)
            self.store.set_runtime(
                connection=self.origin,
                session_id=key.session_id,
                profile=key.profile,
                runtime_session_id=runtime,
            )
            if self.health is not None:
                self.health.record_hermes_success()
            self.logger.info("observer.resumed", status="attached")

            await self._catch_up(rpc, key, runtime, epoch)
            return await self._live(rpc, key, runtime, epoch)
        finally:
            await rpc.close()

    async def _resume(
        self, rpc: GatewayRpc, key: WatchKey
    ) -> Mapping[str, Any]:
        base = {
            "session_id": key.session_id,
            "profile": key.profile or None,
        }
        try:
            return await rpc.call(
                "session.resume",
                {**base, "omit_messages": True},
                timeout=15.0,
            )
        except HermesRpcError as error:
            if error.rpc_code == _RPC_METHOD_NOT_FOUND:
                raise _rpc_error(error) from error
            if error.rpc_code in _RPC_SESSION_NOT_FOUND:
                raise _SessionGone() from error
            if error.rpc_code != _RPC_INVALID_PARAMS:
                raise _rpc_error(error) from error
            # Seul un refus de l'option ``omit_messages`` justifie le repli.
            self.logger.info("observer.resume_fallback")
            try:
                return await rpc.call("session.resume", base, timeout=15.0)
            except HermesRpcError as fallback:
                if fallback.rpc_code in _RPC_SESSION_NOT_FOUND:
                    raise _SessionGone() from fallback
                raise _rpc_error(fallback) from fallback

    async def _catch_up(
        self,
        rpc: GatewayRpc,
        key: WatchKey,
        runtime: str,
        epoch: str | None,
    ) -> None:
        cursor = self.store.get_cursor(
            connection=self.origin,
            profile=key.profile,
            session_id=key.session_id,
        )
        last_seen = cursor.last_seen if cursor is not None else None
        unsafe_epoch = (
            cursor is not None
            and cursor.epoch is not None
            and epoch is not None
            and cursor.epoch != epoch
        )
        missing_epoch = cursor is not None and cursor.epoch is None
        if unsafe_epoch:
            self.logger.warning("observer.epoch_changed")
        elif missing_epoch:
            self.logger.warning("observer.epoch_missing")

        # ``maxReplayEvents`` borne le lot ; au-delà, on repart du dernier
        # numéro traité au lieu de sauter au ``latest_seq`` du serveur.
        limit = max(1, self.contracts.max_replay_events)
        first = True
        reset_requested = unsafe_epoch or missing_epoch
        while True:
            try:
                result = await self._since(
                    rpc, runtime, key.profile, last_seen
                )
            except HermesError as error:
                if (
                    not first
                    or error.retryable
                    or not _catch_up_unavailable(error)
                ):
                    raise
                # Méthode de rejeu absente : l'historique documente
                # l'incertitude, le curseur existant reste la barrière.
                self.logger.warning(
                    "observer.catch_up_unavailable", reason=error.code
                )
                await self._history(rpc, runtime, key.profile)
                return

            if self.health is not None:
                self.health.record_hermes_success()

            reset = first and reset_requested
            if (
                first
                and cursor is not None
                and last_seen is not None
                and result.latest_seq < last_seen
            ):
                self.logger.warning("observer.cursor_ahead")
                reset = True
            if first and result.truncated:
                self.logger.warning("observer.truncated")
                reset = True
            if first and result.epoch is None:
                self.logger.warning("observer.epoch_missing")
                reset = True
            elif (
                first
                and epoch is not None
                and result.epoch != epoch
            ):
                self.logger.warning("observer.epoch_changed")
                reset = True

            if reset:
                # L'historique est rechargé avant d'exploiter les événements
                # présents : ceux-ci restent une preuve terminale valable.
                await self._history(rpc, runtime, key.profile)

            processed = 0
            highest = None if reset else last_seen
            for event in result.events:
                if processed >= limit:
                    break
                seq = _seq(event)
                if seq is None:
                    continue
                if not reset and last_seen is not None and seq <= last_seen:
                    continue
                await self._handle_event(event, key, runtime)
                processed += 1
                if highest is None or seq > highest:
                    highest = seq
                    self.store.set_cursor(
                        connection=self.origin,
                        profile=key.profile,
                        session_id=key.session_id,
                        last_seen=seq,
                        latest_seq=result.latest_seq,
                        epoch=result.epoch or epoch,
                    )
                    last_seen = seq

            if processed:
                self.logger.info("observer.catch_up", count=processed)

            if reset:
                if (
                    processed >= limit
                    and last_seen is not None
                    and last_seen < result.latest_seq
                ):
                    # Le lot de reset est plein : poursuivre depuis le
                    # dernier événement traité, sans recharger l'historique.
                    first = False
                    reset_requested = False
                    continue
                target = result.latest_seq
                if highest is not None:
                    target = max(target, highest)
                self.store.set_cursor(
                    connection=self.origin,
                    profile=key.profile,
                    session_id=key.session_id,
                    last_seen=target,
                    latest_seq=result.latest_seq,
                    epoch=result.epoch or epoch,
                )
                return

            if last_seen is not None and last_seen >= result.latest_seq:
                return
            if processed == 0:
                # Aucun événement exploitable : avancer borne la boucle tout
                # en journalisant l'incertitude.
                self.store.set_cursor(
                    connection=self.origin,
                    profile=key.profile,
                    session_id=key.session_id,
                    last_seen=result.latest_seq,
                    latest_seq=result.latest_seq,
                    epoch=result.epoch or epoch,
                )
                return
            first = False

    async def _live(
        self,
        rpc: GatewayRpc,
        key: WatchKey,
        runtime: str,
        epoch: str | None,
    ) -> str:
        while not self._stop.is_set():
            if not self._has_active(key):
                return "done"
            event = await rpc.next_event(timeout=30.0)
            if event is None:
                # Un poll sans événement prouve que le socket est toujours
                # vivant ; sans cela une veille inactive semble injoignable.
                if self.health is not None:
                    self.health.record_hermes_success()
                continue
            seq = _seq(event)
            accepted = await self._handle_event(event, key, runtime)
            if accepted and seq is not None:
                cursor = self.store.get_cursor(
                    connection=self.origin,
                    profile=key.profile,
                    session_id=key.session_id,
                )
                latest = cursor.latest_seq if cursor is not None else None
                if latest is None or seq > latest:
                    latest = seq
                self.store.set_cursor(
                    connection=self.origin,
                    profile=key.profile,
                    session_id=key.session_id,
                    last_seen=seq,
                    latest_seq=latest,
                    epoch=epoch,
                )
                if self.health is not None:
                    self.health.record_hermes_success()
        return "done"

    # --- traitement d'un événement --------------------------------------

    async def _handle_event(
        self,
        event: Mapping[str, Any],
        key: WatchKey,
        runtime: str,
    ) -> bool:
        event_type = event.get("type")
        if not isinstance(event_type, str):
            return False
        session_id = event.get("session_id")
        if isinstance(session_id, str) and session_id not in {
            key.session_id,
            runtime,
        }:
            return False
        payload = event.get("payload")
        if not isinstance(payload, Mapping):
            payload = {}

        outcome = self.contracts.resolve_terminal(event_type, payload)
        if outcome is None:
            return True

        if event_type == "message.complete":
            row = _user_row(payload)
            submission = _submission_id(payload)
            if row is None:
                self.logger.info("observer.unmatched", reason="row")
                return True
            candidates = [
                execution
                for execution in self.store.find_terminal_candidates(
                    session_ids=[key.session_id, runtime],
                    user_row_id=row,
                )
                if self._in_scope(execution, key)
            ]
            for execution in candidates:
                expected = self.contracts.execution_id(
                    execution.session_id, row
                )
                if expected != execution.execution_id:
                    continue
                self._record(
                    execution,
                    outcome=outcome,
                    submission_id=submission,
                )
            if not candidates:
                self.logger.info("observer.unmatched", reason="execution")
            return True

        if event_type == "error":
            candidates = [
                execution
                for execution in self.store.error_candidates(
                    session_ids=[key.session_id, runtime]
                )
                if self._in_scope(execution, key)
            ]
            if len(candidates) != 1:
                self.logger.info(
                    "observer.error_ambiguous", count=len(candidates)
                )
                return True
            self._record(candidates[0], outcome=outcome, submission_id=None)
            return True

        return True

    def _record(
        self,
        execution: Execution,
        *,
        outcome: str,
        submission_id: str | None,
    ) -> None:
        if self.redactor is not None:
            self.redactor.add(execution.subscription_id)
            self.redactor.add(execution.execution_id)
        result = self.store.record_terminal(
            subscription_id=execution.subscription_id,
            execution_id=execution.execution_id,
            terminal=outcome,
            submission_id=submission_id,
        )
        if result == "enqueued":
            self.logger.info(
                "observer.terminal",
                terminal=outcome,
                outcome=outcome,
                state="pending",
            )
            if self.on_terminal is not None:
                self.on_terminal()
        elif result == "duplicate":
            self.logger.info(
                "observer.duplicate", terminal=outcome, outcome=outcome
            )
        else:
            self.logger.info("observer.unmatched", reason="terminal")

    def _in_scope(self, execution: Execution, key: WatchKey) -> bool:
        return (
            execution.connection == self.origin
            and execution.profile == key.profile
        )

    # --- helpers --------------------------------------------------------

    def _has_active(self, key: WatchKey) -> bool:
        try:
            executions = self.store.watch_executions(
                session_id=key.session_id
            )
        except StorageError:
            if self.health is not None:
                self.health.record_storage_error()
            raise
        return any(
            execution.connection == self.origin
            and execution.profile == key.profile
            for execution in executions
        )

    def _expire_key(self, key: WatchKey) -> None:
        try:
            executions = self.store.watch_executions(
                session_id=key.session_id
            )
        except StorageError:
            if self.health is not None:
                self.health.record_storage_error()
            return
        expired = 0
        for execution in executions:
            if (
                execution.connection == self.origin
                and execution.profile == key.profile
            ):
                if self.store.expire_execution(
                    execution.execution_id,
                    expired_ttl_seconds=self.contracts.retention.expired_ttl_seconds,
                ):
                    expired += 1
        if expired:
            self.logger.warning("observer.expired", count=expired)

    def _delay(self, index: int) -> float:
        if index < 0:
            index = 0
        if index >= len(self.backoff):
            index = len(self.backoff) - 1
        return float(max(1, self.backoff[index]))

    async def _sleep(self, delay: float) -> None:
        deadline = asyncio.get_running_loop().time() + delay
        while not self._stop.is_set():
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                return
            await asyncio.sleep(min(remaining, 1.0))

    async def _since(
        self,
        rpc: GatewayRpc,
        runtime: str,
        profile: str,
        last_seen: int | None,
    ) -> SinceResult:
        result = await rpc.call(
            "session.events.since",
            {
                "session_id": runtime,
                "profile": profile or None,
                "last_seen": last_seen,
            },
            timeout=15.0,
        )
        raw_events = result.get("events")
        latest = result.get("latest_seq")
        truncated = result.get("truncated")
        epoch = result.get("epoch")
        if (
            not isinstance(raw_events, list)
            or not isinstance(latest, int)
            or isinstance(latest, bool)
            or latest < 0
            or not isinstance(truncated, bool)
        ):
            raise HermesError("hermes.invalid_since", retryable=False)
        events = tuple(
            event for event in raw_events if isinstance(event, Mapping)
        )
        return SinceResult(
            events=events,
            latest_seq=latest,
            truncated=truncated,
            epoch=epoch if isinstance(epoch, str) else None,
        )

    async def _history(
        self, rpc: GatewayRpc, runtime: str, profile: str
    ) -> int:
        result = await rpc.call(
            "session.history",
            {"session_id": runtime, "profile": profile or None},
            timeout=15.0,
        )
        messages = result.get("messages")
        if not isinstance(messages, list):
            raise HermesError("hermes.invalid_history", retryable=False)
        self.logger.info("observer.history_refetched", count=len(messages))
        return len(messages)


def _seq(event: Mapping[str, Any]) -> int | None:
    value = event.get("seq")
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    return None


def _user_row(payload: Mapping[str, Any]) -> int | None:
    turn = payload.get("persisted_turn")
    if not isinstance(turn, Mapping):
        return None
    value = turn.get("user_row_id")
    if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
        return value
    return None


def _submission_id(payload: Mapping[str, Any]) -> str | None:
    turn = payload.get("persisted_turn")
    if not isinstance(turn, Mapping):
        return None
    value = turn.get("submission_id")
    return value if isinstance(value, str) and value else None
