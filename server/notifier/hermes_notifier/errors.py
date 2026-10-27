"""Erreurs bornées du notifier.

Les messages sont fixes et ne contiennent jamais d'identifiant, de token, de
chemin ni de contenu. Les codes sont ceux de ``contracts/notification-tracking.json``
(``errors.codes``).
"""

from __future__ import annotations

from typing import Final

# Statuts HTTP du contrat.
INVALID_REQUEST: Final = 400
UNAUTHORIZED: Final = 401
NOT_FOUND: Final = 404
GONE: Final = 410
RATE_LIMITED: Final = 429
INTERNAL: Final = 500
UNAVAILABLE: Final = 503


class NotifierError(Exception):
    """Erreur métier ou de transport, toujours sûre à journaliser."""

    code: str = "internal"
    status: int = INTERNAL
    message: str = "Erreur interne."

    def __init__(
        self,
        code: str | None = None,
        message: str | None = None,
        *,
        status: int | None = None,
        retry_after: int | None = None,
    ) -> None:
        self.code = code or self.code
        self.message = message or self.message
        self.status = status or self.status
        self.retry_after = retry_after
        super().__init__(self.code)


class InvalidRequest(NotifierError):
    code = "invalid-request"
    status = INVALID_REQUEST
    message = "Requête invalide."


class Unauthorized(NotifierError):
    code = "unauthorized"
    status = UNAUTHORIZED
    message = "Authentification requise."


class NotFound(NotifierError):
    code = "not-found"
    status = NOT_FOUND
    message = "Ressource inconnue."


class Gone(NotifierError):
    code = "gone"
    status = GONE
    message = "Abonnement expiré."


class Conflict(NotifierError):
    """Conflit d'exécution : le contrat interdit 409, la requête est invalide."""

    code = "invalid-request"
    status = INVALID_REQUEST
    message = "Requête invalide."


class RateLimited(NotifierError):
    code = "rate-limited"
    status = RATE_LIMITED
    message = "Trop de requêtes."


class Unavailable(NotifierError):
    code = "unavailable"
    status = UNAVAILABLE
    message = "Service indisponible."


class StorageError(Unavailable):
    """Échec SQLite ou clé de chiffrement : jamais détaillé vers l'extérieur."""


class ConfigError(NotifierError):
    """Refus de configuration, journalisé sans secret."""

    code = "unavailable"
    status = UNAVAILABLE
    message = "Configuration invalide."


class ContractError(NotifierError):
    code = "internal"
    status = INTERNAL
    message = "Contrat invalide."


def error_body(error: NotifierError) -> dict[str, str]:
    """Corps d'erreur exact ``{code, message}``."""

    return {"code": error.code, "message": error.message}
