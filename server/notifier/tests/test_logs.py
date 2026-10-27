"""Journaux : champs sûrs, rédaction et absence de contenu."""

from __future__ import annotations

import json
import unittest

from hermes_notifier.logs import EventLogger, Redactor, capture_logger


class LogsTest(unittest.TestCase):
    def test_redacteur_masque_les_secrets_connus(self) -> None:
        redactor = Redactor()
        redactor.add("subscription-secrete")
        redactor.add("execution-secrete")
        redactor.add("session-secrete")
        # Aucune valeur connue ne couvre le bearer : seules les expressions
        # régulières doivent le masquer.
        text = (
            "subscription-secrete execution-secrete session-secrete "
            "Authorization: Bearer abc.def.ghi"
        )
        scrubbed = redactor.scrub(text)
        for value in ("subscription-secrete", "execution-secrete", "session-secrete"):
            self.assertNotIn(value, scrubbed)
        self.assertIn("[redacted]", scrubbed)
        self.assertNotIn("abc.def.ghi", scrubbed)

    def test_redacteur_masque_les_champs_json_et_opaques(self) -> None:
        redactor = Redactor()
        text = json.dumps(
            {
                "subscriptionId": "abcdefghijklmnopqrstuvwx",
                "executionId": "abcdefghijklmnopqrstuvwx",
                "sessionId": "abcdefghijklmnopqrstuvwx",
                "fcmToken": "jeton",
                "contenu": "SYNTHETIC",
            }
        )
        scrubbed = redactor.scrub(text)
        for value in ("abcdefghijklmnopqrstuvwx", "jeton"):
            self.assertNotIn(value, scrubbed)
        self.assertNotIn("SYNTHETIC", scrubbed)

    def test_logger_filtre_les_champs_non_surs(self) -> None:
        redactor = Redactor()
        logger, messages = capture_logger(redactor)
        logger.info(
            "observer.terminal",
            terminal="succeeded",
            subscriptionId="secret-sub",
            sessionId="secret-session",
            text="SYNTHETIC",
        )
        self.assertEqual(len(messages), 1)
        self.assertIn("observer.terminal", messages[0])
        self.assertIn("succeeded", messages[0])
        self.assertNotIn("secret-sub", messages[0])
        self.assertNotIn("secret-session", messages[0])
        self.assertNotIn("SYNTHETIC", messages[0])

    def test_exception_ne_journalise_que_la_classe(self) -> None:
        logger, messages = capture_logger(Redactor())
        logger.exception_code(
            "observer.watch_error", RuntimeError("secret-sub session")
        )
        self.assertIn("RuntimeError", messages[0])
        self.assertNotIn("secret-sub", messages[0])
        self.assertNotIn("session", messages[0])

    def test_troncature_borne_la_memoire(self) -> None:
        redactor = Redactor(limit=8)
        for index in range(20):
            redactor.add(f"valeur-{index:02d}")
        self.assertLessEqual(len(redactor), 8)
        # Les valeurs les plus récentes restent masquées ; les plus anciennes
        # sont oubliées pour borner la mémoire du processus.
        self.assertEqual(redactor.scrub("valeur-19"), "[redacted]")
        self.assertEqual(redactor.scrub("valeur-18"), "[redacted]")
        self.assertEqual(redactor.scrub("valeur-00"), "valeur-00")


if __name__ == "__main__":
    unittest.main()
