# Builds a default Roblox R15 rig in Blender (exact joint layout pulled from Studio) for authoring
# style animations. Axis convention: Roblox (x, y, z) -> Blender (x, -z, y), so the character faces +Y.
# Every bone's rest frame equals its Roblox joint frame, so a pose bone's local rotation/location
# (Euler mode 'ZYX' == Roblox CFrame.Angles order) is exactly the joint's Transform.
import bpy
from mathutils import Matrix, Vector

GROUND = 3.006  # HRP center above the feet

PARTS = {  # name: (size xyz, center xyz) in Roblox HRP space
    "LowerTorso": ((1.991, 0.401, 1.004), (0, -0.8, 0)),
    "UpperTorso": ((1.943, 1.698, 1.004), (0, 0.2, 0)),
    "Head": ((1.159, 1.182, 1.161), (0, 1.586, 0)),
    "RightUpperArm": ((1.001, 1.242, 1.002), (1.5, 0.369, 0)),
    "RightLowerArm": ((1.001, 1.118, 1.002), (1.5, -0.224, 0)),
    "RightHand": ((0.984, 0.316, 1.028), (1.5, -0.85, 0)),
    "LeftUpperArm": ((1.001, 1.242, 1.002), (-1.5, 0.369, 0)),
    "LeftLowerArm": ((1.001, 1.118, 1.002), (-1.5, -0.224, 0)),
    "LeftHand": ((0.984, 0.316, 1.028), (-1.5, -0.85, 0)),
    "RightUpperLeg": ((0.993, 1.363, 0.973), (0.5, -1.421, 0)),
    "RightLowerLeg": ((0.993, 1.301, 0.973), (0.5, -2.201, 0)),
    "RightFoot": ((1.009, 0.312, 1.001), (0.5, -2.85, 0)),
    "LeftUpperLeg": ((0.993, 1.363, 0.973), (-0.5, -1.421, 0)),
    "LeftLowerLeg": ((0.993, 1.301, 0.973), (-0.5, -2.201, 0)),
    "LeftFoot": ((1.009, 0.312, 1.001), (-0.5, -2.85, 0)),
}

JOINTS = {  # joint: (parent joint, part it moves, world position in Roblox HRP space)
    "Root": (None, "LowerTorso", (0, -1.0, 0)),
    "Waist": ("Root", "UpperTorso", (0, -0.6, 0)),
    "Neck": ("Waist", "Head", (0, 1.049, 0)),
    "RightShoulder": ("Waist", "RightUpperArm", (0.972, 0.798, 0)),
    "RightElbow": ("RightShoulder", "RightLowerArm", (1.5, 0.014, 0)),
    "RightWrist": ("RightElbow", "RightHand", (1.5, -0.756, 0)),
    "LeftShoulder": ("Waist", "LeftUpperArm", (-0.972, 0.798, 0)),
    "LeftElbow": ("LeftShoulder", "LeftLowerArm", (-1.5, 0.014, 0)),
    "LeftWrist": ("LeftElbow", "LeftHand", (-1.5, -0.756, 0)),
    "RightHip": ("Root", "RightUpperLeg", (0.5, -1.0, 0)),
    "RightKnee": ("RightHip", "RightLowerLeg", (0.5, -1.87, 0)),
    "RightAnkle": ("RightKnee", "RightFoot", (0.5, -2.797, 0)),
    "LeftHip": ("Root", "LeftUpperLeg", (-0.5, -1.0, 0)),
    "LeftKnee": ("LeftHip", "LeftLowerLeg", (-0.5, -1.87, 0)),
    "LeftAnkle": ("LeftKnee", "LeftFoot", (-0.5, -2.797, 0)),
}

COLORS = {"Head": (0.96, 0.8, 0.26), "UpperTorso": (0.05, 0.41, 0.67), "LowerTorso": (0.05, 0.41, 0.67)}
ARM, LEG = (0.96, 0.8, 0.26), (0.29, 0.6, 0.29)


def b(v):  # Roblox vector -> Blender vector (+ ground offset)
    x, y, z = v
    return Vector((x, -z, y + GROUND))


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def build():
    # Own scene, so the user's scene is never touched; rebuilt from scratch on every run
    scene = bpy.data.scenes.get("PatinteroAnim") or bpy.data.scenes.new("PatinteroAnim")
    bpy.context.window.scene = scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    arm_data = bpy.data.armatures.new("R15")
    rig = bpy.data.objects.new("R15", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    rest = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # columns: X->X, Y(up)->Z, Z(back)->-Y
    for name, (parent, _, pos) in JOINTS.items():
        eb = arm_data.edit_bones.new(name)
        eb.head = (0, 0, 0)
        eb.tail = (0, 0.3, 0)
        m = rest.to_4x4()
        m.translation = b(pos)
        eb.matrix = m
        if parent:
            eb.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.rotation_mode = "ZYX"
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    part_bone = {part: joint for joint, (_, part, _) in JOINTS.items()}
    for part, (size, center) in PARTS.items():
        bpy.ops.mesh.primitive_cube_add(size=1)
        box = bpy.context.active_object
        box.name = part
        box.scale = (size[0], size[2], size[1])
        bpy.ops.object.transform_apply(scale=True)
        bevel = box.modifiers.new("Bevel", "BEVEL")
        bevel.width = 0.06
        bevel.segments = 2
        color = COLORS.get(part) or (ARM if "Arm" in part or "Hand" in part else LEG)
        box.data.materials.append(mat(f"m_{part}", color))
        world = Matrix.Translation(b(center))
        box.parent = rig
        box.parent_type = "BONE"
        box.parent_bone = part_bone[part]
        bpy.context.view_layer.update()
        box.matrix_world = world

    # Face on the front (+Y) so facing is obvious in previews
    head = bpy.data.objects["Head"]
    for x in (-0.22, 0.22):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=b((x, 1.66, -0.58)))
        eye = bpy.context.active_object
        eye.name = "Eye"
        eye.data.materials.append(mat("m_eye", (0.02, 0.02, 0.02)))
        m = eye.matrix_world.copy()
        eye.parent = head
        eye.matrix_world = m

    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.name = "Ground"
    ground.data.materials.append(mat("m_ground", (0.42, 0.38, 0.35)))

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.9, 0.2, 0.6)
    bpy.context.scene.collection.objects.link(sun)
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
    bg.inputs["Strength"].default_value = 0.8

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (6.5, 9.5, 4.2)
    cam.rotation_euler = (1.32, 0, 2.53)
    bpy.context.scene.render.fps = 30
    return rig


build()
print("rig ok", len(bpy.data.objects["R15"].pose.bones), "bones")
