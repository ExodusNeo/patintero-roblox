# Preview a Studio build in Blender when Studio's viewport can't be captured.
# In Studio (Edit, execute_luau): serialize BaseParts as JSON [{n, s(shape), z(size), c(CFrame components),
# k(rgb 0-255), t(transparency), m(material), d([face, texture] of a decal)}] and POST it to a receiver in
# Blender; then here: build(json_path) -> shot(camera_pos, look_at, out_png) with Roblox coordinates.
# Roblox (X right, Y up, Z back) maps to Blender (x, -z, y). Decals with a known local file get a textured plane.
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SCENE = "HubPreview"
DECAL_FILES = {  # rbxassetid -> local png
    "rbxassetid://113273349405803": r"D:\RobloxProjects\PatinteroRobloxVerr\assets\court\court_half.png",
}
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def to_b(x, y, z):
    return Vector((x, -z, y))


def srgb(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mesh_for(shape, cache={}):
    if shape in cache and cache[shape].name in bpy.data.meshes:
        return cache[shape]
    bm = bmesh.new()
    if shape == "Cylinder":  # Roblox cylinders run along local X (Blender local x)
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1)
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    elif shape == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
    elif shape == "Wedge":  # slope from front-bottom (-Z) up to back-top (+Z), in Roblox local space
        pts = [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
        v = [bm.verts.new(to_b(*p)) for p in pts]
        for f in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)):
            bm.faces.new([v[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    else:
        bmesh.ops.create_cube(bm, size=1)
    me = bpy.data.meshes.new(f"rbx_{shape}")
    bm.to_mesh(me)
    bm.free()
    cache[shape] = me
    return me


def material(rgb, mat_name, transparency, cache={}):
    key = (tuple(rgb), mat_name, round(transparency, 2))
    if key in cache and cache[key].name in bpy.data.materials:
        return cache[key]
    m = bpy.data.materials.new(f"rbx_{mat_name}_{rgb}")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    col = (*[srgb(c) for c in rgb], 1)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.35 if mat_name in ("Metal", "SmoothPlastic", "Glass") else 0.85
    if mat_name == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.6
    if mat_name == "Neon":
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = 4
    if transparency > 0:
        bsdf.inputs["Alpha"].default_value = 1 - transparency
    cache[key] = m
    return m


def image_material(path, cache={}):
    if path in cache and cache[path].name in bpy.data.materials:
        return cache[path]
    m = bpy.data.materials.new(os.path.basename(path))
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=True)
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    cache[path] = m
    return m


def build(json_path):
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for ob in list(scene.collection.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.context.window.scene = scene
    parts = json.load(open(json_path))
    for p in parts:
        x, y, z, *r = p["c"]
        rot = P @ Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8]))) @ P.transposed()
        sx, sy, sz = p["z"]
        ob = bpy.data.objects.new(p["n"], mesh_for(p["s"]))
        ob.matrix_world = Matrix.Translation(to_b(x, y, z)) @ rot.to_4x4() @ Matrix.Diagonal((sx, sz, sy, 1))
        ob.data.materials.clear() if False else None
        ob.active_material = material(p["k"], p["m"], p["t"])
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = material(p["k"], p["m"], p["t"])
        scene.collection.objects.link(ob)
        d = p.get("d")
        if d and d[0] == "Top" and d[1] in DECAL_FILES:
            bpy.ops.mesh.primitive_plane_add(size=1)
            plane = bpy.context.active_object
            # Roblox Top-face decal: image top edge toward the part's +Z (Back), i.e. Blender local -y
            local = (Matrix.Translation(Vector((0, 0, sy / 2 + 0.01))) @ Matrix.Rotation(math.pi, 4, "Z")
                     @ Matrix.Diagonal((sx, sz, 1, 1)))
            plane.matrix_world = Matrix.Translation(to_b(x, y, z)) @ rot.to_4x4() @ local
            plane.data.materials.append(image_material(DECAL_FILES[d[1]]))
            if plane.name not in scene.collection.objects:
                scene.collection.objects.link(plane)
    world = bpy.data.worlds.get("HubPreviewWorld") or bpy.data.worlds.new("HubPreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.42, 0.33, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.82, 0.62)
    sun.rotation_euler = (math.radians(62), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    for ob in list(scene.collection.objects):
        if ob.name.startswith("Floodlight"):
            spot = bpy.data.objects.new("Spot", bpy.data.lights.new("Spot", "SPOT"))
            spot.data.energy, spot.data.spot_size, spot.data.color = 2500, math.radians(110), (1, 0.93, 0.8)
            spot.location = ob.location - Vector((0, 0, 0.6))
            scene.collection.objects.link(spot)
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    return len(parts)


def shot(cam_pos, look_at, out_png, lens=24):
    scene = bpy.data.scenes[SCENE]
    cam = scene.objects.get("PreviewCam")
    if not cam:
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 2000
    cam.location = to_b(*cam_pos)
    cam.rotation_euler = (to_b(*look_at) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True, scene=scene.name)
    return out_png
