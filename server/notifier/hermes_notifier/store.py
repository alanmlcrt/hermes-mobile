"""Registre, attachements, outbox, déduplication et curseurs SQLite.

Tout est dans ``/data`` (sous le répertoire du ``registryRef`` de
l'environnement). Une seule connexion sérialisée par verrou : l'API HTTP
s'exécute dans des threads, l'observateur et le dispatcher dans la boucle
asyncio.
"""

from __future__ import annotations

import json
import sqlite3
import threading
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable, Iterator, Sequence

from .errors import Conflict, Gone, NotFound, StorageError

SCHEMA_VERSION = 1

_SCHEMA = (
    """
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS subscriptions (
        subscription_id TEXT PRIMARY KEY,
        token_ciphertext BLOB NOT NULL,
        state TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        notified_at INTEGER
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS executions (
        execution_id TEXT PRIMARY KEY,
        subscription_id TEXT NOT NULL,
        connection TEXT NOT NULL,
        session_id TEXT NOT NULL,
        profile TEXT NOT NULL DEFAULT '',
        user_row_id INTEGER,
        runtime_session_id TEXT,
        state TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        delivered_at INTEGER
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS executions_session
        ON executions(session_id, profile, connection, state)
    """,
    """
    CREATE INDEX IF NOT EXISTS executions_runtime
        ON executions(runtime_session_id, state)
    """,
    """
    CREATE INDEX IF NOT EXISTS executions_subscription
        ON executions(subscription_id, state)
    """,
    """
    CREATE TABLE IF NOT EXISTS outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subscription_id TEXT NOT NULL,
        execution_id TEXT NOT NULL,
        terminal TEXT NOT NULL,
        state TEXT NOT NULL,
        attempt INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        delivered_at INTEGER,
        last_error TEXT,
        UNIQUE(subscription_id, execution_id)
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS outbox_due
        ON outbox(state, next_attempt_at, created_at)
    """,
    """
    CREATE TABLE IF NOT EXISTS deduplication (
        subscription_id TEXT NOT NULL,
        execution_id TEXT NOT NULL,
        terminal TEXT NOT NULL,
        submission_id TEXT,
        first_seen_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        seen_count INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY(subscription_id, execution_id, terminal)
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS deduplication_seen
        ON deduplication(last_seen_at)
    """,
    """
    CREATE TABLE IF NOT EXISTS cursors (
        connection TEXT NOT NULL,
        profile TEXT NOT NULL,
        session_id TEXT NOT NULL,
        last_seen INTEGER NOT NULL,
        latest_seq INTEGER,
        epoch TEXT,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(connection, profile, session_id)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS counters (
        name TEXT PRIMARY KEY,
        value INTEGER NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS revocations (
        subscription_id TEXT PRIMARY KEY,
        revoked_at INTEGER NOT NULL
    )
    """,
)

_COUNTER_NAMES = ("delivered", "failed", "dropped", "expired", "revoked", "invalidToken")


@dataclass(frozen=True)
class Subscription:
    subscription_id: str
    token_ciphertext: bytes
    state: str
    created_at: int
    updated_at: int
    expires_at: int
    notified_at: int | None


@dataclass(frozen=True)
class Execution:
    execution_id: str
    subscription_id: str
    connection: str
    session_id: str
    profile: str
    user_row_id: int | None
    runtime_session_id: str | None
    state: str
    created_at: int
    updated_at: int
    expires_at: int
    delivered_at: int | None


@dataclass(frozen=True)
class OutboxEntry:
    id: int
    subscription_id: str
    execution_id: str
    terminal: str
    state: str
    attempt: int
    next_attempt_at: int
    created_at: int
    updated_at: int
    delivered_at: int | None
    last_error: str | None


@dataclass(frozen=True)
class Cursor:
    connection: str
    profile: str
    session_id: str
    last_seen: int
    latest_seq: int | None
    epoch: str | None
    updated_at: int


@dataclass(frozen=True)
class PruneResult:
    expired: int = 0
    dropped: int = 0
    subscriptions: int = 0
    executions: int = 0
    dedup: int = 0
    cursors: int = 0
    tombstones: int = 0
    outbox: int = 0

    def total(self) -> int:
        return (
            self.expired
            + self.dropped
            + self.subscriptions
            + self.executions
            + self.dedup
            + self.cursors
            + self.tombstones
            + self.outbox
        )


class Store:
    def __init__(
        self,
        path: Path,
        *,
        outcomes: Iterable[str],
        now: Callable[[], int] | None = None,
    ) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._now = now or (lambda: int(time.time()))
        self._outcomes = frozenset(outcomes)
        self._lock = threading.RLock()
        self._conn = self._connect()
        self._migrate()

    # --- infrastructure -------------------------------------------------

    def _connect(self) -> sqlite3.Connection:
        try:
            connection = sqlite3.connect(
                self.path,
                timeout=10,
                check_same_thread=False,
            )
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA journal_mode=WAL")
            connection.execute("PRAGMA foreign_keys=ON")
            connection.execute("PRAGMA busy_timeout=10000")
            return connection
        except sqlite3.Error as exc:
            raise StorageError("storage.open_failed") from exc

    def _migrate(self) -> None:
        with self._lock, self._conn:
            for statement in _SCHEMA:
                self._conn.execute(statement)
            row = self._conn.execute(
                "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1"
            ).fetchone()
            version = int(row["version"]) if row else 0
            if version > SCHEMA_VERSION:
                raise StorageError("storage.schema_newer")
            if version == 0:
                self._conn.execute(
                    "INSERT INTO schema_migrations(version) VALUES (?)",
                    (SCHEMA_VERSION,),
                )
            for name in _COUNTER_NAMES:
                self._conn.execute(
                    "INSERT INTO counters(name, value) VALUES (?, 0) "
                    "ON CONFLICT(name) DO NOTHING",
                    (name,),
                )

    def close(self) -> None:
        with self._lock:
            self._conn.close()

    @contextmanager
    def _transaction(self) -> Iterator[sqlite3.Connection]:
        with self._lock:
            try:
                with self._conn:
                    yield self._conn
            except sqlite3.Error as exc:
                raise StorageError("storage.write_failed") from exc

    def _read_all(
        self, query: str, parameters: Sequence[Any] = ()
    ) -> list[sqlite3.Row]:
        try:
            with self._lock:
                return self._conn.execute(query, parameters).fetchall()
        except sqlite3.Error as exc:
            raise StorageError("storage.read_failed") from exc

    def _read_one(
        self, query: str, parameters: Sequence[Any] = ()
    ) -> sqlite3.Row | None:
        try:
            with self._lock:
                return self._conn.execute(query, parameters).fetchone()
        except sqlite3.Error as exc:
            raise StorageError("storage.read_failed") from exc

    # --- compteurs ------------------------------------------------------

    def increment(self, name: str, amount: int = 1) -> None:
        if amount <= 0:
            return
        with self._transaction() as conn:
            conn.execute(
                "INSERT INTO counters(name, value) VALUES (?, ?) "
                "ON CONFLICT(name) DO UPDATE SET value = value + excluded.value",
                (name, amount),
            )

    def counter(self, name: str) -> int:
        row = self._read_one(
            "SELECT value FROM counters WHERE name = ?", (name,)
        )
        return int(row["value"]) if row else 0

    def counters_snapshot(self) -> dict[str, int]:
        now = self._now()
        pending = self._read_one(
            "SELECT COUNT(*) AS n FROM subscriptions WHERE state = 'registered' "
            "AND expires_at > ?",
            (now,),
        )["n"]
        attached = self._read_one(
            "SELECT COUNT(*) AS n FROM executions e "
            "JOIN subscriptions s ON s.subscription_id = e.subscription_id "
            "WHERE e.state = 'attached' AND s.state IN ('registered', 'attached') "
            "AND e.expires_at > ? AND s.expires_at > ?",
            (now, now),
        )["n"]
        outbox_pending = self._read_one(
            "SELECT COUNT(*) AS n FROM outbox WHERE state = 'pending'"
        )["n"]
        values = {
            row["name"]: int(row["value"])
            for row in self._read_all("SELECT name, value FROM counters")
        }
        result = {name: 0 for name in _COUNTER_NAMES}
        result.update(values)
        result["pending"] = int(pending)
        result["attached"] = int(attached)
        result["outboxPending"] = int(outbox_pending)
        return result

    # --- abonnements ----------------------------------------------------

    def register(
        self,
        subscription_id: str,
        token_ciphertext: bytes,
        *,
        ttl_seconds: int,
    ) -> bool:
        """Crée ou met à jour l'abonnement ; ``True`` si créé.

        Un ré-enregistrement ne renvoie jamais 409 : le token est remplacé.
        """

        now = self._now()
        with self._transaction() as conn:
            conn.execute(
                "DELETE FROM revocations WHERE subscription_id = ?",
                (subscription_id,),
            )
            row = conn.execute(
                "SELECT state, expires_at FROM subscriptions WHERE subscription_id = ?",
                (subscription_id,),
            ).fetchone()
            if row is None:
                conn.execute(
                    "INSERT INTO subscriptions("
                    "subscription_id, token_ciphertext, state, created_at, "
                    "updated_at, expires_at, notified_at) "
                    "VALUES (?, ?, 'registered', ?, ?, ?, NULL)",
                    (
                        subscription_id,
                        token_ciphertext,
                        now,
                        now,
                        now + int(ttl_seconds),
                    ),
                )
                return True
            state = str(row["state"])
            expires_at = int(row["expires_at"])
            if state in {"registered", "attached", "notified"}:
                # Rotation de token sans casser l'attache en cours.
                conn.execute(
                    "UPDATE subscriptions SET token_ciphertext = ?, updated_at = ? "
                    "WHERE subscription_id = ?",
                    (token_ciphertext, now, subscription_id),
                )
            else:
                conn.execute(
                    "UPDATE subscriptions SET token_ciphertext = ?, state = 'registered', "
                    "updated_at = ?, expires_at = ?, notified_at = NULL "
                    "WHERE subscription_id = ?",
                    (token_ciphertext, now, now + int(ttl_seconds), subscription_id),
                )
            return False

    def get_subscription(self, subscription_id: str) -> Subscription | None:
        row = self._read_one(
            "SELECT * FROM subscriptions WHERE subscription_id = ?",
            (subscription_id,),
        )
        return _subscription(row) if row else None

    def _expire_subscription(self, conn: sqlite3.Connection, subscription_id: str) -> None:
        now = self._now()
        cursor = conn.execute(
            "UPDATE subscriptions SET state = 'expired', updated_at = ?, "
            "expires_at = ? WHERE subscription_id = ? "
            "AND state IN ('registered', 'attached') AND expires_at <= ?",
            (now, now, subscription_id, now),
        )
        if cursor.rowcount:
            conn.execute(
                "UPDATE executions SET state = 'expired', updated_at = ? "
                "WHERE subscription_id = ? AND state = 'attached'",
                (now, subscription_id),
            )
            self._increment_conn(conn, "expired", cursor.rowcount)

    def _increment_conn(self, conn: sqlite3.Connection, name: str, amount: int = 1) -> None:
        if amount <= 0:
            return
        conn.execute(
            "INSERT INTO counters(name, value) VALUES (?, ?) "
            "ON CONFLICT(name) DO UPDATE SET value = value + excluded.value",
            (name, amount),
        )

    def revoke(self, subscription_id: str) -> bool:
        """Supprime l'abonnement ; un inconnu reste un succès idempotent."""

        now = self._now()
        with self._transaction() as conn:
            row = conn.execute(
                "SELECT 1 FROM subscriptions WHERE subscription_id = ?",
                (subscription_id,),
            ).fetchone()
            if row is None:
                return False
            conn.execute(
                "DELETE FROM outbox WHERE subscription_id = ?", (subscription_id,)
            )
            conn.execute(
                "DELETE FROM executions WHERE subscription_id = ?", (subscription_id,)
            )
            conn.execute(
                "DELETE FROM subscriptions WHERE subscription_id = ?", (subscription_id,)
            )
            conn.execute(
                "INSERT INTO revocations(subscription_id, revoked_at) VALUES (?, ?) "
                "ON CONFLICT(subscription_id) DO UPDATE SET revoked_at = excluded.revoked_at",
                (subscription_id, now),
            )
            self._increment_conn(conn, "revoked", 1)
            self._delete_orphan_cursors(conn)
            return True

    def revoked(self, subscription_id: str) -> bool:
        with self._lock:
            row = self._conn.execute(
                "SELECT 1 FROM revocations WHERE subscription_id = ?",
                (subscription_id,),
            ).fetchone()
        return row is not None

    # --- attachements ---------------------------------------------------

    def attach(
        self,
        subscription_id: str,
        *,
        connection: str,
        session_id: str,
        profile: str | None,
        execution_id: str,
        user_row_id: int,
        ttl_seconds: int,
    ) -> str:
        """Attache une exécution ; renvoie ``created`` ou ``duplicate``."""

        now = self._now()
        normalized_profile = profile or ""
        with self._transaction() as conn:
            row = conn.execute(
                "SELECT * FROM subscriptions WHERE subscription_id = ?",
                (subscription_id,),
            ).fetchone()
            if row is None:
                if conn.execute(
                    "SELECT 1 FROM revocations WHERE subscription_id = ?",
                    (subscription_id,),
                ).fetchone():
                    raise Gone()
                raise NotFound()
            self._expire_subscription(conn, subscription_id)
            row = conn.execute(
                "SELECT * FROM subscriptions WHERE subscription_id = ?",
                (subscription_id,),
            ).fetchone()
            if row is None:
                raise NotFound()
            if row["state"] in {"expired", "revoked"}:
                # L'expiration comptée doit survivre au refus : le contexte
                # SQLite annulerait les écritures si l'on sortait en erreur.
                conn.commit()
                raise Gone()

            existing = conn.execute(
                "SELECT * FROM executions WHERE execution_id = ?", (execution_id,)
            ).fetchone()
            if existing is not None:
                same_target = (
                    existing["subscription_id"] == subscription_id
                    and existing["session_id"] == session_id
                    and existing["profile"] == normalized_profile
                    and existing["connection"] == connection
                )
                if same_target and existing["state"] == "expired":
                    # Ré-enregistrement puis ré-attache : la veille doit
                    # repartir, sinon le terminal ne serait jamais observé.
                    conn.execute(
                        "UPDATE executions SET state = 'attached', updated_at = ?, "
                        "expires_at = ?, delivered_at = NULL WHERE execution_id = ?",
                        (now, now + int(ttl_seconds), execution_id),
                    )
                    conn.execute(
                        "UPDATE subscriptions SET state = 'attached', updated_at = ?, "
                        "expires_at = ? WHERE subscription_id = ?",
                        (now, now + int(ttl_seconds), subscription_id),
                    )
                    return "created"
                if same_target:
                    return "duplicate"
                raise Conflict()

            active = conn.execute(
                "SELECT 1 FROM executions WHERE subscription_id = ? "
                "AND state = 'attached' LIMIT 1",
                (subscription_id,),
            ).fetchone()
            if active is not None:
                raise Conflict()

            if row["state"] == "notified":
                raise Conflict()
            if row["state"] != "registered":
                raise Conflict()

            conn.execute(
                "INSERT INTO executions("
                "execution_id, subscription_id, connection, session_id, profile, "
                "user_row_id, runtime_session_id, state, created_at, updated_at, "
                "expires_at, delivered_at) "
                "VALUES (?, ?, ?, ?, ?, ?, NULL, 'attached', ?, ?, ?, NULL)",
                (
                    execution_id,
                    subscription_id,
                    connection,
                    session_id,
                    normalized_profile,
                    user_row_id,
                    now,
                    now,
                    now + int(ttl_seconds),
                ),
            )
            conn.execute(
                "UPDATE subscriptions SET state = 'attached', updated_at = ?, "
                "expires_at = ? WHERE subscription_id = ?",
                (now, now + int(ttl_seconds), subscription_id),
            )
            return "created"

    def execution(self, execution_id: str) -> Execution | None:
        row = self._read_one(
            "SELECT * FROM executions WHERE execution_id = ?", (execution_id,)
        )
        return _execution(row) if row else None

    def set_runtime(
        self,
        *,
        connection: str,
        session_id: str,
        profile: str,
        runtime_session_id: str,
    ) -> None:
        now = self._now()
        with self._transaction() as conn:
            conn.execute(
                "UPDATE executions SET runtime_session_id = ?, updated_at = ? "
                "WHERE connection = ? AND session_id = ? AND profile = ? "
                "AND state = 'attached'",
                (runtime_session_id, now, connection, session_id, profile),
            )

    def expire_execution(
        self, execution_id: str, *, expired_ttl_seconds: int
    ) -> bool:
        """Expire une exécution et, sans autre attache, son abonnement."""

        now = self._now()
        with self._transaction() as conn:
            row = conn.execute(
                "SELECT subscription_id FROM executions WHERE execution_id = ? "
                "AND state = 'attached'",
                (execution_id,),
            ).fetchone()
            if row is None:
                return False
            subscription_id = row["subscription_id"]
            conn.execute(
                "UPDATE executions SET state = 'expired', updated_at = ? "
                "WHERE execution_id = ?",
                (now, execution_id),
            )
            remaining = conn.execute(
                "SELECT 1 FROM executions WHERE subscription_id = ? "
                "AND state = 'attached' LIMIT 1",
                (subscription_id,),
            ).fetchone()
            if remaining is None:
                conn.execute(
                    "UPDATE subscriptions SET state = 'expired', updated_at = ?, "
                    "expires_at = ? WHERE subscription_id = ?",
                    (now, now + int(expired_ttl_seconds), subscription_id),
                )
            self._increment_conn(conn, "expired", 1)
            return True

    def active_executions(
        self, *, session_id: str | None = None
    ) -> list[Execution]:
        now = self._now()
        query = (
            "SELECT e.* FROM executions e "
            "JOIN subscriptions s ON s.subscription_id = e.subscription_id "
            "WHERE e.state = 'attached' AND s.state IN ('registered', 'attached') "
            "AND e.expires_at > ? AND s.expires_at > ? "
            "AND NOT EXISTS (SELECT 1 FROM outbox o "
            "WHERE o.subscription_id = e.subscription_id "
            "AND o.execution_id = e.execution_id)"
        )
        parameters: list[Any] = [now, now]
        if session_id is not None:
            query += " AND e.session_id = ?"
            parameters.append(session_id)
        query += " ORDER BY e.created_at, e.execution_id"
        rows = self._read_all(query, parameters)
        return [_execution(row) for row in rows]

    def watch_executions(
        self, *, session_id: str | None = None
    ) -> list[Execution]:
        """Exécutions encore attachées, même si un terminal attend dans l'outbox.

        Une veille déjà ouverte doit continuer à voir les doublons et les
        terminaux tardifs tant que la livraison n'a pas marqué l'exécution
        ``notified``. ``active_executions`` reste la source des veilles à
        ouvrir : elle ignore celles qui ont déjà une entrée outbox.
        """

        now = self._now()
        query = (
            "SELECT e.* FROM executions e "
            "JOIN subscriptions s ON s.subscription_id = e.subscription_id "
            "WHERE e.state = 'attached' AND s.state IN ('registered', 'attached') "
            "AND e.expires_at > ? AND s.expires_at > ?"
        )
        parameters: list[Any] = [now, now]
        if session_id is not None:
            query += " AND e.session_id = ?"
            parameters.append(session_id)
        query += " ORDER BY e.created_at, e.execution_id"
        rows = self._read_all(query, parameters)
        return [_execution(row) for row in rows]

    def find_terminal_candidates(
        self,
        *,
        session_ids: Sequence[str],
        user_row_id: int,
    ) -> list[Execution]:
        ids = [value for value in dict.fromkeys(session_ids) if value]
        if not ids:
            return []
        now = self._now()
        placeholders = ",".join("?" for _ in ids)
        query = (
            "SELECT e.* FROM executions e "
            "JOIN subscriptions s ON s.subscription_id = e.subscription_id "
            "WHERE e.state IN ('attached', 'notified') "
            "AND s.state IN ('registered', 'attached', 'notified') "
            "AND e.expires_at > ? AND s.expires_at > ? "
            "AND e.user_row_id = ? "
            f"AND (e.session_id IN ({placeholders}) "
            f"OR e.runtime_session_id IN ({placeholders}))"
        )
        params: list[Any] = [now, now, user_row_id, *ids, *ids]
        rows = self._read_all(query, params)
        return [_execution(row) for row in rows]

    def error_candidates(self, *, session_ids: Sequence[str]) -> list[Execution]:
        ids = [value for value in dict.fromkeys(session_ids) if value]
        if not ids:
            return []
        now = self._now()
        placeholders = ",".join("?" for _ in ids)
        query = (
            "SELECT e.* FROM executions e "
            "JOIN subscriptions s ON s.subscription_id = e.subscription_id "
            "WHERE e.state = 'attached' AND s.state IN ('registered', 'attached') "
            "AND e.expires_at > ? AND s.expires_at > ? "
            f"AND (e.session_id IN ({placeholders}) "
            f"OR e.runtime_session_id IN ({placeholders})) "
            "AND NOT EXISTS (SELECT 1 FROM outbox o "
            "WHERE o.subscription_id = e.subscription_id "
            "AND o.execution_id = e.execution_id)"
        )
        params: list[Any] = [now, now, *ids, *ids]
        rows = self._read_all(query, params)
        return [_execution(row) for row in rows]

    # --- terminaux / outbox --------------------------------------------

    def record_terminal(
        self,
        *,
        subscription_id: str,
        execution_id: str,
        terminal: str,
        submission_id: str | None = None,
    ) -> str:
        """Écrit déduplication puis outbox ; premier terminal gagnant."""

        if terminal not in self._outcomes:
            raise ValueError("terminal")
        now = self._now()
        with self._transaction() as conn:
            execution = conn.execute(
                "SELECT * FROM executions WHERE execution_id = ? AND subscription_id = ?",
                (execution_id, subscription_id),
            ).fetchone()
            if execution is None or execution["state"] not in {
                "attached",
                "notified",
            }:
                return "unmatched"
            subscription = conn.execute(
                "SELECT state, expires_at FROM subscriptions WHERE subscription_id = ?",
                (subscription_id,),
            ).fetchone()
            if (
                subscription is None
                or subscription["state"]
                not in {"registered", "attached", "notified"}
                or int(subscription["expires_at"]) <= now
            ):
                return "unmatched"

            conn.execute(
                "INSERT INTO deduplication("
                "subscription_id, execution_id, terminal, submission_id, "
                "first_seen_at, last_seen_at, seen_count) "
                "VALUES (?, ?, ?, ?, ?, ?, 1) "
                "ON CONFLICT(subscription_id, execution_id, terminal) DO UPDATE SET "
                "last_seen_at = excluded.last_seen_at, "
                "seen_count = seen_count + 1, "
                "submission_id = COALESCE(deduplication.submission_id, excluded.submission_id)",
                (
                    subscription_id,
                    execution_id,
                    terminal,
                    submission_id,
                    now,
                    now,
                ),
            )

            existing = conn.execute(
                "SELECT 1 FROM outbox WHERE subscription_id = ? AND execution_id = ?",
                (subscription_id, execution_id),
            ).fetchone()
            if existing is not None:
                return "duplicate"
            if execution["state"] != "attached":
                return "unmatched"
            conn.execute(
                "INSERT INTO outbox("
                "subscription_id, execution_id, terminal, state, attempt, "
                "next_attempt_at, created_at, updated_at, delivered_at, last_error) "
                "VALUES (?, ?, ?, 'pending', 0, ?, ?, ?, NULL, NULL)",
                (subscription_id, execution_id, terminal, now, now, now),
            )
            return "enqueued"

    def due_outbox(self, limit: int = 32) -> list[OutboxEntry]:
        now = self._now()
        rows = self._read_all(
            "SELECT * FROM outbox WHERE state = 'pending' "
            "AND next_attempt_at <= ? ORDER BY created_at, id LIMIT ?",
            (now, limit),
        )
        return [_outbox(row) for row in rows]

    def outbox_entry(self, entry_id: int) -> OutboxEntry | None:
        row = self._read_one(
            "SELECT * FROM outbox WHERE id = ?", (entry_id,)
        )
        return _outbox(row) if row else None

    def next_outbox_attempt_at(self) -> int | None:
        row = self._read_one(
            "SELECT MIN(next_attempt_at) AS next FROM outbox "
            "WHERE state = 'pending'"
        )
        return int(row["next"]) if row and row["next"] is not None else None

    def mark_delivered(self, entry_id: int, *, notified_ttl_seconds: int) -> bool:
        now = self._now()
        with self._transaction() as conn:
            row = conn.execute(
                "SELECT * FROM outbox WHERE id = ? AND state = 'pending'", (entry_id,)
            ).fetchone()
            if row is None:
                return False
            conn.execute(
                "UPDATE outbox SET state = 'delivered', delivered_at = ?, "
                "updated_at = ?, last_error = NULL WHERE id = ?",
                (now, now, entry_id),
            )
            conn.execute(
                "UPDATE executions SET state = 'notified', delivered_at = ?, "
                "updated_at = ? WHERE subscription_id = ? AND execution_id = ?",
                (now, now, row["subscription_id"], row["execution_id"]),
            )
            conn.execute(
                "UPDATE subscriptions SET state = 'notified', notified_at = ?, "
                "updated_at = ?, expires_at = ? WHERE subscription_id = ?",
                (
                    now,
                    now,
                    now + int(notified_ttl_seconds),
                    row["subscription_id"],
                ),
            )
            self._increment_conn(conn, "delivered", 1)
            return True

    def mark_retry(
        self,
        entry_id: int,
        *,
        next_attempt_at: int,
        error_code: str,
    ) -> bool:
        now = self._now()
        with self._transaction() as conn:
            cursor = conn.execute(
                "UPDATE outbox SET attempt = attempt + 1, next_attempt_at = ?, "
                "updated_at = ?, last_error = ? WHERE id = ? AND state = 'pending'",
                (next_attempt_at, now, error_code, entry_id),
            )
            if cursor.rowcount:
                self._increment_conn(conn, "failed", 1)
                return True
            return False

    def mark_dropped(
        self, entry_id: int, *, expired_ttl_seconds: int
    ) -> bool:
        now = self._now()
        with self._transaction() as conn:
            row = conn.execute(
                "SELECT * FROM outbox WHERE id = ? AND state = 'pending'", (entry_id,)
            ).fetchone()
            if row is None:
                return False
            conn.execute(
                "UPDATE outbox SET state = 'dropped', updated_at = ?, last_error = NULL "
                "WHERE id = ?",
                (now, entry_id),
            )
            conn.execute(
                "UPDATE executions SET state = 'expired', updated_at = ? "
                "WHERE subscription_id = ? AND execution_id = ?",
                (now, row["subscription_id"], row["execution_id"]),
            )
            remaining = conn.execute(
                "SELECT 1 FROM executions WHERE subscription_id = ? "
                "AND state = 'attached' LIMIT 1",
                (row["subscription_id"],),
            ).fetchone()
            if remaining is None:
                conn.execute(
                    "UPDATE subscriptions SET state = 'expired', updated_at = ?, "
                    "expires_at = ? WHERE subscription_id = ?",
                    (now, now + int(expired_ttl_seconds), row["subscription_id"]),
                )
            self._increment_conn(conn, "dropped", 1)
            return True

    def invalidate_subscription(self, subscription_id: str) -> None:
        now = self._now()
        with self._transaction() as conn:
            conn.execute(
                "DELETE FROM outbox WHERE subscription_id = ?", (subscription_id,)
            )
            conn.execute(
                "DELETE FROM executions WHERE subscription_id = ?", (subscription_id,)
            )
            conn.execute(
                "DELETE FROM subscriptions WHERE subscription_id = ?", (subscription_id,)
            )
            conn.execute(
                "INSERT INTO revocations(subscription_id, revoked_at) VALUES (?, ?) "
                "ON CONFLICT(subscription_id) DO UPDATE SET revoked_at = excluded.revoked_at",
                (subscription_id, now),
            )
            self._increment_conn(conn, "invalidToken", 1)
            self._delete_orphan_cursors(conn)

    # --- curseurs -------------------------------------------------------

    def get_cursor(
        self, *, connection: str, profile: str, session_id: str
    ) -> Cursor | None:
        row = self._read_one(
            "SELECT * FROM cursors WHERE connection = ? AND profile = ? "
            "AND session_id = ?",
            (connection, profile or "", session_id),
        )
        return _cursor(row) if row else None

    def set_cursor(
        self,
        *,
        connection: str,
        profile: str,
        session_id: str,
        last_seen: int,
        latest_seq: int | None,
        epoch: str | None,
    ) -> None:
        now = self._now()
        with self._transaction() as conn:
            conn.execute(
                "INSERT INTO cursors(connection, profile, session_id, last_seen, "
                "latest_seq, epoch, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) "
                "ON CONFLICT(connection, profile, session_id) DO UPDATE SET "
                "last_seen = excluded.last_seen, latest_seq = excluded.latest_seq, "
                "epoch = excluded.epoch, updated_at = excluded.updated_at",
                (
                    connection,
                    profile or "",
                    session_id,
                    int(last_seen),
                    latest_seq,
                    epoch,
                    now,
                ),
            )

    def _delete_orphan_cursors(self, conn: sqlite3.Connection) -> int:
        return conn.execute(
            "DELETE FROM cursors WHERE session_id NOT IN "
            "(SELECT session_id FROM executions)"
        ).rowcount

    # --- purge ----------------------------------------------------------

    def prune(
        self,
        *,
        notified_ttl_seconds: int,
        expired_ttl_seconds: int,
        deduplication_ttl_seconds: int,
        outbox_max_age_seconds: int,
    ) -> PruneResult:
        now = self._now()
        with self._transaction() as conn:
            expired = conn.execute(
                "UPDATE subscriptions SET state = 'expired', updated_at = ?, "
                "expires_at = ? WHERE state IN ('registered', 'attached') "
                "AND expires_at <= ?",
                (now, now, now),
            ).rowcount
            if expired:
                self._increment_conn(conn, "expired", expired)
            conn.execute(
                "UPDATE executions SET state = 'expired', updated_at = ? "
                "WHERE state = 'attached' AND (expires_at <= ? OR "
                "subscription_id NOT IN (SELECT subscription_id FROM subscriptions "
                "WHERE state IN ('registered', 'attached')))",
                (now, now),
            )

            subscriptions = 0
            if expired_ttl_seconds > 0:
                stale = conn.execute(
                    "DELETE FROM subscriptions WHERE state = 'expired' "
                    "AND updated_at <= ?",
                    (now - expired_ttl_seconds,),
                ).rowcount
                subscriptions += stale
            if notified_ttl_seconds > 0:
                stale = conn.execute(
                    "DELETE FROM subscriptions WHERE state = 'notified' "
                    "AND notified_at IS NOT NULL AND notified_at <= ?",
                    (now - notified_ttl_seconds,),
                ).rowcount
                subscriptions += stale
            executions = conn.execute(
                "DELETE FROM executions WHERE subscription_id NOT IN "
                "(SELECT subscription_id FROM subscriptions)"
            ).rowcount

            tombstones = 0
            if expired_ttl_seconds > 0:
                tombstones = conn.execute(
                    "DELETE FROM revocations WHERE revoked_at <= ?",
                    (now - expired_ttl_seconds,),
                ).rowcount

            dropped = 0
            if outbox_max_age_seconds > 0:
                stale = conn.execute(
                    "SELECT id, subscription_id, execution_id FROM outbox "
                    "WHERE state = 'pending' AND created_at <= ?",
                    (now - outbox_max_age_seconds,),
                ).fetchall()
                for row in stale:
                    conn.execute(
                        "UPDATE outbox SET state = 'dropped', updated_at = ?, "
                        "last_error = NULL WHERE id = ?",
                        (now, row["id"]),
                    )
                    conn.execute(
                        "UPDATE executions SET state = 'expired', updated_at = ? "
                        "WHERE subscription_id = ? AND execution_id = ?",
                        (now, row["subscription_id"], row["execution_id"]),
                    )
                    conn.execute(
                        "UPDATE subscriptions SET state = 'expired', updated_at = ?, "
                        "expires_at = ? WHERE subscription_id = ? "
                        "AND NOT EXISTS (SELECT 1 FROM executions "
                        "WHERE subscription_id = ? AND state = 'attached')",
                        (
                            now,
                            now + expired_ttl_seconds,
                            row["subscription_id"],
                            row["subscription_id"],
                        ),
                    )
                    dropped += 1
                if dropped:
                    self._increment_conn(conn, "dropped", dropped)

            dedup = 0
            if deduplication_ttl_seconds > 0:
                dedup = conn.execute(
                    "DELETE FROM deduplication WHERE last_seen_at <= ?",
                    (now - deduplication_ttl_seconds,),
                ).rowcount

            outbox = 0
            if notified_ttl_seconds > 0:
                outbox += conn.execute(
                    "DELETE FROM outbox WHERE state = 'delivered' "
                    "AND delivered_at IS NOT NULL AND delivered_at <= ?",
                    (now - notified_ttl_seconds,),
                ).rowcount
            if expired_ttl_seconds > 0:
                outbox += conn.execute(
                    "DELETE FROM outbox WHERE state = 'dropped' AND updated_at <= ?",
                    (now - expired_ttl_seconds,),
                ).rowcount

            cursors = self._delete_orphan_cursors(conn)

        return PruneResult(
            expired=expired,
            dropped=dropped,
            subscriptions=subscriptions,
            executions=executions,
            dedup=dedup,
            cursors=cursors,
            tombstones=tombstones,
            outbox=outbox,
        )

    # --- introspection (tests / diagnostic) ----------------------------

    def dedup_row(
        self, subscription_id: str, execution_id: str, terminal: str
    ) -> dict[str, Any] | None:
        row = self._read_one(
            "SELECT * FROM deduplication WHERE subscription_id = ? "
            "AND execution_id = ? AND terminal = ?",
            (subscription_id, execution_id, terminal),
        )
        return dict(row) if row else None

    def outbox_rows(self) -> list[OutboxEntry]:
        rows = self._read_all("SELECT * FROM outbox ORDER BY id")
        return [_outbox(row) for row in rows]

    def cursor_rows(self) -> list[Cursor]:
        rows = self._read_all("SELECT * FROM cursors")
        return [_cursor(row) for row in rows]

    def schema_version(self) -> int:
        row = self._read_one(
            "SELECT MAX(version) AS version FROM schema_migrations"
        )
        return int(row["version"] or 0)


def _subscription(row: sqlite3.Row) -> Subscription:
    return Subscription(
        subscription_id=row["subscription_id"],
        token_ciphertext=bytes(row["token_ciphertext"]),
        state=row["state"],
        created_at=int(row["created_at"]),
        updated_at=int(row["updated_at"]),
        expires_at=int(row["expires_at"]),
        notified_at=row["notified_at"],
    )


def _execution(row: sqlite3.Row) -> Execution:
    return Execution(
        execution_id=row["execution_id"],
        subscription_id=row["subscription_id"],
        connection=row["connection"],
        session_id=row["session_id"],
        profile=row["profile"],
        user_row_id=row["user_row_id"],
        runtime_session_id=row["runtime_session_id"],
        state=row["state"],
        created_at=int(row["created_at"]),
        updated_at=int(row["updated_at"]),
        expires_at=int(row["expires_at"]),
        delivered_at=row["delivered_at"],
    )


def _outbox(row: sqlite3.Row) -> OutboxEntry:
    return OutboxEntry(
        id=int(row["id"]),
        subscription_id=row["subscription_id"],
        execution_id=row["execution_id"],
        terminal=row["terminal"],
        state=row["state"],
        attempt=int(row["attempt"]),
        next_attempt_at=int(row["next_attempt_at"]),
        created_at=int(row["created_at"]),
        updated_at=int(row["updated_at"]),
        delivered_at=row["delivered_at"],
        last_error=row["last_error"],
    )


def _cursor(row: sqlite3.Row) -> Cursor:
    return Cursor(
        connection=row["connection"],
        profile=row["profile"],
        session_id=row["session_id"],
        last_seen=int(row["last_seen"]),
        latest_seq=row["latest_seq"],
        epoch=row["epoch"],
        updated_at=int(row["updated_at"]),
    )
