"""Plugin Hermes Mobile : notification FCM générique à chaque fin de tour.

- ``/hermes-mobile-token <jeton>`` mémorise le jeton FCM du téléphone dans
  ``HERMES_HOME/hermes-mobile/fcm-token`` (l'app l'envoie par ``command.dispatch``
  avant chaque ``prompt.submit``).
- ``on_session_end`` journalise le tour (métadonnées seulement) et lance l'envoi
  FCM dans un fil démon : le hook rend la main sans attendre le réseau.

Le compte de service est lu dans ``HERMES_HOME/hermes-mobile/service-account.json``
(hors dossier du plugin). Notification au titre et au corps fixes ; ``data`` ne
porte que ``outcome`` et ``sessionId``. Le journal ``session-end.jsonl`` (dossier
du plugin) et ``agent.log`` ne gardent du jeton que ses 8 derniers caractères.
Aucune erreur ne remonte au tour.

Erreurs FCM : un seul nouvel essai (après ``_RETRY_DELAY``) sur erreur de
transport ou HTTP 5xx ; ``UNREGISTERED`` supprime ``fcm-token`` s'il porte
encore ce jeton (l'app le renverra au prochain message). Pas de file durable.
"""

import json
import logging
import os
import re
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger("hermes_mobile_notify")

_LOG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "session-end.jsonl")
_STATE_DIR = "hermes-mobile"
_TOKEN_FILE = "fcm-token"
_KEY_FILE = "service-account.json"
_TIMEOUT = 8.0
_RETRY_DELAY = 2.0  # secondes avant l'unique nouvel essai (patché par l'auto-vérification)
_MAX_ATTEMPTS = 2
_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_TOKEN_URI = "https://oauth2.googleapis.com/token"

# Repris de contracts/notification-tracking.json (payload.notification / android).
_TITLE = "Hermes"
_BODIES = {
    "succeeded": "Hermes a terminé",
    "failed": "Hermes a échoué",
    "stopped": "Hermes s'est arrêté",
}
_CHANNEL = "hermes_turn_complete"
_TTL = "86400s"

_ALLOWED = (
    "session_id",
    "task_id",
    "turn_id",
    "completed",
    "failed",
    "interrupted",
    "turn_exit_reason",
    "model",
    "platform",
    "telemetry_schema_version",
)
_SCALARS = (str, int, float, bool, type(None))
_USAGE = "usage : /hermes-mobile-token <jeton FCM>"

_journal_lock = threading.Lock()
_token_lock = threading.Lock()  # écriture du jeton par la commande / oubli par le fil d'envoi
_credentials_lock = threading.Lock()
_credentials_cache = {}  # chemin -> (mtime, credentials, project_id)


def register(ctx):
    """Enregistre le hook de fin de tour et la commande du jeton."""
    ctx.register_hook("on_session_end", _on_session_end)
    ctx.register_command(
        "hermes-mobile-token",
        _cmd_token,
        description="Hermes Mobile : mémorise le jeton FCM du téléphone.",
        args_hint="<jeton>",
    )


# --- chemins ---------------------------------------------------------------


def _hermes_home():
    try:
        from hermes_constants import get_hermes_home

        return Path(get_hermes_home())
    except Exception:
        return Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes")


def _state_dir():
    return _hermes_home() / _STATE_DIR


def _tail(token):
    return token[-8:] if isinstance(token, str) else None


def _journal(record):
    line = json.dumps(record, ensure_ascii=False)
    with _journal_lock:
        with open(_LOG_PATH, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")


def _now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


# --- commande /hermes-mobile-token ------------------------------------------


def _cmd_token(raw_args=""):
    token = (raw_args or "").strip() if isinstance(raw_args, str) else ""
    if not token or len(token) > 4096 or any(c.isspace() for c in token):
        return _USAGE
    try:
        state = _state_dir()
        state.mkdir(parents=True, exist_ok=True)
        path = state / _TOKEN_FILE
        with _token_lock:
            try:
                previous = path.read_text(encoding="utf-8").strip()
            except OSError:
                previous = None
            changed = previous != token
            if changed:
                tmp = path.with_name(_TOKEN_FILE + ".tmp")
                tmp.write_text(token, encoding="utf-8")
                try:
                    os.chmod(tmp, 0o600)
                except OSError:
                    pass
                os.replace(tmp, path)
        try:
            _journal({"ts": _now(), "event": "token", "token_tail": _tail(token), "changed": changed})
        except Exception:
            pass
        if changed:
            logger.info("hermes-mobile-notify jeton enregistré (…%s)", _tail(token))
        return "ok"
    except Exception as exc:
        try:
            logger.warning("hermes-mobile-notify: jeton non enregistré: %s", type(exc).__name__)
        except Exception:
            pass
        return "erreur : jeton non enregistré"


# --- hook on_session_end ----------------------------------------------------


def _outcome(kwargs):
    if kwargs.get("interrupted") is True:
        return "stopped"
    if kwargs.get("failed") is True or kwargs.get("completed") is not True:
        return "failed"
    return "succeeded"


def _spawn(target, args):
    thread = threading.Thread(target=target, args=args, name="hermes-mobile-notify", daemon=True)
    thread.start()
    return thread


def _on_session_end(**kwargs):
    started = time.monotonic()
    try:
        record = {"ts": _now(), "event": "session_end"}
        for key in _ALLOWED:
            if key in kwargs:
                value = kwargs[key]
                record[key] = value if isinstance(value, _SCALARS) else type(value).__name__
        extra = sorted(k for k in kwargs if k not in _ALLOWED)
        if extra:
            record["extra_keys"] = extra
        record["outcome"] = _outcome(kwargs)
        if record.get("platform") != "tui":
            # Tours hors app (ex. sous-agents « subagent ») : pas de notification.
            _finish(record, "skipped", None, "platform", started)
            return
        # Résolu ici : un fil neuf ne voit pas la surcharge de HERMES_HOME du tour.
        state = _state_dir()
        _spawn(_deliver, (record, state, started))
    except Exception as exc:  # jamais fatal pour le tour
        try:
            logger.warning("hermes-mobile-notify: hook en échec: %s", type(exc).__name__)
        except Exception:
            pass


def _deliver(record, state, started):
    try:
        try:
            action, status, reason = _send(record, state)
        except Exception as exc:
            action, status, reason = "failed", None, type(exc).__name__
        _finish(record, action, status, reason, started)
    except Exception:
        pass


def _finish(record, action, status, reason, started):
    try:
        record["action"] = action
        record["status"] = status
        if reason:
            record["reason"] = reason
        record["duration_ms"] = round((time.monotonic() - started) * 1000)
        try:
            _journal(record)
        except Exception as exc:
            logger.warning("hermes-mobile-notify: journal impossible: %s", type(exc).__name__)
        logger.info(
            "hermes-mobile-notify session_id=%s platform=%s outcome=%s action=%s status=%s reason=%s duration_ms=%s",
            record.get("session_id"),
            record.get("platform"),
            record.get("outcome"),
            action,
            status,
            reason,
            record["duration_ms"],
        )
    except Exception:
        pass


def _send(record, state):
    session_id = record.get("session_id")
    if not isinstance(session_id, str) or not session_id or len(session_id) > 256:
        return "skipped", None, "no_session_id"
    try:
        token = (state / _TOKEN_FILE).read_text(encoding="utf-8").strip()
    except OSError:
        token = ""
    if not token:
        return "skipped", None, "no_token"
    record["token_tail"] = _tail(token)
    key = state / _KEY_FILE
    if not key.is_file():
        return "skipped", None, "no_key"
    try:
        credentials, project_id = _load_credentials(str(key))
    except Exception:
        return "failed", None, "key_invalid"
    body = _payload(token, session_id, record["outcome"])
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    attempt = 0
    while True:
        attempt += 1
        record["attempts"] = attempt
        last = attempt >= _MAX_ATTEMPTS
        try:
            status, fcm_error = _post(url, body, credentials)
        except Exception as exc:
            if last:
                return "failed", None, type(exc).__name__
            time.sleep(_RETRY_DELAY)
            continue
        if 200 <= status < 300:
            return "sent", status, None
        if fcm_error == "UNREGISTERED":
            _forget_token(state, token)
            return "failed", status, fcm_error
        if status >= 500 and not last:
            time.sleep(_RETRY_DELAY)
            continue
        return "failed", status, fcm_error or "fcm_http"


def _forget_token(state, token):
    """Supprime ``fcm-token`` s'il contient encore ``token`` (jamais un jeton renvoyé depuis)."""
    path = state / _TOKEN_FILE
    try:
        with _token_lock:
            if path.read_text(encoding="utf-8").strip() == token:
                path.unlink()
                logger.info("hermes-mobile-notify jeton refusé par FCM oublié (…%s)", _tail(token))
    except OSError:
        pass


def _payload(token, session_id, outcome):
    return {
        "message": {
            "token": token,
            "notification": {"title": _TITLE, "body": _BODIES[outcome]},
            "data": {"outcome": outcome, "sessionId": session_id},
            "android": {
                "priority": "high",
                "ttl": _TTL,
                "collapse_key": f"hermes:{session_id}",
                "notification": {
                    "channel_id": _CHANNEL,
                    "notification_priority": "PRIORITY_HIGH",
                    "sound": "default",
                    "tag": f"hermes:{session_id}:{outcome}",
                },
            },
        }
    }


# --- transport FCM HTTP v1 (remplacé par l'auto-vérification) ---------------


def _google_credentials(path):
    mtime = os.stat(path).st_mtime
    with _credentials_lock:
        cached = _credentials_cache.get(path)
        if cached and cached[0] == mtime:
            return cached[1], cached[2]
        from google.oauth2 import service_account

        with open(path, encoding="utf-8") as fh:
            raw = json.load(fh)
        # Refuser un endpoint OAuth arbitraire dans le fichier fourni.
        if raw.get("token_uri") != _TOKEN_URI:
            raise ValueError("token_uri")
        credentials = service_account.Credentials.from_service_account_info(raw, scopes=[_SCOPE])
        project_id = credentials.project_id
        if not isinstance(project_id, str) or not re.fullmatch(r"[a-z][a-z0-9-]{4,61}[a-z0-9]", project_id):
            raise ValueError("project_id")
        _credentials_cache[path] = (mtime, credentials, project_id)
        return credentials, project_id


def _http_post(url, body, credentials):
    import requests
    from google.auth.transport.requests import Request

    with _credentials_lock:
        if not credentials.valid:
            request = Request()
            credentials.refresh(lambda **kw: request(**{**kw, "timeout": _TIMEOUT}))
        bearer = credentials.token
    response = requests.post(
        url,
        data=json.dumps(body, separators=(",", ":"), ensure_ascii=False).encode("utf-8"),
        headers={"Authorization": f"Bearer {bearer}", "Content-Type": "application/json; charset=UTF-8"},
        timeout=_TIMEOUT,
        allow_redirects=False,
    )
    return response.status_code, _fcm_error(response)


def _fcm_error(response):
    """Code d'erreur FCM (énuméré, ex. ``UNREGISTERED``) ; jamais le texte libre."""
    if 200 <= response.status_code < 300:
        return None
    try:
        error = response.json().get("error") or {}
        codes = [d.get("errorCode") for d in error.get("details") or () if isinstance(d, dict)]
        for code in codes + [error.get("status")]:
            if isinstance(code, str) and re.fullmatch(r"[A-Z_]{1,40}", code):
                return code
    except Exception:
        pass
    return None


_load_credentials = _google_credentials
_post = _http_post


# --- auto-vérification --------------------------------------------------------


def _self_check():
    import tempfile

    global _LOG_PATH, _hermes_home, _load_credentials, _post, _spawn, _RETRY_DELAY
    saved = (_LOG_PATH, _hermes_home, _load_credentials, _post, _spawn, _RETRY_DELAY)
    token = "synthetic-fcm-token-0123456789-ABCDEFGH"
    hooks, commands, sent, threads, records, spawned = {}, {}, [], [], [], []

    class _Ctx:
        def register_hook(self, name, cb):
            hooks[name] = cb

        def register_command(self, name, handler, description="", args_hint=""):
            commands[name] = handler

    class _Capture(logging.Handler):
        def emit(self, rec):
            records.append(rec)

    def spawn(target, args):
        thread = saved[4](target, args)
        threads.append(thread)
        spawned.append(thread)
        return thread

    def end_turn(**kwargs):
        kwargs.setdefault("platform", "tui")
        started = time.monotonic()
        hooks["on_session_end"](**kwargs)
        elapsed = time.monotonic() - started
        for thread in threads:
            thread.join(5)
        threads.clear()
        with open(_LOG_PATH, encoding="utf-8") as fh:
            return json.loads(fh.readlines()[-1]), elapsed

    register(_Ctx())
    assert set(hooks) == {"on_session_end"} and set(commands) == {"hermes-mobile-token"}
    cmd, capture = commands["hermes-mobile-token"], _Capture()
    logger.addHandler(capture)
    logger.setLevel(logging.INFO)
    with tempfile.TemporaryDirectory() as tmp:
        try:
            home = Path(tmp) / "home"
            state = home / _STATE_DIR
            _LOG_PATH = os.path.join(tmp, "session-end.jsonl")
            _hermes_home = lambda: home
            _spawn = spawn
            _RETRY_DELAY = 0.05

            def post(url, body, credentials):
                sent.append((url, body))
                return 200, None

            _load_credentials = lambda path: ("creds", "hermes-mobile-test")
            _post = post

            # Pas de jeton : rien n'est envoyé.
            line, _ = end_turn(session_id="s1", completed=True, failed=False, interrupted=False, platform="tui")
            assert (line["action"], line["reason"], line["status"]) == ("skipped", "no_token", None), line
            assert not sent

            # Commande : argument vide → usage ; jeton → « ok », stocké.
            assert cmd("") == _USAGE and cmd("   ") == _USAGE and cmd("a b") == _USAGE
            assert cmd(f"  {token}\n") == "ok"
            assert (state / _TOKEN_FILE).read_text(encoding="utf-8") == token
            assert cmd(token) == "ok"

            # Pas de clé : rien n'est envoyé.
            line, _ = end_turn(session_id="s1", completed=True)
            assert (line["action"], line["reason"]) == ("skipped", "no_key"), line
            assert line["token_tail"] == token[-8:]
            assert not sent

            # Jeton + clé : envoi, sans attendre le réseau.
            (state / _KEY_FILE).write_text("{}", encoding="utf-8")

            def slow_post(url, body, credentials):
                time.sleep(0.5)
                return post(url, body, credentials)

            _post = slow_post
            line, elapsed = end_turn(
                session_id="20261029_212234_ce7c72", task_id="t", turn_id="u", completed=True,
                failed=False, interrupted=False, turn_exit_reason="text_response(finish_reason=stop)",
                model="m", platform="tui", messages=["secret"],
            )
            assert elapsed < 0.2, elapsed
            assert (line["action"], line["status"], line["outcome"]) == ("sent", 200, "succeeded"), line
            assert line["attempts"] == 1, line
            assert line["duration_ms"] >= 500 and line["extra_keys"] == ["messages"], line
            url, body = sent[-1]
            assert url == "https://fcm.googleapis.com/v1/projects/hermes-mobile-test/messages:send"
            message = body["message"]
            assert message["token"] == token
            assert message["notification"] == {"title": "Hermes", "body": "Hermes a terminé"}
            assert message["data"] == {"outcome": "succeeded", "sessionId": "20261029_212234_ce7c72"}
            assert message["android"]["notification"]["channel_id"] == "hermes_turn_complete"
            assert "secret" not in json.dumps(body)
            _post = post

            # Arrêt et échec.
            line, _ = end_turn(session_id="s2", completed=False, interrupted=True)
            assert (line["action"], line["outcome"]) == ("sent", "stopped"), line
            assert sent[-1][1]["message"]["notification"]["body"] == "Hermes s'est arrêté"
            line, _ = end_turn(session_id="s2", completed=False, failed=True, interrupted=False)
            assert line["outcome"] == "failed" and sent[-1][1]["message"]["data"]["outcome"] == "failed"

            # Sous-agent (ou toute plateforme hors app) : journalisé, ni fil ni envoi.
            before, forks = len(sent), len(spawned)
            for platform in ("subagent", "cron", "telegram"):
                line, _ = end_turn(session_id="s2-child", completed=True, platform=platform)
                assert (line["action"], line["reason"], line["platform"]) == ("skipped", "platform", platform), line
            assert len(sent) == before and len(spawned) == forks

            token_path = state / _TOKEN_FILE

            def scripted(*answers):
                """Transport rejouant ``answers`` : (statut, code) ou exception."""
                calls = []

                def fake(url, body, credentials):
                    calls.append(body)
                    answer = answers[min(len(calls), len(answers)) - 1]
                    if isinstance(answer, Exception):
                        raise answer
                    if callable(answer):
                        return answer()
                    return answer

                return fake, calls

            # Refus non transitoire (4xx autre qu'UNREGISTERED) : aucun nouvel essai, jeton gardé.
            _post, calls = scripted((400, "INVALID_ARGUMENT"))
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["status"], line["reason"], line["attempts"]) == (
                "failed", 400, "INVALID_ARGUMENT", 1), line
            assert len(calls) == 1 and token_path.read_text(encoding="utf-8") == token

            # Erreur réseau puis succès : un seul nouvel essai, après le délai.
            _post, calls = scripted(ConnectionError("synthetic"), (200, None))
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["status"], line["attempts"]) == ("sent", 200, 2), line
            assert len(calls) == 2 and line["duration_ms"] >= 50, line

            # HTTP 503 puis succès : nouvel essai aussi.
            _post, calls = scripted((503, "UNAVAILABLE"), (200, None))
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["attempts"]) == ("sent", 2) and len(calls) == 2, line

            # Deux erreurs réseau : échec, pas de troisième essai, aucune exception.
            _post, calls = scripted(ConnectionError("synthetic"))
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["status"], line["reason"], line["attempts"]) == (
                "failed", None, "ConnectionError", 2), line
            assert len(calls) == 2

            # 429 : refus 4xx, échec sans nouvel essai, jeton gardé.
            _post, calls = scripted((429, "QUOTA_EXCEEDED"))
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["status"], line["attempts"]) == ("failed", 429, 1), line
            assert len(calls) == 1 and token_path.read_text(encoding="utf-8") == token

            # UNREGISTERED : jeton oublié, sans nouvel essai ; le tour suivant n'envoie rien.
            _post, calls = scripted((404, "UNREGISTERED"))
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["status"], line["reason"], line["attempts"]) == (
                "failed", 404, "UNREGISTERED", 1), line
            assert len(calls) == 1 and not token_path.exists()
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["reason"]) == ("skipped", "no_token"), line
            assert len(calls) == 1

            # UNREGISTERED alors que l'app a renvoyé un autre jeton entre-temps : le nouveau est gardé.
            assert cmd(token) == "ok"
            fresh = "synthetic-fresh-token-9876543210-ZYXWVUTS"

            def resent():
                assert cmd(fresh) == "ok"
                return 404, "UNREGISTERED"

            _post, calls = scripted(resent)
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["reason"]) == ("failed", "UNREGISTERED"), line
            assert token_path.read_text(encoding="utf-8") == fresh
            assert cmd(token) == "ok"
            _post = post

            def bad_key(path):
                raise ValueError("synthetic")

            _load_credentials = bad_key
            line, _ = end_turn(session_id="s3", completed=True)
            assert (line["action"], line["reason"]) == ("failed", "key_invalid"), line

            # Sans session_id : ignoré.
            line, _ = end_turn(completed=True)
            assert (line["action"], line["reason"]) == ("skipped", "no_session_id"), line

            # Journal illisible : le hook et le fil ne lèvent rien.
            _LOG_PATH = tmp
            hooks["on_session_end"](session_id="s4", completed=True, platform="tui")
            for thread in threads:
                thread.join(5)
            threads.clear()
            _LOG_PATH = os.path.join(tmp, "session-end.jsonl")

            # Le jeton complet n'apparaît ni dans le journal ni dans agent.log.
            with open(_LOG_PATH, encoding="utf-8") as fh:
                assert token not in fh.read()
            logged = "\n".join(rec.getMessage() for rec in records)
            assert token not in logged and token[-8:] in logged

            # Code d'erreur FCM : seulement une valeur énumérée.
            class _Resp:
                status_code = 404

                def json(self):
                    return {"error": {"status": "NOT_FOUND", "message": "texte libre",
                                      "details": [{"errorCode": "UNREGISTERED"}]}}

            assert _fcm_error(_Resp()) == "UNREGISTERED"
            _Resp.json = lambda self: {"error": {"status": "free text"}}
            assert _fcm_error(_Resp()) is None
        finally:
            _LOG_PATH, _hermes_home, _load_credentials, _post, _spawn, _RETRY_DELAY = saved
            logger.removeHandler(capture)
    print("hermes-mobile-notify: auto-vérification réussie")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    _self_check()
