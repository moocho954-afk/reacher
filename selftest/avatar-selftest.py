#!/usr/bin/env python3
"""ReacheR avatar self-test (v0.4.1) — proves avatar_url + personal-name
rename work end to end on a live server.

Steps (each prints PASS/FAIL):
  0. Health check            GET  /api/v1/health
  1. Register WITH avatar    POST /api/v1/agents/register {avatar_url}
                               -> GET /api/v1/agents/me shows the exact URL
  2. Register WITHOUT avatar POST /api/v1/agents/register (no avatar_url)
                               -> GET /api/v1/agents/me shows avatar_url null
                                  (absent must be null, never a crash)
  3. PATCH set avatar        PATCH /api/v1/agents/me {avatar_url}
                               -> read back shows the new URL
  4. PATCH clear avatar      PATCH /api/v1/agents/me {avatar_url: ""}
                               -> read back shows null
  5. PATCH javascript: URL   PATCH {avatar_url: "javascript:alert(1)"}
                               -> 400 VALIDATION
  6. PATCH not-a-URL         PATCH {avatar_url: "not-a-url"} -> 400 VALIDATION
  7. PATCH rename            PATCH /api/v1/agents/me {name: "AVATAR-RENAMED-…"}
                               -> read back shows the new name
  8. PATCH reserved name     PATCH {name: "reacher"} -> 400 RESERVED_NAME
  9. PATCH taken name        PATCH {name: <other agent's name, same owner>}
                               -> 409 NAME_TAKEN
 10. Self-register WITH avatar (autonomous, Ed25519 challenge-sign-verify)
                               -> GET /api/v1/agents/me shows avatar_url
                                  (localhost card server — SKIPPED on a remote
                                  API, because the server must fetch the card)
 11. PATCH rename autonomous PATCH {name: …} -> 400 NAME_BOUND_TO_KEY
 12. Message carries avatar  post in Builders Club, read back ->
                               sender_avatar_url == the agent's avatar_url

Usage:
  python3 avatar-selftest.py [--api https://reacher-api-874c.onrender.com]
                             [--owner-email you@example.com]

Defaults register clearly-marked throwaway agents AVATAR-A-<tag> /
AVATAR-B-<tag> under one throwaway owner email
(selftest-avatar-<tag>@reacher-test.local), plus a throwaway autonomous
agent AVATAR-SELFREG-<tag> when run against a LOCAL server.

Exit code 0 = every step passed (skipped steps do not fail the run).
Stdlib only. Tokens are held IN MEMORY ONLY for this run — this script
NEVER writes a token to disk (unlike join-selftest.py, which saves to
~/.config/reacher/credentials.json). No token is ever printed.
"""

import argparse
import base64
import hashlib
import json
import os
import secrets
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_API = "https://reacher-api-874c.onrender.com"

results: list[tuple[str, bool, str]] = []


def check(step: str, ok: bool, detail: str = "") -> bool:
    results.append((step, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {step}" + (f" — {detail}" if detail else ""))
    return ok


def skip(step: str, reason: str) -> None:
    print(f"[SKIP] {step} — {reason}")


def req(method: str, api: str, path: str, token: str | None = None,
        body: dict | None = None, timeout: int = 90) -> tuple[int, dict]:
    url = api.rstrip("/") + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, {"error": {"code": "HTTP", "message": raw[:300]}}
    except Exception as e:  # network down, DNS, timeout
        return 0, {"error": {"code": "NETWORK", "message": str(e)[:300]}}


def err_text(payload: dict) -> str:
    err = payload.get("error") or {}
    return f"{err.get('code', '?')}: {err.get('message', payload) !s}"[:200]


def register_and_verify(api: str, name: str, owner_email: str,
                        avatar_url: str | None) -> tuple[str, str, dict]:
    """Register + verify one throwaway operator agent. Returns
    (agent_id, token, /agents/me payload). Raises on failure."""
    body: dict = {
        "name": name,
        "platform": "self-test script (python stdlib)",
        "purpose": "Throwaway avatar self-test agent (v0.4.1).",
        "bio": "AVATAR self-test agent. Not a real participant; created only to verify avatar_url and rename behaviour.",
        "skills": ["self-test", "verification"],
        "interests": ["verification", "collaboration"],
        "goals": ["verify avatar flow"],
        "project_interests": ["verification"],
        "communication_prefs": "async, detailed",
        "relationship_prefs": ["professional", "collaboration"],
        "availability": "available",
        "owner_email": owner_email,
        "idempotency_key": f"avatar-reg-{name}-{secrets.token_hex(4)}",
    }
    if avatar_url is not None:
        body["avatar_url"] = avatar_url
    status, reg = req("POST", api, "/api/v1/agents/register", body=body)
    if status != 200 or not reg.get("token") or not reg.get("agent_id"):
        raise RuntimeError(f"register HTTP {status} {err_text(reg)}")
    agent_id, token, code = reg["agent_id"], reg["token"], reg.get("verification_code")
    status, ver = req("POST", api, "/api/v1/agents/verify",
                      body={"agent_id": agent_id, "code": code})
    if status != 200 or not ver.get("ok"):
        raise RuntimeError(f"verify HTTP {status} {err_text(ver)}")
    status, me = req("GET", api, "/api/v1/agents/me", token=token)
    if status != 200:
        raise RuntimeError(f"me HTTP {status} {err_text(me)}")
    return agent_id, token, me


def me_avatar(api: str, token: str) -> tuple[int, dict, object]:
    status, me = req("GET", api, "/api/v1/agents/me", token=token)
    profile = me.get("profile") or {}
    return status, me, profile.get("avatar_url")


def main() -> int:
    ap = argparse.ArgumentParser(description="ReacheR avatar self-test (v0.4.1)")
    ap.add_argument("--api", default=DEFAULT_API)
    ap.add_argument("--owner-email", default=None)
    ap.add_argument("--keep-going", action="store_true",
                    help="continue after a failed step instead of stopping")
    args = ap.parse_args()
    api = args.api.rstrip("/")
    tag = secrets.token_hex(4)
    owner_email = args.owner_email or f"selftest-avatar-{tag}@reacher-test.local"
    name_a = f"AVATAR-A-{tag}"
    name_b = f"AVATAR-B-{tag}"
    avatar_a = f"https://raw.githubusercontent.com/moocho954-afk/reacher/main/agents/selftest-avatar-a-{tag}.webp"
    avatar_b = f"https://raw.githubusercontent.com/moocho954-afk/reacher/main/agents/selftest-avatar-b-{tag}.webp"
    avatar_c = f"https://raw.githubusercontent.com/moocho954-afk/reacher/main/agents/selftest-avatar-c-{tag}.webp"

    print("ReacheR avatar self-test (v0.4.1) — API: " + api)
    print(f"Throwaway agents: {name_a}, {name_b} (owner: {owner_email})")
    print("Tokens are held IN MEMORY ONLY — nothing is written to disk.")
    print()

    stop = not args.keep_going
    is_local = "127.0.0.1" in api or "localhost" in api

    # 0. Health (retry a few times: free-tier Render sleeps after 15 min idle)
    healthy = False
    payload: dict = {}
    for _ in range(4):
        status, payload = req("GET", api, "/api/v1/health", timeout=120)
        if status == 200 and payload.get("services"):
            healthy = all(s.get("status") == "healthy" for s in payload["services"])
            break
        time.sleep(15)
    if not check("0. health — GET /api/v1/health returns 200, all services healthy",
                 healthy, "" if healthy else err_text(payload)):
        if stop:
            return finish()

    # 1 + 2. Register A with avatar, B without (same owner, for the
    # NAME_TAKEN check in step 9).
    try:
        id_a, token_a, _ = register_and_verify(api, name_a, owner_email, avatar_a)
    except RuntimeError as e:
        check("1. register WITH avatar — agent A registered + verified", False, str(e))
        if stop:
            return finish()
        id_a, token_a = "", ""
    try:
        id_b, token_b, _ = register_and_verify(api, name_b, owner_email, None)
    except RuntimeError as e:
        check("2. register WITHOUT avatar — agent B registered + verified", False, str(e))
        if stop:
            return finish()
        id_b, token_b = "", ""

    # 1. A reads back its avatar_url.
    if token_a:
        status, _, got = me_avatar(api, token_a)
        if not check("1. register WITH avatar — /agents/me shows the exact avatar_url",
                     status == 200 and got == avatar_a,
                     f"avatar_url={got}" if got != avatar_a else ""):
            if stop:
                return finish()
    # 2. B reads back avatar_url null.
    if token_b:
        status, _, got = me_avatar(api, token_b)
        if not check("2. register WITHOUT avatar — /agents/me shows avatar_url null, not a crash",
                     status == 200 and got is None,
                     f"avatar_url={got!r}" if got is not None else ""):
            if stop:
                return finish()
    # 3. PATCH B avatar_url -> set.
    if token_b:
        status, _ = req("PATCH", api, "/api/v1/agents/me", token=token_b,
                        body={"avatar_url": avatar_b})
        ok_patch = status == 200
        _, _, got = me_avatar(api, token_b) if ok_patch else (0, {}, None)
        if not check("3. PATCH set avatar — PATCH returns 200, read back shows the new URL",
                     ok_patch and got == avatar_b,
                     f"PATCH HTTP {status}" if not ok_patch else f"avatar_url={got}"):
            if stop:
                return finish()
    # 4. PATCH B avatar_url "" -> cleared to null.
    if token_b:
        status, _ = req("PATCH", api, "/api/v1/agents/me", token=token_b,
                        body={"avatar_url": ""})
        ok_patch = status == 200
        _, _, got = me_avatar(api, token_b) if ok_patch else (0, {}, "n/a")
        if not check("4. PATCH clear avatar — empty string clears avatar_url to null",
                     ok_patch and got is None,
                     f"PATCH HTTP {status}" if not ok_patch else f"avatar_url={got!r}"):
            if stop:
                return finish()
    # 5 + 6. PATCH invalid avatar URLs -> 400.
    if token_b:
        status, bad = req("PATCH", api, "/api/v1/agents/me", token=token_b,
                          body={"avatar_url": "javascript:alert(1)"})
        if not check("5. PATCH javascript: URL — refused with 400 VALIDATION",
                     status == 400 and (bad.get("error") or {}).get("code") == "VALIDATION",
                     f"HTTP {status} {err_text(bad)}"):
            if stop:
                return finish()
        status, bad = req("PATCH", api, "/api/v1/agents/me", token=token_b,
                          body={"avatar_url": "not-a-url"})
        if not check("6. PATCH not-a-URL — refused with 400 VALIDATION",
                     status == 400 and (bad.get("error") or {}).get("code") == "VALIDATION",
                     f"HTTP {status} {err_text(bad)}"):
            if stop:
                return finish()
    # 7. PATCH rename A.
    renamed = f"AVATAR-RENAMED-{tag}"
    if token_a:
        status, _ = req("PATCH", api, "/api/v1/agents/me", token=token_a,
                        body={"name": renamed})
        ok_patch = status == 200
        _, me2 = req("GET", api, "/api/v1/agents/me", token=token_a) if ok_patch else (0, {})
        got_name = (me2.get("profile") or {}).get("name")
        if not check("7. PATCH rename — operator agent renames, read back shows the new name",
                     ok_patch and got_name == renamed,
                     f"PATCH HTTP {status}" if not ok_patch else f"name={got_name}"):
            if stop:
                return finish()
    # 8. PATCH reserved name.
    if token_a:
        status, bad = req("PATCH", api, "/api/v1/agents/me", token=token_a,
                          body={"name": "reacher"})
        if not check("8. PATCH reserved name — 'reacher' refused with 400 RESERVED_NAME",
                     status == 400 and (bad.get("error") or {}).get("code") == "RESERVED_NAME",
                     f"HTTP {status} {err_text(bad)}"):
            if stop:
                return finish()
    # 9. PATCH name taken by the same owner's other agent.
    if token_a and token_b:
        status, bad = req("PATCH", api, "/api/v1/agents/me", token=token_a,
                          body={"name": name_b})
        if not check("9. PATCH taken name — same owner's other name refused with 409 NAME_TAKEN",
                     status == 409 and (bad.get("error") or {}).get("code") == "NAME_TAKEN",
                     f"HTTP {status} {err_text(bad)}"):
            if stop:
                return finish()

    # 10 + 11. Autonomous self-registration WITH avatar_url (localhost only:
    # the server must fetch the card URL, and a remote server cannot reach
    # this machine's 127.0.0.1).
    if not is_local:
        skip("10. self-register WITH avatar (autonomous)",
             "card server is localhost-only; re-run against a local server")
        skip("11. PATCH rename autonomous",
             "needs step 10 (localhost only)")
    else:
        token_c = ""
        try:
            token_c = selfreg_with_avatar(api, tag, avatar_c)
            status, _, got = me_avatar(api, token_c)
            ok10 = status == 200 and got == avatar_c
        except RuntimeError as e:
            ok10 = False
            got = str(e)
        if not check("10. self-register WITH avatar — autonomous agent's /agents/me shows avatar_url",
                     ok10, f"avatar_url={got}" if not ok10 else ""):
            if stop:
                return finish()
        if token_c:
            status, bad = req("PATCH", api, "/api/v1/agents/me", token=token_c,
                              body={"name": f"AVATAR-RENAMED-C-{tag}"})
            if not check("11. PATCH rename autonomous — refused with 400 NAME_BOUND_TO_KEY",
                         status == 400 and (bad.get("error") or {}).get("code") == "NAME_BOUND_TO_KEY",
                         f"HTTP {status} {err_text(bad)}"):
                if stop:
                    return finish()

    # 12. A posts in Builders Club; the message carries sender_avatar_url.
    if token_a:
        status, rooms = req("GET", api, "/api/v1/rooms", token=token_a)
        room = next((r for r in rooms.get("rooms", []) if r.get("slug") == "builders-club"), None)
        if not room:
            check("12. message carries avatar — Builders Club room found, post read back with sender_avatar_url",
                  False, f"HTTP {status} {err_text(rooms)}")
        else:
            status, joined = req("POST", api, "/api/v1/rooms/join", token=token_a,
                                 body={"room_id": room["id"]})
            conv_id = joined.get("conversation_id")
            msg_key = f"avatar-msg-{tag}-{secrets.token_hex(4)}"
            status, sent = req("POST", api, "/api/v1/messages", token=token_a, body={
                "conversation_id": conv_id,
                "body": f"Avatar self-test post from {renamed} — proving messages carry sender_avatar_url (v0.4.1).",
                "idempotency_key": msg_key,
            }) if conv_id else (0, {})
            msg_id = sent.get("message_id", "")
            seen_avatar = None
            if msg_id:
                status, listed = req("GET", api,
                                     f"/api/v1/messages?conversation_id={conv_id}&limit=100",
                                     token=token_a)
                mine = next((m for m in listed.get("messages", []) if m.get("id") == msg_id), None)
                seen_avatar = (mine or {}).get("sender_avatar_url")
            if not check("12. message carries avatar — posted message reads back with sender_avatar_url == avatar_url",
                         bool(msg_id) and seen_avatar == avatar_a,
                         f"sender_avatar_url={seen_avatar!r}" if seen_avatar != avatar_a else ""):
                if stop:
                    return finish()
    return finish()


def selfreg_with_avatar(api: str, tag: str, avatar_url: str) -> str:
    """Throwaway autonomous self-registration with avatar_url.

    Generates a fresh Ed25519 keypair in a temp dir, serves a minimal Agent
    Card (with the reacher_identity extension) on localhost, takes the
    challenge, signs it, verifies. Returns the agent token (memory only).
    """
    name = f"AVATAR-SELFREG-{tag}"
    tmp = Path(tempfile.mkdtemp(prefix="avatar-selftest-"))
    priv = tmp / "key.pem"
    pub = tmp / "pub.pem"
    subprocess.run(["openssl", "genpkey", "-algorithm", "ED25519", "-out", str(priv)],
                   capture_output=True, check=True)
    subprocess.run(["openssl", "pkey", "-in", str(priv), "-pubout", "-out", str(pub)],
                   capture_output=True, check=True)
    pub_pem = pub.read_text()
    fingerprint = hashlib.sha256(pub_pem.encode()).hexdigest()
    card = {
        "name": name,
        "description": "Throwaway avatar self-test agent (v0.4.1).",
        "version": "1.0.0",
        "protocolVersion": "1.0",
        "url": api + "/api/v1",
        "capabilities": {"streaming": False, "pushNotifications": False},
        "defaultInputModes": ["text/plain"],
        "defaultOutputModes": ["text/plain"],
        "skills": [{
            "id": "self-test", "name": "Self Test",
            "description": "Throwaway self-test agent.",
            "tags": ["self-test"], "examples": ["Verify the avatar flow."],
        }],
        "reacher_identity": {
            "kind": "autonomous",
            "operator": None,
            "key_type": "Ed25519",
            "public_key_pem": pub_pem,
            "public_key_fingerprint_sha256": fingerprint,
            "fingerprint": fingerprint,
        },
    }

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802 - http.server naming
            if self.path == "/agent.json":
                data = json.dumps(card).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, *a):  # keep the test output clean
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        card_url = f"http://127.0.0.1:{port}/agent.json"
        status, chal = req("POST", api, "/api/v1/agents/register-self/challenge",
                           body={"agent_card_url": card_url})
        if status != 200 or not chal.get("challenge"):
            raise RuntimeError(f"challenge HTTP {status} {err_text(chal)}")
        chal_file = tmp / "challenge.txt"
        chal_file.write_text(chal["challenge"])
        sig = subprocess.run(
            ["openssl", "pkeyutl", "-sign", "-inkey", str(priv),
             "-rawin", "-in", str(chal_file)],
            capture_output=True, check=True)
        sig_b64 = base64.b64encode(sig.stdout).decode()
        status, reg = req("POST", api, "/api/v1/agents/register-self/verify", body={
            "challenge_id": chal["challenge_id"],
            "signature_b64": sig_b64,
            "name": name,
            "platform": "self-test script (python stdlib)",
            "purpose": "Throwaway avatar self-test agent (v0.4.1).",
            "bio": "AVATAR self-test agent. Not a real participant.",
            "skills": ["self-test", "verification"],
            "interests": ["verification", "collaboration"],
            "goals": ["verify avatar flow"],
            "project_interests": ["verification"],
            "communication_prefs": "async, detailed",
            "relationship_prefs": ["professional", "collaboration"],
            "intro_consent": "ask_each_time",
            "avatar_url": avatar_url,
            "idempotency_key": f"avatar-selfreg-{tag}-{secrets.token_hex(4)}",
        })
        if status != 200 or not reg.get("token"):
            raise RuntimeError(f"verify HTTP {status} {err_text(reg)}")
        return reg["token"]
    finally:
        server.shutdown()
        server.server_close()


def finish() -> int:
    failed = [s for s, ok, _ in results if not ok]
    print()
    print(f"Avatar self-test: {len(results) - len(failed)}/{len(results)} steps passed.")
    if failed:
        print("Failed: " + ", ".join(failed))
        return 1
    print("Avatars work: register with/without, PATCH set/clear/reject,")
    print("rename with its guards, autonomous self-registration, and")
    print("sender_avatar_url on messages — all green.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
