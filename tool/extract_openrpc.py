"""Extrait reproductible du contrat public épinglé, références locales incluses."""
import argparse
import copy
import json
from pathlib import Path

METHODS = {"gateway.capabilities", "ping", "client.capabilities",
           "session.events.since", "session.create", "file.attach",
           "session.list", "session.history", "session.resume", "session.status",
           "prompt.submit", "session.interrupt", "session.title"}
NOTIFICATIONS = {"gateway.ready", "message.start", "message.delta", "message.complete",
                 "message.interim", "error", "session.info", "status.update",
                 "sessions.changed", "session.title"}
COMMIT = "9e01b44dd23978f9ff40b7837467f3a9f1582130"


def extract(source: dict) -> dict:
    output = {"openrpc": source["openrpc"], "info": copy.deepcopy(source["info"]),
              "methods": [m for m in source["methods"] if m["name"] in METHODS],
              "components": {"schemas": {}},
              "x-notifications": [m for m in source["x-notifications"] if m["name"] in NOTIFICATIONS],
              "x-provenance": {"release": "v0.22.2+1690 (main 9e01b44)", "commit": COMMIT,
                  "kind": "excerpt", "evidence": "documentary",
                  "source": f"https://github.com/NousResearch/hermes-agent/blob/{COMMIT}/apps/shared/src/gateway-contract.openrpc.json"}}
    seen = set()

    def visit(value):
        if isinstance(value, list):
            for item in value:
                visit(item)
        elif isinstance(value, dict):
            for key, item in value.items():
                if key == "$ref":
                    if item in seen:
                        continue
                    if not item.startswith("#/components/schemas/"):
                        raise ValueError(f"Référence non prise en charge : {item}")
                    seen.add(item)
                    name = item.removeprefix("#/components/schemas/")
                    schema = source["components"]["schemas"][name]
                    output["components"]["schemas"][name] = schema
                    visit(schema)
                else:
                    visit(item)
    visit(output["methods"])
    visit(output["x-notifications"])
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = extract(json.loads(args.source.read_text(encoding="utf-8")))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(result['methods'])} méthodes ; {len(result['components']['schemas'])} schémas.")


if __name__ == "__main__":
    main()
