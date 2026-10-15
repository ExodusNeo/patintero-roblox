# Hub props from Sketchfab (CC Attribution only), prepared for ONE Roblox "Import 3D".
# Run inside Blender with the Sketchfab add-on logged in (its API token is reused, never stored here).
#   download_all() -> import_all() -> prepare() -> export()   (credits() writes CREDITS.md)
# Every prop ends up as one mesh object named Prop_<Key> (materials kept), origin at its bottom center,
# scaled so 1 Blender unit = 1 Roblox stud (avatar 5.5 studs ~ 1.75 m, so 1 m ~ 3.2 studs). HubService places
# them by name and rescales to the same target heights, so the importer's unit setting doesn't matter.
import json
import os
import shutil
import tempfile
import urllib.error
import urllib.request
import zipfile

import bpy

ROOT = r"D:\RobloxProjects\PatinteroRobloxVerr"
CACHE = os.path.join(tempfile.gettempdir(), "patintero_sketchfab")
SCENE = "HubProps"
M = 3.2  # studs per meter

# key, uid, real height (m), title, author
PROPS = [
    ("Jeepney", "0b8bcde5df19458da9fa5606989b1e7d", 2.5, "Jeepney", "maclinmacalindong"),
    ("Tricycle", "08cb15a0c57748f793e0ead5e5095722", 1.65, "Lowpoly Traysikel/Tricycle", "jshwwy"),
    ("Monobloc", "68089dce5fa1461981d690f1cfd657fa", 0.85, "Monobloc Plastic Garden Chair", "kuuttisiitonen"),
    ("WaterDrum", "1dcc9bd0f44f4e1892c5531ad03ae0d2", 0.95, "Indian 200L Plastic Water Drum", "speeddroners"),
    ("LPG", "f71b4c9d1b9a4e8f85b72610c2153063", 0.6, "Small LPG Gas Tank", "ditovirnantio"),
    ("Bin", "f61aeec14ff441abb0f6add5485a2e90", 0.9, "Trash Can", "longtail"),
    ("Plant", "1ab9bf841df04c07b1819be596327629", 1.2, "Monstera Deliciosa Potted Mid-Century plant", "ChubbyPanda"),
    ("Aircon", "2ee631cfd24542b4b47eb6d88b34d4a8", 0.55, "Mitsubishi AC unit", "ZobboZ"),
    ("Meter", "33c41e0176cd41d8bbc40185683ee441", 0.5, "Electric Meter with fuse boxes", "BarrySArt"),
    ("TableSet", "0a6eafb63018479b98d29456dc3f6fc8", 0.85, "Dirty Plastic Chairs & Tables", "CheeseARG3d"),
]


def _token():
    return bpy.context.window_manager.sketchfab_api.api_token


def _get(url, auth=True):
    if not auth:
        return urllib.request.urlopen(url, timeout=120)
    last = None
    for scheme in ("Bearer", "Token"):  # OAuth login or a pasted API token
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": f"{scheme} {_token()}"}), timeout=120)
        except urllib.error.HTTPError as e:
            last = e
            if e.code != 401:
                raise
    raise last


def download_all():
    os.makedirs(CACHE, exist_ok=True)
    done = []
    for key, uid, *_ in PROPS:
        folder = os.path.join(CACHE, key)
        if not os.path.isdir(folder):
            info = json.load(_get(f"https://api.sketchfab.com/v3/models/{uid}/download"))
            zpath = folder + ".zip"
            with _get(info["gltf"]["url"], auth=False) as r, open(zpath, "wb") as f:
                shutil.copyfileobj(r, f)
            with zipfile.ZipFile(zpath) as z:
                z.extractall(folder)
            os.remove(zpath)
        done.append(key)
    return done


def _scene():
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scene
    return scene


def import_all():
    scene = _scene()
    report = {}
    for key, *_ in PROPS:
        coll = bpy.data.collections.get("Src_" + key)
        if coll:
            continue
        coll = bpy.data.collections.new("Src_" + key)
        scene.collection.children.link(coll)
        layer = bpy.context.view_layer.layer_collection.children[coll.name]
        bpy.context.view_layer.active_layer_collection = layer
        gltf = next(os.path.join(dp, f) for dp, _, fs in os.walk(os.path.join(CACHE, key)) for f in fs if f.endswith(".gltf"))
        bpy.ops.import_scene.gltf(filepath=gltf)
        meshes = [o for o in coll.all_objects if o.type == "MESH"]
        report[key] = {"meshes": len(meshes), "tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes),
                       "materials": len({m for o in meshes for m in o.data.materials if m})}
    return report


MAX_TRIS = {"Jeepney": 24000, "Tricycle": 12000}  # per prop; the rest are already light
MAX_TEX = 1024  # Roblox downscales anything bigger anyway


def _bbox(ob):  # from the vertices themselves (bound_box is stale right after joins and transforms)
    import numpy as np
    from mathutils import Vector
    co = np.empty(len(ob.data.vertices) * 3, dtype=np.float64)
    ob.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    mw = np.array(ob.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    return Vector(co.min(axis=0)), Vector(co.max(axis=0))


def prepare():
    """Bake each Src_<Key> collection into one mesh Prop_<Key>: transforms applied, scaled to studs, origin at the
    bottom center, decimated if heavy, laid out in a row along X (2 studs apart)."""
    from mathutils import Matrix, Vector
    scene = _scene()
    out_coll = bpy.data.collections.get("HubPropsExport") or bpy.data.collections.new("HubPropsExport")
    if out_coll.name not in scene.collection.children:
        scene.collection.children.link(out_coll)
    for ob in list(out_coll.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    x = 0.0
    report = {}
    for key, uid, height_m, *_ in PROPS:
        src = bpy.data.collections["Src_" + key]
        parts = []
        for ob in src.all_objects:
            if ob.type != "MESH":
                continue
            me = ob.data.copy()
            me.transform(ob.matrix_world)
            parts.append(me)
        merged = bpy.data.meshes.new("Prop_" + key)
        prop = bpy.data.objects.new("Prop_" + key, merged)
        out_coll.objects.link(prop)
        # join the baked copies into the new object
        tmp = []
        for me in parts:
            o = bpy.data.objects.new("tmp", me)
            out_coll.objects.link(o)
            tmp.append(o)
        bpy.ops.object.select_all(action="DESELECT")
        for o in tmp:
            o.select_set(True)
        prop.select_set(True)
        bpy.context.view_layer.objects.active = prop
        with bpy.context.temp_override(active_object=prop, selected_editable_objects=tmp + [prop], selected_objects=tmp + [prop]):
            bpy.ops.object.join()
        # scale to studs, origin at bottom center
        lo, hi = _bbox(prop)
        s = height_m * M / max(hi.z - lo.z, 1e-6)
        center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        prop.data.transform(Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation(-center))
        prop.matrix_world = Matrix.Identity(4)
        tris = sum(len(p.vertices) - 2 for p in prop.data.polygons)
        if key in MAX_TRIS and tris > MAX_TRIS[key]:
            mod = prop.modifiers.new("Decimate", "DECIMATE")
            mod.ratio = MAX_TRIS[key] / tris
            mod.use_collapse_triangulate = True
            with bpy.context.temp_override(object=prop, active_object=prop):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            tris = sum(len(p.vertices) - 2 for p in prop.data.polygons)
        lo, hi = _bbox(prop)
        prop.location.x = x - lo.x
        x += (hi.x - lo.x) + 2
        report[key] = {"tris": tris, "size_studs": [round(v, 1) for v in (hi - lo)], "materials": len(prop.data.materials)}
    # cap texture size
    for img in bpy.data.images:
        if img.size[0] > MAX_TEX or img.size[1] > MAX_TEX:
            f = MAX_TEX / max(img.size)
            img.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))
    return report


def export():
    path = os.path.join(ROOT, "assets", "models", "HubProps.fbx")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for img in bpy.data.images:  # scaled images must be written out so the FBX can embed them
        if img.is_dirty and img.source == "FILE":
            img.pack()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections["HubPropsExport"].objects:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", path_mode="COPY",
                             embed_textures=True, mesh_smooth_type="FACE", use_mesh_modifiers=True)
    return path, round(os.path.getsize(path) / 1e6, 1)


def credits():
    lines = ["# Credits", "", "## 3D models (Sketchfab, CC Attribution 4.0)", "",
             "Used in the hub (`assets/models/HubProps.fbx`, prepared by `tools/blender/hub_props.py`); scaled,",
             "decimated and re-textured at lower resolution. License: https://creativecommons.org/licenses/by/4.0/", ""]
    for key, uid, _, title, author in PROPS:
        lines.append(f'- "{title}" by {author} — https://sketchfab.com/3d-models/{uid} (as `Prop_{key}`)')
    path = os.path.join(ROOT, "CREDITS.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return path


def _material_color(mat):
    """(sRGB 0-255 color, textured) of a glTF material: Principled base color, or the Emission color of
    Sketchfab's unlit materials; a linked image texture counts as textured for Principled (Roblox imports it) but
    is averaged into a flat color for unlit ones (the importer drops those)."""
    import numpy as np
    to_srgb = lambda v: 255 * (v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055)
    if not (mat and mat.use_nodes):
        return [200, 200, 200], False
    nodes = mat.node_tree.nodes
    bsdf = next((nd for nd in nodes if nd.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        inp = bsdf.inputs["Base Color"]
        c = inp.default_value
        return [round(min(255, max(0, to_srgb(c[i])))) for i in range(3)], inp.is_linked
    emission = next((nd for nd in nodes if nd.type == "EMISSION"), None)
    if emission:
        inp = emission.inputs["Color"]
        if inp.is_linked and inp.links[0].from_node.type == "TEX_IMAGE" and inp.links[0].from_node.image:
            img = inp.links[0].from_node.image
            px = np.empty(len(img.pixels), dtype=np.float32)
            img.pixels.foreach_get(px)
            avg = px.reshape(-1, 4)[:, :3].mean(axis=0)  # stored as linear floats
            return [round(min(255, max(0, to_srgb(float(v))))) for v in avg], False
        c = inp.default_value
        return [round(min(255, max(0, to_srgb(c[i])))) for i in range(3)], False
    return [200, 200, 200], False


def recolor_json():
    """Rewrites HubProps_colors.json from the split pieces (no re-export or re-import needed)."""
    info = {}
    for ob in bpy.data.collections["HubPropsExport"].objects:
        if ob.type == "MESH":
            color, textured = _material_color(next((m for m in ob.data.materials if m), None))
            info[ob.name] = {"color": color, "textured": textured}
    with open(os.path.join(ROOT, "assets", "models", "HubProps_colors.json"), "w") as f:
        json.dump(info, f, indent=1)
    return {k: v["color"] for k, v in info.items() if k.startswith(("Prop_Tricycle", "Prop_Meter"))}


def split_by_material():
    """Roblox gives a MeshPart one texture, so each Prop_<Key> becomes an Empty "Prop_<Key>" holding one mesh per
    material (Prop_<Key>_<n>). Returns {part name: {"color": [r, g, b] 0-255 sRGB, "textured": bool}} for the
    Studio side to color untextured parts."""
    scene = _scene()
    coll = bpy.data.collections["HubPropsExport"]
    info = {}
    for key, *_ in PROPS:
        src = bpy.data.objects.get("Prop_" + key)
        if not src or src.type != "MESH":
            continue
        loc = src.location.copy()
        src.name = "Prop_" + key + "_src"
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = src
        src.select_set(True)
        with bpy.context.temp_override(active_object=src, object=src, selected_objects=[src], selected_editable_objects=[src]):
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.separate(type="MATERIAL")
            bpy.ops.object.mode_set(mode="OBJECT")
        pieces = [o for o in coll.objects if o.name.startswith("Prop_" + key + "_src")]
        holder = bpy.data.objects.new("Prop_" + key, None)
        holder.location = loc
        coll.objects.link(holder)
        for n, piece in enumerate(pieces, 1):
            piece.name = f"Prop_{key}_{n}"
            mw = piece.matrix_world.copy()
            piece.parent = holder
            piece.matrix_world = mw
            color, textured = _material_color(next((m for m in piece.data.materials if m), None))
            info[piece.name] = {"color": color, "textured": textured}
    with open(os.path.join(ROOT, "assets", "models", "HubProps_colors.json"), "w") as f:
        json.dump(info, f, indent=1)
    return {k: v for k, v in list(info.items())[:4]} | {"parts": len(info)}


def export_split():
    path = os.path.join(ROOT, "assets", "models", "HubProps.fbx")
    for img in bpy.data.images:
        if img.is_dirty and img.source == "FILE":
            img.pack()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.collections["HubPropsExport"].objects:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", path_mode="COPY",
                             embed_textures=True, mesh_smooth_type="FACE", use_mesh_modifiers=True, bake_space_transform=False)
    return path, round(os.path.getsize(path) / 1e6, 1)
