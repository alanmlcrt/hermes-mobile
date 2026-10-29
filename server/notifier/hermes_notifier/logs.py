"""Journaux ``domaine.code`` rédigés.

Les champs libres sont limités à une allowlist de valeurs non sensibles. Un
redacteur retire en plus les identifiants connus, les en-têtes
d'autorisation, les tokens et les secrets. Aucun payload, contenu ou message
Hermes n'est journalisé.
"""

from __future__ import annotations

import json
import logging
import re
import threading
from typing import Any, Final

SAFE_FIELDS: Final = frozenset(
    {
        "attempt",
        "count",
        "degraded",
        "duration_ms",
        "environment",
        "error",
        "method",
        "outcome",
        "port",
        "reason",
        "rpc_code",
        "schema_valid",
        "state",
        "status",
        "terminal",
        "version",
    }
)

_BEARER = re.compile(r"(?i)\b(bearer\s+)[A-Za-z0-9._~+/=-]+")
_AUTHORIZATION = re.compile(
    r"(?i)\b(authorization\s*[:=]\s*)[^\s,;]+"
)
_SECRET_FIELD = re.compile(
    r"(?i)(\"?(?:fcmToken|fcm_token|subscriptionId|executionId|sessionId|"
    r"session_id|profile|token|password|secret|credential|payload|content|"
    r"contenu|message|text)\"?\s*[:=]\s*)"
    r"\"[^\"]*\""
)
_LONG_OPAQUE = re.compile(
    r"\b(?=[A-Za-z0-9_-]{22,}\b)(?=[A-Za-z0-9_-]*[0-9A-Z])[A-Za-z0-9_-]+\b"
)


class Redactor:
    """Remplace les valeurs sensibles connues et les motifs à risque."""

    def __init__(self, limit: int = 4096) -> None:
        self._limit = limit
        self._values: dict[str, int] = {}
        self._counter = 0
        self._lock = threading.Lock()

    def add(self, value: object) -> None:
        if not isinstance(value, str):
            return
        value = value.strip()
        if len(value) < 3 or value in {"None", "null", "default"}:
            return
        with self._lock:
            self._counter += 1
            self._values[value] = self._counter
            if len(self._values) > self._limit:
                oldest = sorted(self._values, key=self._values.get)[: self._limit // 4]
                for key in oldest:
                    self._values.pop(key, None)

    def __len__(self) -> int:
        with self._lock:
            return len(self._values)

    def scrub(self, text: str) -> str:
        if not isinstance(text, str):
            text = str(text)
        with self._lock:
            values = sorted(self._values, key=len, reverse=True)
        for value in values:
            text = text.replace(value, "[redacted]")
        text = _BEARER.sub(r"\1[redacted]", text)
        text = _AUTHORIZATION.sub(r"\1[redacted]", text)
        text = _SECRET_FIELD.sub(r'\1"[redacted]"', text)
        # Une valeur opaque très longue qui aurait échappé aux listes connues
        # ne doit pas finir en clair. Les codes ``domaine.code`` ne sont pas
        # touchés (point et longueur).
        text = _LONG_OPAQUE.sub("[redacted]", text)
        return text


class EventLogger:
    """Façade : seuls des champs sûrs et un code ``domaine.code``."""

    def __init__(self, redactor: Redactor, logger: logging.Logger | None = None) -> None:
        self.redactor = redactor
        self._logger = logger or logging.getLogger("hermes_notifier")

    def debug(self, code: str, **fields: Any) -> None:
        self._emit(logging.DEBUG, code, fields)

    def info(self, code: str, **fields: Any) -> None:
        self._emit(logging.INFO, code, fields)

    def warning(self, code: str, **fields: Any) -> None:
        self._emit(logging.WARNING, code, fields)

    def error(self, code: str, **fields: Any) -> None:
        self._emit(logging.ERROR, code, fields)

    def exception_code(self, code: str, error: BaseException, **fields: Any) -> None:
        """Ne journalise que le nom de la classe, jamais le message."""

        self._emit(
            logging.WARNING,
            code,
            {**fields, "error": type(error).__name__},
        )

    def _emit(self, level: int, code: str, fields: dict[str, Any]) -> None:
        safe = {
            key: value
            for key, value in fields.items()
            if key in SAFE_FIELDS and isinstance(value, (str, int, float, bool))
        }
        message = code
        if safe:
            message += " " + json.dumps(safe, sort_keys=True, separators=(",", ":"))
        self._logger.log(level, self.redactor.scrub(message))


def configure_logging(level: str, redactor: Redactor) -> EventLogger:
    logger = logging.getLogger("hermes_notifier")
    logger.handlers.clear()
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    logger.propagate = False
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(levelname)s %(message)s"))
    logger.addHandler(handler)
    return EventLogger(redactor, logger)


def capture_logger(redactor: Redactor) -> tuple[EventLogger, list[str]]:
    """Utilitaire de test : capture les messages sans les écrire."""

    messages: list[str] = []

    class _Capture(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:
            messages.append(record.getMessage())

    logger = logging.getLogger("hermes_notifier.capture")
    logger.handlers.clear()
    logger.setLevel(logging.DEBUG)
    logger.propagate = False
    logger.addHandler(_Capture())
    return EventLogger(redactor, logger), messages
