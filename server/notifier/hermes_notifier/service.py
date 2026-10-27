"""Orchestration de l'add-on : API, observateur, outbox et purge.

Le transport personnel exige un compte FCM valide, l'intégration reste simulée.
La reprise au démarrage recharge le registre, l'outbox et les curseurs
depuis ``/data`` ; un SIGTERM arrête proprement les threads.
"""

from __future__ import annotations

import json
import os
import signal
import threading
import time
from pathlib import Path
from typing import Any, Callable

from . import __version__
from .api import NotificationApi
from .config import Config
from .contracts import Contracts
from .credential import BearerCredential, TokenCipher
from .errors import ConfigError, NotifierError, StorageError
from .health import HealthState
from .hermes.observer import Observer
from .hermes.rpc import HermesRest, HermesSession
from .logs import EventLogger, Redactor, configure_logging
from .outbox import DeliveryTransport, DryRunTransport, OutboxDispatcher
from .fcm import FcmTransport
from .retention import RetentionPolicy
from .store import Store


class Service:
    def __init__(
        self,
        config: Config,
        contracts: Contracts,
        *,
        clock: Callable[[], int] | None = None,
    ) -> None:
        self.config = config
        self.contracts = contracts
        self.clock = clock or (lambda: int(time.time()))
        self.redactor = Redactor()
        self.logger: EventLogger | None = None
        self.health: HealthState | None = None
        self.store: Store | None = None
        self.cipher: TokenCipher | None = None
        self.credential: BearerCredential | None = None
        self.retention: RetentionPolicy | None = None
        self.transport: DeliveryTransport | None = None
        self.dispatcher: OutboxDispatcher | None = None
        self.observer: Observer | None = None
        self.api: NotificationApi | None = None
        self._dispatcher_thread: threading.Thread | None = None
        self._started = False
        self._stop = threading.Event()

    # --- validation -----------------------------------------------------

    def check(self) -> dict[str, Any]:
        self.config.validate(self.contracts)
        if self.config.environment == "personal":
            FcmTransport.from_file(self.config.fcm_service_account)
        return self.config.summary(self.contracts)

    # --- préparation ----------------------------------------------------

    def prepare(self) -> None:
        self.check()
        self.redactor.add(self.config.hermes_password)
        self.redactor.add(self.config.bearer_hash)
        self.redactor.add(self.config.bearer_salt)
        if self.config.fcm_service_account:
            self.redactor.add(self.config.fcm_service_account)
        self.logger = configure_logging(self.config.log_level, self.redactor)

        data_path = self.config.data_path(self.contracts)
        try:
            data_path.mkdir(parents=True, exist_ok=True)
            try:
                os.chmod(data_path, 0o700)
            except OSError:
                pass
        except OSError as exc:
            raise StorageError("storage.data_dir") from exc

        self.store = Store(
            data_path / "notifier.sqlite3",
            outcomes=self.contracts.outcomes,
            now=self.clock,
        )
        try:
            self.cipher = TokenCipher(data_path / "token.key")
        except Exception as exc:
            self.store.close()
            raise StorageError("storage.key") from exc
        self.credential = BearerCredential(
            self.config.bearer_hash, self.config.bearer_salt
        )
        self.health = HealthState(
            self.contracts,
            environment=self.config.environment,
            dry_run=self.config.environment != "personal",
            now=None,
        )
        self.retention = RetentionPolicy(
            self.store, self.contracts, self.logger, health=self.health
        )
        self.transport = (
            FcmTransport.from_file(self.config.fcm_service_account)
            if self.config.environment == "personal"
            else DryRunTransport(self.contracts)
        )
        self.dispatcher = OutboxDispatcher(
            self.store,
            self.contracts,
            self.cipher,
            self.transport,
            self.logger,
            health=self.health,
            now=self.clock,
        )

        rest = HermesRest(
            self.config.hermes_origin,
            contracts=self.contracts,
        )
        session = HermesSession(
            rest,
            username=self.config.hermes_username,
            password=self.config.hermes_password,
            logger=self.logger,
        )
        self.observer = Observer(
            self.config,
            self.contracts,
            self.store,
            session,
            self.logger,
            health=self.health,
            redactor=self.redactor,
            on_terminal=self.dispatcher.wake,
        )
        self.api = NotificationApi(
            self.config,
            self.contracts,
            self.store,
            self.cipher,
            self.credential,
            self.health,
            self.logger,
            redactor=self.redactor,
            on_attach=self.observer.wake,
        )

        # La purge de démarrage borne les états laissés par un arrêt brutal.
        self.retention.prune()

    # --- démarrage / arrêt ---------------------------------------------

    def start(self) -> None:
        if self._started:
            return
        self._stop.clear()
        if self.api is None or self.observer is None or self.dispatcher is None:
            self.prepare()
        assert self.api is not None
        assert self.observer is not None
        assert self.dispatcher is not None
        assert self.logger is not None

        self.api.create_server()
        self.observer.start()
        self._dispatcher_thread = threading.Thread(
            target=self.dispatcher.run,
            name="notifier-outbox",
            daemon=True,
        )
        self._dispatcher_thread.start()
        self.api.start()
        self._started = True
        self.logger.info(
            "service.started",
            environment=self.config.environment,
            version=__version__,
            port=self.api.port,
        )

    def stop(self) -> None:
        self._stop.set()
        if self.api is not None:
            self.api.stop()
        if self.observer is not None:
            self.observer.stop()
        if self.dispatcher is not None:
            self.dispatcher.stop()
        if self._dispatcher_thread is not None:
            self._dispatcher_thread.join(10.0)
            self._dispatcher_thread = None
        if self.store is not None:
            self.store.close()
        # Un redémarrage logique doit reconstruire des composants neufs :
        # conserver les anciens réutiliserait des threads et un serveur
        # arrêtés.
        self.api = None
        self.observer = None
        self.dispatcher = None
        self.retention = None
        self.transport = None
        self.cipher = None
        self.credential = None
        self.health = None
        self.store = None
        self._started = False
        if self.logger is not None:
            self.logger.info("service.stopped", status="stopped")

    def run(self) -> int:
        previous = _install_signals(self._stop)
        try:
            self.start()
            while not self._stop.wait(1.0):
                if self.retention is not None:
                    try:
                        self.retention.prune_if_due()
                    except StorageError:
                        continue
        finally:
            _restore_signals(previous)
            self.stop()
        return 0


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(
        prog="hermes_notifier",
        description="Observateur de fins de travail Hermes pour Home Assistant.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Valide la configuration et affiche un résumé sans secret.",
    )
    parser.add_argument(
        "--version", action="store_true", help="Affiche la version."
    )
    parser.add_argument(
        "--contracts-dir",
        type=Path,
        default=None,
        help="Répertoire des contrats vendorisés (diagnostic).",
    )
    parser.add_argument(
        "--options",
        type=Path,
        default=None,
        help="Chemin d'un fichier d'options Home Assistant (diagnostic).",
    )
    arguments = parser.parse_args(argv)

    if arguments.version:
        print(__version__)
        return 0

    try:
        contracts = Contracts.load(arguments.contracts_dir)
        config = Config.load(options_path=arguments.options)
        service = Service(config, contracts)
        if arguments.check:
            summary = service.check()
            print(
                json.dumps(
                    {"ok": True, **summary},
                    separators=(",", ":"),
                    sort_keys=True,
                )
            )
            return 0
        return service.run()
    except NotifierError as error:
        print(
            json.dumps(
                {"ok": False, "error": error.code},
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 1
    except Exception:
        # Aucun chemin, aucune trace et aucun secret sur la sortie standard.
        print(
            json.dumps(
                {"ok": False, "error": "internal"},
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 1


def _install_signals(stop: threading.Event) -> dict[int, Any]:
    previous: dict[int, Any] = {}

    def handler(signum: int, frame: Any) -> None:
        stop.set()

    for name in ("SIGTERM", "SIGINT"):
        number = getattr(signal, name, None)
        if number is None:
            continue
        try:
            previous[number] = signal.getsignal(number)
            signal.signal(number, handler)
        except (ValueError, OSError):
            continue
    return previous


def _restore_signals(previous: dict[int, Any]) -> None:
    for number, handler in previous.items():
        try:
            signal.signal(number, handler)
        except (ValueError, OSError):
            continue


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
