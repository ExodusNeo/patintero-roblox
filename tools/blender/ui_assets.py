# UI art for the "jeepney chrome" interface, made in Blender. Run inside Blender:
#   exec(open(r"...\tools\blender\ui_assets.py").read(), {})
# Writes assets/ui/*.png. Two kinds of output:
#   - 3D renders (Eevee, own "PatinteroUI" scene): the chrome frame rim and the embossed skill icons
#   - flat sprites (numpy + bpy image API): rays, ribbon, bunting, confetti flag, glow
# Everything meant to be tinted in Roblox (ImageColor3) is rendered white/grey; the bunting is full color.
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


def ribbon(w=1024, h=256):
    """Banner ribbon: a body with two lower tails ending in V-notches; grey shading for tinting."""
    X, Y = grid(w, h)
    u = (X + 1) / 2 * w  # pixels
    v = (Y + 1) / 2 * h
    body = (u > 150) & (u < w - 150) & (v > 52) & (v < 204)
    tail_y = (v > 28) & (v < 172)
    notch = lambda dist: dist > (72 - np.abs(v - 100)) * 0.55  # V cut into the outer end, deepest mid-height
    left = tail_y & (u > 18) & (u < 190) & notch(u - 18)
    right = tail_y & (u < w - 18) & (u > w - 190) & notch(w - 18 - u)
    tails = (left | right) & ~body
    shade = np.where(body, 0.95 - 0.18 * ((204 - v) / 152) ** 2, 0.72)  # body lit from the top, tails behind
    fold = tails & (((u > 150) & (u < 190)) | ((u > w - 190) & (u < w - 150))) & (v < 60)
    shade = np.where(fold, 0.45, shade)
    stitch = body & ((np.abs(v - 66) < 2.5) | (np.abs(v - 190) < 2.5)) & ((u.astype(int) // 14) % 2 == 0)
    shade = np.where(stitch, 0.7, shade)
    return mono((body | tails).astype(np.float32), shade.astype(np.float32))


def bunting(w=512, h=128):
    """Tileable banderitas: a sagging string with six colored pennants."""
    X, Y = grid(w, h)
    u = (X + 1) / 2 * w
    v = (1 - Y) / 2 * h  # pixels from the top
    string_y = 14 + 10 * np.sin(np.pi * u / w)
    rgba = np.zeros((h, w, 4), dtype=np.float32)
    line = np.abs(v - string_y) < 2.2
    rgba[line] = (0.15, 0.13, 0.12, 1)
    colors = [(0.88, 0.19, 0.25), (1.0, 0.79, 0.24), (0.12, 0.71, 0.66), (0.25, 0.5, 0.95), (0.98, 0.97, 0.94), (0.4, 0.78, 0.3)]
    n = len(colors)
    for i, col in enumerate(colors):
        cx = (i + 0.5) * w / n
        top = 14 + 10 * math.sin(math.pi * cx / w)
        half = w / n * 0.38
        tri = (v > top) & (v < top + 72) & (np.abs(u - cx) < half * (1 - (v - top) / 72))
        shade = 1 - 0.25 * ((u - (cx - half)) / (2 * half))  # left edge catches the light
        for c in range(3):
            rgba[..., c] = np.where(tri, col[c] * shade, rgba[..., c])
        rgba[..., 3] = np.where(tri, 1, rgba[..., 3])
    return rgba


def flag(size=96):
    X, Y = grid(size, size)
    v = (1 - Y) / 2  # 0 top .. 1 bottom
    tri = (v > 0.1) & (v < 0.92) & (np.abs(X) < 0.85 * (1 - (v - 0.1) / 0.82))
    shade = 1 - 0.3 * (X + 1) / 2
    return mono(tri.astype(np.float32), shade.astype(np.float32))


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


def rounded_rect_points(half, radius, steps=24):
    pts = []
    for cx, cy, a0 in ((half - radius, half - radius, 0), (-half + radius, half - radius, 90),
                       (-half + radius, -half + radius, 180), (half - radius, -half + radius, 270)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            pts.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return pts


def matcap_chrome():
    """Chrome as emission driven by how much the surface faces a top-left light: crisp bright/dark bands
    every time (Eevee's world reflections blur them away on a thin tube)."""
    m = bpy.data.materials.get("m_matcap_chrome") or bpy.data.materials.new("m_matcap_chrome")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = (-0.42, 0.42, 0.8)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (0.1, 0.11, 0.16, 1)
    els[1].position, els[1].color = 1.0, (1.0, 1.0, 1.0, 1)
    for pos, col in ((0.3, (0.55, 0.6, 0.7, 1)), (0.5, (0.16, 0.18, 0.26, 1)), (0.66, (0.92, 0.95, 1.0, 1)), (0.82, (0.62, 0.68, 0.8, 1))):
        els.new(pos).color = col
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    nt.links.new(dot.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return m


def chrome_rim(scene):
    """Rounded-rect chrome tube for 9-slice frames. At 512 px: centerline 41 px in from the edge,
    corner radius 107 px, tube 36 px thick -> SliceCenter Rect(170, 170, 342, 342)."""
    curve = bpy.data.curves.new("RimPath", "CURVE")
    curve.dimensions = "3D"
    spline = curve.splines.new("POLY")
    pts = rounded_rect_points(1 - 0.16, 0.42)
    spline.points.add(len(pts) - 1)
    for p, (x, y) in zip(spline.points, pts):
        p.co = (x, y, 0, 1)
    spline.use_cyclic_u = True
    curve.bevel_depth = 0.07
    curve.bevel_resolution = 8
    rim = bpy.data.objects.new("Rim", curve)
    rim.data.materials.append(matcap_chrome())
    scene.collection.objects.link(rim)
    render(scene, "ui_rim", 512)
    bpy.data.objects.remove(rim, do_unlink=True)


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
    save_rgba("ui_ribbon", ribbon())
    save_rgba("ui_bunting", bunting())
    save_rgba("ui_flag", flag())
    scene = ui_scene()
    chrome_rim(scene)
    for name, polys in glyphs().items():
        icon(scene, name, polys)
    return sorted(os.listdir(OUT))


print(build())
