#!/usr/bin/env python3
"""Stage 3: merge resolved betas + iTunes data into the app's bundled catalog.json."""
import json, re, difflib, html

tf = json.load(open("tf.json")) + json.load(open("tf2.json"))
it = dict(json.load(open("itunes.json")))
it.update(json.load(open("itunes2.json")))

def norm(s):
    s = html.unescape(s or "")
    return re.sub(r"[^a-z0-9]", "", s.lower())

def first_token(s):
    toks = re.findall(r"[A-Za-z0-9]+", html.unescape(s or ""))
    return toks[0].lower() if toks else ""

out, dropped = [], []
for r in tf:
    if r.get("http") != 200 or not r.get("name"):
        continue
    code = r["code"]
    meta = it.get(code)
    name = html.unescape(r["name"]).strip()
    if meta and meta.get("trackName"):
        tn = html.unescape(meta["trackName"])
        a, b = norm(name), norm(tn)
        ratio = difflib.SequenceMatcher(None, a, b).ratio()
        ok = (ratio > 0.55 or a in b or b in a or
              (len(first_token(name)) >= 4 and first_token(name) == first_token(tn)))
        # "X Beta" should match "X ..." even if the rest differs
        if not ok and a.endswith("beta") and b.startswith(a[:-4]):
            ok = True
        if not ok:
            dropped.append((name, tn, round(ratio, 2)))
            meta = None
    entry = {
        "id": code,
        "code": code,
        "name": (meta or {}).get("trackName") or name,
        "betaName": name,
        "developer": (meta or {}).get("sellerName") or (meta or {}).get("artistName") or "",
        "genre": (meta or {}).get("primaryGenreName") or "",
        "icon": (meta or {}).get("artworkUrl512") or r.get("icon") or "",
        "description": (meta or {}).get("description") or "",
        "releaseNotes": (meta or {}).get("releaseNotes") or "",
        "screenshots": ((meta or {}).get("screenshotUrls") or [])[:6],
        "rating": (meta or {}).get("averageUserRating") or 0,
        "ratingCount": (meta or {}).get("userRatingCount") or 0,
        "price": (meta or {}).get("formattedPrice") or "",
        "version": (meta or {}).get("version") or "",
        "minOS": (meta or {}).get("minimumOsVersion") or "",
        "appStoreURL": (meta or {}).get("trackViewUrl") or "",
        "trackId": (meta or {}).get("trackId") or 0,
        "full": bool(r.get("full")),
    }
    entry["name"] = html.unescape(entry["name"])
    entry["developer"] = html.unescape(entry["developer"])
    if not entry["icon"]:
        continue
    out.append(entry)

seen_code, seen_track, final = set(), set(), []
for e in out:
    if e["code"] in seen_code:
        continue
    if e["trackId"] and e["trackId"] in seen_track:
        continue
    seen_code.add(e["code"])
    if e["trackId"]:
        seen_track.add(e["trackId"])
    final.append(e)

final.sort(key=lambda e: e["name"].lower())
json.dump(final, open("catalog.json", "w"), indent=1, ensure_ascii=False)
print(f"entries={len(final)} dropped_mismatch={len(dropped)}")
print("genres:", sorted({e["genre"] for e in final if e["genre"]}))
print("with_desc:", sum(1 for e in final if e["description"]), "with_shots:", sum(1 for e in final if e["screenshots"]))
json.dump([d for d in dropped], open("dropped.json", "w"), indent=1)
