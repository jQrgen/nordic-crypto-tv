#!/usr/bin/env python3
"""Draws the Android launcher icon, TV banner and notification icon from the
same Nordlys art as the Apple icons. Run from the repo root:
python3 support/make_android_assets.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_brand_assets import aurora, sparkle, icon_flat, ROUNDED  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

RES = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def main():
    # Adaptive icon layers (432 px = 108 dp at xxxhdpi), plus a legacy PNG.
    d = os.path.join(RES, "mipmap-xxxhdpi")
    os.makedirs(d, exist_ok=True)
    aurora(432, 432).save(os.path.join(d, "ic_launcher_background.png"))
    sparkle(432, 432, 0.36).save(os.path.join(d, "ic_launcher_foreground.png"))
    icon_flat(192).save(os.path.join(d, "ic_launcher.png"))
    write(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
""")

    # Android TV banner, 320x180 dp (xhdpi = 640x360 px).
    w, h = 640, 360
    banner = aurora(w, h).convert("RGBA")
    glyph = icon_flat(150).convert("RGBA")
    mask = Image.new("L", (150, 150), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 149, 149], radius=33, fill=255)
    banner.paste(glyph, (48, 105), mask)
    dr = ImageDraw.Draw(banner)
    dr.text((228, 128), "Nordic Crypto", font=ImageFont.truetype(ROUNDED, 56), fill=(242, 245, 250, 255))
    dr.text((230, 200), "News · Events · Radio", font=ImageFont.truetype(ROUNDED, 26), fill=(163, 173, 194, 255))
    os.makedirs(os.path.join(RES, "drawable-xhdpi"), exist_ok=True)
    banner.convert("RGB").save(os.path.join(RES, "drawable-xhdpi", "tv_banner.png"))

    # Notification icon: a white four-point star as a vector.
    write(os.path.join(RES, "drawable", "ic_notification.xml"), """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M12,1 C13,8 16,11 23,12 C16,13 13,16 12,23 C11,16 8,13 1,12 C8,11 11,8 12,1 Z" />
</vector>
""")
    print("ok")


if __name__ == "__main__":
    main()
