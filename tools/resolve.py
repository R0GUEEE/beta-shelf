#!/usr/bin/env python3
"""Stage 1: resolve join codes concurrently -> tf.json (no iTunes)."""
import json, re, sys
from concurrent.futures import ThreadPoolExecutor
from harvest import get

def tf(code):
    url = f"https://testflight.apple.com/join/{code}"
    out = {"code": code}
    try:
        st, html = get(url, 20)
    except Exception as e:
        out["http"] = 0; out["error"] = str(e)[:100]; return out
    out["http"] = st
    if st != 200:
        return out
    m = re.search(r"<title>(.*?)</title>", html, re.S)
    name = m.group(1).strip() if m else ""
    name = re.sub(r"^Join the\s+", "", name)
    name = re.sub(r"\s*beta\s*-\s*TestFlight\s*-\s*Apple\s*$", "", name)
    name = re.sub(r"\s*-\s*TestFlight\s*-\s*Apple\s*$", "", name)
    out["name"] = name.strip()
    m = re.search(r"og:image\" content=\"([^\"]+)\"", html)
    if m:
        out["icon"] = re.sub(r"/\d+x\d+ia-.*$", "/512x512bb.png", m.group(1))
    m = re.search(r"<div class=\"beta-status\">(.*?)</div>\s*</div>", html, re.S)
    if m:
        txt = re.sub(r"<[^>]+>", " ", m.group(1))
        out["status_text"] = re.sub(r"\s+", " ", txt).strip()[:400]
    low = html.lower()
    out["full"] = any(p in low for p in ("this beta is full", "isn't accepting new testers",
                                         "no longer accepting", "beta is full"))
    return out

if __name__ == "__main__":
    codes = [l.strip() for l in open(sys.argv[1]) if l.strip()]
    with ThreadPoolExecutor(max_workers=8) as ex:
        res = list(ex.map(tf, codes))
    json.dump(res, open(sys.argv[2], "w"), indent=1)
    ok = [r for r in res if r.get("http") == 200 and r.get("name")]
    print(f"live {len(ok)}/{len(res)}")
