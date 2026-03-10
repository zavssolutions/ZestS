#!/usr/bin/env python3
"""
API smoke test against a running ZestS backend.

Usage:
    python scripts/smoke_test.py [BASE_URL]

Default BASE_URL: http://localhost:8000
"""

from __future__ import annotations

import sys
import json
import urllib.request
import urllib.error

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
API = f"{BASE_URL}/api/v1"

passed = 0
failed = 0


def check(name: str, method: str, path: str, *, expected: int = 200, body: dict | None = None) -> None:
    global passed, failed
    url = f"{API}{path}"
    data = json.dumps(body).encode() if body else None
    headers = {"Content-Type": "application/json"} if body else {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
    except urllib.error.HTTPError as e:
        status = e.code

    if status == expected:
        print(f"  ✅ {name} ({method} {path}) → {status}")
        passed += 1
    else:
        print(f"  ❌ {name} ({method} {path}) → {status} (expected {expected})")
        failed += 1


print(f"\n🔥 ZestS API Smoke Test → {BASE_URL}\n")

# Health
check("Health check", "GET", "/../healthz")

# Static pages
check("List static pages", "GET", "/pages")
check("About Us page", "GET", "/pages/about-us")
check("Terms page", "GET", "/pages/terms-and-conditions")

# Config
check("Public config", "GET", "/config")

# Events
check("List upcoming events", "GET", "/events/upcoming")
check("Anonymous events", "GET", "/events/upcoming/anonymous")

# Search
check("Search events", "GET", "/search?q=skating")

# Banners (public)
check("List banners", "GET", "/banners")

# Not found
check("Event not found", "GET", "/events/00000000-0000-0000-0000-000000000000", expected=404)

# Auth required endpoints (expect 401/403 without token)
check("Get profile (no auth)", "GET", "/users/me", expected=401)
check("Admin stats (no auth)", "GET", "/admin/stats", expected=401)

print(f"\n{'═' * 50}")
print(f"Results: {passed} passed, {failed} failed, {passed + failed} total")

if failed > 0:
    print("❌ Some tests failed!")
    sys.exit(1)
else:
    print("✅ All smoke tests passed!")
    sys.exit(0)
