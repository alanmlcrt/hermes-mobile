"""Outils de test : faux Hermes HTTP+WS sur une seule origine.

Le proxy TCP démultiplexe ``/api/ws`` vers le serveur WebSocket et le reste
vers le serveur REST. L'observateur utilise donc exactement le même chemin
qu'en production, sans port séparé ni adaptation de test.
"""

from __future__ import annotations

import asyncio
import base64
import http.client
import json
import os
import socket
import socketserver
import threading
import time
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable, Mapping
from urllib.parse import urlsplit

from websockets.asyncio.server import serve

from hermes_notifier.config import Config
from hermes_notifier.contracts import Contracts
from hermes_notifier.credential import compute_hash, generate_salt, generate_token

VENDOR = Path(__file__).resolve().parents[1] / "vendor" / "contracts"
GATEWAY_PROTOCOL = "hermes-gateway-v1"


def contracts() -> Contracts:
    return Contracts.load(VENDOR)


@dataclass
class SessionState:
    session_id: str
    events: list[dict[str, Any]] = field(default_factory=list)
    latest_seq: int = 0
    truncated: bool = False
    resume_error: bool | int = False
    omit_error: bool = False
    since_error: int | None = None
    invalid_since: bool = False


@dataclass
class _Connection:
    websocket: Any
    session_id: str | None = None


class FakeHermes:
    def __init__(self, *, password: str = "secret", epoch: str = "epoch-1") -> None:
        self.password = password
        self.epoch = epoch
        self.sessions: dict[str, SessionState] = {}
        self.access_tokens: set[str] = set()
        self.refresh_tokens: set[str] = set()
        self.tickets: set[str] = set()
        self.lock = threading.RLock()
        self.rest_calls: list[tuple[str, str]] = []
        self.ws_handshakes = 0
        self.resume_calls: list[dict[str, Any]] = []
        self.since_calls: list[dict[str, Any]] = []
        self.history_calls: list[dict[str, Any]] = []
        self.login_calls = 0
        self._counter = 0
        self._connections: list[_Connection] = []
        self._ws_ready = threading.Event()
        self._ws_loop: asyncio.AbstractEventLoop | None = None
        self._ws_stop: asyncio.Event | None = None
        self._ws_thread: threading.Thread | None = None
        self._ws_port = 0
        self._rest_server: ThreadingHTTPServer | None = None
        self._rest_thread: threading.Thread | None = None
        self._rest_port = 0
        self._proxy: _ProxyServer | None = None
        self._proxy_thread: threading.Thread | None = None
        self.port = 0

    # --- cycle de vie ---------------------------------------------------

    def start(self) -> "FakeHermes":
        self._start_rest()
        self._start_ws()
        self._start_proxy()
        return self

    def stop(self) -> None:
        if self._proxy is not None:
            self._proxy.shutdown()
            self._proxy.server_close()
            self._proxy = None
        if self._proxy_thread is not None:
            self._proxy_thread.join(5)
            self._proxy_thread = None
        if self._rest_server is not None:
            self._rest_server.shutdown()
            self._rest_server.server_close()
            self._rest_server = None
        if self._rest_thread is not None:
            self._rest_thread.join(5)
            self._rest_thread = None
        loop = self._ws_loop
        stop = self._ws_stop
        if loop is not None and stop is not None:
            try:
                loop.call_soon_threadsafe(stop.set)
            except RuntimeError:
                pass
        if self._ws_thread is not None:
            self._ws_thread.join(5)
            self._ws_thread = None
        self._ws_loop = None

    def __enter__(self) -> "FakeHermes":
        return self.start()

    def __exit__(self, *_: Any) -> None:
        self.stop()

    @property
    def origin(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    # --- serveur REST ---------------------------------------------------

    def _start_rest(self) -> None:
        state = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            server_version = "fake-hermes"
            sys_version = ""

            def log_message(self, format: str, *args: Any) -> None:
                return

            def do_POST(self) -> None:
                self._handle("POST")

            def do_GET(self) -> None:
                self._handle("GET")

            def _handle(self, method: str) -> None:
                state._rest_call(method, self.path)
                length = int(self.headers.get("Content-Length") or 0)
                raw = self.rfile.read(length) if length else b""
                try:
                    body = json.loads(raw.decode("utf-8")) if raw else {}
                except (UnicodeDecodeError, json.JSONDecodeError):
                    self._json(400, {"error": "invalid"})
                    return
                path = urlsplit(self.path).path
                if path == "/auth/password-login" and method == "POST":
                    state.login_calls += 1
                    if (
                        body.get("provider") == "basic"
                        and body.get("username") == "hermes"
                        and body.get("password") == state.password
                    ):
                        access, refresh = state._issue_tokens()
                        self._json(
                            200,
                            {"ok": True},
                            cookies=[
                                f"hermes_session_at={access}; Path=/; HttpOnly",
                                f"hermes_session_rt={refresh}; Path=/; HttpOnly",
                            ],
                        )
                    else:
                        self._json(401, {"error": "auth"})
                    return
                if path == "/auth/native/refresh" and method == "POST":
                    refresh = body.get("refresh_token")
                    if isinstance(refresh, str) and state._refresh(refresh):
                        access, renewed = state._issue_tokens()
                        self._json(
                            200,
                            {"access_token": access, "refresh_token": renewed},
                        )
                    else:
                        self._json(401, {"error": "auth"})
                    return
                bearer = state._bearer(self.headers.get("Authorization"))
                if bearer is None:
                    self._json(401, {"error": "auth"})
                    return
                if path == "/api/profiles" and method == "GET":
                    self._json(
                        200,
                        {
                            "profiles": [
                                {
                                    "name": "default",
                                    "display_name": "Default",
                                    "is_default": True,
                                }
                            ]
                        },
                    )
                    return
                if path == "/api/auth/ws-ticket" and method == "POST":
                    ticket = state._ticket()
                    self._json(200, {"ticket": ticket})
                    return
                self._json(404, {"error": "missing"})

            def _json(
                self,
                status: int,
                body: Mapping[str, Any],
                *,
                cookies: list[str] | None = None,
            ) -> None:
                payload = json.dumps(body).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Connection", "close")
                for cookie in cookies or []:
                    self.send_header("Set-Cookie", cookie)
                self.end_headers()
                self.wfile.write(payload)
                self.close_connection = True

        self._rest_server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self._rest_server.daemon_threads = True
        self._rest_port = int(self._rest_server.server_address[1])
        self._rest_thread = threading.Thread(
            target=self._rest_server.serve_forever,
            kwargs={"poll_interval": 0.1},
            daemon=True,
        )
        self._rest_thread.start()

    def _rest_call(self, method: str, path: str) -> None:
        with self.lock:
            self.rest_calls.append((method, path))

    def _bearer(self, header: str | None) -> str | None:
        if not header or not header.startswith("Bearer "):
            return None
        token = header[7:].strip()
        with self.lock:
            return token if token in self.access_tokens else None

    def _issue_tokens(self) -> tuple[str, str]:
        with self.lock:
            self._counter += 1
            access = f"access-{self._counter}"
            refresh = f"refresh-{self._counter}"
            self.access_tokens.add(access)
            self.refresh_tokens.add(refresh)
            return access, refresh

    def _refresh(self, refresh: str) -> bool:
        with self.lock:
            if refresh not in self.refresh_tokens:
                return False
            self.refresh_tokens.discard(refresh)
            return True

    def _ticket(self) -> str:
        with self.lock:
            self._counter += 1
            ticket = f"ticket-{self._counter}"
            self.tickets.add(ticket)
            return ticket

    # --- serveur WebSocket ---------------------------------------------

    def _start_ws(self) -> None:
        thread = threading.Thread(target=self._run_ws, daemon=True)
        self._ws_thread = thread
        thread.start()
        if not self._ws_ready.wait(5):
            raise RuntimeError("fake hermes ws did not start")

    def _run_ws(self) -> None:
        loop = asyncio.new_event_loop()
        self._ws_loop = loop
        asyncio.set_event_loop(loop)

        async def runner() -> None:
            stop = asyncio.Event()
            self._ws_stop = stop
            async with serve(
                self._ws_handler,
                "127.0.0.1",
                0,
                subprotocols=[GATEWAY_PROTOCOL],
                ping_interval=None,
                max_size=2 * 1024 * 1024,
            ) as server:
                self._ws_port = int(server.sockets[0].getsockname()[1])
                self._ws_ready.set()
                await stop.wait()

        try:
            loop.run_until_complete(runner())
        finally:
            try:
                loop.run_until_complete(loop.shutdown_asyncgens())
            except Exception:
                pass
            loop.close()

    async def _ws_handler(self, websocket: Any) -> None:
        with self.lock:
            self.ws_handshakes += 1
            protocols = websocket.request.headers.get_all("Sec-WebSocket-Protocol")
            ticket_ok = False
            for header in protocols:
                for value in header.split(","):
                    value = value.strip()
                    if value.startswith("hermes-gateway-ticket."):
                        ticket = value.split(".", 1)[1]
                        ticket_ok = ticket in self.tickets
            connection = _Connection(websocket=websocket)
        if not ticket_ok:
            await websocket.close(code=4001, reason="ticket")
            return
        with self.lock:
            self._connections.append(connection)
        try:
            await websocket.send(
                _event_frame(
                    {
                        "type": "gateway.ready",
                        "payload": {
                            "replay_epoch": self.epoch,
                            "change_events": True,
                            "heartbeat": True,
                            "session_authority": False,
                        },
                    }
                )
            )
            async for raw in websocket:
                try:
                    message = json.loads(raw)
                except (TypeError, ValueError):
                    continue
                if not isinstance(message, dict):
                    continue
                identifier = message.get("id")
                method = message.get("method")
                params = message.get("params")
                if not isinstance(identifier, str) or not isinstance(method, str):
                    continue
                if not isinstance(params, dict):
                    params = {}
                if method == "gateway.capabilities":
                    await websocket.send(
                        _result_frame(identifier, {"ok": True})
                    )
                    continue
                if method == "session.resume":
                    await self._resume(websocket, connection, identifier, params)
                    continue
                if method == "session.history":
                    await self._history(websocket, identifier, params)
                    continue
                if method == "session.events.since":
                    await self._since(websocket, identifier, params)
                    continue
                await websocket.send(
                    _error_frame(identifier, -32601)
                )
        except Exception:
            pass
        finally:
            with self.lock:
                self._connections = [
                    item for item in self._connections if item is not connection
                ]

    async def _resume(
        self,
        websocket: Any,
        connection: _Connection,
        identifier: str,
        params: Mapping[str, Any],
    ) -> None:
        session_id = params.get("session_id")
        with self.lock:
            self.resume_calls.append(dict(params))
            session = self.sessions.get(session_id) if isinstance(session_id, str) else None
            omit = params.get("omit_messages") is True
            if session is None:
                error = -32004
            elif session.resume_error:
                # ``True`` : code du contrat ; un entier : code réel du gateway.
                error = (
                    -32004 if session.resume_error is True else session.resume_error
                )
            elif omit and session.omit_error:
                error = -32602
            else:
                error = None
                connection.session_id = session_id
        if error is not None:
            await websocket.send(_error_frame(identifier, error))
            return
        await websocket.send(
            _result_frame(
                identifier,
                {
                    "session_id": session_id,
                    "message_count": 0,
                    "messages": [],
                    "info": {},
                    "running": True,
                    "messages_omitted": omit,
                },
            )
        )

    async def _history(
        self, websocket: Any, identifier: str, params: Mapping[str, Any]
    ) -> None:
        with self.lock:
            self.history_calls.append(dict(params))
            session = self.sessions.get(params.get("session_id"))
            count = len(session.events) if session is not None else 0
        await websocket.send(
            _result_frame(identifier, {"count": count, "messages": []})
        )

    async def _since(
        self, websocket: Any, identifier: str, params: Mapping[str, Any]
    ) -> None:
        session_id = params.get("session_id")
        last_seen = params.get("last_seen")
        with self.lock:
            self.since_calls.append(dict(params))
            session = self.sessions.get(session_id)
            if session is not None and session.since_error is not None:
                error_code = session.since_error
            else:
                error_code = None
            if session is not None and session.invalid_since:
                invalid = True
            else:
                invalid = False
            if session is None:
                events: list[dict[str, Any]] = []
                latest = 0
                truncated = False
                epoch = self.epoch
            else:
                if last_seen is None:
                    events = list(session.events)
                else:
                    events = [
                        event
                        for event in session.events
                        if int(event["seq"]) > int(last_seen)
                    ]
                latest = session.latest_seq
                truncated = session.truncated
                epoch = self.epoch
        if error_code is not None:
            await websocket.send(_error_frame(identifier, error_code))
            return
        if invalid:
            await websocket.send(_result_frame(identifier, {"events": "bad"}))
            return
        await websocket.send(
            _result_frame(
                identifier,
                {
                    "events": events,
                    "latest_seq": latest,
                    "truncated": truncated,
                    "count": len(events),
                    "epoch": epoch,
                    "open_requests": [],
                },
            )
        )

    # --- contrôle des tests --------------------------------------------

    def add_session(
        self,
        session_id: str,
        *,
        truncated: bool = False,
        resume_error: bool | int = False,
        omit_error: bool = False,
        since_error: int | None = None,
        invalid_since: bool = False,
    ) -> SessionState:
        with self.lock:
            session = SessionState(
                session_id=session_id,
                truncated=truncated,
                resume_error=resume_error,
                omit_error=omit_error,
                since_error=since_error,
                invalid_since=invalid_since,
            )
            self.sessions[session_id] = session
            return session

    def add_event(
        self,
        session_id: str,
        event_type: str,
        payload: Mapping[str, Any] | None = None,
        *,
        broadcast: bool = False,
    ) -> dict[str, Any]:
        with self.lock:
            session = self.sessions[session_id]
            session.latest_seq += 1
            event = {
                "type": event_type,
                "session_id": session_id,
                "payload": dict(payload or {}),
                "seq": session.latest_seq,
            }
            session.events.append(event)
            targets = [
                connection
                for connection in self._connections
                if connection.session_id == session_id
            ]
        if broadcast:
            for connection in targets:
                loop = self._ws_loop
                if loop is not None:
                    asyncio.run_coroutine_threadsafe(
                        connection.websocket.send(_event_frame(event)), loop
                    )
        return event

    def emit(
        self,
        session_id: str,
        event_type: str,
        payload: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        return self.add_event(session_id, event_type, payload, broadcast=True)

    def set_epoch(self, epoch: str) -> None:
        with self.lock:
            self.epoch = epoch

    def wait(self, predicate: Callable[[], bool], timeout: float = 5.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.02)
        return predicate()

    def wait_resumed(self, session_id: str, timeout: float = 5.0) -> bool:
        return self.wait(
            lambda: any(
                call.get("session_id") == session_id
                for call in self.resume_calls
            ),
            timeout,
        )

    def wait_since(self, count: int = 1, timeout: float = 5.0) -> bool:
        return self.wait(lambda: len(self.since_calls) >= count, timeout)

    # --- proxy ----------------------------------------------------------

    def _start_proxy(self) -> None:
        state = self

        class Handler(socketserver.BaseRequestHandler):
            def handle(self) -> None:
                first = self.request.recv(8192, socket.MSG_PEEK)
                if not first:
                    return
                line = first.split(b"\r\n", 1)[0]
                upstream_port = (
                    state._ws_port
                    if b"/api/ws " in line or b"/api/ws?" in line
                    else state._rest_port
                )
                try:
                    upstream = socket.create_connection(
                        ("127.0.0.1", upstream_port), timeout=5
                    )
                except OSError:
                    return
                def pump(source: Any, target: Any) -> None:
                    try:
                        while True:
                            chunk = source.recv(65536)
                            if not chunk:
                                break
                            target.sendall(chunk)
                    except OSError:
                        pass
                    finally:
                        try:
                            target.shutdown(socket.SHUT_WR)
                        except OSError:
                            pass

                to_upstream = threading.Thread(
                    target=pump,
                    args=(self.request, upstream),
                    daemon=True,
                )
                to_upstream.start()
                pump(upstream, self.request)
                to_upstream.join(5)
                try:
                    upstream.close()
                except OSError:
                    pass

        class Proxy(socketserver.ThreadingTCPServer):
            daemon_threads = True
            allow_reuse_address = True

        self._proxy = Proxy(("127.0.0.1", 0), Handler)
        self.port = int(self._proxy.server_address[1])
        self._proxy_thread = threading.Thread(
            target=self._proxy.serve_forever,
            kwargs={"poll_interval": 0.1},
            daemon=True,
        )
        self._proxy_thread.start()


def _event_frame(event: Mapping[str, Any]) -> str:
    return json.dumps(
        {
            "jsonrpc": "2.0",
            "method": "event",
            "params": event,
        },
        separators=(",", ":"),
    )


def _result_frame(identifier: str, result: Mapping[str, Any]) -> str:
    return json.dumps(
        {"jsonrpc": "2.0", "id": identifier, "result": result},
        separators=(",", ":"),
    )


def _error_frame(identifier: str, code: int) -> str:
    return json.dumps(
        {
            "jsonrpc": "2.0",
            "id": identifier,
            "error": {"code": code, "message": "fake"},
        },
        separators=(",", ":"),
    )


def make_config(
    data_dir: Path,
    origin: str,
    *,
    environment: str = "integration",
    port: int = 0,
    fcm_enabled: bool = False,
    fcm_service_account: str | None = None,
    rate_limit: int = 120,
) -> tuple[Config, str]:
    token = generate_token()
    salt = generate_salt()
    digest = compute_hash(token, salt)
    options = {
        "environment": environment,
        "hermes_origin": origin,
        "hermes_username": "hermes",
        "hermes_password": "secret",
        "hermes_profile": "default",
        "bearer_hash": digest,
        "bearer_salt": salt,
        "fcm_enabled": fcm_enabled,
        "fcm_service_account": fcm_service_account,
        "log_level": "debug",
        "rate_limit_per_minute": rate_limit,
    }
    environ = {
        "HERMES_NOTIFIER_DATA_DIR": str(data_dir),
        "HERMES_NOTIFIER_PORT": str(port),
    }
    return Config.load(options=options, environ=environ), token


def subscription_id(seed: str = "subscription") -> str:
    raw = base64.urlsafe_b64encode(seed.encode("utf-8")).rstrip(b"=")
    value = raw.decode("ascii")
    while len(value) < 22:
        value += "A"
    return value[:128]


def execution_id(session_id: str, row: int) -> str:
    raw = f"{session_id}:{row}".encode("utf-8")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def http_request(
    origin: str,
    method: str,
    path: str,
    *,
    token: str | None = None,
    body: Mapping[str, Any] | None = None,
    headers: Mapping[str, str] | None = None,
) -> tuple[int, dict[str, str], bytes]:
    parsed = urlsplit(origin)
    connection = http.client.HTTPConnection(
        parsed.hostname or "127.0.0.1", parsed.port, timeout=5
    )
    request_headers = dict(headers or {})
    if token is not None:
        request_headers["Authorization"] = f"Bearer {token}"
    payload = None
    if body is not None:
        payload = json.dumps(body).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/json")
    try:
        connection.request(method, path, body=payload, headers=request_headers)
        response = connection.getresponse()
        data = response.read()
        return (
            response.status,
            {key.lower(): value for key, value in response.getheaders()},
            data,
        )
    finally:
        connection.close()
