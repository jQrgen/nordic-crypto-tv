#!/usr/bin/env python3
"""Draws the "Nordlys" brand assets into NordicCrypto/Assets.xcassets:
iOS/iPadOS and macOS app icons, the layered Apple TV icons and Top Shelf
images, and the layered visionOS icon. Run from the repo root:
python3 support/make_brand_assets.py
"""
import json
import math
import os
import shutil
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "NordicCrypto", "Assets.xcassets")
ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
BG = (7, 11, 20)
AURORA = (61, 220, 151)
VIOLET = (139, 124, 246)
LAKE = (77, 157, 255)
COUNTRY = [(242, 84, 91), (242, 193, 78), (255, 122, 162), (77, 157, 255), (63, 211, 198)]
INFO = {"author": "xcode", "version": 1}


def write_json(path, data):
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def aurora(w, h, bands=True):
    """Opaque polar-night backdrop with blurred aurora light."""
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(glow)
    s = min(w, h)
    blobs = [(0.25, 0.30, 0.55, AURORA), (0.72, 0.22, 0.45, VIOLET), (0.55, 0.75, 0.50, LAKE)]
    for cx, cy, r, color in blobs:
        rx, ry = r * w * 0.6, r * h * 0.6
        d.ellipse([cx * w - rx, cy * h - ry, cx * w + rx, cy * h + ry], fill=color)
    if bands:
        # Two soft curtains sweeping across, like aurora arcs.
        for k, color in enumerate((AURORA, VIOLET)):
            pts = []
            for i in range(41):
                x = w * i / 40
                y = h * (0.42 + 0.12 * k + 0.08 * math.sin(i / 40 * math.pi * 2 + k))
                pts.append((x, y))
            d.line(pts, fill=color, width=max(4, int(s * 0.10)))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.16))
    img = Image.blend(img, glow, 0.62)
    return img


def sparkle(w, h, scale=0.42):
    """Transparent layer with a white four-point sparkle in the centre."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h / 2
    r = min(w, h) * scale / 2
    pts = []
    for i in range(400):
        t = i / 400 * 2 * math.pi
        # Astroid-like star: sharp points, curved sides.
        x = math.copysign(abs(math.cos(t)) ** 3, math.cos(t))
        y = math.copysign(abs(math.sin(t)) ** 3, math.sin(t))
        pts.append((cx + r * x, cy + r * y))
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon(pts, fill=(255, 255, 255, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(r * 0.25))
    img.alpha_composite(shadow)
    d.polygon(pts, fill=(255, 255, 255, 255))
    return img


def icon_flat(size):
    img = aurora(size, size).convert("RGBA")
    img.alpha_composite(sparkle(size, size))
    return img.convert("RGB")


def mac_icon(size):
    """macOS shape: rounded square inset in a transparent canvas."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.805)
    art = icon_flat(inner).convert("RGBA")
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner - 1, inner - 1], radius=int(inner * 0.225), fill=255)
    off = (size - inner) // 2
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([off, off + size * 0.01, off + inner, off + inner + size * 0.01],
                                            radius=int(inner * 0.225), fill=(0, 0, 0, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.012)))
    canvas.paste(art, (off, off), mask)
    return canvas


def imageset(path, files, idiom="tv"):
    write_json(path, {"images": [{"idiom": idiom, "filename": n, "scale": s} for n, s in files], "info": INFO})


def layered(path, size_1x, scales, idiom="tv"):
    write_json(path, {"info": INFO, "layers": [{"filename": "Front.imagestacklayer"}, {"filename": "Back.imagestacklayer"}]})
    for layer, maker in (("Front", lambda w, h: sparkle(w, h, 0.5)), ("Back", lambda w, h: aurora(w, h))):
        lpath = os.path.join(path, f"{layer}.imagestacklayer")
        write_json(lpath, {"info": INFO})
        cpath = os.path.join(lpath, "Content.imageset")
        os.makedirs(cpath, exist_ok=True)
        files = []
        for s in scales:
            name = f"{layer.lower()}@{s}x.png"
            maker(size_1x[0] * s, size_1x[1] * s).save(os.path.join(cpath, name))
            files.append((name, f"{s}x"))
        imageset(cpath, files, idiom)


def top_shelf(path, size_1x, scales):
    os.makedirs(path, exist_ok=True)
    files = []
    for s in scales:
        w, h = size_1x[0] * s, size_1x[1] * s
        img = aurora(w, h).convert("RGBA")
        glyph = int(h * 0.36)
        tile = icon_flat(glyph).convert("RGBA")
        mask = Image.new("L", (glyph, glyph), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, glyph - 1, glyph - 1], radius=int(glyph * 0.22), fill=255)
        x0, y0 = int(w * 0.08), int(h * 0.30)
        img.paste(tile, (x0, y0), mask)
        d = ImageDraw.Draw(img)
        d.text((x0 + glyph + h * 0.08, y0 + glyph * 0.08), "Nordic Crypto", font=ImageFont.truetype(ROUNDED, int(h * 0.15)),
               fill=(242, 245, 250, 255))
        d.text((x0 + glyph + h * 0.08, y0 + glyph * 0.62), "Norway · Sweden · Denmark · Finland · Iceland",
               font=ImageFont.truetype(ROUNDED, int(h * 0.055)), fill=(163, 173, 194, 255))
        name = f"topshelf@{s}x.png"
        img.convert("RGB").save(os.path.join(path, name))
        files.append((name, f"{s}x"))
    imageset(path, files)


def color(path, light, dark=None):
    def comp(rgb):
        r, g, b = (f"{c / 255:.3f}" for c in rgb)
        return {"color-space": "srgb", "components": {"red": r, "green": g, "blue": b, "alpha": "1.000"}}
    colors = [{"idiom": "universal", "color": comp(light)}]
    if dark:
        colors.append({"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}], "color": comp(dark)})
    write_json(path, {"colors": colors, "info": INFO})


def main():
    if os.path.isdir(ROOT):
        shutil.rmtree(ROOT)
    write_json(ROOT, {"info": INFO})
    color(os.path.join(ROOT, "AccentColor.colorset"), (14, 143, 99), AURORA)

    # iOS / iPadOS: one 1024 opaque icon.
    ios = os.path.join(ROOT, "AppIcon.appiconset")
    os.makedirs(ios, exist_ok=True)
    icon_flat(1024).save(os.path.join(ios, "ios-1024.png"))
    images = [{"idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png"}]
    # macOS: the classic size set.
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"mac-{pt}@{scale}x.png"
            mac_icon(px).save(os.path.join(ios, name))
            images.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": name})
    write_json(ios, {"images": images, "info": INFO})

    # visionOS: three-layer solid image stack, 1024 square.
    vision = os.path.join(ROOT, "AppIcon-Vision.solidimagestack")
    write_json(vision, {"info": INFO, "layers": [{"filename": "Front.solidimagestacklayer"},
                                                 {"filename": "Middle.solidimagestacklayer"},
                                                 {"filename": "Back.solidimagestacklayer"}]})
    for layer, img in (("Front", sparkle(1024, 1024, 0.5)), ("Middle", Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))),
                       ("Back", aurora(1024, 1024))):
        lpath = os.path.join(vision, f"{layer}.solidimagestacklayer")
        write_json(lpath, {"info": INFO})
        cpath = os.path.join(lpath, "Content.imageset")
        os.makedirs(cpath, exist_ok=True)
        img.save(os.path.join(cpath, f"{layer.lower()}.png"))
        write_json(cpath, {"images": [{"idiom": "vision", "filename": f"{layer.lower()}.png", "scale": "2x"}], "info": INFO})

    # Apple TV.
    brand = os.path.join(ROOT, "App Icon & Top Shelf Image.brandassets")
    write_json(brand, {"assets": [
        {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
        {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
        {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
        {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
    ], "info": INFO})
    layered(os.path.join(brand, "App Icon.imagestack"), (400, 240), [1, 2])
    layered(os.path.join(brand, "App Icon - App Store.imagestack"), (1280, 768), [1])
    top_shelf(os.path.join(brand, "Top Shelf Image.imageset"), (1920, 720), [1, 2])
    top_shelf(os.path.join(brand, "Top Shelf Image Wide.imageset"), (2320, 720), [1, 2])


if __name__ == "__main__":
    main()
