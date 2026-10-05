#!/usr/bin/env python3
"""Draws the tvOS brand assets (layered app icons, Top Shelf images) into
NordicCryptoTV/Assets.xcassets. Run from the repo root: python3 support/make_brand_assets.py
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "NordicCryptoTV", "Assets.xcassets")
FONT = "/System/Library/Fonts/Menlo.ttc"
AMBER = (251, 139, 30)
AMBER_DIM = (110, 60, 12)
BLACK = (0, 0, 0)
PANEL = (14, 16, 21)
RULE = (40, 44, 52)
COUNTRIES = [("NO", (220, 46, 56)), ("SE", (0, 107, 189)), ("DK", (199, 15, 46)),
             ("FI", (0, 77, 158)), ("IS", (0, 82, 158))]


def font(size, bold=True):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def write_json(path, data):
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


INFO = {"author": "xcode", "version": 1}


def back_layer(w, h, chart=True):
    """Opaque terminal backdrop: grid, a faint chart line, country bars."""
    img = Image.new("RGB", (w, h), BLACK)
    d = ImageDraw.Draw(img)
    step = max(w // 24, 8)
    for x in range(0, w, step):
        d.line([(x, 0), (x, h)], fill=(18, 20, 26), width=max(1, w // 800))
    for y in range(0, h, step):
        d.line([(0, y), (w, y)], fill=(18, 20, 26), width=max(1, w // 800))
    pts = []
    if not chart:
        return draw_bars(img, d, w, h)
    for i in range(13):
        x = int(w * i / 12)
        y = int(h * (0.72 - 0.05 * ((i * 7) % 5) - 0.025 * i))
        pts.append((x, y))
    d.line(pts, fill=AMBER_DIM, width=max(2, w // 160))
    return draw_bars(img, d, w, h)


def draw_bars(img, d, w, h):
    bar_h = max(4, h // 28)
    seg = w / len(COUNTRIES)
    for i, (_, color) in enumerate(COUNTRIES):
        d.rectangle([int(i * seg), h - bar_h, int((i + 1) * seg), h], fill=color)
    return img


def front_layer(w, h, wordmark=True):
    """Transparent foreground: the amber NC block and the wordmark."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    block_h = int(h * (0.42 if wordmark else 0.5))
    f = font(int(block_h * 0.72))
    text = "NC"
    tw = d.textlength(text, font=f)
    pad = block_h * 0.22
    bw = int(tw + pad * 2)
    total_w = bw
    word_f = font(int(block_h * 0.30))
    word = "NORDIC CRYPTO"
    if wordmark:
        total_w = max(bw, int(d.textlength(word, font=word_f)))
    x0 = (w - bw) // 2
    y0 = int(h * (0.18 if wordmark else 0.25))
    d.rectangle([x0, y0, x0 + bw, y0 + block_h], fill=AMBER + (255,))
    d.text((x0 + bw / 2, y0 + block_h / 2), text, font=f, fill=BLACK + (255,), anchor="mm")
    if wordmark:
        d.text((w / 2, y0 + block_h + block_h * 0.42), word, font=word_f, fill=AMBER + (255,), anchor="mm")
    return img


def imageset(path, files, idiom="tv"):
    images = [{"idiom": idiom, "filename": name, "scale": scale} for name, scale in files]
    write_json(path, {"images": images, "info": INFO})


def imagestack(path, size_1x, scales):
    write_json(path, {"info": INFO, "layers": [{"filename": "Front.imagestacklayer"},
                                               {"filename": "Back.imagestacklayer"}]})
    for layer, maker in (("Front", lambda w, h: front_layer(w, h, wordmark=False)), ("Back", back_layer)):
        lpath = os.path.join(path, f"{layer}.imagestacklayer")
        write_json(lpath, {"info": INFO})
        cpath = os.path.join(lpath, "Content.imageset")
        files = []
        for s in scales:
            w, h = size_1x[0] * s, size_1x[1] * s
            name = f"{layer.lower()}@{s}x.png"
            maker(w, h).save(os.path.join(cpath if os.makedirs(cpath, exist_ok=True) is None else cpath, name))
            files.append((name, f"{s}x"))
        imageset(cpath, files)


def top_shelf(path, size_1x, scales):
    os.makedirs(path, exist_ok=True)
    files = []
    for s in scales:
        w, h = size_1x[0] * s, size_1x[1] * s
        img = back_layer(w, h, chart=False).convert("RGBA")
        front = front_layer(h, h)  # square wordmark block, centred on the left third
        img.alpha_composite(front, (int(w * 0.08), 0))
        d = ImageDraw.Draw(img)
        f = font(int(h * 0.075))
        lines = ["NEWS · EVENTS · NEWSLETTER", "NO  SE  DK  FI  IS"]
        for i, line in enumerate(lines):
            d.text((int(w * 0.08) + h + int(w * 0.04), int(h * (0.38 + i * 0.14))), line, font=f,
                   fill=(AMBER if i == 0 else (230, 230, 230)) + (255,))
        name = f"topshelf@{s}x.png"
        img.convert("RGB").save(os.path.join(path, name))
        files.append((name, f"{s}x"))
    imageset(path, files)


def color(path, rgb):
    r, g, b = (f"{c / 255:.3f}" for c in rgb)
    write_json(path, {"colors": [{"idiom": "universal",
                                  "color": {"color-space": "srgb",
                                            "components": {"red": r, "green": g, "blue": b, "alpha": "1.000"}}}],
                      "info": INFO})


def main():
    write_json(ROOT, {"info": INFO})
    color(os.path.join(ROOT, "AccentColor.colorset"), AMBER)
    color(os.path.join(ROOT, "LaunchBackground.colorset"), BLACK)
    brand = os.path.join(ROOT, "App Icon & Top Shelf Image.brandassets")
    write_json(brand, {"assets": [
        {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
        {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
        {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
        {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
    ], "info": INFO})
    imagestack(os.path.join(brand, "App Icon.imagestack"), (400, 240), [1, 2])
    imagestack(os.path.join(brand, "App Icon - App Store.imagestack"), (1280, 768), [1])
    top_shelf(os.path.join(brand, "Top Shelf Image.imageset"), (1920, 720), [1, 2])
    top_shelf(os.path.join(brand, "Top Shelf Image Wide.imageset"), (2320, 720), [1, 2])


if __name__ == "__main__":
    main()
