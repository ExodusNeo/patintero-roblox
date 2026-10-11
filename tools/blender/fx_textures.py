# Effect sprites for style skills, generated in Blender (numpy + bpy image API) as white-on-transparent
# PNGs so ParticleEmitter.Color can tint them per style. Run inside Blender; writes assets/fx/*.png.
import math
import os

import bpy
import numpy as np

SIZE = 256
OUT = r"D:\RobloxProjects\PatinteroRobloxVerr\assets\fx"

yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
X = (xx + 0.5) / SIZE * 2 - 1  # -1..1, +X right
Y = (yy + 0.5) / SIZE * 2 - 1  # -1..1, +Y up (Blender images start at the bottom row)
R = np.sqrt(X * X + Y * Y)
A = np.arctan2(Y, X)


def glow(d, width):
    return np.exp(-(d / width) ** 2)


def smooth(edge0, edge1, v):
    t = np.clip((v - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def ring():
    return np.clip(glow(R - 0.78, 0.07) + 0.35 * glow(R - 0.78, 0.2), 0, 1) * smooth(1.0, 0.92, R)


def rune():  # clock/sun rune for Bathala: double ring, 12 hour ticks, 4 long rays
    a = glow(R - 0.86, 0.025) + glow(R - 0.62, 0.02) + 0.6 * glow(R - 0.45, 0.015)
    tick = smooth(0.97, 0.99, np.cos(A * 12)) * (R > 0.66) * (R < 0.83)
    # Four diamonds at the cardinal points (|dx| + |dy| < size around each)
    diamonds = np.zeros_like(R)
    for cx, cy in ((0, 0.74), (0, -0.74), (0.74, 0), (-0.74, 0)):
        diamonds = np.maximum(diamonds, smooth(0.11, 0.08, np.abs(X - cx) + np.abs(Y - cy)))
    a = a + tick * 0.9 + diamonds + 0.25 * glow(R - 0.74, 0.12)
    return np.clip(a, 0, 1) * smooth(1.0, 0.94, R)


def slash():  # crescent swipe: outer circle minus offset inner circle, tapered toward the tips
    outer = smooth(0.92, 0.86, R)
    inner = smooth(0.66, 0.74, np.sqrt(X * X + (Y + 0.22) ** 2))
    taper = smooth(-0.15, 0.55, Y) * smooth(1.0, 0.7, np.abs(X))
    core = outer * inner * taper
    return np.clip(core * 1.2, 0, 1)


def wind():  # spiral swoosh, bright at the head, fading along the tail
    best = np.full_like(R, 9.0)
    along = np.zeros_like(R)
    for i in range(240):
        t = i / 239
        theta = t * math.pi * 1.6
        rad = 0.85 - 0.55 * t
        px, py = rad * math.cos(theta), rad * math.sin(theta)
        d = np.sqrt((X - px) ** 2 + (Y - py) ** 2)
        closer = d < best
        best = np.where(closer, d, best)
        along = np.where(closer, t, along)
    width = 0.03 + 0.05 * (1 - along)
    return np.clip(glow(best, width) * (1 - along) ** 0.7 * 1.3, 0, 1)


def leaf():  # pointed leaf (vesica) with a darker midrib
    rot = math.radians(35)
    u = (X * math.cos(rot) + Y * math.sin(rot)) * 1.3  # scaled so the tips stay inside the image
    v = (-X * math.sin(rot) + Y * math.cos(rot)) * 1.3
    d = 0.62  # two unit discs centered at u = +-d; their overlap is the leaf (long along v)
    far = np.maximum(np.sqrt((u - d) ** 2 + v * v), np.sqrt((u + d) ** 2 + v * v))
    body = smooth(1.0, 0.96, far)
    vein = 1 - 0.5 * glow(u, 0.02) * (np.abs(v) < 0.75)
    return np.clip(body * vein, 0, 1)


def feather():  # long feather: tapered vane, central shaft, barb striations
    rot = math.radians(-30)
    u = X * math.cos(rot) + Y * math.sin(rot)   # along the shaft
    v = -X * math.sin(rot) + Y * math.cos(rot)  # across
    half = 0.32 * np.sqrt(np.clip(1 - (u / 0.9) ** 2, 0, 1)) * (0.75 + 0.25 * u)
    vane = smooth(0.0, 0.03, half - np.abs(v)) * (np.abs(u) < 0.9)
    barbs = 0.8 + 0.2 * np.sin((u * 60 + np.abs(v) * 25))
    shaft = glow(v, 0.018) * (u > -0.98) * (u < 0.9)
    return np.clip(vane * barbs + shaft, 0, 1)


def star():  # four-point sparkle
    cross = np.maximum(glow(X, 0.035) * glow(Y, 0.6), glow(Y, 0.035) * glow(X, 0.6))
    diag = 0.35 * np.maximum(glow((X - Y) / 1.414, 0.02) * glow((X + Y) / 1.414, 0.3), glow((X + Y) / 1.414, 0.02) * glow((X - Y) / 1.414, 0.3))
    return np.clip(cross + diag + glow(R, 0.12), 0, 1)


def streak():  # speed line: thin bright core, tapered ends
    return np.clip(glow(Y, 0.05) * smooth(1.0, 0.2, np.abs(X)) * 1.2, 0, 1)


TEXTURES = dict(fx_ring=ring, fx_rune=rune, fx_slash=slash, fx_wind=wind, fx_leaf=leaf, fx_feather=feather, fx_star=star, fx_streak=streak)


def save(name, alpha):
    img = bpy.data.images.get(name) or bpy.data.images.new(name, SIZE, SIZE, alpha=True)
    rgba = np.ones((SIZE, SIZE, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


def build():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in TEXTURES.items():
        save(name, fn().astype(np.float32))
    return sorted(os.listdir(OUT))


print(build())
