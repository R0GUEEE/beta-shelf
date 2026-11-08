#!/usr/bin/env python3
"""Resolve TestFlight public join codes -> catalog entries, enriched with iTunes lookup."""
import json, re, sys, time, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "en-US,en;q=0.9"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read().decode("utf-8", "replace")

def tf(code):
    url = f"https://testflight.apple.com/join/{code}"
    try:
        st, html = get(url)
    except Exception as e:
        return {"code": code, "http": 0, "error": str(e)[:120]}
    out = {"code": code, "http": st}
    m = re.search(r"<title>(.*?)</title>", html, re.S)
    title = m.group(1).strip() if m else ""
    out["raw_title"] = title
    name = title
    name = re.sub(r"^Join the\s+", "", name)
    name = re.sub(r"\s*beta\s*-\s*TestFlight\s*-\s*Apple\s*$", "", name)
    name = re.sub(r"\s*-\s*TestFlight\s*-\s*Apple\s*$", "", name)
    out["name"] = name.strip()
    m = re.search(r"og:image\" content=\"([^\"]+)\"", html)
    if m:
        icon = m.group(1)
        # the og image is a wide render; derive a square 512 icon from the same asset
        icon512 = re.sub(r"/\d+x\d+ia-.*$", "/512x512bb.png", icon)
        out["icon"] = icon512
        out["icon_og"] = icon
    m = re.search(r"<meta name=\"description\" content=\"([^\"]*)\"", html)
    if m:
        out["meta_desc"] = m.group(1)
    # beta availability phrases rendered into the status panel
    st_txt = " ".join(re.findall(r"<div class=\"beta-status\">(.*?)</div>", html, re.S))
    st_txt = re.sub(r"<[^>]+>", " ", st_txt)
    out["status_text"] = re.sub(r"\s+", " ", st_txt).strip()[:300]
    low = html.lower()
    for phrase in ["this beta is full", "isn't accepting", "is not accepting", "no longer accepting",
                   "beta is closed", "has expired", "not available", "stopped accepting"]:
        if phrase in low:
            out.setdefault("flags", []).append(phrase)
    return out

def itunes(name):
    q = urllib.parse.quote(name)
    url = f"https://itunes.apple.com/search?term={q}&entity=software&country=us&limit=5"
    for attempt in range(4):
        try:
            st, body = get(url, 20)
            if st == 403 or not body.startswith("{"):
                time.sleep(6 * (attempt + 1))
                continue
            data = json.loads(body)
            res = data.get("results", [])
            if not res:
                return None
            nlow = name.lower()
            best = None
            for r in res:
                t = r.get("trackName", "").lower()
                if t == nlow or t.startswith(nlow) or nlow.startswith(t):
                    best = r
                    break
            return best or res[0]
        except Exception:
            time.sleep(4)
    return None

def main():
    codes = [l.strip() for l in open(sys.argv[1]) if l.strip()]
    with ThreadPoolExecutor(max_workers=5) as ex:
        tfs = list(ex.map(tf, codes))
    tfs = [t for t in tfs if t.get("http") == 200 and t.get("name")]
    print(f"resolved {len(tfs)}/{len(codes)}", file=sys.stderr)

    def enrich(t):
        r = itunes(t["name"])
        if r:
            t["itunes"] = {k: r.get(k) for k in (
                "trackId", "trackName", "sellerName", "artistName", "primaryGenreName",
                "averageUserRating", "userRatingCount", "formattedPrice", "version",
                "minimumOsVersion", "description", "artworkUrl512", "artworkUrl100",
                "screenshotUrls", "ipadScreenshotUrls", "trackViewUrl", "currentVersionReleaseDate",
                "releaseNotes", "contentAdvisoryRating", "bundleId")}
            t["itunes"]["screenshotUrls"] = (r.get("screenshotUrls") or [])[:6]
            t["itunes"]["ipadScreenshotUrls"] = (r.get("ipadScreenshotUrls") or [])[:4]
        else:
            t["itunes"] = None
        return t

    with ThreadPoolExecutor(max_workers=3) as ex:
        out = list(ex.map(enrich, tfs))
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    matched = sum(1 for o in out if o.get("itunes"))
    print(f"enriched {matched}/{len(out)}", file=sys.stderr)

if __name__ == "__main__":
    main()
