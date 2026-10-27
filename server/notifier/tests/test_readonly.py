"""Lecture seule : allowlists RPC/REST et dialecte WS."""

from __future__ import annotations

import asyncio
import unittest

from hermes_notifier.hermes.rpc import (
    GATEWAY_PROTOCOL,
    GatewayRpc,
    HermesProtocolError,
    HermesRest,
    ws_url,
)

from . import support


class FakeWebSocket:
    def __init__(self) -> None:
        self.sent: list[str] = []
        self.closed = False

    async def send(self, raw: str) -> None:
        self.sent.append(raw)

    async def close(self) -> None:
        self.closed = True


class ReadOnlyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.contracts = support.contracts()

    def test_rpc_interdits_sont_refuses_avant_envoi(self) -> None:
        async def scenario() -> None:
            websocket = FakeWebSocket()
            rpc = GatewayRpc(websocket, self.contracts)
            for method in (
                "prompt.submit",
                "session.interrupt",
                "session.create",
                "session.title",
                "file.attach",
                "client.capabilities",
            ):
                with self.assertRaises(HermesProtocolError):
                    await rpc.call(method, {})
            self.assertEqual(websocket.sent, [])

        asyncio.run(scenario())

    def test_route_rest_hors_allowlist_refusee(self) -> None:
        rest = HermesRest("http://127.0.0.1:1", contracts=self.contracts)
        for method, path in (
            ("POST", "/v1/prompt.submit"),
            ("POST", "/api/prompt"),
            ("DELETE", "/api/sessions"),
            ("GET", "/auth/password-login"),
        ):
            with self.assertRaises(HermesProtocolError):
                rest.request(method, path)

    def test_url_websocket_suit_l_origine(self) -> None:
        self.assertEqual(ws_url("http://hermes:8080"), "ws://hermes:8080/api/ws")
        self.assertEqual(
            ws_url("https://hermes.example/base"), "wss://hermes.example/base/api/ws"
        )
        self.assertEqual(GATEWAY_PROTOCOL, "hermes-gateway-v1")

    def test_origin_invalide(self) -> None:
        with self.assertRaises(HermesProtocolError):
            HermesRest("ftp://hermes", contracts=self.contracts)
        with self.assertRaises(HermesProtocolError):
            HermesRest("http://", contracts=self.contracts)


if __name__ == "__main__":
    unittest.main()
