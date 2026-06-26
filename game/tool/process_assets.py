#!/usr/bin/env python3
"""Build-time fetch + processing of Higgsfield-generated assets.

Runs on the CI runner (which has open internet; the dev sandbox's egress blocks
the CDN). Reads tool/higgsfield_assets.json, downloads each URL, optionally
flood-fills the white background to transparent and trims to the subject, then
writes the result to its target slot (which art_map.json already points at).

Resilient by design: any per-asset failure is logged and skipped so the APK
build still succeeds and the game falls back to its vector art.
"""
import io
import json
import os
import sys
import urllib.request

try:
    from PIL import Image, ImageDraw
    import numpy as np
except Exception as e:  # pragma: no cover
    print(f"[assets] Pillow/numpy unavailable ({e}); skipping asset processing")
    sys.exit(0)

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "higgsfield_assets.json")
ROOT = os.path.dirname(HERE)  # the game/ package root


def fetch(url: str) -> Image.Image:
    req = urllib.request.Request(url, headers={"User-Agent": "shefali-ci"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return Image.open(io.BytesIO(data)).convert("RGBA")


def key_white(img: Image.Image, thresh: int = 40) -> Image.Image:
    """Make the border-connected white background transparent (interior whites,
    e.g. shoes, are preserved because flood-fill only spreads from the edges)."""
    w, h = img.size
    rgb = img.convert("RGB")
    sentinel = (255, 0, 255)
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        try:
            ImageDraw.floodfill(rgb, corner, sentinel, thresh=thresh)
        except Exception:
            pass
    out = np.array(img)  # H x W x 4
    mask = np.all(np.array(rgb) == sentinel, axis=-1)
    out[mask, 3] = 0
    return Image.fromarray(out, "RGBA")


def trim(img: Image.Image, pad: int = 4) -> Image.Image:
    bbox = img.split()[-1].getbbox()  # alpha bbox
    if not bbox:
        return img
    l, t, r, b = bbox
    l = max(0, l - pad); t = max(0, t - pad)
    r = min(img.width, r + pad); b = min(img.height, b + pad)
    return img.crop((l, t, r, b))


def downscale(img: Image.Image, max_h: int) -> Image.Image:
    if max_h and img.height > max_h:
        scale = max_h / img.height
        img = img.resize((max(1, round(img.width * scale)), max_h), Image.LANCZOS)
    return img


def main() -> int:
    try:
        manifest = json.load(open(MANIFEST, encoding="utf-8"))
    except Exception as e:
        print(f"[assets] no manifest ({e}); nothing to do")
        return 0
    ok = 0
    for entry in manifest.get("assets", []):
        target = os.path.join(ROOT, entry["target"])
        try:
            img = fetch(entry["url"])
            if entry.get("key"):
                img = key_white(img)
            if entry.get("trim"):
                img = trim(img)
            img = downscale(img, int(entry.get("maxH", 0)))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            img.save(target)
            print(f"[assets] OK  {entry['target']}  ({img.width}x{img.height})")
            ok += 1
        except Exception as e:
            print(f"[assets] SKIP {entry['target']}: {e}")
    print(f"[assets] processed {ok}/{len(manifest.get('assets', []))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
