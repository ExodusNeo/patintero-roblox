# Barangay basketball court floor, painted on worn concrete, generated in Blender (numpy + bpy image API).
# Renders ONE half court (both halves use it, the far one turned 180 degrees); writes assets/court/court_half.png.
# Units are studs (1 stud ~ 0.32 m, FIBA lines scaled): x across the court (0 = center), y from the baseline
# (y = 0) to the center line (y = HALF). The image spans the painted out-of-bounds border too.
import os

import bpy
import numpy as np

OUT = r"D:\RobloxProjects\PatinteroRobloxVerr\assets\court"
W, HALF = 47.0, 44.0  # court width, half length
BORDER = 3.0  # painted out-of-bounds band around the court
X0, X1, Y0, Y1 = -W / 2 - BORDER, W / 2 + BORDER, -BORDER, HALF
PX = 1024
PY = round(PX * (Y1 - Y0) / (X1 - X0))
LINE = 0.2  # half line width
KEY_W, KEY_D, FT_R = 15.3, 18.1, 5.6
HOOP_Y, THREE_R, CORNER_X = 4.9, 21.1, 20.7
CENTER_R = 5.6

GREEN = np.array([46, 112, 78]) / 255
RED = np.array([150, 40, 44]) / 255
WHITE = np.array([238, 236, 228]) / 255

yy, xx = np.mgrid[0:PY, 0:PX].astype(np.float32)
X = X0 + (xx + 0.5) / PX * (X1 - X0)
Y = Y0 + (yy + 0.5) / PY * (Y1 - Y0)  # Blender images start at the bottom row: row 0 is behind the baseline
AA = (X1 - X0) / PX  # one pixel in studs


def cover(d):  # 1 inside (d < 0), 0 outside, antialiased over a pixel
    return np.clip(0.5 - d / AA, 0, 1)


def stroke(d):  # line of half-width LINE along the zero set of distance d
    return cover(np.abs(d) - LINE)


def box(x0, x1, y0, y1):  # signed distance to an axis-aligned box
    dx = np.maximum(x0 - X, X - x1)
    dy = np.maximum(y0 - Y, Y - y1)
    return np.maximum(dx, dy)


def seg_v(x, y0, y1):  # distance to a vertical segment
    return np.hypot(X - x, np.maximum(0, np.maximum(y0 - Y, Y - y1)))


def seg_h(y, x0, x1):
    return np.hypot(Y - y, np.maximum(0, np.maximum(x0 - X, X - x1)))


def circle(cx, cy, r):
    return np.hypot(X - cx, Y - cy) - r


def noise(cells, seed):  # smooth value noise in 0..1
    rng = np.random.default_rng(seed)
    grid = rng.random((cells + 1, cells + 1))
    gx, gy = xx / PX * cells, yy / PY * cells
    ix, iy = np.floor(gx).astype(int), np.floor(gy).astype(int)
    fx, fy = gx - ix, gy - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = grid[iy, ix], grid[iy, ix + 1]
    c, d = grid[iy + 1, ix], grid[iy + 1, ix + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def build():
    img = np.zeros((PY, PX, 3), np.float32)
    img[:] = RED  # out-of-bounds band
    inside = cover(box(-W / 2, W / 2, 0, HALF + 1))
    key = cover(box(-KEY_W / 2, KEY_W / 2, 0, KEY_D))
    center = cover(circle(0, HALF, CENTER_R))
    paint = inside * (1 - np.maximum(key, center))
    img = img * (1 - paint[..., None]) + GREEN * paint[..., None]

    d = np.full_like(X, 1e9)
    d = np.minimum(d, seg_v(-W / 2, 0, HALF + 1))
    d = np.minimum(d, seg_v(W / 2, 0, HALF + 1))
    d = np.minimum(d, seg_h(0, -W / 2, W / 2))  # baseline
    d = np.minimum(d, seg_h(HALF, -W / 2, W / 2))  # center line (the other half draws the rest)
    d = np.minimum(d, seg_v(-KEY_W / 2, 0, KEY_D))
    d = np.minimum(d, seg_v(KEY_W / 2, 0, KEY_D))
    d = np.minimum(d, seg_h(KEY_D, -KEY_W / 2, KEY_W / 2))
    d = np.minimum(d, np.abs(circle(0, KEY_D, FT_R)))
    d = np.minimum(d, np.abs(circle(0, HALF, CENTER_R)))
    corner_y = HOOP_Y + np.sqrt(THREE_R ** 2 - CORNER_X ** 2)
    d = np.minimum(d, seg_v(-CORNER_X, 0, corner_y))
    d = np.minimum(d, seg_v(CORNER_X, 0, corner_y))
    arc = np.where(Y >= corner_y, np.abs(circle(0, HOOP_Y, THREE_R)), 1e9)
    d = np.minimum(d, arc)
    charge = np.where(Y >= HOOP_Y, np.abs(circle(0, HOOP_Y, 3.9)), 1e9)  # no-charge semicircle
    d = np.minimum(d, charge)

    wear = noise(18, 7) * 0.6 + noise(70, 11) * 0.4  # big blotches + finer grit
    lines = stroke(d) * (0.78 + 0.22 * noise(40, 3))  # chipped paint
    img = img * (1 - lines[..., None]) + WHITE * lines[..., None]
    img *= (0.9 + 0.16 * wear)[..., None]  # sun-faded patches and scuffs
    speck = (noise(220, 5) > 0.82) * 0.06
    img = np.clip(img - speck[..., None], 0, 1)
    return img


def save(name, rgb):
    os.makedirs(OUT, exist_ok=True)
    image = bpy.data.images.get(name) or bpy.data.images.new(name, PX, PY, alpha=False)
    if tuple(image.size) != (PX, PY):
        image.scale(PX, PY)
    rgba = np.concatenate([rgb, np.ones((PY, PX, 1), np.float32)], axis=2)
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
    image.filepath_raw = os.path.join(OUT, name + ".png")
    image.file_format = "PNG"
    image.save()
    return image.filepath_raw


print(save("court_half", build()), PX, PY)
