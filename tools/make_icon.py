#!/usr/bin/env python3
"""生成 PokeBonk iOS App 图标（精灵球 + 深紫底）。

用法: python tools/make_icon.py
产物: Resources/Assets.xcassets/AppIcon.appiconset/
需要先 pip install pillow
"""
import json
import os
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "Resources", "Assets.xcassets", "AppIcon.appiconset")

BG = (26, 22, 48)          # #1a1630
RED = (255, 74, 106)       # #ff4a6a
CREAM = (255, 247, 232)    # #fff7e8
DARK = (42, 23, 70)        # #2a1746

BASE = 1024
SS = 4                     # 超采样倍数，抗锯齿
S = BASE * SS


def build_master() -> Image.Image:
    cx = cy = S / 2
    r = S * 0.34

    # 圆形遮罩（超采样后缩小 = 抗锯齿）
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    ball = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # 上半红
    ball.paste(Image.new("RGBA", (S, S), RED + (255,)), (0, 0), mask)

    # 下半米白
    bottom = mask.copy()
    ImageDraw.Draw(bottom).rectangle([0, 0, S, int(cy)], fill=0)
    ball.paste(Image.new("RGBA", (S, S), CREAM + (255,)), (0, 0), bottom)

    # 中间黑带
    band_h = r * 0.19
    band = mask.copy()
    bd = ImageDraw.Draw(band)
    bd.rectangle([0, 0, S, int(cy - band_h)], fill=0)
    bd.rectangle([0, int(cy + band_h), S, S], fill=0)
    ball.paste(Image.new("RGBA", (S, S), DARK + (255,)), (0, 0), band)

    # 中心按钮：米白圆 + 深色描边
    kr = r * 0.30
    knob = Image.new("L", (S, S), 0)
    ImageDraw.Draw(knob).ellipse([cx - kr, cy - kr, cx + kr, cy + kr], fill=255)
    ball.paste(Image.new("RGBA", (S, S), CREAM + (255,)), (0, 0), knob)
    ImageDraw.Draw(ball).ellipse([cx - kr, cy - kr, cx + kr, cy + kr],
                                 outline=DARK + (255,), width=int(r * 0.085))

    # 外圈描边
    ImageDraw.Draw(ball).ellipse([cx - r, cy - r, cx + r, cy + r],
                                 outline=DARK + (255,), width=int(r * 0.10))

    ball = ball.resize((BASE, BASE), Image.LANCZOS)

    canvas = Image.new("RGB", (BASE, BASE), BG)
    canvas.paste(ball, (0, 0), ball)
    return canvas


SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]

IMAGES = [
    {"idiom": "iphone", "size": "20x20", "scale": "2x", "px": 40},
    {"idiom": "iphone", "size": "20x20", "scale": "3x", "px": 60},
    {"idiom": "iphone", "size": "29x29", "scale": "2x", "px": 58},
    {"idiom": "iphone", "size": "29x29", "scale": "3x", "px": 87},
    {"idiom": "iphone", "size": "40x40", "scale": "2x", "px": 80},
    {"idiom": "iphone", "size": "40x40", "scale": "3x", "px": 120},
    {"idiom": "iphone", "size": "60x60", "scale": "2x", "px": 120},
    {"idiom": "iphone", "size": "60x60", "scale": "3x", "px": 180},
    {"idiom": "ipad", "size": "20x20", "scale": "1x", "px": 20},
    {"idiom": "ipad", "size": "20x20", "scale": "2x", "px": 40},
    {"idiom": "ipad", "size": "29x29", "scale": "1x", "px": 29},
    {"idiom": "ipad", "size": "29x29", "scale": "2x", "px": 58},
    {"idiom": "ipad", "size": "40x40", "scale": "1x", "px": 40},
    {"idiom": "ipad", "size": "40x40", "scale": "2x", "px": 80},
    {"idiom": "ipad", "size": "76x76", "scale": "1x", "px": 76},
    {"idiom": "ipad", "size": "76x76", "scale": "2x", "px": 152},
    {"idiom": "ipad", "size": "83.5x83.5", "scale": "2x", "px": 167},
    {"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x", "px": 1024},
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    master = build_master()

    cache = {}
    files = []
    for item in IMAGES:
        px = item["px"]
        if px not in cache:
            cache[px] = master.resize((px, px), Image.LANCZOS) if px != BASE else master
        name = "icon-%d.png" % px
        cache[px].save(os.path.join(OUT_DIR, name), "PNG", optimize=True)
        files.append({"idiom": item["idiom"], "size": item["size"],
                      "scale": item["scale"], "filename": name})

    contents = {"images": files, "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(OUT_DIR, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump(contents, fh, indent=2)
        fh.write("\n")

    print("图标已生成:", OUT_DIR, "共", len(set(i["px"] for i in IMAGES)), "个尺寸")


if __name__ == "__main__":
    main()
