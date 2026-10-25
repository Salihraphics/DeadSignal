"""Generates the small, worn placeholder textures in assets/textures/.

Run from the project root:  python3 tools/gen_textures.py
Textures are deliberately low resolution (128-256 px) for a gritty look
and a small memory footprint on Android. Re-running with the same seed
produces identical files.
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
rng = np.random.default_rng(1985)


def value_noise(size, cell, seed_scale=1.0):
    """Tileable smooth value noise in [0, 1]."""
    n = size // cell
    grid = rng.random((n, n))
    grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
    xs = np.linspace(0, n, size, endpoint=False)
    i = xs.astype(int)
    f = xs - i
    f = f * f * (3 - 2 * f)
    a = grid[i][:, i]
    b = grid[i][:, i + 1]
    c = grid[i + 1][:, i]
    d = grid[i + 1][:, i + 1]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, cells=(64, 32, 16, 8, 4)):
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for c in cells:
        if size // c < 1:
            continue
        out += value_noise(size, c) * amp
        total += amp
        amp *= 0.55
    return out / total


def save(name, arr):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(os.path.join(OUT, name))
    print("wrote", name)


def colorize(base_rgb, lum):
    return np.stack([lum * c for c in base_rgb], axis=-1)


def scratches(img, count, length, color, alpha, size):
    for _ in range(count):
        x, y = rng.integers(0, size, 2)
        ang = rng.normal(0.3, 0.6)
        ln = rng.integers(length // 3, length)
        for t in range(ln):
            px = int(x + np.cos(ang) * t) % size
            py = int(y + np.sin(ang) * t) % size
            img[py, px] = img[py, px] * (1 - alpha) + np.array(color) * alpha


def concrete():
    s = 256
    n = fbm(s, (64, 32, 16, 8, 4, 2))
    lum = 0.78 + (n - 0.5) * 0.45
    # pits and air holes
    for _ in range(260):
        x, y = rng.integers(0, s, 2)
        lum[y, x] *= 0.55
        if rng.random() < 0.3:
            lum[y, (x + 1) % s] *= 0.7
    # faint formwork seam and water stains running down
    lum[s // 2 - 1: s // 2 + 1, :] *= 0.88
    for _ in range(5):
        x = rng.integers(0, s)
        w = rng.integers(3, 10)
        streak = np.linspace(0.86, 1.0, s)[:, None]
        lum[:, x:x + w] *= streak[: , :].repeat(min(w, s - x), axis=1)
    img = colorize((112, 110, 104), lum)
    save("concrete.png", img)


def painted_metal(name, rgb, wear):
    s = 128
    n = fbm(s, (32, 16, 8, 4, 2))
    lum = 0.88 + (n - 0.5) * 0.25
    img = colorize(rgb, lum)
    scratches(img, int(16 * wear), 24, (140, 140, 130), 0.3, s)
    # chipped paint showing dark primer
    chips = value_noise(s, 4) > (1.0 - 0.06 * wear)
    img[chips] = img[chips] * 0.45 + np.array((40, 38, 34)) * 0.55
    save(name, img)


def dark_metal():
    s = 128
    n = fbm(s, (16, 8, 4, 2))
    brushed = np.repeat(rng.random((1, s)) * 0.15, s, axis=0)
    lum = 0.8 + (n - 0.5) * 0.3 + brushed
    img = colorize((62, 64, 66), lum)
    scratches(img, 25, 40, (120, 122, 124), 0.35, s)
    save("metal_dark.png", img)


def floor():
    s = 256
    n = fbm(s, (32, 16, 8, 4))
    lum = 0.85 + (n - 0.5) * 0.3
    img = colorize((52, 54, 52), lum)
    # tile grid: 4 x 4 tiles per texture
    for k in range(0, s, 64):
        img[k:k + 2, :] *= 0.55
        img[:, k:k + 2] *= 0.55
    scratches(img, 60, 50, (90, 92, 88), 0.3, s)
    save("floor.png", img)


def hazard():
    s = 128
    y, x = np.mgrid[0:s, 0:s]
    stripe = ((x + y) // 32) % 2 == 0
    img = np.where(stripe[..., None], np.array((190, 140, 30)), np.array((28, 26, 24))).astype(float)
    n = fbm(s, (16, 8, 4))
    img *= (0.75 + n * 0.35)[..., None]
    scratches(img, 30, 30, (90, 85, 75), 0.5, s)
    save("hazard.png", img)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    concrete()
    painted_metal("paint_green.png", (78, 90, 76), 1.0)    # military green-grey
    painted_metal("paint_beige.png", (150, 142, 118), 0.6)  # instrument panels
    painted_metal("paint_grey.png", (92, 96, 98), 0.8)      # cabinets
    dark_metal()
    floor()
    hazard()
