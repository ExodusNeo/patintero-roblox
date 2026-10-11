# UI art for the "night court" interface, made in Blender. Run inside Blender:
#   exec(open(r"...\tools\blender\ui_assets.py").read(), {})
# Writes assets/ui/*.png. Two kinds of output:
#   - 3D renders (Eevee, own "PatinteroUI" scene): the embossed skill-kind icons
#   - flat sprites (numpy + bpy image API): sunburst rays, glow, asphalt grain
# Everything is white/grey so Roblox can tint it (ImageColor3).
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

OUT = r"D:\RobloxProjects\PatinteroRobloxVerr\assets\ui"
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------- flat sprites
def save_rgba(name, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=True)
    if tuple(img.size) != (w, h):
        img.scale(w, h)
    img.pixels.foreach_set(np.ascontiguousarray(rgba, dtype=np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


def grid(w, h):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return (xx + 0.5) / w * 2 - 1, (yy + 0.5) / h * 2 - 1  # -1..1, +Y up


def smooth(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mono(alpha, shade=None):
    rgba = np.ones(alpha.shape + (4,), dtype=np.float32)
    if shade is not None:
        rgba[..., :3] = shade[..., None]
    rgba[..., 3] = np.clip(alpha, 0, 1)
    return rgba


def rays(n=16, size=512):
    X, Y = grid(size, size)
    r, a = np.sqrt(X * X + Y * Y), np.arctan2(Y, X)
    beam = smooth(-0.15, 0.25, np.cos(a * n))  # soft-edged wedges
    fade = smooth(1.0, 0.15, r) * smooth(0.0, 0.08, r)
    return mono(beam * fade * 0.9)


def glow(size=256):
    X, Y = grid(size, size)
    r = np.sqrt(X * X + Y * Y)
    return mono(np.exp(-(r / 0.45) ** 2) * smooth(1.0, 0.85, r))


def grain(size=256, seed=7):
    """Tileable asphalt grain: sparse light specks over soft noise, laid over panels at low opacity."""
    rng = np.random.default_rng(seed)
    noise = rng.random((size, size)).astype(np.float32)
    soft = (noise + np.roll(noise, 1, 0) + np.roll(noise, 1, 1) + np.roll(noise, -1, 0) + np.roll(noise, -1, 1)) / 5
    specks = (noise > 0.985).astype(np.float32)
    return mono(np.clip((soft - 0.35) * 0.6 + specks * 0.8, 0, 1))


# ---------------------------------------------------------------- 3D renders
def ui_scene():
    scene = bpy.data.scenes.get("PatinteroUI") or bpy.data.scenes.new("PatinteroUI")
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = next(e for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE") if e in engines)
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_percentage = 100

    world = bpy.data.worlds.get("UIWorld") or bpy.data.worlds.new("UIWorld")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    # Studio sky for chrome: dark below the horizon, a bright band above it, soft white top
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.3, (0.04, 0.05, 0.1, 1)
    els[1].position, els[1].color = 0.95, (0.85, 0.9, 1.0, 1)
    for pos, col in ((0.45, (1.0, 1.0, 1.0, 1)), (0.58, (0.12, 0.14, 0.22, 1)), (0.72, (0.95, 0.97, 1.0, 1))):
        els.new(pos).color = col
    nt.links.new(coord.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    bg.inputs["Strength"].default_value = 1.2

    cam = bpy.data.objects.new("UICam", bpy.data.cameras.new("UICam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.0
    cam.location = (0, 0, 5)
    scene.collection.objects.link(cam)
    scene.camera = cam

    sun = bpy.data.objects.new("UISun", bpy.data.lights.new("UISun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(35), math.radians(-25), 0)  # light from the top-left
    scene.collection.objects.link(sun)
    return scene


def material(name, rgb, metallic, roughness):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


def render(scene, name, size):
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True, scene=scene.name)


# Glyph outlines in -1..1 (several polygons per icon are fine; overlaps read as one shape)
def star(cx, cy, r_out, r_in, points=4, rot=90):
    out = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        r = r_out if i % 2 == 0 else r_in
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def bar(cx, cy, length, width, angle):
    a = math.radians(angle)
    dx, dy = math.cos(a) * length / 2, math.sin(a) * length / 2
    nx, ny = -math.sin(a) * width / 2, math.cos(a) * width / 2
    return [(cx - dx - nx, cy - dy - ny), (cx + dx - nx, cy + dy - ny), (cx + dx + nx, cy + dy + ny), (cx - dx + nx, cy - dy + ny)]


def band(fn, t0, t1, w0, w1, steps=60, width=None):
    """Polygon of a stroke following fn(t) -> (x, y), width tapering w0 -> w1 (or width(u), u = 0..1)."""
    pts = [fn(t0 + (t1 - t0) * i / steps) for i in range(steps + 1)]
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        x2, y2 = pts[min(i + 1, steps)]
        x1, y1 = pts[max(i - 1, 0)]
        tx, ty = x2 - x1, y2 - y1
        n = math.hypot(tx, ty) or 1
        w = (width(i / steps) if width else w0 + (w1 - w0) * i / steps) / 2
        left.append((x - ty / n * w, y + tx / n * w))
        right.append((x + ty / n * w, y - tx / n * w))
    return left + right[::-1]


def crescent():
    arc = lambda t: (0.5 * math.cos(math.radians(70 + 220 * t)) - 0.08, 0.5 * math.sin(math.radians(70 + 220 * t)))
    return band(arc, 0, 1, 0, 0, steps=72, width=lambda u: 0.04 + 0.62 * math.sin(math.pi * u))


def gust(y, x0, x1, curl):
    """Wind stroke: straight run ending in a curl (curl = +1 up, -1 down)."""
    r = 0.2
    def fn(t):
        if t < 0.6:
            return (x0 + (x1 - x0) * t / 0.6, y)
        a = (t - 0.6) / 0.4 * math.radians(270)
        return (x1 + r * math.sin(a), y + curl * r * (1 - math.cos(a)))
    return band(fn, 0, 1, 0, 0, steps=70, width=lambda u: 0.16 - 0.08 * u)


def glyphs():
    chevron = lambda dx: [(-0.95 + dx, 0.72), (-0.5 + dx, 0.72), (0.02 + dx, 0), (-0.5 + dx, -0.72), (-0.95 + dx, -0.72), (-0.43 + dx, 0)]
    snow = []
    for k in range(3):
        snow.append(bar(0, 0, 1.9, 0.17, 90 + k * 60))
    for k in range(6):
        a = math.radians(90 + k * 60)
        bx, by = 0.55 * math.cos(a), 0.55 * math.sin(a)
        for side in (-1, 1):
            b_ang = math.degrees(a) + side * 50
            ex, ey = bx + 0.17 * math.cos(math.radians(b_ang)), by + 0.17 * math.sin(math.radians(b_ang))
            snow.append(bar(ex, ey, 0.38, 0.13, b_ang))
    return {
        "Dash": [chevron(0.05), chevron(0.85)],
        "Blink": [star(-0.12, -0.08, 0.9, 0.22), star(0.6, 0.62, 0.34, 0.09)],
        "Haste": [[(-0.05, 0.95), (0.45, 0.95), (0.12, 0.2), (0.55, 0.2), (-0.25, -0.95), (0.0, -0.12), (-0.45, -0.12)]],
        "SecondWind": [gust(0.42, -0.9, 0.35, 1), gust(-0.02, -0.6, 0.6, 1), gust(-0.5, -0.95, 0.15, -1)],
        "LongArm": [[(-1, 0), (-0.52, 0.45), (-0.52, 0.17), (0.52, 0.17), (0.52, 0.45), (1, 0), (0.52, -0.45), (0.52, -0.17), (-0.52, -0.17), (-0.52, -0.45)]],
        "Slow": snow,
        "Veil": [crescent(), star(0.55, 0.55, 0.26, 0.07)],
    }


def icon(scene, name, polys):
    mesh = bpy.data.meshes.new("Glyph")
    bm = bmesh.new()
    for poly in polys:
        verts = [bm.verts.new((x * 0.88, y * 0.88, 0)) for x, y in poly]
        bm.faces.new(verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Glyph", mesh)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.16
    solid.offset = 1
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.045
    bev.segments = 4
    bev.limit_method = "ANGLE"
    obj.data.materials.append(material("m_glyph", (0.92, 0.92, 0.94), 0.25, 0.3))
    scene.collection.objects.link(obj)
    render(scene, f"icon_{name}", 256)
    bpy.data.objects.remove(obj, do_unlink=True)


def build():
    save_rgba("ui_rays", rays())
    save_rgba("ui_glow", glow())
    save_rgba("ui_grain", grain())
    scene = ui_scene()
    for name, polys in glyphs().items():
        icon(scene, name, polys)
    return sorted(os.listdir(OUT))


print(build())
