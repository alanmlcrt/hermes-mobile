"""FCM HTTP v1, sans journaliser secrets, réponses ni tokens du téléphone."""
from __future__ import annotations

import json
import re
import threading
import time
from pathlib import Path
from typing import Any

from .errors import ConfigError
from .outbox import DeliveryError, InvalidTokenError, PermanentDeliveryError
from .payload import PushPayload


class FcmTransport:
    def __init__(self, credentials: Any, project_id: str, *, session: Any = None,
                 auth_request: Any = None, timeout: float = 8.0) -> None:
        if not re.fullmatch(r"[a-z][a-z0-9-]{4,61}[a-z0-9]", project_id):
            raise ConfigError("config.firebase_project")
        if session is None:
            import requests
            session = requests.Session()
        if auth_request is None:
            from google.auth.transport.requests import Request
            # Même délai fini pour OAuth et pour la requête FCM.
            request = Request()
            auth_request = lambda **kw: request(**{**kw, "timeout": timeout})
        self.credentials = credentials
        self.session = session
        self.auth_request = auth_request
        self.timeout = timeout
        self.url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        self._lock = threading.Lock()

    @classmethod
    def from_file(cls, path: str) -> "FcmTransport":
        try:
            from google.oauth2 import service_account
            credentials = service_account.Credentials.from_service_account_file(
                path, scopes=["https://www.googleapis.com/auth/firebase.messaging"])
            # Refuser un endpoint OAuth arbitraire dans le fichier fourni.
            raw = json.loads(Path(path).read_text())
            if raw.get("token_uri") != "https://oauth2.googleapis.com/token":
                raise ValueError()
            return cls(credentials, credentials.project_id)
        except Exception:
            raise ConfigError("config.firebase_credentials") from None

    def send(self, payload: PushPayload, *, terminal: str, attempt: int) -> None:
        with self._lock:
            try:
                if not self.credentials.valid:
                    self.credentials.refresh(self.auth_request)
                deadline = time.monotonic() + self.timeout
                response = self.session.post(
                    self.url, data=payload.encoded(),
                    headers={"Authorization": f"Bearer {self.credentials.token}",
                             "Content-Type": "application/json; charset=UTF-8"},
                    timeout=self.timeout, allow_redirects=False, stream=True)
            except Exception as error:
                if getattr(error, "retryable", True) is False:
                    raise PermanentDeliveryError("fcm.authorization") from None
                raise DeliveryError("fcm.unavailable") from None
            try:
                if 200 <= response.status_code < 300:
                    return
                # Lecture bornée ; aucun texte du fournisseur n'est exposé.
                codes = set()
                try:
                    chunks = bytearray()
                    while len(chunks) <= 16384:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0:
                            raise TimeoutError()
                        # read1 rend les octets disponibles, sans attendre de remplir
                        # 16 Kio. Le timeout socket suit le budget restant.
                        connection = getattr(response.raw, "_connection", None)
                        sock = getattr(connection, "sock", None)
                        if sock is None:
                            fp = getattr(getattr(response.raw, "_fp", None), "fp", None)
                            sock = getattr(getattr(fp, "raw", None), "_sock", None)
                        if sock is not None:
                            sock.settimeout(remaining)
                        chunk = response.raw.read1(min(1024, 16385 - len(chunks)), decode_content=True)
                        if time.monotonic() >= deadline:
                            raise TimeoutError()
                        if not chunk:
                            break
                        chunks.extend(chunk)
                    raw = bytes(chunks)
                except Exception:
                    raise DeliveryError("fcm.unavailable") from None
                if len(raw) <= 16384:
                    try:
                        error = json.loads(raw).get("error", {})
                        codes = {d.get("errorCode") for d in error.get("details", [])
                                 if isinstance(d, dict)}
                    except (ValueError, AttributeError, TypeError):
                        pass
                if "UNREGISTERED" in codes:
                    raise InvalidTokenError("fcm.invalid_token")
                if response.status_code == 401:
                    # Forcer un nouveau token OAuth à la prochaine tentative.
                    self.credentials.token = None
                if response.status_code in {401, 429, 500, 502, 503, 504}:
                    raise DeliveryError("fcm.unavailable")
                raise PermanentDeliveryError("fcm.permanent")
            finally:
                try:
                    response.close()
                except Exception:
                    pass
