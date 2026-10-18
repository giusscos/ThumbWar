#!/usr/bin/env python3
"""Builds the layered app icon (ThumbWar/AppIcon.icon) from a render of the game's own thumbs.

The render comes from the app in DEBUG with `-iconShot` (see CameraRig.icon):
a square of the arena whose sky is one flat unlit color. The sky is keyed out,
leaving the thumbs as their own layer over a blue-vs-red sunburst. The
background has a light and a dark version; iOS picks one per appearance and
derives the clear and tinted looks from the layers. Open the result in
Icon Composer to preview it.

    python3 Tools/make_icon.py Art/IconRender.png
"""

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SKY = np.array([123, 182, 214], dtype=np.float32)  # the unlit sky dome as rendered
SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "ThumbWar/AppIcon.icon"
# Where the rays come from: between the two faces.
CENTER = (0.5, 0.35)


def key(render: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Alpha from distance to the sky color, and the foreground with sky spill removed."""
    dist = np.linalg.norm(render - SKY, axis=2)
    alpha = np.clip((dist - 10) / 45, 0, 1)[..., None]
    # Unmix edge pixels: pixel = a * fg + (1 - a) * sky.
    safe = np.maximum(alpha, 1e-3)
    fg = np.clip((render - (1 - alpha) * SKY) / safe, 0, 255)
    return fg, alpha


def sunburst(inner, outer, ray_light, rays=18) -> np.ndarray:
    """Radial gradient with soft alternating rays."""
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    dx, dy = x - CENTER[0], y - CENTER[1]
    r = np.sqrt(dx * dx + dy * dy) / 0.75
    t = np.clip(r, 0, 1)[..., None] ** 1.2
    base = np.array(inner, np.float32) * (1 - t) + np.array(outer, np.float32) * t
    stripe = (np.sin(np.arctan2(dy, dx) * rays) > 0).astype(np.float32)
    # Rays fade in away from the center so the thumbs stay clean.
    strength = (np.clip(r * 1.6, 0, 1) * ray_light)[..., None]
    return np.clip(base + stripe[..., None] * strength * 255, 0, 255)


def versus(blue, red, seam_color, ray_light) -> np.ndarray:
    """Blue half and red half split by a zigzag bolt."""
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    seam = 0.5 + (y - 0.5) * -0.18 + 0.025 * np.sign(np.sin(y * 22))
    left = sunburst(*blue, ray_light)
    right = sunburst(*red, ray_light)
    m = (x < seam)[..., None].astype(np.float32)
    bg = left * m + right * (1 - m)
    edge = (np.abs(x - seam) < 0.008)[..., None].astype(np.float32)
    return bg * (1 - edge) + np.array(seam_color, np.float32) * edge


def save_rgb(a: np.ndarray, path: Path) -> None:
    Image.fromarray(a.astype(np.uint8)).save(path)


def main(path: str) -> None:
    render = Image.open(path).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    fg, alpha = key(np.asarray(render, np.float32))

    if OUT.exists():
        shutil.rmtree(OUT)
    assets = OUT / "Assets"
    assets.mkdir(parents=True)

    Image.fromarray(np.concatenate([fg, alpha * 255], axis=2).astype(np.uint8)).save(assets / "thumbs.png")
    save_rgb(versus(blue=((140, 205, 255), (30, 105, 210)), red=((255, 165, 150), (200, 40, 45)),
                    seam_color=(255, 255, 255), ray_light=0.06), assets / "background.png")
    save_rgb(versus(blue=((38, 74, 128), (8, 22, 52)), red=((120, 40, 46), (40, 8, 12)),
                    seam_color=(210, 220, 235), ray_light=0.03), assets / "background-dark.png")

    shadow = {"kind": "neutral", "opacity": 0.5}
    off = {"enabled": False, "value": 0.5}
    icon = {
        "fill": {"automatic-gradient": "extended-srgb:0.18824,0.41176,0.82353,1.00000"},
        "groups": [
            {"name": "Thumbs", "layers": [{"glass": False, "image-name": "thumbs.png", "name": "thumbs"}],
             "shadow": shadow, "specular": False, "translucency": off},
            {"name": "Background", "layers": [{"glass": False, "image-name": "background.png", "name": "background"}],
             "opacity-specializations": [{"appearance": "dark", "value": 0}],
             "shadow": {"kind": "none", "opacity": 0.5}, "specular": False, "translucency": off},
            {"name": "Background dark", "layers": [{"glass": False, "image-name": "background-dark.png", "name": "background-dark"}],
             "opacity-specializations": [{"value": 0}, {"appearance": "dark", "value": 1}],
             "shadow": {"kind": "none", "opacity": 0.5}, "specular": False, "translucency": off},
        ],
        "supported-platforms": {"squares": "shared"},
    }
    (OUT / "icon.json").write_text(json.dumps(icon, indent=2) + "\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Art/IconRender.png")
