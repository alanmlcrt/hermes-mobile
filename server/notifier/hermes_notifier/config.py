"""Configuration de l'add-on.

Les options viennent de ``/data/options.json`` (format Home Assistant) ; les
variables ``HERMES_NOTIFIER_*`` servent aux tests et au diagnostic local. Aucun
bearer en clair n'est accepté : seulement un hash salé et son sel.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping
from urllib.parse import urlsplit

from .errors import ConfigError

DEFAULT_OPTIONS_PATH = Path("/data/options.json")
DEFAULT_DATA_DIR = Path("/data")

# Options Home Assistant (snake_case) et leur override d'environnement.
ENVIRONMENT_VARIABLES = {
    "environment": "HERMES_NOTIFIER_ENVIRONMENT",
    "hermes_origin": "HERMES_NOTIFIER_HERMES_ORIGIN",
    "hermes_username": "HERMES_NOTIFIER_HERMES_USERNAME",
    "hermes_password": "HERMES_NOTIFIER_HERMES_PASSWORD",
    "hermes_profile": "HERMES_NOTIFIER_HERMES_PROFILE",
    "bearer_hash": "HERMES_NOTIFIER_BEARER_HASH",
    "bearer_salt": "HERMES_NOTIFIER_BEARER_SALT",
    "fcm_enabled": "HERMES_NOTIFIER_FCM_ENABLED",
    "fcm_service_account": "HERMES_NOTIFIER_FCM_SERVICE_ACCOUNT",
    "log_level": "HERMES_NOTIFIER_LOG_LEVEL",
    "rate_limit_per_minute": "HERMES_NOTIFIER_RATE_LIMIT_PER_MINUTE",
}

PLAINTEXT_CREDENTIAL_KEYS = (
    "bearer",
    "token",
    "bearer_token",
    "authorization",
    "fcm_token",
    "password_hash_plain",
)

LOG_LEVELS = ("debug", "info", "warning", "error")
_PLAINTEXT_ENV = ("HERMES_NOTIFIER_BEARER", "HERMES_NOTIFIER_TOKEN")


@dataclass(frozen=True)
class Config:
    environment: str
    data_dir: Path
    hermes_origin: str
    hermes_username: str
    hermes_password: str
    hermes_profile: str | None
    bearer_hash: str
    bearer_salt: str
    fcm_enabled: bool = False
    fcm_service_account: str | None = None
    log_level: str = "info"
    rate_limit_per_minute: int = 120
    # Port d'écoute interne. Le contrat propose 8787 ; 0 est réservé aux tests.
    port: int = 8787
    options_path: Path | None = field(default=None, compare=False, repr=False)

    # --- chargement -----------------------------------------------------

    @classmethod
    def load(
        cls,
        *,
        options: Mapping[str, Any] | None = None,
        environ: Mapping[str, str] | None = None,
        options_path: Path | None = None,
    ) -> "Config":
        environ = dict(os.environ if environ is None else environ)
        path = Path(options_path) if options_path is not None else DEFAULT_OPTIONS_PATH

        if options is None:
            options = {}
            if path.is_file():
                try:
                    raw = json.loads(path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    raise ConfigError("config.options_unreadable") from exc
                if not isinstance(raw, dict):
                    raise ConfigError("config.options_unreadable")
                options = raw

        merged: dict[str, Any] = dict(options)
        for key, variable in ENVIRONMENT_VARIABLES.items():
            if variable in environ:
                merged[key] = environ[variable]

        if environ.get("HERMES_NOTIFIER_DATA_DIR"):
            data_dir = Path(environ["HERMES_NOTIFIER_DATA_DIR"])
        else:
            data_dir = DEFAULT_DATA_DIR

        for key in PLAINTEXT_CREDENTIAL_KEYS:
            if merged.get(key):
                raise ConfigError("config.plaintext_credential")
        for variable in _PLAINTEXT_ENV:
            if environ.get(variable):
                raise ConfigError("config.plaintext_credential")

        environment = str(merged.get("environment") or "integration").strip()
        origin = str(merged.get("hermes_origin") or "").strip()
        username = str(merged.get("hermes_username") or "hermes").strip()
        password = str(merged.get("hermes_password") or "")
        profile_value = merged.get("hermes_profile")
        profile = (
            str(profile_value).strip()
            if profile_value is not None and str(profile_value).strip()
            else None
        )
        bearer_hash = str(merged.get("bearer_hash") or "").strip()
        bearer_salt = str(merged.get("bearer_salt") or "").strip()
        fcm_enabled = _bool(merged.get("fcm_enabled"), default=False)
        fcm_service_account = (
            str(merged.get("fcm_service_account") or "").strip() or None
        )
        log_level = str(merged.get("log_level") or "info").strip().lower()
        rate_limit = _int(
            merged.get("rate_limit_per_minute"), default=120, minimum=1, maximum=10000
        )
        port = _int(
            environ.get("HERMES_NOTIFIER_PORT", merged.get("port")),
            default=8787,
            minimum=0,
            maximum=65535,
        )

        return cls(
            environment=environment,
            data_dir=data_dir,
            hermes_origin=origin,
            hermes_username=username,
            hermes_password=password,
            hermes_profile=profile,
            bearer_hash=bearer_hash,
            bearer_salt=bearer_salt,
            fcm_enabled=fcm_enabled,
            fcm_service_account=fcm_service_account,
            log_level=log_level,
            rate_limit_per_minute=rate_limit,
            port=port,
            options_path=path if options is None else None,
        )

    # --- validation -----------------------------------------------------

    def validate(self, contracts: Any) -> None:
        """Valide l'environnement, l'auth et les prérequis FCM.

        ``personal`` refuse de démarrer sans Firebase/FCM. En 5.2 aucun
        transport FCM réel n'est fourni : même complet, ``personal`` est refusé
        par le service avec un code borné.
        """

        try:
            environment = contracts.environment(self.environment)
        except Exception as exc:
            raise ConfigError("config.environment") from exc

        if environment.isolated is not True:
            raise ConfigError("config.environment_not_isolated")
        if not environment.registry_ref:
            raise ConfigError("config.registry_reference")
        if not environment.fcm_transport:
            raise ConfigError("config.transport")
        if not self.hermes_origin:
            raise ConfigError("config.origin_missing")
        self._validate_origin()
        if not self.hermes_username or not self.hermes_password:
            raise ConfigError("config.hermes_credentials")
        if self.log_level not in LOG_LEVELS:
            raise ConfigError("config.log_level")
        if not self.bearer_hash:
            raise ConfigError("config.bearer_hash_missing")
        if not self.bearer_salt:
            raise ConfigError("config.bearer_salt_missing")
        self._validate_hash()

        if environment.fcm_transport == "dry-run":
            if self.fcm_enabled:
                # L'intégration est verrouillée en dry-run ; seul le personal
                # peut exiger FCM.
                raise ConfigError("config.dry_run_locked")
        elif environment.fcm_transport == "fcm-http-v1":
            if not self.fcm_enabled:
                raise ConfigError("config.fcm_required")
            if not environment.firebase_project:
                raise ConfigError("config.firebase_required")
            if not self.fcm_service_account:
                raise ConfigError("config.firebase_missing")
            if not Path(self.fcm_service_account).is_file():
                raise ConfigError("config.firebase_missing")
        else:
            raise ConfigError("config.transport")

        if environment.dry_run_locked and self.fcm_enabled:
            raise ConfigError("config.dry_run_locked")

    def _validate_origin(self) -> None:
        try:
            parsed = urlsplit(self.hermes_origin)
            # ``urlsplit`` ne valide le port qu'à l'accès : ``host:abc``
            # passait la validation avant d'échouer au premier appel.
            parsed.port
        except ValueError as exc:
            raise ConfigError("config.origin_invalid") from exc
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ConfigError("config.origin_invalid")
        if parsed.username or parsed.password:
            raise ConfigError("config.origin_credentials")
        if parsed.query or parsed.fragment:
            raise ConfigError("config.origin_query")

    def _validate_hash(self) -> None:
        if len(self.bearer_hash) != 64:
            raise ConfigError("config.bearer_hash_format")
        if not 64 <= len(self.bearer_salt) <= 128:
            raise ConfigError("config.bearer_salt_format")
        try:
            bytes.fromhex(self.bearer_hash)
            bytes.fromhex(self.bearer_salt)
        except ValueError as exc:
            raise ConfigError("config.bearer_hash_format") from exc

    # --- chemins et résumé ---------------------------------------------

    def data_path(self, contracts: Any) -> Path:
        environment = contracts.environment(self.environment)
        if not environment.registry_ref or "/" in environment.registry_ref:
            raise ConfigError("config.registry_reference")
        return self.data_dir / environment.registry_ref

    def resolve_profile(self, value: str | None) -> str | None:
        return value if value else self.hermes_profile

    def summary(self, contracts: Any) -> dict[str, Any]:
        """Résumé sans secret, pour ``--check`` et les journaux."""

        environment = contracts.environment(self.environment)
        return {
            "environment": self.environment,
            "registryRef": environment.registry_ref,
            "fcmTransport": environment.fcm_transport,
            "dryRun": environment.fcm_transport == "dry-run",
            "fcmEnabled": self.fcm_enabled,
            "logLevel": self.log_level,
            "rateLimitPerMinute": self.rate_limit_per_minute,
        }


def _bool(value: Any, *, default: bool) -> bool:
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in {"1", "true", "yes", "on"}:
        return True
    if text in {"0", "false", "no", "off"}:
        return False
    raise ConfigError("config.boolean")


def _int(value: Any, *, default: int, minimum: int, maximum: int) -> int:
    if value is None or value == "":
        return default
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise ConfigError("config.integer") from exc
    if not minimum <= number <= maximum:
        raise ConfigError("config.integer")
    return number
