#!/usr/bin/env python3
"""Forward opted-in activity/error rows from Supabase to Sentry; Python stdlib only.

Server env: SUPABASE_URL, SUPABASE_SERVICE_KEY, SENTRY_DSN, SENTRY_ENVIRONMENT.
Requires migration 0007, explicitly enabled by an owner. --demo sends synthetic
data only (needs just SENTRY_DSN); --dry-run is fully offline and prints counts only.
Protocol: https://develop.sentry.dev/sdk/telemetry/logs/ (stable 3.1.0).
"""
import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

SDK = {"name": "mobile-vault.sentry-forward", "version": "1.0.0"}
DETAIL_KEYS = {"base", "rar", "salvaged", "item_level", "crew_id", "happiness", "test",
               "food", "water", "power", "scrap", "fuel", "crops", "meat", "components",
               "stimpack", "radaway", "ammo", "antibiotics"}
SEVERITY = {"info": 9, "warn": 13, "error": 17}


class DeliveryError(Exception):
    def __init__(self, status=0, retry_after=60):
        super().__init__(f"upstream request failed (HTTP {status})")
        self.retry_after = retry_after


def json_bytes(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")


def endpoint(dsn):
    """Validate before a privileged server makes an outbound connection."""
    p = urllib.parse.urlsplit(dsn)
    if (p.scheme != "https" or not p.username or p.password or p.query or p.fragment
            or not p.hostname or not p.hostname.endswith(".sentry.io") or p.port not in (None, 443)):
        raise ValueError("SENTRY_DSN must be an HTTPS Sentry SaaS ingestion DSN")
    project = p.path.strip("/")
    if not project.isdigit() or not re.fullmatch(r"[a-fA-F0-9]{16,64}", p.username):
        raise ValueError("SENTRY_DSN has an invalid project or public key")
    return f"https://{p.hostname}/api/{project}/envelope/", p.username


def timestamp(value):
    if isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value):
        return float(value)
    return dt.datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()


def attr(value):
    if isinstance(value, bool):
        return {"type": "boolean", "value": value}
    if isinstance(value, int):
        return {"type": "integer", "value": value}
    if isinstance(value, float) and math.isfinite(value):
        return {"type": "double", "value": value}
    if isinstance(value, str):
        return {"type": "string", "value": value[:1000]}
    return None


def mapped(row, environment):
    """Allowlist attributes; never forward auth UUIDs, email, or arbitrary save data."""
    data = row.get("data") if isinstance(row.get("data"), dict) else {}
    category = row.get("cat")
    if category not in ("activity", "error"):
        raise ValueError("only activity and error rows can be forwarded")
    error = category == "error" and data.get("kind") not in ("warning", "test")
    level = "error" if error else ("warn" if data.get("kind") in ("bad", "warn", "warning") else "info")
    attributes = {
        "user.id": str(row.get("player_id", "")), "player_id": str(row.get("player_id", "")),
        "session_id": str(row.get("session", "")), "event.name": str(row.get("msg", ""))[:100],
        "event.category": str(data.get("category", category)), "source.log_id": str(row["id"]),
        "sentry.environment": environment, "sentry.release": str(row.get("game_version") or "unknown"),
        "sentry.sdk.name": SDK["name"], "sentry.sdk.version": SDK["version"],
    }
    for key in ("km", "generation", "environment"):
        if key in data and attr(data[key]) is not None:
            attributes["game." + key] = data[key]
    detail = data.get("detail") if isinstance(data.get("detail"), dict) else {}
    for key in DETAIL_KEYS & detail.keys():
        if attr(detail[key]) is not None:
            attributes["game." + key] = detail[key]
    # Stable per-row identity makes retried error events deduplicate in Sentry.
    identity = hashlib.sha256(f"{environment}:{row['id']}".encode()).hexdigest()[:32]
    body = str(data.get("text", row.get("msg", "")))[:1000]
    log = {"timestamp": timestamp(row["t"]), "trace_id": identity, "level": level,
           "severity_number": SEVERITY[level], "body": body,
           "attributes": {k: attr(v) for k, v in attributes.items()}}
    issue = None
    if error:
        issue = {"event_id": identity, "timestamp": log["timestamp"], "platform": "other",
                 "level": "error", "logger": "godot", "message": body,
                 "environment": environment, "release": attributes["sentry.release"],
                 "user": {"id": attributes["player_id"]},
                 "tags": {"player_id": attributes["player_id"], "session_id": attributes["session_id"]},
                 "contexts": {"trace": {"trace_id": identity, "span_id": identity[:16], "op": "game.error"}}}
    return log, issue


def envelope(rows, dsn, environment):
    endpoint(dsn)
    if not 1 <= len(rows) <= 100:
        raise ValueError("a batch must contain 1-100 logs")
    converted = [mapped(r, environment) for r in rows]
    lines = [json_bytes({"dsn": dsn, "sdk": SDK, "sent_at": dt.datetime.now(dt.timezone.utc).isoformat()})]
    payload = json_bytes({"items": [log for log, _ in converted]})
    lines.extend((json_bytes({"type": "log", "item_count": len(rows),
                             "content_type": "application/vnd.sentry.items.log+json", "length": len(payload)}), payload))
    for _, issue in converted:
        if issue:
            payload = json_bytes(issue)
            lines.extend((json_bytes({"type": "event", "content_type": "application/json", "length": len(payload)}), payload))
    return b"\n".join(lines) + b"\n"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward a server secret or event body to another destination.


def request(url, body, headers):
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.build_opener(NoRedirect()).open(req, timeout=30) as result:
            raw = result.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        delay = 60
        try:
            delay = max(60, min(3600, int(float(exc.headers.get("Retry-After", "60")))))
        except ValueError:
            pass
        # A rate-limit header may accompany a successful response too (handled below
        # by the next request's 429). Failed batches are retained in the DB outbox.
        raise DeliveryError(exc.code, delay) from None
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        raise DeliveryError() from None


def send(rows, dsn, environment):
    url, key = endpoint(dsn)
    return request(url, envelope(rows, dsn, environment), {
        "Content-Type": "application/x-sentry-envelope",
        "X-Sentry-Auth": f"Sentry sentry_version=7, sentry_client={SDK['name']}/{SDK['version']}, sentry_key={key}",
    })


class Supabase:
    def __init__(self, url, key):
        p = urllib.parse.urlsplit(url)
        if (p.scheme != "https" or not p.hostname or not p.hostname.endswith(".supabase.co")
                or p.username or p.password or p.query or p.fragment or p.path not in ("", "/")
                or p.port not in (None, 443)):
            raise ValueError("SUPABASE_URL must be an HTTPS Supabase project URL")
        self.url, self.key = url.rstrip("/"), key

    def rpc(self, name, body):
        headers = {"Content-Type": "application/json", "apikey": self.key}
        if self.key.startswith("eyJ"):
            headers["Authorization"] = "Bearer " + self.key
        return request(self.url + "/rest/v1/rpc/" + name, json_bytes(body), headers)


def forward_once(source, dsn, environment, send_batch=send):
    endpoint(dsn)  # Configuration errors cannot strand a claimed batch.
    worker = str(uuid.uuid4())
    rows = source.rpc("sentry_claim", {"p_worker": worker, "p_limit": 100})
    if not rows:
        return 0
    ids = [r["id"] for r in rows]
    try:
        send_batch(rows, dsn, environment)
    except (DeliveryError, ValueError) as exc:
        source.rpc("sentry_retry", {"p_worker": worker, "p_ids": ids,
                                   "p_delay": getattr(exc, "retry_after", 60)})
        raise
    acknowledged = source.rpc("sentry_ack", {"p_worker": worker, "p_ids": ids})
    if acknowledged != len(ids):
        raise DeliveryError()  # Lease expired: leave rows retryable, never silently drop.
    return len(ids)


def demo_rows():
    now = time.time()
    return [{"id": "synthetic-" + uuid.uuid4().hex, "player_id": "DEMO-PLAYER", "session": "setup-test",
             "t": now, "cat": "activity", "msg": "monitoring.test", "game_version": "setup-test",
             "data": {"text": "Sentry connection verified — synthetic game activity, no player data",
                      "category": "event", "kind": "info", "detail": {"test": True}}}]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--demo", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-batches", type=int, default=10)
    args = parser.parse_args()
    if args.dry_run:
        mapped(demo_rows()[0], "setup-test")
        print("DRY RUN: synthetic payload valid; no network, credentials or player data read")
        return
    dsn = os.environ.get("SENTRY_DSN", "")
    environment = os.environ.get("SENTRY_ENVIRONMENT", "")
    if args.demo:
        send(demo_rows(), dsn, "setup-test")
        print("Sentry accepted one synthetic setup-test log (no player data)")
        return
    if environment not in ("production", "test", "staging", "uat", "dev"):
        raise ValueError("SENTRY_ENVIRONMENT must explicitly identify the source environment")
    source = Supabase(os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_SERVICE_KEY", ""))
    if not source.key:
        raise ValueError("SUPABASE_SERVICE_KEY is required on the server")
    count = 0
    for _ in range(max(1, min(100, args.max_batches))):
        n = forward_once(source, dsn, environment)
        count += n
        if n == 0:
            break
    print(f"Sentry forward complete: {count} logs acknowledged")


if __name__ == "__main__":
    try:
        main()
    except (DeliveryError, ValueError) as exc:
        # No traceback or response body: upstream URLs/keys and player logs stay private.
        print(str(exc), file=sys.stderr)
        sys.exit(1)
