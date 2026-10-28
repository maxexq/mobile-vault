"""Offline tests: no packages, account credentials or external requests required."""
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("sentry_forward", Path(__file__).parents[1] / "sentry_forward.py")
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)
DSN = "https://" + "a" * 32 + "@o1.ingest.de.sentry.io/123"


def row(**changes):
    data = {"text": "ได้รับของ: ไรเฟิล", "category": "loot", "kind": "good", "km": 12.5,
            "generation": 2, "environment": "uat",
            "detail": {"base": "hunting_rifle", "rar": 2, "salvaged": False,
                       "email": "private@example.invalid", "token": "DO-NOT-FORWARD"},
            "email": "private@example.invalid", "save": {"secret": "DO-NOT-FORWARD"}}
    result = {"id": 42, "player_id": "DEMO-PLAYER", "user_id": "PRIVATE-AUTH-UUID",
              "session": "session-a", "t": "2026-10-28T10:00:00+00:00", "cat": "activity",
              "msg": "loot.received", "data": data, "game_version": "4.7.0-alpha.2"}
    result.update(changes)
    return result


class FakeSource:
    def __init__(self, rows, ack_count=None):
        self.rows, self.ack_count, self.calls = rows, ack_count, []

    def rpc(self, name, body):
        self.calls.append((name, body))
        if name == "sentry_claim":
            return self.rows
        if name == "sentry_ack":
            return len(self.rows) if self.ack_count is None else self.ack_count
        return len(self.rows)


class ForwardTests(unittest.TestCase):
    def test_destination_is_https_sentry_only(self):
        self.assertEqual(relay.endpoint(DSN)[0], "https://o1.ingest.de.sentry.io/api/123/envelope/")
        for bad in (DSN.replace("https:", "http:"), DSN.replace("sentry.io", "sentry.io.evil.invalid"),
                    DSN + "?token=secret", DSN.replace("/123", "/abc"), "https://secret:password@host.invalid/1"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                relay.endpoint(bad)

    def test_supabase_destination_rejects_credential_redirect_targets(self):
        for url in ("http://localhost:8000", "https://project.supabase.co.evil.invalid", "https://project.supabase.co/x"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                relay.Supabase(url, "secret")

    def test_searchable_public_id_and_typed_attributes(self):
        log, issue = relay.mapped(row(), "test")
        self.assertIsNone(issue)
        self.assertEqual(log["attributes"]["player_id"]["value"], "DEMO-PLAYER")
        self.assertEqual(log["attributes"]["event.name"]["value"], "loot.received")
        self.assertEqual(log["attributes"]["sentry.environment"]["value"], "test")
        self.assertEqual(log["attributes"]["game.environment"]["value"], "uat")
        self.assertEqual(log["attributes"]["game.salvaged"]["type"], "boolean")
        self.assertEqual(log["attributes"]["game.rar"]["type"], "integer")
        self.assertEqual(log["attributes"]["game.km"]["type"], "double")

    def test_private_and_unknown_fields_never_forwarded(self):
        output = relay.envelope([row()], DSN, "test").decode()
        for forbidden in ("PRIVATE-AUTH-UUID", "private@example.invalid", "DO-NOT-FORWARD", '"save"', '"token"'):
            self.assertNotIn(forbidden, output)

    def test_gameplay_warning_is_not_a_bug(self):
        log, issue = relay.mapped(row(data={"text": "ลูกเรือเครียด", "kind": "bad"}), "test")
        self.assertEqual(log["level"], "warn")
        self.assertIsNone(issue)

    def test_script_error_creates_an_issue_with_stable_retry_id(self):
        source = row(cat="error", msg="script failed (game.gd:10)", data={"kind": "script"})
        log, issue = relay.mapped(source, "test")
        self.assertEqual(log["level"], "error")
        self.assertEqual(issue["user"]["id"], "DEMO-PLAYER")
        self.assertEqual(issue["event_id"], relay.mapped(source, "test")[1]["event_id"])
        self.assertNotEqual(issue["event_id"], relay.mapped(source, "production")[1]["event_id"])

    def test_engine_warning_and_god_test_are_not_real_issues(self):
        for kind in ("warning", "test"):
            self.assertIsNone(relay.mapped(row(cat="error", data={"kind": kind}), "test")[1])

    def test_envelope_lengths_count_utf8_bytes(self):
        lines = relay.envelope([row()], DSN, "test").splitlines()
        header, payload = json.loads(lines[1]), json.loads(lines[2])
        self.assertEqual(header["length"], len(lines[2]))
        self.assertEqual(header["content_type"], "application/vnd.sentry.items.log+json")
        self.assertEqual(header["item_count"], len(payload["items"]))
        self.assertEqual(len(payload["items"][0]["trace_id"]), 32)

    def test_protocol_batch_limit(self):
        relay.envelope([row()] * 100, DSN, "test")
        for count in (0, 101):
            with self.assertRaises(ValueError):
                relay.envelope([row()] * count, DSN, "test")

    def test_only_selected_categories_forwarded(self):
        for category in ("session", "sample", "save", "god"):
            with self.assertRaises(ValueError):
                relay.mapped(row(cat=category), "test")

    def test_acknowledges_only_after_success(self):
        source = FakeSource([row()])
        seen = []
        self.assertEqual(relay.forward_once(source, DSN, "test", lambda *args: seen.append(args)), 1)
        self.assertEqual(len(seen), 1)
        self.assertEqual([c[0] for c in source.calls], ["sentry_claim", "sentry_ack"])
        self.assertEqual(source.calls[0][1]["p_worker"], source.calls[1][1]["p_worker"])

    def test_rate_limited_batch_is_retained(self):
        source = FakeSource([row()])
        def fail(*_):
            raise relay.DeliveryError(429, 120)
        with self.assertRaises(relay.DeliveryError):
            relay.forward_once(source, DSN, "test", fail)
        self.assertEqual([c[0] for c in source.calls], ["sentry_claim", "sentry_retry"])
        self.assertEqual(source.calls[-1][1]["p_delay"], 120)

    def test_disabled_or_empty_outbox_does_not_send(self):
        self.assertEqual(relay.forward_once(FakeSource([]), DSN, "test", lambda *_: self.fail("must not send")), 0)

    def test_invalid_config_cannot_claim_rows(self):
        source = FakeSource([row()])
        with self.assertRaises(ValueError):
            relay.forward_once(source, "invalid", "test")
        self.assertEqual(source.calls, [])

    def test_expired_lease_is_not_reported_as_success(self):
        with self.assertRaises(relay.DeliveryError):
            relay.forward_once(FakeSource([row()], ack_count=0), DSN, "test", lambda *_: None)


if __name__ == "__main__":
    unittest.main()
