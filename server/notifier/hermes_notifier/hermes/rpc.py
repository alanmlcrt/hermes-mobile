"""Dialecte Hermes en lecture seule : REST d'authentification et JSON-RPC WS.

Reproduit le dialecte de ``lib/data/hermes_adapter.dart`` sans l'importer :
login ``password-login``, refresh natif, ticket WS et sous-protocoles
``hermes-gateway-v1`` / ``hermes-gateway-ticket.<ticket>``. Aucune redirection
n'est suivie et aucun corps d'erreur n'est interprété ou journalisé.
"""

from __future__ import annotations

import asyncio
import http.client
import json
import ssl
from dataclasses import dataclass
from typing import Any, Mapping
from urllib.parse import urlsplit, urlunsplit

from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed, InvalidHandshake, WebSocketException

from ..contracts import Contracts
from ..errors import NotifierError
from ..logs import EventLogger

MAX_BODY_BYTES = 1024 * 1024
GATEWAY_PROTOCOL = "hermes-gateway-v1"


class HermesError(NotifierError):
    code = "hermes.error"
    status = 503
    message = "Hermes indisponible."

    def __init__(
        self,
        code: str | None = None,
        *,
        retryable: bool = True,
        rpc_code: int | str | None = None,
    ) -> None:
        super().__init__(code)
        self.retryable = retryable
        self.rpc_code = rpc_code


class HermesAuthError(HermesError):
    code = "hermes.auth"
    status = 503
    message = "Authentification Hermes refusée."

    def __init__(self) -> None:
        super().__init__(self.code, retryable=False)


class HermesNotFoundError(HermesError):
    code = "hermes.not_found"
    status = 404
    message = "Méthode Hermes absente."

    def __init__(self) -> None:
        super().__init__(self.code, retryable=False)


class HermesProtocolError(HermesError):
    code = "hermes.protocol"
    status = 502
    message = "Réponse Hermes invalide."

    def __init__(self, code: str | None = None) -> None:
        super().__init__(code or self.code, retryable=False)


class HermesRpcError(HermesError):
    code = "hermes.rpc_error"
    status = 502
    message = "Erreur Hermes."

    def __init__(self, rpc_code: int | str | None) -> None:
        super().__init__(self.code, retryable=False, rpc_code=rpc_code)


@dataclass(frozen=True)
class AuthTokens:
    access: str
    refresh: str | None


@dataclass(frozen=True)
class ProfileInfo:
    name: str
    label: str
    is_default: bool


class HermesRest:
    """Client REST minimal, sans redirection ni conservation des erreurs."""

    def __init__(
        self,
        origin: str,
        *,
        contracts: Contracts,
        timeout: float = 15.0,
    ) -> None:
        self.origin = origin
        self.contracts = contracts
        self.timeout = timeout
        parsed = urlsplit(origin)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname:
            raise HermesProtocolError("hermes.origin")
        self._scheme = parsed.scheme
        self._host = parsed.hostname
        self._port = parsed.port
        self._base_path = parsed.path.rstrip("/") or ""

    # --- transport ------------------------------------------------------

    def _connection(self) -> http.client.HTTPConnection:
        if self._scheme == "https":
            return http.client.HTTPSConnection(
                self._host,
                self._port,
                timeout=self.timeout,
                context=ssl.create_default_context(),
            )
        return http.client.HTTPConnection(
            self._host, self._port, timeout=self.timeout
        )

    def _path(self, endpoint: str) -> str:
        return f"{self._base_path}{endpoint}" if self._base_path else endpoint

    def request(
        self,
        method: str,
        endpoint: str,
        *,
        body: Mapping[str, Any] | None = None,
        bearer: str | None = None,
    ) -> dict[str, Any]:
        route = f"{method} {endpoint}"
        if route not in self.contracts.allowed_rest:
            raise HermesProtocolError("hermes.rest_forbidden")

        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Connection": "close",
        }
        if bearer is not None:
            headers["Authorization"] = f"Bearer {bearer}"
        payload = (
            json.dumps(body, separators=(",", ":")).encode("utf-8")
            if body is not None
            else None
        )

        connection = self._connection()
        try:
            connection.request(
                method,
                self._path(endpoint),
                body=payload,
                headers=headers,
            )
            response = connection.getresponse()
            data = response.read(MAX_BODY_BYTES + 1)
            status = response.status
        except (OSError, http.client.HTTPException, ssl.SSLError) as exc:
            raise HermesError("hermes.unreachable", retryable=True) from exc
        finally:
            try:
                connection.close()
            except OSError:  # pragma: no cover - fermeture best effort
                pass

        if len(data) > MAX_BODY_BYTES:
            raise HermesProtocolError("hermes.body_too_large")
        if status in {301, 302, 303, 307, 308}:
            raise HermesError("hermes.redirect", retryable=False)
        if status in {401, 403}:
            raise HermesAuthError()
        if status in {404, 405, 501}:
            raise HermesNotFoundError()
        if status == 429:
            raise HermesError("hermes.rate_limited", retryable=True)
        if status >= 500:
            raise HermesError("hermes.server", retryable=True)
        if status != 200:
            raise HermesError("hermes.status", retryable=False)

        try:
            decoded = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HermesProtocolError("hermes.invalid_json") from exc
        if not isinstance(decoded, dict):
            raise HermesProtocolError("hermes.invalid_json")
        return decoded

    # --- routes autorisées ---------------------------------------------

    def login(self, username: str, password: str) -> AuthTokens:
        response = self._request_with_headers(
            "POST",
            "/auth/password-login",
            body={
                "provider": "basic",
                "username": username,
                "password": password,
                "next": "",
            },
        )
        body, headers = response
        cookies: dict[str, str] = {}
        for header in _header_values(headers, "set-cookie"):
            name_value = header.split(";", 1)[0]
            name, separator, value = name_value.partition("=")
            if not separator:
                continue
            normalized = name.strip()
            for prefix in ("__Host-", "__Secure-"):
                if normalized.startswith(prefix):
                    normalized = normalized[len(prefix) :]
            cookies[normalized] = value
        access = cookies.get("hermes_session_at")
        if body.get("ok") is not True or not access:
            raise HermesAuthError()
        refresh = cookies.get("hermes_session_rt") or None
        return AuthTokens(access, refresh)

    def refresh(self, refresh_token: str) -> AuthTokens:
        body = self.request(
            "POST",
            "/auth/native/refresh",
            body={"provider": "basic", "refresh_token": refresh_token},
        )
        access = body.get("access_token")
        refresh = body.get("refresh_token")
        if not isinstance(access, str) or not access:
            raise HermesAuthError()
        if refresh is not None and (not isinstance(refresh, str) or not refresh):
            raise HermesAuthError()
        return AuthTokens(access, refresh or refresh_token)

    def profiles(self, bearer: str) -> list[ProfileInfo]:
        body = self.request("GET", "/api/profiles", bearer=bearer)
        raw = body.get("profiles")
        if not isinstance(raw, list):
            raise HermesProtocolError("hermes.invalid_profiles")
        names: set[str] = set()
        result: list[ProfileInfo] = []
        for entry in raw:
            if not isinstance(entry, Mapping):
                raise HermesProtocolError("hermes.invalid_profiles")
            name = entry.get("name")
            is_default = entry.get("is_default")
            if (
                not isinstance(name, str)
                or not name
                or name in names
                or not isinstance(is_default, bool)
            ):
                raise HermesProtocolError("hermes.invalid_profiles")
            label = entry.get("display_name")
            if not isinstance(label, str) or not label:
                label = name
            names.add(name)
            result.append(ProfileInfo(name=name, label=label, is_default=is_default))
        return result

    def ws_ticket(self, bearer: str) -> str:
        body = self.request("POST", "/api/auth/ws-ticket", bearer=bearer)
        ticket = body.get("ticket")
        if not isinstance(ticket, str) or not ticket:
            raise HermesProtocolError("hermes.invalid_ticket")
        return ticket

    def _request_with_headers(
        self,
        method: str,
        endpoint: str,
        *,
        body: Mapping[str, Any],
    ) -> tuple[dict[str, Any], list[tuple[str, str]]]:
        route = f"{method} {endpoint}"
        if route not in self.contracts.allowed_rest:
            raise HermesProtocolError("hermes.rest_forbidden")
        connection = self._connection()
        try:
            connection.request(
                method,
                self._path(endpoint),
                body=json.dumps(body, separators=(",", ":")).encode("utf-8"),
                headers={
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                    "Connection": "close",
                },
            )
            response = connection.getresponse()
            data = response.read(MAX_BODY_BYTES + 1)
            status = response.status
            headers = response.getheaders()
        except (OSError, http.client.HTTPException, ssl.SSLError) as exc:
            raise HermesError("hermes.unreachable", retryable=True) from exc
        finally:
            try:
                connection.close()
            except OSError:  # pragma: no cover
                pass

        if len(data) > MAX_BODY_BYTES:
            raise HermesProtocolError("hermes.body_too_large")
        if status in {301, 302, 303, 307, 308}:
            raise HermesError("hermes.redirect", retryable=False)
        if status in {401, 403}:
            raise HermesAuthError()
        if status in {404, 405, 501}:
            raise HermesNotFoundError()
        if status == 429:
            raise HermesError("hermes.rate_limited", retryable=True)
        if status >= 500:
            raise HermesError("hermes.server", retryable=True)
        if status != 200:
            raise HermesError("hermes.status", retryable=False)
        try:
            decoded = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise HermesProtocolError("hermes.invalid_json") from exc
        if not isinstance(decoded, dict):
            raise HermesProtocolError("hermes.invalid_json")
        return decoded, headers


class HermesSession:
    """Authentification partagée entre les veilles, sans journaliser de secret."""

    def __init__(
        self,
        rest: HermesRest,
        *,
        username: str,
        password: str,
        logger: EventLogger | None = None,
    ) -> None:
        self.rest = rest
        self._username = username
        self._password = password
        self._logger = logger
        self._lock = asyncio.Lock()
        self._tokens: AuthTokens | None = None

    async def _login_locked(self) -> AuthTokens:
        tokens = await asyncio.to_thread(
            self.rest.login, self._username, self._password
        )
        self._tokens = tokens
        return tokens

    async def login(self) -> AuthTokens:
        async with self._lock:
            return await self._login_locked()

    async def access_token(self) -> str:
        if self._tokens is None:
            await self.login()
        assert self._tokens is not None
        return self._tokens.access

    async def renew(self) -> str:
        current = self._tokens
        if current is not None and current.refresh:
            try:
                renewed = await asyncio.to_thread(
                    self.rest.refresh, current.refresh
                )
            except HermesAuthError:
                if self._logger is not None:
                    self._logger.warning("hermes.refresh_refused")
            else:
                async with self._lock:
                    self._tokens = renewed
                return renewed.access
        async with self._lock:
            if self._tokens is not current and self._tokens is not None:
                return self._tokens.access
            return (await self._login_locked()).access

    async def ws_ticket(self) -> str:
        token = await self.access_token()
        try:
            return await asyncio.to_thread(self.rest.ws_ticket, token)
        except HermesAuthError:
            token = await self.renew()
            return await asyncio.to_thread(self.rest.ws_ticket, token)

    async def profiles(self) -> list[ProfileInfo]:
        token = await self.access_token()
        try:
            return await asyncio.to_thread(self.rest.profiles, token)
        except HermesAuthError:
            token = await self.renew()
            return await asyncio.to_thread(self.rest.profiles, token)


class GatewayRpc:
    """Session JSON-RPC sur un WebSocket, avec événements en file ordonnée."""

    def __init__(
        self,
        websocket: Any,
        contracts: Contracts,
        *,
        logger: EventLogger | None = None,
    ) -> None:
        self._ws = websocket
        self.contracts = contracts
        self.logger = logger
        self.replay_epoch: str | None = None
        self._pending: dict[str, asyncio.Future[Mapping[str, Any]]] = {}
        self._events: asyncio.Queue[Any] = asyncio.Queue(maxsize=4096)
        self._closed = asyncio.Event()
        self._ready = asyncio.Event()
        self._reader_task: asyncio.Task[None] | None = None
        self._sequence = 0
        self._closing = False

    @classmethod
    async def connect(
        cls,
        origin: str,
        ticket: str,
        contracts: Contracts,
        *,
        timeout: float = 15.0,
        logger: EventLogger | None = None,
    ) -> "GatewayRpc":
        uri = ws_url(origin)
        try:
            websocket = await connect(
                uri,
                subprotocols=[GATEWAY_PROTOCOL, f"hermes-gateway-ticket.{ticket}"],
                open_timeout=timeout,
                close_timeout=5,
                ping_interval=15,
                ping_timeout=15,
                max_size=2 * 1024 * 1024,
                proxy=None,
                user_agent_header="hermes-notifier",
            )
        except (OSError, InvalidHandshake, WebSocketException, asyncio.TimeoutError) as exc:
            raise HermesError("hermes.websocket", retryable=True) from exc
        if websocket.subprotocol != GATEWAY_PROTOCOL:
            await websocket.close()
            raise HermesProtocolError("hermes.subprotocol")
        rpc = cls(websocket, contracts, logger=logger)
        rpc._reader_task = asyncio.create_task(rpc._read_loop())
        return rpc

    @property
    def closed(self) -> bool:
        return self._closed.is_set()

    async def wait_ready(self, timeout: float = 15.0) -> str | None:
        try:
            await asyncio.wait_for(self._ready.wait(), timeout)
        except asyncio.TimeoutError as exc:
            raise HermesError("hermes.ready_timeout", retryable=True) from exc
        if self._closed.is_set():
            raise HermesError("hermes.closed", retryable=True)
        return self.replay_epoch

    async def announce_capabilities(self, timeout: float = 5.0) -> None:
        """Séquence du mobile ; l'échec n'empêche pas la lecture."""

        try:
            await self.call("gateway.capabilities", {}, timeout=timeout)
        except HermesError:
            return

    async def call(
        self,
        method: str,
        params: Mapping[str, Any],
        *,
        timeout: float = 15.0,
    ) -> Mapping[str, Any]:
        if method not in self.contracts.allowed_rpc:
            raise HermesProtocolError("hermes.rpc_forbidden")
        if method in self.contracts.forbidden_rpc:
            raise HermesProtocolError("hermes.rpc_forbidden")
        if self._closed.is_set():
            raise HermesError("hermes.closed", retryable=True)

        self._sequence += 1
        identifier = str(self._sequence)
        future: asyncio.Future[Mapping[str, Any]] = (
            asyncio.get_running_loop().create_future()
        )
        self._pending[identifier] = future
        message = {
            "jsonrpc": "2.0",
            "id": identifier,
            "method": method,
            "params": dict(params),
        }
        try:
            await self._ws.send(
                json.dumps(message, separators=(",", ":"))
            )
            result = await asyncio.wait_for(future, timeout)
        except asyncio.TimeoutError as exc:
            raise HermesError("hermes.timeout", retryable=True) from exc
        except WebSocketException as exc:
            raise HermesError("hermes.websocket", retryable=True) from exc
        finally:
            self._pending.pop(identifier, None)
        return result

    async def next_event(self, timeout: float = 30.0) -> Mapping[str, Any] | None:
        try:
            item = await asyncio.wait_for(self._events.get(), timeout)
        except asyncio.TimeoutError:
            return None
        if item is _CLOSED:
            raise HermesError("hermes.closed", retryable=True)
        return item

    async def close(self) -> None:
        if self._closing:
            return
        self._closing = True
        try:
            await self._ws.close()
        except (WebSocketException, OSError):
            pass
        if self._reader_task is not None:
            self._reader_task.cancel()
            try:
                await self._reader_task
            except (asyncio.CancelledError, Exception):
                pass
        self._closed.set()
        self._fail_pending("hermes.closed")
        try:
            self._events.put_nowait(_CLOSED)
        except asyncio.QueueFull:  # pragma: no cover
            pass

    def _fail_pending(self, code: str) -> None:
        for future in list(self._pending.values()):
            if not future.done():
                future.set_exception(HermesError(code, retryable=True))
        self._pending.clear()

    async def _read_loop(self) -> None:
        try:
            async for raw in self._ws:
                if isinstance(raw, bytes):
                    raw = raw.decode("utf-8", "strict")
                try:
                    message = json.loads(raw)
                except (ValueError, TypeError):
                    continue
                if not isinstance(message, Mapping):
                    continue
                method = message.get("method")
                if isinstance(method, str):
                    if method == "event":
                        await self._handle_event(message)
                    elif "id" in message:
                        await self._reject_server_request(message.get("id"))
                    continue
                identifier = message.get("id")
                if not isinstance(identifier, str):
                    continue
                future = self._pending.get(identifier)
                if future is None or future.done():
                    continue
                error = message.get("error")
                if isinstance(error, Mapping):
                    code = error.get("code")
                    future.set_exception(
                        HermesRpcError(code if isinstance(code, (int, str)) else None)
                    )
                    continue
                result = message.get("result")
                if isinstance(result, Mapping):
                    future.set_result(result)
                else:
                    future.set_exception(HermesProtocolError("hermes.invalid_result"))
        except asyncio.CancelledError:
            raise
        except (ConnectionClosed, WebSocketException, OSError):
            pass
        except Exception:  # pragma: no cover - garde-fou de lecture
            pass
        finally:
            if not self._closing:
                self._closed.set()
                self._fail_pending("hermes.closed")
                try:
                    self._events.put_nowait(_CLOSED)
                except asyncio.QueueFull:  # pragma: no cover
                    pass

    async def _handle_event(self, message: Mapping[str, Any]) -> None:
        params = message.get("params")
        if not isinstance(params, Mapping):
            return
        if params.get("type") == "gateway.ready":
            payload = params.get("payload")
            epoch = payload.get("replay_epoch") if isinstance(payload, Mapping) else None
            self.replay_epoch = epoch if isinstance(epoch, str) and epoch else None
            self._ready.set()
            return
        await self._events.put(params)

    async def _reject_server_request(self, identifier: Any) -> None:
        if identifier is None:
            return
        try:
            await self._ws.send(
                json.dumps(
                    {
                        "jsonrpc": "2.0",
                        "id": identifier,
                        "error": {"code": -32601, "message": "unsupported"},
                    },
                    separators=(",", ":"),
                )
            )
        except WebSocketException:
            pass


_CLOSED = object()


def ws_url(origin: str) -> str:
    parsed = urlsplit(origin)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    path = f"{parsed.path.rstrip('/')}/api/ws" if parsed.path.strip("/") else "/api/ws"
    return urlunsplit((scheme, parsed.netloc, path, "", ""))


def _header_values(
    headers: list[tuple[str, str]], name: str
) -> list[str]:
    lower = name.lower()
    return [value for key, value in headers if key.lower() == lower]
