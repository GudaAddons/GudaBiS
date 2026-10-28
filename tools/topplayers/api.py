"""A small client for Blizzard's Battle.net API (GB-131), standard library only.

The key is a client ID and secret from develop.battle.net, read from a file outside the
repository (default G:\\addon-data\\GudaBis\\blizzard.env, never committed or shipped):
    BLIZZARD_CLIENT_ID=...
    BLIZZARD_CLIENT_SECRET=...
They are traded for an access token with the client-credentials flow: no player logs
in. The secret never appears in output, logs or cache files.

Responses are cached as JSON under the cache folder, keyed by URL, so a rerun of the
build only asks Blizzard for what it has not seen (leaderboards for a new week, new
characters). Requests are paced under Blizzard's limit (100 per second, 36,000 per
hour); a 429 waits and retries, and a 404 (a character renamed, moved or private) is
returned as None rather than stopping the build.
"""

import base64
import hashlib
import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

TOKEN_URL = "https://oauth.battle.net/token"
API_URL = "https://{region}.api.blizzard.com"
MIN_INTERVAL = 0.02
RETRIES = 4


class ApiError(RuntimeError):
    pass


def read_key(path):
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                name, value = line.split("=", 1)
                values[name.strip()] = value.strip()
    client_id = values.get("BLIZZARD_CLIENT_ID")
    secret = values.get("BLIZZARD_CLIENT_SECRET")
    if not client_id or not secret:
        raise ApiError(f"{path} needs BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET lines")
    return client_id, secret


class Client:
    def __init__(self, key_path, cache_dir, opener=None, sleep=time.sleep, now=time.monotonic):
        self._key_path = key_path
        self._cache_dir = cache_dir
        self._open = opener or urllib.request.urlopen
        self._sleep = sleep
        self._now = now
        self._token = None
        self._last = 0.0
        self._lock = threading.Lock()
        self.requests = 0
        self.cache_hits = 0
        os.makedirs(cache_dir, exist_ok=True)

    def _token_value(self):
        with self._lock:
            return self._token or self._new_token()

    def _new_token(self):
        client_id, secret = read_key(self._key_path)
        basic = base64.b64encode(f"{client_id}:{secret}".encode()).decode()
        request = urllib.request.Request(
            TOKEN_URL, data=b"grant_type=client_credentials",
            headers={"Authorization": "Basic " + basic, "Content-Type": "application/x-www-form-urlencoded"},
        )
        try:
            with self._open(request, timeout=30) as response:
                body = json.loads(response.read().decode())
        except urllib.error.HTTPError as error:
            raise ApiError(f"token request refused ({error.code}): check the client ID and secret") from None
        self._token = body.get("access_token")
        if not self._token:
            raise ApiError("no access_token in the token response")
        return self._token

    def _cache_path(self, url):
        return os.path.join(self._cache_dir, hashlib.sha1(url.encode()).hexdigest() + ".json")

    def _pace(self):
        with self._lock:
            wait = MIN_INTERVAL - (self._now() - self._last)
            if wait > 0:
                self._sleep(wait)
            self._last = self._now()

    # A 401 renews the token once; 429, 5xx and network errors (timeouts, dropped
    # connections, a broken answer) wait and retry, then raise ApiError; 404 is None.
    def _fetch(self, url, path, region):
        for attempt in range(RETRIES):
            self._pace()
            request = urllib.request.Request(url, headers={"Authorization": "Bearer " + self._token_value()})
            self.requests += 1
            try:
                with self._open(request, timeout=30) as response:
                    return json.loads(response.read().decode())
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    return None
                if error.code == 401 and attempt == 0:
                    self._token = None
                    continue
                if error.code in (429, 500, 502, 503, 504) and attempt < RETRIES - 1:
                    self._sleep(2 ** attempt)
                    continue
                raise ApiError(f"{error.code} for {path} ({region})") from None
            except (urllib.error.URLError, OSError, ValueError) as error:
                if attempt < RETRIES - 1:
                    self._sleep(2 ** attempt)
                    continue
                raise ApiError(f"{type(error).__name__} for {path} ({region})") from None
        raise ApiError(f"no answer for {path} ({region}) after {RETRIES} tries")

    def get(self, region, path, namespace, cache=True, max_age=None, **params):
        """GET a path on a region's API; returns parsed JSON, or None for a 404.
        max_age (seconds): a cached answer older than this is fetched again."""
        query = dict(params, namespace=f"{namespace}-{region}", locale="en_US")
        url = API_URL.format(region=region) + path + "?" + urllib.parse.urlencode(sorted(query.items()))
        cached = self._cache_path(url)
        fresh = os.path.exists(cached) and (max_age is None or time.time() - os.path.getmtime(cached) < max_age)
        if cache and fresh:
            self.cache_hits += 1
            with open(cached, encoding="utf-8") as handle:
                return json.load(handle)
        body = self._fetch(url, path, region)
        if cache:
            with open(cached, "w", encoding="utf-8") as handle:
                json.dump(body, handle)
        return body
