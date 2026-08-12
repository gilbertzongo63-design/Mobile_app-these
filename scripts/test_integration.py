"""Integration tests for Waste Sorting API — run against a live backend."""
import sys
import json
import traceback
from urllib.request import Request, urlopen
from urllib.error import HTTPError

BASE = "http://localhost:8000"
passed = 0
failed = 0

def req(method, path, body=None, token=None, expect=None):
    global passed, failed
    url = f"{BASE}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body else None
    r = Request(url, data=data, headers=headers, method=method)
    try:
        resp = urlopen(r, timeout=10)
        status = resp.status
        payload = json.loads(resp.read().decode())
        ok = expect is None or status == expect
        if ok:
            passed += 1
            print(f"  PASS {method} {path} -> {status}")
        else:
            failed += 1
            print(f"  FAIL {method} {path} -> {status} (expected {expect})")
        return status, payload
    except HTTPError as e:
        status = e.code
        body = e.read().decode()
        ok = expect is None or status == expect
        if ok:
            passed += 1
            print(f"  PASS {method} {path} -> {status}")
        else:
            failed += 1
            print(f"  FAIL {method} {path} -> {status} (expected {expect}): {body[:120]}")
        return status, body
    except Exception as e:
        failed += 1
        print(f"  ERROR {method} {path}: {e}")
        return 0, str(e)

print("=" * 60)
print("INTEGRATION TESTS")
print("=" * 60)

# --- 1. Health ---
print("\n--- Health ---")
req("GET", "/health", expect=200)

# --- 2. Root ---
print("\n--- Root ---")
req("GET", "/", expect=200)

# --- 3. Auth (Google OAuth) ---
print("\n--- Auth ---")
req("POST", "/auth/google-login", body={"id_token": "x" * 30}, expect=401)

# --- 4. Public endpoints (no auth) ---
print("\n--- Predictions (no auth) ---")
req("GET", "/predictions", expect=401)

print("\n--- Categories (no auth) ---")
req("GET", "/categories", expect=200)

# --- 5. Admin endpoints (no auth) ---
print("\n--- Admin endpoints (no auth) ---")
req("GET", "/admin/predictions", expect=401)
req("GET", "/admin/stats", expect=401)

# --- 6. Notifications (no auth) ---
print("\n--- Notifications (no auth) ---")
req("GET", "/notifications", expect=401)

# --- 7. Admin DELETE (no auth) ---
print("\n--- Admin DELETE (no auth) ---")
req("DELETE", "/admin/predictions/1", expect=401)

# --- 8. CORS ---
print("\n--- CORS headers ---")
r = Request(f"{BASE}/health", method="OPTIONS")
r.add_header("Origin", "http://localhost:5173")
r.add_header("Access-Control-Request-Method", "GET")
try:
    resp = urlopen(r, timeout=5)
    acao = resp.headers.get("Access-Control-Allow-Origin", "")
    if "localhost:5173" in acao or acao == "*":
        print(f"  PASS CORS for localhost:5173 (Allow-Origin: {acao})")
        passed += 1
    else:
        print(f"  FAIL CORS: Allow-Origin = {acao}")
        failed += 1
except Exception as e:
    print(f"  FAIL CORS preflight: {e}")
    failed += 1

# --- 9. Static file serving ---
print("\n--- Static files ---")
req("GET", "/static/placeholder.txt", expect=404)

print("\n" + "=" * 60)
print(f"RESULTS: {passed} passed, {failed} failed out of {passed + failed}")
print("=" * 60)
if failed:
    sys.exit(1)
