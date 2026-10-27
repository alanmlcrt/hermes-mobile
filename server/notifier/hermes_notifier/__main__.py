"""Point d'entrée ``python -m hermes_notifier``."""

from .service import main

if __name__ == "__main__":
    raise SystemExit(main())
