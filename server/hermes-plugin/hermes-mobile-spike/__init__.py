"""Plugin d'essai Hermes Mobile : journalise chaque ``on_session_end``.

Ajoute une ligne JSON (horodatage + métadonnées du hook) à ``session-end.jsonl``
dans le dossier du plugin. Seuls les kwargs connus (identifiants, booléens,
modèle, plateforme) sont recopiés ; pour une clé inattendue, seul son nom est
noté. Aucun réseau, aucune exception ne remonte au tour.
"""

import json
import logging
import os
import time
from datetime import datetime, timezone

logger = logging.getLogger("hermes_mobile_spike")

_LOG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "session-end.jsonl")

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


def register(ctx):
    """Enregistre le callback ``on_session_end``."""
    ctx.register_hook("on_session_end", _on_session_end)


def _on_session_end(**kwargs):
    try:
        record = {"ts": datetime.now(timezone.utc).isoformat(timespec="milliseconds")}
        for key in _ALLOWED:
            if key in kwargs:
                value = kwargs[key]
                record[key] = value if isinstance(value, _SCALARS) else type(value).__name__
        extra = sorted(k for k in kwargs if k not in _ALLOWED)
        if extra:
            record["extra_keys"] = extra
        line = json.dumps(record, ensure_ascii=False)
        with open(_LOG_PATH, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
        logger.info(
            "hermes-mobile-spike on_session_end session_id=%s platform=%s completed=%s interrupted=%s",
            record.get("session_id"),
            record.get("platform"),
            record.get("completed"),
            record.get("interrupted"),
        )
    except Exception as exc:  # jamais fatal pour le tour
        try:
            logger.warning("hermes-mobile-spike: écriture impossible: %s", exc)
        except Exception:
            pass


def _self_check():
    import tempfile

    global _LOG_PATH
    original = _LOG_PATH
    hooks = {}

    class _Ctx:
        def register_hook(self, name, cb):
            hooks[name] = cb

    register(_Ctx())
    assert set(hooks) == {"on_session_end"}, hooks
    cb = hooks["on_session_end"]

    with tempfile.TemporaryDirectory() as tmp:
        try:
            _LOG_PATH = os.path.join(tmp, "session-end.jsonl")
            cb(session_id="s1", task_id="t1", turn_id="u1", completed=True, failed=False,
               interrupted=False, turn_exit_reason="final_response", model="m",
               platform="tui", telemetry_schema_version=1, messages=["secret"])
            cb(session_id="s1", completed=False, interrupted=True, platform="tui")
            with open(_LOG_PATH, encoding="utf-8") as fh:
                lines = [json.loads(l) for l in fh]
            assert len(lines) == 2, lines
            assert lines[0]["completed"] is True and lines[0]["platform"] == "tui"
            assert lines[0]["extra_keys"] == ["messages"]
            assert "secret" not in json.dumps(lines), "contenu recopié"
            assert lines[1]["interrupted"] is True

            # Valeur non scalaire sur une clé autorisée : seul son type est noté.
            cb(session_id="s3", model={"x": "secret"})
            with open(_LOG_PATH, encoding="utf-8") as fh:
                last = json.loads(fh.readlines()[-1])
            assert last["model"] == "dict", last
            assert "secret" not in json.dumps(last), "contenu recopié"

            # Fichier non inscriptible : aucune exception, un avertissement.
            warnings = []

            class _Capture(logging.Handler):
                def emit(self, rec):
                    if rec.levelno == logging.WARNING:
                        warnings.append(rec)

            handler = _Capture()
            logger.addHandler(handler)
            try:
                _LOG_PATH = tmp  # un dossier ne s'ouvre pas en écriture
                started = time.monotonic()
                cb(session_id="s2", completed=True)
                assert time.monotonic() - started < 1
            finally:
                logger.removeHandler(handler)
            assert len(warnings) == 1, warnings
        finally:
            _LOG_PATH = original
    print("hermes-mobile-spike: auto-vérification réussie")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    _self_check()
