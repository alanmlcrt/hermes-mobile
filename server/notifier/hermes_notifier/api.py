"""API HTTP du contrat : quatre routes, bearer, erreurs bornées.

Aucune route, aucun chemin et aucun identifiant n'est journalisé. Le serveur
n'écoute que dans le conteneur ; aucun port hôte n'est publié par l'add-on.
"""

from __future__ import annotations

import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Callable, Mapping
from urllib.parse import unquote, urlsplit

from .config import Config
from .contracts import Contracts
from .credential import BearerCredential, CredentialError, TokenCipher
from .errors import (
    NotifierError,
    InvalidRequest,
    NotFound,
    RateLimited,
    StorageError,
    Unauthorized,
    error_body,
)
from .health import HealthState
from .logs import EventLogger, Redactor
from .store import Store

MAX_REQUEST_BYTES = 16 * 1024
MAX_TOKEN_BYTES = 4096
MAX_SESSION_BYTES = 512


class RateLimiter:
    """Fenêtre fixe d'une minute, sans dépendance ni stockage."""

    def __init__(
        self,
        limit: int,
        *,
        window_seconds: float = 60.0,
        now: Callable[[], float] | None = None,
    ) -> None:
        self.limit = max(1, int(limit))
        self.window_seconds = float(window_seconds)
        self._now = now or time.monotonic
        self._lock = threading.Lock()
        self._start = self._now()
        self._count = 0

    def allow(self) -> tuple[bool, int]:
        now = self._now()
        with self._lock:
            if now - self._start >= self.window_seconds:
                self._start = now
                self._count = 0
            if self._count >= self.limit:
                retry = max(1, int(self.window_seconds - (now - self._start)))
                return False, retry
            self._count += 1
            return True, 0


class NotificationApi:
    def __init__(
        self,
        config: Config,
        contracts: Contracts,
        store: Store,
        cipher: TokenCipher,
        credential: BearerCredential,
        health: HealthState,
        logger: EventLogger,
        *,
        redactor: Redactor | None = None,
        on_attach: Callable[[], None] | None = None,
        limiter: RateLimiter | None = None,
    ) -> None:
        self.config = config
        self.contracts = contracts
        self.store = store
        self.cipher = cipher
        self.credential = credential
        self.health = health
        self.logger = logger
        self.redactor = redactor
        self.on_attach = on_attach
        self.limiter = limiter or RateLimiter(config.rate_limit_per_minute)
        self._server: ThreadingHTTPServer | None = None
        self._thread: threading.Thread | None = None

    # --- cycle de vie ---------------------------------------------------

    def create_server(self) -> ThreadingHTTPServer:
        api = self

        class _Server(ThreadingHTTPServer):
            daemon_threads = True
            allow_reuse_address = True

            def __init__(self, address: tuple[str, int]) -> None:
                super().__init__(address, _Handler)
                self.api = api

        self._server = _Server((self.config.bind, self.config.port))
        return self._server

    @property
    def port(self) -> int:
        if self._server is None:
            return self.config.port
        return int(self._server.server_address[1])

    def start(self) -> None:
        if self._server is None:
            self.create_server()
        assert self._server is not None
        self._thread = threading.Thread(
            target=self._server.serve_forever,
            kwargs={"poll_interval": 0.2},
            name="notifier-api",
            daemon=True,
        )
        self._thread.start()

    def stop(self, timeout: float = 5.0) -> None:
        server = self._server
        thread = self._thread
        if server is not None:
            if thread is not None and thread.is_alive():
                # ``shutdown`` attend ``serve_forever`` ; l'appeler sans
                # thread démarré bloquerait indéfiniment.
                server.shutdown()
            server.server_close()
        if thread is not None:
            thread.join(timeout)
        self._thread = None
        self._server = None

    def error_body(self, error: NotifierError) -> dict[str, str]:
        """Corps borné aux sept codes du contrat, sans fuite interne."""

        code = error.code
        if code not in self.contracts.error_codes:
            code = {
                400: "invalid-request",
                401: "unauthorized",
                404: "not-found",
                410: "gone",
                429: "rate-limited",
                503: "unavailable",
            }.get(error.status, "internal")
        return {"code": code, "message": error.message}

    # --- routes ---------------------------------------------------------

    def handle_health(self) -> tuple[int, dict[str, Any]]:
        return 200, self.health.snapshot(self.store)

    def handle_register(self, body: Mapping[str, Any]) -> tuple[int, dict[str, Any]]:
        _only_keys(body, {"subscriptionId", "fcmToken"})
        subscription_id = body.get("subscriptionId")
        token = body.get("fcmToken")
        if not self.contracts.valid_subscription_id(subscription_id):
            raise InvalidRequest()
        if not _valid_token(token):
            raise InvalidRequest()
        if self.redactor is not None:
            self.redactor.add(subscription_id)
            self.redactor.add(token)
        try:
            ciphertext = self.cipher.encrypt(token)
        except CredentialError as exc:
            raise StorageError() from exc
        created = self.store.register(
            subscription_id,
            ciphertext,
            ttl_seconds=self.contracts.registered_ttl_seconds,
        )
        return (201 if created else 200), {"state": "registered"}

    def handle_attach(
        self, subscription_id: str, body: Mapping[str, Any]
    ) -> tuple[int, dict[str, Any]]:
        _only_keys(body, {"sessionId", "profile", "executionId"})
        session_id = body.get("sessionId")
        execution_id = body.get("executionId")
        profile_value = body.get("profile")
        if not _valid_session(session_id) or not isinstance(execution_id, str):
            raise InvalidRequest()
        if profile_value is not None and not isinstance(profile_value, str):
            raise InvalidRequest()
        if not self.contracts.valid_subscription_id(subscription_id):
            raise InvalidRequest()
        try:
            row = self.contracts.execution_row(execution_id, session_id)
        except ValueError as exc:
            raise InvalidRequest() from exc
        if self.contracts.execution_id(session_id, row) != execution_id:
            raise InvalidRequest()
        profile = self.config.resolve_profile(profile_value) or ""
        if self.redactor is not None:
            self.redactor.add(subscription_id)
            self.redactor.add(session_id)
            self.redactor.add(execution_id)
            if profile:
                self.redactor.add(profile)
        state = self.store.attach(
            subscription_id,
            connection=self.config.hermes_origin,
            session_id=session_id,
            profile=profile,
            execution_id=execution_id,
            user_row_id=row,
            ttl_seconds=self.contracts.attached_ttl_seconds,
        )
        if self.on_attach is not None:
            self.on_attach()
        return (202 if state == "created" else 200), {"state": "attached"}

    def handle_revoke(self, subscription_id: str) -> tuple[int, None]:
        if not self.contracts.valid_subscription_id(subscription_id):
            raise InvalidRequest()
        if self.redactor is not None:
            self.redactor.add(subscription_id)
        self.store.revoke(subscription_id)
        return 204, None


class _Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "hermes-notifier"
    sys_version = ""

    @property
    def api(self) -> NotificationApi:
        return self.server.api  # type: ignore[attr-defined]

    # --- méthodes HTTP (toutes routées, aucune 501 HTML) ----------------

    def do_GET(self) -> None:
        self._dispatch("GET")

    def do_POST(self) -> None:
        self._dispatch("POST")

    def do_DELETE(self) -> None:
        self._dispatch("DELETE")

    def do_PUT(self) -> None:
        self._dispatch("PUT")

    def do_PATCH(self) -> None:
        self._dispatch("PATCH")

    def do_OPTIONS(self) -> None:
        self._dispatch("OPTIONS")

    def do_HEAD(self) -> None:
        self._dispatch("HEAD", head=True)

    def _dispatch(self, method: str, *, head: bool = False) -> None:
        api = self.api
        try:
            if not api.credential.verify_header(
                self.headers.get("Authorization")
            ):
                self._send(
                    401,
                    api.error_body(Unauthorized()),
                    head=head,
                    extra_headers={"WWW-Authenticate": "Bearer"},
                )
                api.logger.warning(
                    "api.refused",
                    method=method,
                    status=401,
                    reason="unauthorized",
                )
                return
            allowed, retry_after = api.limiter.allow()
            if not allowed:
                self._send(
                    429,
                    api.error_body(RateLimited()),
                    head=head,
                    extra_headers={"Retry-After": str(retry_after)},
                )
                api.logger.warning(
                    "api.refused",
                    method=method,
                    status=429,
                    reason="rate-limited",
                )
                return
            status, body = self._route(method)
            self._send(status, body, head=head)
            api.logger.info("api.request", method=method, status=status)
        except NotifierError as error:
            if isinstance(error, StorageError):
                api.health.record_storage_error()
                api.logger.error("storage.error", reason="api")
            status = error.status
            self._send(status, api.error_body(error), head=head)
            api.logger.warning(
                "api.refused", method=method, status=status, reason=error.code
            )
        except Exception as error:  # pragma: no cover - garde-fou
            api.logger.exception_code("api.error", error)
            self._send(500, api.error_body(NotifierError("internal")), head=head)

    def _route(self, method: str) -> tuple[int, Any]:
        api = self.api
        path = urlsplit(self.path).path
        segments = [segment for segment in path.split("/") if segment]
        if method == "GET" and segments == ["v1", "health"]:
            return api.handle_health()
        if method == "POST" and segments == ["v1", "subscriptions"]:
            return api.handle_register(self._read_json())
        if (
            method == "POST"
            and len(segments) == 4
            and segments[:2] == ["v1", "subscriptions"]
            and segments[3] == "attach"
        ):
            return api.handle_attach(unquote(segments[2]), self._read_json())
        if (
            method == "DELETE"
            and len(segments) == 3
            and segments[:2] == ["v1", "subscriptions"]
        ):
            return api.handle_revoke(unquote(segments[2]))
        raise NotFound()

    # --- entrées/sorties ------------------------------------------------

    def _read_json(self) -> Mapping[str, Any]:
        if self.headers.get("Transfer-Encoding"):
            raise InvalidRequest()
        length_header = self.headers.get("Content-Length")
        if length_header is None:
            raise InvalidRequest()
        try:
            length = int(length_header)
        except ValueError as exc:
            raise InvalidRequest() from exc
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise InvalidRequest()
        raw = self.rfile.read(length)
        if len(raw) != length:
            raise InvalidRequest()
        try:
            body = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise InvalidRequest() from exc
        if not isinstance(body, dict):
            raise InvalidRequest()
        return body

    def _send(
        self,
        status: int,
        body: Any = None,
        *,
        head: bool = False,
        extra_headers: Mapping[str, str] | None = None,
    ) -> None:
        payload = b""
        if body is not None:
            payload = json.dumps(
                body, separators=(",", ":"), ensure_ascii=False
            ).encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            if body is not None:
                self.send_header(
                    "Content-Type", "application/json; charset=utf-8"
                )
            if status not in {204, 304}:
                self.send_header("Content-Length", str(len(payload)))
            for name, value in (extra_headers or {}).items():
                self.send_header(name, value)
            self.end_headers()
            if payload and not head:
                self.wfile.write(payload)
        except OSError:
            # Déconnexion du client : une seconde réponse 500 ne doit pas
            # être tentée sur un socket déjà fermé.
            pass
        finally:
            self.close_connection = True

    def send_error(
        self,
        code: int,
        message: str | None = None,
        explain: str | None = None,
    ) -> None:
        if code in {404, 405, 501}:
            error: NotifierError = NotFound()
            status = 404
        else:
            error = InvalidRequest()
            status = 400
        try:
            self._send(status, self.api.error_body(error))
        except OSError:
            pass

    def log_message(self, format: str, *args: Any) -> None:
        return

    def log_request(self, code: int | str = "-", size: int | str = "-") -> None:
        return

    def log_error(self, format: str, *args: Any) -> None:
        return


def _only_keys(body: Mapping[str, Any], allowed: set[str]) -> None:
    if set(body) - allowed:
        raise InvalidRequest()


def _valid_token(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    if len(value.encode("utf-8")) > MAX_TOKEN_BYTES:
        return False
    return not any(character.isspace() or ord(character) < 32 for character in value)


def _valid_session(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    if len(value.encode("utf-8")) > MAX_SESSION_BYTES:
        return False
    return not any(ord(character) < 32 for character in value)
