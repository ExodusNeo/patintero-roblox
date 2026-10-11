# Contact-sheet previews of style_anims poses: copies of the R15 rig side by side, each posed at one key.
# Run after rig.py and style_anims.py in the same Blender session (shares their globals).
import bpy

SPACING = 4.6
TURN = 40  # degrees; negative shows the other side


def rig_copies(n):
    base = bpy.data.objects["R15"]
    rigs = [base]
    for i in range(1, n):
        rig = bpy.data.objects.get(f"R15_{i}")
        if rig is None:
            bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
            bpy.ops.object.select_all(action="DESELECT")
            base.select_set(True)
            for child in base.children_recursive:
                child.select_set(True)
            bpy.context.view_layer.objects.active = base
            bpy.ops.object.duplicate()
            rig = bpy.context.view_layer.objects.active
            rig.name = f"R15_{i}"
        rigs.append(rig)
    import math
    for i, rig in enumerate(rigs):
        # Row along X, each turned to a 3/4 angle so a straight-on camera shows depth (arms forward/back)
        rig.location = (i * SPACING, 0, 0)
        rig.rotation_euler = (0, 0, math.radians(TURN))
    for i, rig in enumerate(rigs):
        rig.hide_viewport = rig.hide_render = False
        for child in rig.children_recursive:
            child.hide_viewport = child.hide_render = False
    # Hide extra copies from a previous, wider sheet
    i = n
    while bpy.data.objects.get(f"R15_{i}"):
        extra = bpy.data.objects[f"R15_{i}"]
        extra.hide_viewport = extra.hide_render = True
        for child in extra.children_recursive:
            child.hide_viewport = child.hide_render = True
        i += 1
    return rigs


def sheet(entries):
    """entries: list of (anim name, key index). Returns the rig object names to frame."""
    rigs = rig_copies(len(entries))
    ground = bpy.data.objects["Ground"]
    ground.location.x = (len(entries) - 1) * SPACING / 2
    ground.scale.x = max(1.0, len(entries) * SPACING / 36)
    for rig, (name, index) in zip(rigs, entries):
        _, keys = resolved(ANIMS[name])
        pose_rig(rig, keys[index][2])
    bpy.context.view_layer.update()
    return [r.name for r in rigs]
