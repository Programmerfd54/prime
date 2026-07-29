from __future__ import annotations

import json
import urllib.request


BASE_URL = "https://api.inpr1me.ru/api/v1"
EMAIL = "primebot071215401@example.com"
PASSWORD = "PrimeBot123"


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
        raw = response.read()
        print(path, response.headers.get("content-type"), raw[:120])
        return json.loads(raw.decode("utf-8"))


auth = request(
    "/auth/login",
    "POST",
    {"email": EMAIL, "password": PASSWORD, "developer_mode": False},
)
token = auth["access_token"]
groups = request("/groups", token=token)
skills = request("/skills", token=token)
regions = request("/regions", token=token)

group = groups[0]
print("group.name:", group["name"].encode("unicode_escape").decode())
print("group.skill_name:", group["skill_name"].encode("unicode_escape").decode())
print("group.region_name:", group["region_name"].encode("unicode_escape").decode())
print("skill sample:", skills[3]["name"].encode("unicode_escape").decode())
print("region 77:", next(item for item in regions if item["code"] == "77")["name"].encode("unicode_escape").decode())
