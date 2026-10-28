"""A small client for the Warcraft Logs v2 API (GraphQL), standard library only (GB-101).

The key is a client ID and secret from warcraftlogs.com/api/clients, read from the same
file as the Blizzard key (api.py), never committed or shipped:
    WCL_CLIENT_ID=...
    WCL_CLIENT_SECRET=...
They are traded for an access token with the client-credentials flow (no player logs in).

Warcraft Logs runs one site per game version; the 2019 Classic raids (zones 1000-1006)
are on classic.warcraftlogs.com. A free key has a budget of points per hour: before each
query the client reads how much is left, and when it runs low it waits for the hour to
reset, printing why. Answers are cached as JSON keyed by site and query, so a rerun only
spends points on what it has not asked before; finished phases never change.
"""

import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

import api

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
RESERVE = 60
RETRIES = 4
DATABASE_WAIT = 300
DATABASE_WAITS = 12


def read_key(path):
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                name, value = line.split("=", 1)
                values[name.strip()] = value.strip()
    client_id, secret = values.get("WCL_CLIENT_ID"), values.get("WCL_CLIENT_SECRET")
    if not client_id or not secret:
        raise api.ApiError(f"{path} needs WCL_CLIENT_ID and WCL_CLIENT_SECRET lines")
    return client_id, secret


class Client:
    def __init__(self, key_path, cache_dir, host="classic.warcraftlogs.com", opener=None, sleep=time.sleep):
        self._key_path = key_path
        self._cache_dir = cache_dir
        self._host = host
        self._open = opener or urllib.request.urlopen
        self._sleep = sleep
        self._token = None
        self.queries = 0
        self.cache_hits = 0
        os.makedirs(cache_dir, exist_ok=True)

    def _token_value(self):
        if self._token:
            return self._token
        client_id, secret = read_key(self._key_path)
        basic = base64.b64encode(f"{client_id}:{secret}".encode()).decode()
        request = urllib.request.Request(
            TOKEN_URL, data=b"grant_type=client_credentials",
            headers={"Authorization": "Basic " + basic, "Content-Type": "application/x-www-form-urlencoded"},
        )
        try:
            with self._open(request, timeout=30) as response:
                self._token = json.loads(response.read().decode()).get("access_token")
        except urllib.error.HTTPError as error:
            raise api.ApiError(f"Warcraft Logs token refused ({error.code}): check WCL_CLIENT_ID and SECRET") from None
        if not self._token:
            raise api.ApiError("no access_token from Warcraft Logs")
        return self._token

    def _post(self, query):
        body = json.dumps({"query": query}).encode()
        busy = 0
        for attempt in range(RETRIES):
            while True:
                request = urllib.request.Request(
                    f"https://{self._host}/api/v2/client", data=body,
                    headers={"Authorization": "Bearer " + self._token_value(), "Content-Type": "application/json"},
                )
                try:
                    with self._open(request, timeout=90) as response:
                        answer = json.loads(response.read().decode())
                except urllib.error.HTTPError as error:
                    if (error.code == 429 or error.code >= 500) and attempt < RETRIES - 1:
                        self._sleep(10 * (attempt + 1))
                        break
                    raise api.ApiError(f"Warcraft Logs HTTP {error.code}") from None
                except (urllib.error.URLError, OSError, ValueError) as error:
                    if attempt < RETRIES - 1:
                        self._sleep(5 * (attempt + 1))
                        break
                    raise api.ApiError(f"Warcraft Logs {type(error).__name__}") from None
                if not answer.get("errors"):
                    return answer["data"]
                text = json.dumps(answer["errors"])
                # A limit on the rankings database apart from the hourly points
                # (MoP, 2026-10-29): plain ranking queries fail with it while points
                # are left. It is waited out, up to DATABASE_WAITS times.
                if "no database points remaining" in text and busy < DATABASE_WAITS:
                    busy += 1
                    print(f"Warcraft Logs: rankings database limit, waiting {DATABASE_WAIT // 60} min "
                          f"({busy} of {DATABASE_WAITS})", file=sys.stderr, flush=True)
                    self._sleep(DATABASE_WAIT)
                    continue
                raise api.ApiError("Warcraft Logs: " + text[:300])
        raise api.ApiError("Warcraft Logs: no answer")

    def _wait_for_points(self):
        data = self._post("{ rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn } }")["rateLimitData"]
        left = data["limitPerHour"] - data["pointsSpentThisHour"]
        if left < RESERVE:
            wait = int(data["pointsResetIn"]) + 5
            print(f"Warcraft Logs: {left:.0f} points left this hour, waiting {wait // 60} min for the reset",
                  file=sys.stderr, flush=True)
            self._sleep(wait)

    def query(self, query, cache=True):
        cached = os.path.join(self._cache_dir, hashlib.sha1((self._host + query).encode()).hexdigest() + ".json")
        if cache and os.path.exists(cached):
            self.cache_hits += 1
            with open(cached, encoding="utf-8") as handle:
                return json.load(handle)
        self._wait_for_points()
        data = self._post(query)
        self.queries += 1
        if cache:
            with open(cached, "w", encoding="utf-8") as handle:
                json.dump(data, handle)
        return data
