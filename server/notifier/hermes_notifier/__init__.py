"""Observateur de fins de travail Hermes.

Ce paquet est un add-on Home Assistant autonome : il expose les endpoints du
contrat de suivi, garde registre et outbox dans ``/data`` et observe Hermes en
lecture seule. Aucun push FCM réel n'est envoyé en 5.2 ; le transport est un
dry-run local.
"""

__version__ = "0.1.3"
