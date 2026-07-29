from __future__ import annotations

import json
import urllib.request


BASE_URL = "https://api.inpr1me.ru/api/v1"
GROUP_ID = "fa76f31b-1e3e-4837-8265-9b22ec3d99e8"


def request(path: str, method: str = "GET", payload: dict | None = None, token: str | None = None):
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE_URL + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


auth = request(
    "/auth/login",
    "POST",
    {
        "email": "primebot071215401@example.com",
        "password": "PrimeBot123",
        "developer_mode": False,
    },
)
token = auth["access_token"]
group = request(f"/groups/{GROUP_ID}", token=token)
messages = request(f"/chat/{GROUP_ID}/messages", token=token)

print("group_id", group["id"])
print("status", group["status"])
print("members_count", group["members_count"])
print("matrix_room_id", group["matrix_room_id"])
print("message_count", len(messages.get("messages", [])))
for message in messages.get("messages", [])[-8:]:
    body = message.get("body") or message.get("content", {}).get("body") or ""
    print("-", body.encode("unicode_escape").decode())
