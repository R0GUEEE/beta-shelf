#!/usr/bin/env python3
"""Stage 2: enrich resolved betas with iTunes metadata, resumable, rate-limit friendly."""
import json, os, re, sys, time, urllib.parse
import urllib.error
from harvest import get

FIELDS = ("trackId", "trackName", "sellerName", "artistName", "primaryGenreName",
          "averageUserRating", "userRatingCount", "formattedPrice", "version",
          "minimumOsVersion", "description", "artworkUrl512", "screenshotUrls",
          "trackViewUrl", "releaseNotes", "contentAdvisoryRating", "bundleId",
          "trackCensoredName")

def search(name):
    q = urllib.parse.quote(name)
    url = f"https://itunes.apple.com/search?term={q}&entity=software&country=us&limit=5"
    for attempt in range(3):
        try:
            st, body = get(url, 18)
            if st != 200 or not body.lstrip().startswith("{"):
                time.sleep(8 * (attempt + 1)); continue
            res = json.loads(body).get("results", [])
            if not res:
                return None
            nlow = name.lower().strip()
            for r in res:
                t = (r.get("trackName") or "").lower().strip()
                if t == nlow or t.startswith(nlow) or nlow.startswith(t):
                    return r
            return res[0]
        except urllib.error.HTTPError as e:
            time.sleep(10 * (attempt + 1))
        except Exception:
            time.sleep(5)
    return None

def main():
    src, dst, budget = sys.argv[1], sys.argv[2], int(sys.argv[3])
    rows = json.load(open(src))
    cache = json.load(open(dst)) if os.path.exists(dst) else {}
    done = 0
    for r in rows:
        if r.get("http") != 200 or not r.get("name"):
            continue
        code = r["code"]
        if code in cache:
            continue
        if done >= budget:
            break
        hit = search(r["name"])
        cache[code] = {k: hit.get(k) for k in FIELDS} if hit else None
        done += 1
        if done % 10 == 0:
            json.dump(cache, open(dst, "w"), indent=1)
            print(f"{done} done, {sum(1 for v in cache.values() if v)} matched", flush=True)
        time.sleep(2.2)
    json.dump(cache, open(dst, "w"), indent=1)
    print(f"TOTAL cache={len(cache)} matched={sum(1 for v in cache.values() if v)}")

if __name__ == "__main__":
    main()
