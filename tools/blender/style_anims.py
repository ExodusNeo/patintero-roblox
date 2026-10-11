# Style animations for Patintero, authored for Blender (run inside Blender: exec(open(path).read())).
#
# Source of truth for every style's Q / E skill animation and its looping showcase pose.
# Values are in Roblox joint space: each entry is (rx, ry, rz) degrees, optionally followed by
# (px, py, pz) studs (only the Root joint moves). Axes: X = character right, Y = up, Z = back, and the
# Euler order matches CFrame.Angles (Blender rotation mode 'ZYX'), so a value here IS the joint Transform.
#   Shoulder/Hip +rx = limb forward, Elbow +rx = bend, Knee -rx = bend, Ankle +rx = toes up,
#   right limb out = +rz (left = -rz), Waist -rx = lean forward, +ry = turn left, Neck +rx = look up.
# Each key: (time, easing into this key, poses). A joint missing from a key keeps its previous value.
#
# build_actions() bakes everything into Blender actions on the "R15" rig (from rig.py) for scrubbing;
# export_luau(path) writes ReplicatedStorage.Shared.Modules.StyleAnimations.

JOINTS = dict(R="Root", W="Waist", N="Neck", RS="RightShoulder", RE="RightElbow", RW="RightWrist",
              LS="LeftShoulder", LE="LeftElbow", LW="LeftWrist", RH="RightHip", RK="RightKnee", RA="RightAnkle",
              LH="LeftHip", LK="LeftKnee", LA="LeftAnkle")


def root(py, px=0.0, pz=0.0, rx=0.0, ry=0.0, rz=0.0):
    return (rx, ry, rz, px, py, pz)


CROUCH = dict(RH=(30, 0, 0), RK=(-55, 0, 0), RA=(25, 0, 0), LH=(30, 0, 0), LK=(-55, 0, 0), LA=(25, 0, 0))
STAND = dict(RH=(0, 0, 0), RK=(0, 0, 0), RA=(0, 0, 0), LH=(0, 0, 0), LK=(0, 0, 0), LA=(0, 0, 0))

ANIMS = {
    # ---------------- Tsinelas (light on your feet) ----------------
    "Tsinelas_Q": dict(length=0.45, loop=False, keys=[  # Dash: low anime sprint, arms swept back
        (0.00, "Quad Out", dict(R=root(-0.2), W=(-12, 0, 0), RS=(-30, 0, 8), LS=(-30, 0, -8))),
        (0.09, "Quad Out", dict(R=root(-0.45), W=(-35, 0, 0), N=(22, 0, 0), RS=(-75, 0, 12), LS=(-75, 0, -12),
                                RE=(15, 0, 0), LE=(15, 0, 0), RH=(45, 0, 0), RK=(-60, 0, 0), LH=(-35, 0, 0), LK=(-25, 0, 0))),
        (0.45, "Sine InOut", dict(R=root(-0.3), W=(-25, 0, 0), N=(15, 0, 0), RS=(-60, 0, 10), LS=(-60, 0, -10),
                                  RH=(25, 0, 0), RK=(-40, 0, 0), LH=(-20, 0, 0), LK=(-20, 0, 0))),
    ]),
    "Tsinelas_E": dict(length=0.8, loop=False, keys=[  # Takbo!: sprinter's set, then a fist pump
        (0.00, "Quad Out", dict(R=root(-0.5), W=(-25, 0, 0), N=(10, 0, 0), RS=(-20, 0, 10), LS=(30, 0, -10),
                                RE=(70, 0, 0), LE=(70, 0, 0), RH=(30, 0, 0), RK=(-50, 0, 0), LH=(20, 0, 0), LK=(-40, 0, 0),
                                RA=(15, 0, 0), LA=(15, 0, 0))),
        (0.24, "Back Out", dict(R=root(0.15), W=(8, 0, 0), N=(22, 0, 0), RS=(168, 0, 15), RE=(25, 0, 0), LS=(-30, 0, -15),
                                LE=(85, 0, 0), **STAND)),
        (0.55, "Sine InOut", dict(R=root(0.05), RS=(160, 0, 12), RE=(35, 0, 0), N=(15, 0, 0), W=(4, 0, 0))),
        (0.80, "Quad In", dict(R=root(-0.1), W=(-15, 0, 0), N=(5, 0, 0), RS=(-20, 0, 5), RE=(60, 0, 0), LS=(20, 0, -5), LE=(60, 0, 0))),
    ]),
    "Tsinelas_Pose": dict(length=1.2, loop=True, keys=[  # Tinikling: hop side to side, hands on hips
        (0.0, "Sine InOut", dict(R=root(-0.35, px=-0.5), W=(-8, 0, 5), N=(0, 0, -4), **CROUCH,
                                 RS=(-20, 20, 40), RE=(95, 0, 0), LS=(-20, -20, -40), LE=(95, 0, 0))),
        (0.3, "Quad Out", dict(R=root(0.45, px=0.0), W=(0, 0, 0), N=(6, 0, 0), RH=(35, 0, 0), RK=(-75, 0, 0), RA=(-20, 0, 0),
                               LH=(35, 0, 0), LK=(-75, 0, 0), LA=(-20, 0, 0))),
        (0.6, "Quad In", dict(R=root(-0.35, px=0.5), W=(-8, 0, -5), N=(0, 0, 4), **CROUCH)),
        (0.9, "Quad Out", dict(R=root(0.45, px=0.0), W=(0, 0, 0), N=(6, 0, 0), RH=(35, 0, 0), RK=(-75, 0, 0), RA=(-20, 0, 0),
                               LH=(35, 0, 0), LK=(-75, 0, 0), LA=(-20, 0, 0))),
        (1.2, "Quad In", dict(R=root(-0.35, px=-0.5), W=(-8, 0, 5), N=(0, 0, -4), **CROUCH)),
    ]),

    # ---------------- Kanto (street-corner endurance) ----------------
    "Kanto_Q": dict(length=0.45, loop=False, keys=[  # Dash: lowered-shoulder charge
        (0.00, "Quad Out", dict(R=root(-0.2), W=(-10, 15, 0))),
        (0.09, "Quad Out", dict(R=root(-0.45), W=(-25, 35, 0), N=(12, -30, 0), RS=(40, 0, 10), RE=(110, 0, 0),
                                LS=(-40, 0, -12), LE=(40, 0, 0), RH=(40, 0, 0), RK=(-55, 0, 0), LH=(-30, 0, 0), LK=(-20, 0, 0))),
        (0.45, "Sine InOut", dict(R=root(-0.3), W=(-18, 25, 0), N=(8, -20, 0), RH=(20, 0, 0), RK=(-35, 0, 0), LH=(-15, 0, 0))),
    ]),
    "Kanto_E": dict(length=1.0, loop=False, keys=[  # Second Wind: big breath in, sharp breath out
        (0.00, "Sine InOut", dict(W=(0, 0, 0))),
        (0.40, "Sine Out", dict(R=root(0.1), W=(14, 0, 0), N=(22, 0, 0), RS=(10, 0, 125), LS=(10, 0, -125), RE=(15, 0, 0), LE=(15, 0, 0))),
        (0.62, "Quad In", dict(R=root(-0.35), W=(-18, 0, 0), N=(-12, 0, 0), RS=(25, 0, 20), LS=(25, 0, -20), RE=(30, 0, 0), LE=(30, 0, 0),
                               RH=(15, 0, 0), RK=(-25, 0, 0), LH=(15, 0, 0), LK=(-25, 0, 0))),
        (1.00, "Sine InOut", dict(R=root(-0.1), W=(-5, 0, 0), N=(0, 0, 0), RS=(5, 0, 10), LS=(5, 0, -10), RH=(5, 0, 0), RK=(-8, 0, 0),
                                  LH=(5, 0, 0), LK=(-8, 0, 0))),
    ]),
    "Kanto_Pose": dict(length=1.0, loop=True, keys=[  # Budots: loose bouncing street dance
        (0.0, "Sine InOut", dict(R=root(-0.35), RH=(20, 0, 0), RK=(-40, 0, 0), RA=(20, 0, 0), LH=(20, 0, 0), LK=(-40, 0, 0), LA=(20, 0, 0),
                                 W=(-5, 10, 8), N=(0, -10, 0), RS=(45, 0, 25), RE=(70, 0, 0), RW=(30, 0, 0), LS=(15, 0, -30), LE=(80, 0, 0), LW=(-30, 0, 0))),
        (0.5, "Sine InOut", dict(R=root(-0.1), RH=(8, 0, 0), RK=(-15, 0, 0), RA=(8, 0, 0), LH=(8, 0, 0), LK=(-15, 0, 0), LA=(8, 0, 0),
                                 W=(-5, -10, -8), N=(0, 10, 0), RS=(15, 0, 30), RE=(80, 0, 0), RW=(-30, 0, 0), LS=(45, 0, -25), LE=(70, 0, 0), LW=(30, 0, 0))),
        (1.0, "Sine InOut", dict(R=root(-0.35), RH=(20, 0, 0), RK=(-40, 0, 0), RA=(20, 0, 0), LH=(20, 0, 0), LK=(-40, 0, 0), LA=(20, 0, 0),
                                 W=(-5, 10, 8), N=(0, -10, 0), RS=(45, 0, 25), RE=(70, 0, 0), RW=(30, 0, 0), LS=(15, 0, -30), LE=(80, 0, 0), LW=(-30, 0, 0))),
    ]),

    # ---------------- Bantay (born to guard) ----------------
    "Bantay_Q": dict(length=0.55, loop=False, keys=[  # Lunge: fencing lunge, arm thrust
        (0.00, "Quad Out", dict(R=root(-0.2), W=(-5, 0, 0))),
        (0.11, "Quad Out", dict(R=root(-0.85, pz=-0.4), RH=(75, 0, 0), RK=(-75, 0, 0), RA=(5, 0, 0), LH=(-45, 0, 0), LK=(-15, 0, 0),
                                W=(-15, 0, 0), N=(8, 0, 0), RS=(88, 0, 0), RE=(0, 0, 0), LS=(-45, 0, -25), LE=(10, 0, 0))),
        (0.55, "Sine InOut", dict(R=root(-0.6, pz=-0.2), RH=(55, 0, 0), RK=(-55, 0, 0), LH=(-30, 0, 0), RS=(70, 0, 0), RE=(15, 0, 0))),
    ]),
    "Bantay_E": dict(length=0.85, loop=False, keys=[  # Long Arm: arms cross, then snap open wide
        (0.00, "Quad Out", dict(W=(0, 0, 0))),
        (0.16, "Quad Out", dict(R=root(-0.2), W=(-10, 0, 0), N=(-8, 0, 0), RS=(80, 0, -30), LS=(80, 0, 30), RE=(30, 0, 0), LE=(30, 0, 0))),
        (0.38, "Back Out", dict(R=root(-0.5), W=(10, 0, 0), N=(10, 0, 0), RS=(10, 0, 95), LS=(10, 0, -95), RE=(0, 0, 0), LE=(0, 0, 0),
                                RH=(0, 0, 15), LH=(0, 0, -15), RK=(-10, 0, 0), LK=(-10, 0, 0), RA=(0, 0, -15), LA=(0, 0, 15))),
        (0.85, "Sine InOut", dict(R=root(-0.45), W=(6, 0, 0), RS=(5, 0, 90), LS=(5, 0, -90))),
    ]),
    "Bantay_Pose": dict(length=1.6, loop=True, keys=[  # Guard shuffle: wide squat, arms spread, side steps
        (0.0, "Sine InOut", dict(R=root(-0.6, px=-0.6), RH=(15, 0, 15), LH=(15, 0, -15), RK=(-35, 0, 0), LK=(-35, 0, 0),
                                 RA=(15, 0, -15), LA=(15, 0, 15), W=(-15, -10, 0), N=(0, 10, 0), RS=(35, 0, 70), LS=(35, 0, -70),
                                 RE=(25, 0, 0), LE=(25, 0, 0))),
        (0.8, "Sine InOut", dict(R=root(-0.6, px=0.6), W=(-15, 10, 0), N=(0, -10, 0))),
        (1.6, "Sine InOut", dict(R=root(-0.6, px=-0.6), W=(-15, -10, 0), N=(0, 10, 0))),
    ]),

    # ---------------- Sipa (kick past the line) ----------------
    "Sipa_Q": dict(length=0.5, loop=False, keys=[  # Hop: crouch, hop with a high kick, land
        (0.00, "Quad Out", dict(R=root(-0.45), **CROUCH, W=(-15, 0, 0), RS=(-30, 0, 20), LS=(-30, 0, -20))),
        (0.20, "Back Out", dict(R=root(0.6), RH=(95, 0, 0), RK=(-5, 0, 0), RA=(-20, 0, 0), LH=(-10, 0, 0), LK=(-50, 0, 0), LA=(-20, 0, 0),
                                W=(-5, 0, 0), N=(-10, 0, 0), RS=(30, 0, 70), LS=(-10, 0, -75), RE=(20, 0, 0), LE=(20, 0, 0))),
        (0.50, "Quad In", dict(R=root(-0.25), RH=(20, 0, 0), RK=(-35, 0, 0), RA=(15, 0, 0), LH=(20, 0, 0), LK=(-35, 0, 0), LA=(15, 0, 0),
                               RS=(10, 0, 30), LS=(10, 0, -30))),
    ]),
    "Sipa_E": dict(length=0.75, loop=False, keys=[  # Takbo!: three quick knee juggles, then go
        (0.10, "Quad Out", dict(R=root(0.1), W=(-5, 0, 0), RH=(85, 0, 0), RK=(-90, 0, 0), RA=(-20, 0, 0), RS=(-20, 0, 40), LS=(20, 0, -40))),
        (0.28, "Quad InOut", dict(RH=(0, 0, 0), RK=(0, 0, 0), RA=(0, 0, 0), LH=(85, 0, 0), LK=(-90, 0, 0), LA=(-20, 0, 0),
                                  RS=(20, 0, 40), LS=(-20, 0, -40))),
        (0.46, "Quad InOut", dict(LH=(0, 0, 0), LK=(0, 0, 0), LA=(0, 0, 0), RH=(85, 0, 0), RK=(-90, 0, 0), RA=(-20, 0, 0),
                                  RS=(-20, 0, 40), LS=(20, 0, -40))),
        (0.75, "Quad In", dict(R=root(-0.1), W=(-15, 0, 0), **STAND, RS=(-15, 0, 10), LS=(15, 0, -10))),
    ]),
    "Sipa_Pose": dict(length=1.2, loop=True, keys=[  # Sipa juggling: alternating inside-foot kicks, eyes down
        (0.0, "Sine InOut", dict(R=root(-0.15), RH=(5, 0, 0), LH=(5, 0, 0), RK=(-10, 0, 0), LK=(-10, 0, 0), RA=(0, 0, 0), LA=(0, 0, 0),
                                 RS=(10, 0, 45), LS=(10, 0, -45), RE=(30, 0, 0), LE=(30, 0, 0), N=(-25, 0, 0), W=(-10, 0, 0))),
        (0.3, "Quad Out", dict(R=root(0.15), RH=(40, 0, -20), RK=(-75, 0, 0), LK=(-15, 0, 0), W=(-10, 0, -5),
                               RS=(0, 0, 55), LS=(20, 0, -35))),
        (0.6, "Quad In", dict(R=root(-0.15), RH=(5, 0, 0), RK=(-10, 0, 0), LK=(-10, 0, 0), W=(-10, 0, 0), RS=(10, 0, 45), LS=(10, 0, -45))),
        (0.9, "Quad Out", dict(R=root(0.15), LH=(40, 0, 20), LK=(-75, 0, 0), RK=(-15, 0, 0), W=(-10, 0, 5),
                               LS=(0, 0, -55), RS=(20, 0, 35))),
        (1.2, "Quad In", dict(R=root(-0.15), LH=(5, 0, 0), LK=(-10, 0, 0), RK=(-10, 0, 0), W=(-10, 0, 0), RS=(10, 0, 45), LS=(10, 0, -45))),
    ]),

    # ---------------- Tumbang (knock the can) ----------------
    "Tumbang_Q": dict(length=0.5, loop=False, keys=[  # Dash: diving reach for the can
        (0.00, "Quad Out", dict(R=root(-0.2), W=(-12, 0, 0))),
        (0.10, "Quad Out", dict(R=root(-0.5, pz=-0.3), W=(-40, 0, 0), N=(25, 0, 0), RS=(130, 0, 10), LS=(130, 0, -10), RE=(5, 0, 0), LE=(5, 0, 0),
                                RH=(30, 0, 0), RK=(-40, 0, 0), LH=(-40, 0, 0), LK=(-30, 0, 0))),
        (0.50, "Sine InOut", dict(R=root(-0.3), W=(-28, 0, 0), N=(15, 0, 0), RS=(100, 0, 10), LS=(100, 0, -10), RH=(20, 0, 0), LH=(-25, 0, 0))),
    ]),
    "Tumbang_E": dict(length=0.85, loop=False, keys=[  # Lata Shock: wind up and slam the can down
        (0.00, "Quad Out", dict(R=root(0.05), W=(18, 25, 0), N=(10, -20, 0), RS=(165, 0, 25), RE=(60, 0, 0), LS=(70, 0, -10), LE=(10, 0, 0),
                                LH=(-5, 0, 0), RH=(10, 0, 0))),
        (0.18, "Sine Out", dict(W=(22, 30, 0), RS=(175, 0, 30), RE=(80, 0, 0))),
        (0.32, "Quad In", dict(R=root(-0.6, pz=-0.2), W=(-38, -15, 0), N=(-10, 10, 0), RS=(40, 0, 10), RE=(10, 0, 0), LS=(-30, 0, -20), LE=(30, 0, 0),
                               RH=(55, 0, 0), RK=(-60, 0, 0), LH=(-30, 0, 0), LK=(-20, 0, 0))),
        (0.85, "Sine InOut", dict(R=root(-0.45, pz=-0.1), W=(-28, -10, 0), RS=(25, 0, 10))),
    ]),
    "Tumbang_Pose": dict(length=2.0, loop=True, keys=[  # Tumbang preso: aim, wind up, throw the tsinelas
        (0.0, "Sine InOut", dict(R=root(-0.15), W=(0, 20, 0), N=(0, -20, 0), RS=(140, 0, 30), RE=(70, 0, 0), LS=(80, 0, -15), LE=(10, 0, 0),
                                 LH=(15, 0, 0), LK=(-10, 0, 0), RH=(-10, 0, 0), RK=(0, 0, 0))),
        (0.6, "Sine InOut", dict(W=(12, 35, 0), RS=(170, 0, 35), RE=(90, 0, 0), LS=(90, 0, -5))),
        (1.0, "Quad In", dict(R=root(-0.35), W=(-25, -25, 0), N=(-5, 15, 0), RS=(45, 0, 5), RE=(5, 0, 0), LS=(-20, 0, -25), LE=(40, 0, 0),
                              RH=(35, 0, 0), RK=(-35, 0, 0), LH=(-20, 0, 0))),
        (1.4, "Sine Out", dict(W=(-20, -20, 0), RS=(30, 0, 5))),
        (2.0, "Sine InOut", dict(R=root(-0.15), W=(0, 20, 0), N=(0, -20, 0), RS=(140, 0, 30), RE=(70, 0, 0), LS=(80, 0, -15), LE=(10, 0, 0),
                                 LH=(15, 0, 0), LK=(-10, 0, 0), RH=(-10, 0, 0), RK=(0, 0, 0))),
    ]),

    # ---------------- Habagat (monsoon wind) ----------------
    "Habagat_Q": dict(length=0.5, loop=False, keys=[  # Gale Step: a full spin with the arms out
        (0.00, "Quad Out", dict(R=root(-0.3), RS=(20, 0, 70), LS=(20, 0, -70), W=(-10, 0, 0), RH=(20, 0, 0), RK=(-30, 0, 0), LH=(20, 0, 0), LK=(-30, 0, 0))),
        (0.15, "Linear", dict(R=root(0.2, ry=120), RS=(0, 0, 88), LS=(0, 0, -88), LH=(60, 0, 0), LK=(-80, 0, 0), RH=(0, 0, 0), RK=(0, 0, 0))),
        (0.30, "Linear", dict(R=root(0.2, ry=240))),
        (0.50, "Quad Out", dict(R=root(-0.2, ry=360), LH=(10, 0, 0), LK=(-20, 0, 0), RS=(15, 0, 50), LS=(15, 0, -50))),
    ]),
    "Habagat_E": dict(length=0.9, loop=False, keys=[  # Monsoon: gather, rise, slam the storm outward
        (0.12, "Sine Out", dict(R=root(-0.3), W=(-20, 0, 0), N=(-15, 0, 0), RS=(30, 0, -25), LS=(30, 0, 25), RE=(40, 0, 0), LE=(40, 0, 0))),
        (0.30, "Sine InOut", dict(R=root(0.15), W=(15, 0, 0), N=(25, 0, 0), RS=(175, 0, 20), LS=(175, 0, -20), RE=(10, 0, 0), LE=(10, 0, 0))),
        (0.45, "Quad In", dict(R=root(-0.7), W=(-25, 0, 0), N=(-5, 0, 0), RS=(70, 0, 60), LS=(70, 0, -60), RE=(0, 0, 0), LE=(0, 0, 0),
                               RH=(10, 0, 20), LH=(10, 0, -20), RK=(-30, 0, 0), LK=(-30, 0, 0), RA=(15, 0, -20), LA=(15, 0, 20))),
        (0.90, "Sine InOut", dict(R=root(-0.6), W=(-18, 0, 0))),
    ]),
    "Habagat_Pose": dict(length=2.4, loop=True, keys=[  # Flowing wind arms
        (0.0, "Sine InOut", dict(R=root(-0.1, px=-0.15), W=(0, 0, 10), N=(0, 0, -8), RS=(20, 0, 100), RE=(40, 0, 0), RW=(0, 0, 25),
                                 LS=(20, 0, -60), LE=(10, 0, 0), LW=(0, 0, -10), RH=(0, 0, 8), LH=(0, 0, -4))),
        (0.6, "Sine InOut", dict(R=root(0.05, px=0.0), W=(8, 0, 0), N=(12, 0, 0), RS=(30, 0, 130), RE=(15, 0, 0), RW=(0, 0, 0),
                                 LS=(30, 0, -130), LE=(15, 0, 0), LW=(0, 0, 0), RH=(0, 0, 0), LH=(0, 0, 0))),
        (1.2, "Sine InOut", dict(R=root(-0.1, px=0.15), W=(0, 0, -10), N=(0, 0, 8), RS=(20, 0, 60), RE=(10, 0, 0), RW=(0, 0, 10),
                                 LS=(20, 0, -100), LE=(40, 0, 0), LW=(0, 0, -25), RH=(0, 0, 4), LH=(0, 0, -8))),
        (1.8, "Sine InOut", dict(R=root(-0.25, px=0.0), W=(-8, 0, 0), N=(-6, 0, 0), RS=(15, 0, 40), RE=(30, 0, 0), RW=(0, 0, -15),
                                 LS=(15, 0, -40), LE=(30, 0, 0), LW=(0, 0, 15), RH=(0, 0, 0), LH=(0, 0, 0))),
        (2.4, "Sine InOut", dict(R=root(-0.1, px=-0.15), W=(0, 0, 10), N=(0, 0, -8), RS=(20, 0, 100), RE=(40, 0, 0), RW=(0, 0, 25),
                                 LS=(20, 0, -60), LE=(10, 0, 0), LW=(0, 0, -10), RH=(0, 0, 8), LH=(0, 0, -4))),
    ]),

    # ---------------- Anino (a shadow on the street) ----------------
    "Anino_Q": dict(length=0.45, loop=False, keys=[  # Dash: low shadow run, arms straight back
        (0.00, "Quad Out", dict(R=root(-0.25), W=(-20, 0, 0))),
        (0.08, "Quad Out", dict(R=root(-0.55), W=(-45, 0, 0), N=(35, 0, 0), RS=(-80, 0, 12), LS=(-80, 0, -12), RE=(0, 0, 0), LE=(0, 0, 0),
                                RH=(55, 0, 0), RK=(-80, 0, 0), LH=(-30, 0, 0), LK=(-30, 0, 0))),
        (0.45, "Sine InOut", dict(R=root(-0.45), W=(-38, 0, 0), N=(28, 0, 0), RH=(35, 0, 0), RK=(-55, 0, 0), LH=(-20, 0, 0))),
    ]),
    "Anino_E": dict(length=0.9, loop=False, keys=[  # Shadow Veil: drop into a cloaked crouch
        (0.00, "Quad Out", dict(W=(-5, 0, 0))),
        (0.15, "Quad Out", dict(R=root(-1.1), RH=(75, 0, 0), RK=(-110, 0, 0), RA=(35, 0, 0), LH=(75, 0, 0), LK=(-110, 0, 0), LA=(35, 0, 0),
                                W=(-25, 0, 0), N=(-25, 0, 0), RS=(100, 0, -35), LS=(100, 0, 35), RE=(70, 0, 0), LE=(70, 0, 0))),
        (0.60, "Sine InOut", dict(R=root(-0.95), W=(-20, 0, 0), N=(-15, 0, 0))),
        (0.90, "Sine InOut", dict(R=root(-0.4), RH=(30, 0, 0), RK=(-45, 0, 0), RA=(15, 0, 0), LH=(30, 0, 0), LK=(-45, 0, 0), LA=(15, 0, 0),
                                  RS=(40, 0, -10), LS=(40, 0, 10), RE=(40, 0, 0), LE=(40, 0, 0))),
    ]),
    "Anino_Pose": dict(length=2.0, loop=True, keys=[  # Shadow seal: low crouch, hands together, scanning
        (0.0, "Sine InOut", dict(R=root(-0.55), RH=(40, 0, 8), RK=(-70, 0, 0), RA=(30, 0, 0), LH=(40, 0, -8), LK=(-70, 0, 0), LA=(30, 0, 0),
                                 W=(-15, 15, 0), N=(-5, -15, 0), RS=(60, 0, -20), LS=(60, 0, 20), RE=(75, 0, 0), LE=(75, 0, 0))),
        (1.0, "Sine InOut", dict(R=root(-0.45), W=(-15, -15, 0), N=(-5, 15, 0))),
        (2.0, "Sine InOut", dict(R=root(-0.55), W=(-15, 15, 0), N=(-5, -15, 0))),
    ]),

    # ---------------- Bathala (the street bows) ----------------
    "Bathala_Q": dict(length=0.55, loop=False, keys=[  # Divine Step: rise with arms spread to the heavens
        (0.00, "Quad Out", dict(R=root(0.0))),
        (0.12, "Back Out", dict(R=root(0.7), RS=(15, 0, 135), LS=(15, 0, -135), RE=(10, 0, 0), LE=(10, 0, 0), N=(25, 0, 0), W=(12, 0, 0),
                                RA=(-35, 0, 0), LA=(-35, 0, 0), RK=(-15, 0, 0), LK=(-15, 0, 0))),
        (0.40, "Sine InOut", dict(R=root(0.6))),
        (0.55, "Quad In", dict(R=root(0.2), RS=(10, 0, 90), LS=(10, 0, -90))),
    ]),
    "Bathala_E": dict(length=1.0, loop=False, keys=[  # Divine Halt: palm thrust forward, other arm to the sky
        (0.00, "Quad Out", dict(W=(0, 0, 0))),
        (0.15, "Quad Out", dict(R=root(-0.2), W=(-10, 0, 0), N=(-10, 0, 0), RS=(40, 0, -20), RE=(100, 0, 0), LS=(40, 0, 20), LE=(100, 0, 0))),
        (0.35, "Back Out", dict(R=root(-0.3), W=(8, 0, 0), N=(15, 0, 0), RS=(90, 0, 0), RE=(0, 0, 0), RW=(70, 0, 0), LS=(170, 0, -15), LE=(10, 0, 0),
                                RH=(10, 0, 15), LH=(-10, 0, -15), RK=(-15, 0, 0), LK=(-10, 0, 0), RA=(0, 0, -15), LA=(0, 0, 15))),
        (0.85, "Sine InOut", dict(R=root(-0.28), RS=(88, 0, 0), LS=(168, 0, -15))),
        (1.00, "Sine InOut", dict(R=root(-0.15), RW=(20, 0, 0))),
    ]),
    "Bathala_Pose": dict(length=2.4, loop=True, keys=[  # Levitation: floating, arms open, legs dangling
        (0.0, "Sine InOut", dict(R=root(0.5), RS=(20, 0, 70), LS=(20, 0, -70), RE=(15, 0, 0), LE=(15, 0, 0), RW=(-15, 0, 0), LW=(-15, 0, 0),
                                 N=(15, 0, 0), W=(5, 0, 0), RH=(10, 0, 0), LH=(5, 0, 0), RK=(-25, 0, 0), LK=(-15, 0, 0), RA=(-30, 0, 0), LA=(-30, 0, 0))),
        (1.2, "Sine InOut", dict(R=root(0.95), RS=(25, 0, 80), LS=(25, 0, -80), N=(20, 0, 0), RH=(5, 0, 0), LH=(10, 0, 0), RK=(-15, 0, 0), LK=(-25, 0, 0))),
        (2.4, "Sine InOut", dict(R=root(0.5), RS=(20, 0, 70), LS=(20, 0, -70), N=(15, 0, 0), RH=(10, 0, 0), LH=(5, 0, 0), RK=(-25, 0, 0), LK=(-15, 0, 0))),
    ]),
}


def resolved(anim):
    """Full per-key poses: every joint the animation uses, carried forward (rest = 0) when a key omits it."""
    used = []
    for _, _, poses in anim["keys"]:
        for short in poses:
            if JOINTS[short] not in used:
                used.append(JOINTS[short])
    current = {name: (0, 0, 0, 0, 0, 0) for name in used}
    out = []
    for t, ease, poses in anim["keys"]:
        for short, value in poses.items():
            current[JOINTS[short]] = tuple(value) + (0, 0, 0)[: 6 - len(value)]
        out.append((t, ease, dict(current)))
    return used, out


def pose_rig(rig, poses):
    import math
    for pb in rig.pose.bones:
        value = poses.get(pb.name, (0, 0, 0, 0, 0, 0))
        pb.rotation_mode = "ZYX"
        pb.rotation_euler = tuple(math.radians(v) for v in value[:3])
        x, y, z = value[3:]
        pb.location = (x, y, z)


EASE_TO_BLENDER = {"Linear": "LINEAR", "Sine": "SINE", "Quad": "QUAD", "Cubic": "CUBIC", "Back": "BACK", "Quart": "QUART"}
DIR_TO_BLENDER = {"In": "EASE_IN", "Out": "EASE_OUT", "InOut": "EASE_IN_OUT"}


def build_actions(rig_name="R15", fps=30):
    """One Blender action per animation (fake user, so they survive saving) for scrubbing in the Dope Sheet."""
    import bpy
    rig = bpy.data.objects[rig_name]
    rig.animation_data_create()
    for name, anim in ANIMS.items():
        action = bpy.data.actions.get(name) or bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        _, keys = resolved(anim)
        for t, _, poses in keys:
            pose_rig(rig, poses)
            frame = round(t * fps)
            for pb in rig.pose.bones:
                if pb.name in poses:
                    pb.keyframe_insert("rotation_euler", frame=frame)
                    if pb.name == "Root":
                        pb.keyframe_insert("location", frame=frame)
        # Easing into each key, like the game's player
        try:
            from bpy_extras import anim_utils
            fcurves = anim_utils.action_get_channelbag_for_slot(action, rig.animation_data.action_slot).fcurves
        except Exception:
            fcurves = action.fcurves
        frame_ease = {round(t * fps): ease for t, ease, _ in keys}
        for fc in fcurves:
            points = fc.keyframe_points
            for i in range(len(points) - 1):
                style, _, direction = frame_ease[round(points[i + 1].co.x)].partition(" ")
                points[i].interpolation = EASE_TO_BLENDER[style]
                if direction:
                    points[i].easing = DIR_TO_BLENDER[direction]
        action.frame_range = (0, round(anim["length"] * fps))
    rig.animation_data.action = None
    pose_rig(rig, {})


def export_luau(path):
    """Writes the StyleAnimations ModuleScript: per animation the joint list and, per key, its time, easing
    and a flat {rx, ry, rz, px, py, pz} run per joint (degrees / studs)."""
    lines = [
        "--!strict",
        "-- GENERATED by tools/blender/style_anims.py (export_luau). Edit the animations there, not here.",
        "-- Style skill + showcase animations: per key, `pose` holds rx, ry, rz (degrees), px, py, pz (studs)",
        "-- for each joint in `joints`, in Roblox joint space (CFrame.new(p) * CFrame.Angles(r)).",
        "",
        "export type Key = { t: number, ease: string, pose: { number } }",
        "export type Anim = { length: number, looped: boolean, joints: { string }, keys: { Key } }",
        "",
        "local anims: { [string]: Anim } = {",
    ]
    for name, anim in ANIMS.items():
        used, keys = resolved(anim)
        lines.append(f"    {name} = {{")
        lines.append(f"        length = {anim['length']}, looped = {'true' if anim['loop'] else 'false'},")
        lines.append("        joints = { " + ", ".join(f'"{j}"' for j in used) + " },")
        lines.append("        keys = {")
        for t, ease, poses in keys:
            flat = []
            for j in used:
                v = poses[j]
                flat += [f"{v[0]:g}", f"{v[1]:g}", f"{v[2]:g}", f"{v[3]:g}", f"{v[4]:g}", f"{v[5]:g}"]
            lines.append(f'            {{ t = {t:g}, ease = "{ease}", pose = {{ {", ".join(flat)} }} }},')
        lines.append("        },")
        lines.append("    },")
    lines += ["}", "", "return table.freeze(anims)", ""]
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines))
    return path
