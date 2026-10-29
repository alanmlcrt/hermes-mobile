#!/usr/bin/env sh
set -eu

# Réseau hôte : écouter uniquement sur la boucle locale (cible Tailscale Services).
export HERMES_NOTIFIER_BIND="${HERMES_NOTIFIER_BIND:-127.0.0.1}"

exec python -m hermes_notifier
