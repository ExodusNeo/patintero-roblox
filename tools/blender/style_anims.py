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
import math

# Every animation plays this much slower than authored (key times and lengths are stretched on build and
# export). SkillEffects stretches its animation-beat delays by the same TEMPO; change both together.
TEMPO = 1.15

JOINTS = dict(R="Root", W="Waist", N="Neck", RS="RightShoulder", RE="RightElbow", RW="RightWrist",
              LS="LeftShoulder", LE="LeftElbow", LW="LeftWrist", RH="RightHip", RK="RightKnee", RA="RightAnkle",
              LH="LeftHip", LK="LeftKnee", LA="LeftAnkle")


def root(py, px=0.0, pz=0.0, rx=0.0, ry=0.0, rz=0.0):
    return (rx, ry, rz, px, py, pz)


THIGH, SHIN = 0.87, 0.927  # hip -> knee -> ankle (rig.py joint layout)


def _rot(axis, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    if axis == "x":
        return ((1, 0, 0), (0, c, -s), (0, s, c))
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))  # z


def _mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def _euler(m):  # (rx, ry, rz) degrees of a rotation matrix m = Rx * Ry * Rz (CFrame.Angles order)
    return (round(math.degrees(math.atan2(-m[1][2], m[2][2])), 2), round(math.degrees(math.asin(max(-1.0, min(1.0, m[0][2])))), 2),
            round(math.degrees(math.atan2(-m[0][1], m[0][0])), 2))


def leg(side, drop, fwd=0.0, out=0.0):
    """Hip, knee and ankle that keep one foot flat on the ground (2-bone IK): the root is `drop` studs below
    rest and the ankle sits `fwd` studs in front of its hip (negative = behind) and `out` studs outward."""
    s = 1 if side == "R" else -1
    down = THIGH + SHIN - drop
    reach = min(math.sqrt(out * out + down * down + fwd * fwd), THIGH + SHIN - 1e-6)
    knee = -math.acos(max(-1.0, min(1.0, (reach * reach - THIGH * THIGH - SHIN * SHIN) / (2 * THIGH * SHIN))))
    along, back = THIGH + SHIN * math.cos(knee), -SHIN * math.sin(knee)  # chain end in the thigh's frame
    spread = math.asin(max(-1.0, min(1.0, out / along)))
    hip = math.atan2(-fwd, -down) - math.atan2(back, -along * math.cos(spread))
    hip = (hip + math.pi) % (2 * math.pi) - math.pi
    h, k, r = math.degrees(hip), math.degrees(knee), math.degrees(spread) * s
    # The ankle undoes the hip and knee so the sole stays flat
    m = _mul(_mul(_rot("x", h), _rot("z", r)), _rot("x", k))
    flat = tuple(tuple(m[j][i] for j in range(3)) for i in range(3))
    return {side + "H": (round(h, 2), 0, round(r, 2)), side + "K": (round(k, 2), 0, 0), side + "A": _euler(flat)}


def stance(drop, r=(0.0, 0.0), l=(0.0, 0.0), px=0.0, pz=0.0):
    """Root + both legs with the feet planted. r / l = (fwd, out) of each ankle from its hip at rest; px / pz
    shift the root (weight shift, +px = right, +pz = back) while the feet stay where they are."""
    pose = dict(R=root(-drop, px=px, pz=pz))
    pose.update(leg("R", drop, r[0] + pz, r[1] - px))
    pose.update(leg("L", drop, l[0] + pz, l[1] + px))
    return pose


def pose(*parts, **joints):
    """Merges stance()/leg() dicts and joint keywords into one key pose (later wins)."""
    out = {}
    for part in parts:
        out.update(part)
    out.update(joints)
    return out


STAND = dict(RH=(0, 0, 0), RK=(0, 0, 0), RA=(0, 0, 0), LH=(0, 0, 0), LK=(0, 0, 0), LA=(0, 0, 0))

# Showcase loops are fighting-game character-select idles: feet planted on the ground, slow breathing and
# weight shift, one sharp signature beat per loop, eyes on the camera. No hops, dances or levitation.
# Skills: anticipation -> strike (Cubic Out) -> short hold -> settle, low and heavy, no celebrating.
# Impact beats line up with SkillEffects' delays (noted per skill); move both together.
ANIMS = {
    # ---------------- Tsinelas (light on your feet) ----------------
    "Tsinelas_Q": dict(length=0.45, loop=False, keys=[  # Dash: sprinter's drive, arms pumping
        (0.00, "Quad Out", pose(stance(0.25, r=(0.1, 0.1), l=(-0.1, 0.1)), W=(-15, 0, 0), RS=(20, 0, 8), LS=(-20, 0, -8),
                                RE=(70, 0, 0), LE=(70, 0, 0))),
        (0.08, "Cubic Out", dict(R=root(-0.4), W=(-38, 0, 0), N=(25, 0, 0), RS=(70, 0, 8), RE=(85, 0, 0), LS=(-60, 0, -8), LE=(40, 0, 0),
                                 RH=(65, 0, 0), RK=(-70, 0, 0), RA=(10, 0, 0), LH=(-30, 0, 0), LK=(-45, 0, 0), LA=(-10, 0, 0))),
        (0.25, "Sine Out", dict(R=root(-0.38), W=(-35, 0, 0), RS=(62, 0, 8), LS=(-52, 0, -8))),
        (0.45, "Sine InOut", dict(R=root(-0.3), W=(-28, 0, 0), N=(18, 0, 0), RS=(40, 0, 8), RE=(80, 0, 0), LS=(-40, 0, -8), LE=(60, 0, 0),
                                  RH=(35, 0, 0), RK=(-45, 0, 0), RA=(0, 0, 0), LH=(-15, 0, 0), LK=(-30, 0, 0), LA=(0, 0, 0))),
    ]),
    "Tsinelas_E": dict(length=0.8, loop=False, keys=[  # Takbo!: sprinter's set, then the explosive first drive (spark 0.22)
        (0.00, "Quad Out", dict(R=root(-0.75), W=(-40, 0, 0), N=(30, 0, 0), RS=(75, 0, 8), LS=(75, 0, -8), RE=(10, 0, 0), LE=(10, 0, 0),
                                RH=(80, 0, 0), RK=(-110, 0, 0), RA=(30, 0, 0), LH=(25, 0, 0), LK=(-100, 0, 0), LA=(-10, 0, 0))),
        (0.12, "Quad In", dict(R=root(-0.8), W=(-44, 0, 0), N=(32, 0, 0))),
        (0.22, "Cubic Out", dict(R=root(-0.2, pz=-0.2), W=(-25, 0, 0), N=(15, 0, 0), RS=(110, 0, 10), RE=(80, 0, 0), LS=(-55, 0, -10),
                                 LE=(50, 0, 0), RH=(70, 0, 0), RK=(-80, 0, 0), RA=(0, 0, 0), LH=(-25, 0, 0), LK=(-20, 0, 0), LA=(-15, 0, 0))),
        (0.50, "Sine Out", dict(R=root(-0.22, pz=-0.2), W=(-22, 0, 0), RS=(100, 0, 10), LS=(-48, 0, -10))),
        (0.80, "Quad In", pose(STAND, R=root(-0.15), W=(-15, 0, 0), N=(5, 0, 0), RS=(-20, 0, 5), RE=(60, 0, 0), LS=(20, 0, -5), LE=(60, 0, 0))),
    ]),
    "Tsinelas_Pose": dict(length=2.0, loop=True, keys=[  # Ready on the balls of the feet: light knee bounce, glance down the line
        (0.0, "Sine InOut", pose(stance(0.16, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-6, -8, 0), N=(0, 8, 0), RS=(10, 0, 10), RE=(35, 0, 0),
                                 RW=(-10, 0, 0), LS=(-5, 0, -10), LE=(30, 0, 0), LW=(-10, 0, 0))),
        (0.25, "Quad Out", pose(stance(0.26, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-8, -8, 0), RS=(14, 0, 10), RE=(45, 0, 0), LS=(-9, 0, -10), LE=(40, 0, 0))),
        (0.5, "Quad In", pose(stance(0.16, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-6, -8, 0), RS=(10, 0, 10), RE=(35, 0, 0), LS=(-5, 0, -10), LE=(30, 0, 0))),
        (0.75, "Quad Out", pose(stance(0.26, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-8, -8, 0), RS=(14, 0, 10), RE=(45, 0, 0), LS=(-9, 0, -10), LE=(40, 0, 0))),
        (1.0, "Cubic Out", pose(stance(0.18, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-6, -14, 0), N=(0, -32, 0), RS=(10, 0, 10), RE=(35, 0, 0),
                                LS=(-5, 0, -10), LE=(30, 0, 0))),
        (1.45, "Sine Out", pose(stance(0.22, r=(0.08, 0.12), l=(-0.18, 0.12)), N=(0, -28, 0))),
        (1.7, "Cubic Out", pose(stance(0.16, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-6, -8, 0), N=(0, 8, 0))),
        (2.0, "Sine InOut", pose(stance(0.16, r=(0.08, 0.12), l=(-0.18, 0.12)), W=(-6, -8, 0), N=(0, 8, 0), RS=(10, 0, 10), RE=(35, 0, 0),
                                 RW=(-10, 0, 0), LS=(-5, 0, -10), LE=(30, 0, 0), LW=(-10, 0, 0))),
    ]),

    # ---------------- Kanto (street-corner endurance) ----------------
    "Kanto_Q": dict(length=0.45, loop=False, keys=[  # Dash: lowered-shoulder charge (impact 0.1)
        (0.00, "Quad Out", dict(R=root(-0.3), W=(-15, 25, 0), N=(10, -20, 0), RS=(30, 0, 15), RE=(100, 0, 0), LS=(-25, 0, -10), LE=(60, 0, 0),
                                RH=(30, 0, 0), RK=(-45, 0, 0), LH=(-10, 0, 0), LK=(-25, 0, 0))),
        (0.09, "Cubic Out", dict(R=root(-0.45, pz=-0.35), W=(-28, 40, 0), N=(14, -35, 0), RS=(45, 0, 8), RE=(115, 0, 0), LS=(-45, 0, -12),
                                 LE=(45, 0, 0), RH=(50, 0, 0), RK=(-60, 0, 0), LH=(-35, 0, 0), LK=(-20, 0, 0))),
        (0.22, "Sine Out", dict(R=root(-0.42, pz=-0.3), W=(-26, 38, 0))),
        (0.45, "Sine InOut", dict(R=root(-0.3), W=(-18, 25, 0), N=(8, -20, 0), RH=(20, 0, 0), RK=(-35, 0, 0), LH=(-15, 0, 0), LK=(-15, 0, 0))),
    ]),
    "Kanto_E": dict(length=1.0, loop=False, keys=[  # Second Wind: hands on knees, one deep breath in, then set
        (0.00, "Quad Out", pose(stance(0.32, r=(0.05, 0.2), l=(0.05, 0.2)), W=(-42, 0, 0), N=(28, 0, 0), RS=(58, 0, 6), RE=(12, 0, 0),
                                LS=(58, 0, -6), LE=(12, 0, 0))),
        (0.40, "Sine Out", pose(stance(0.0, r=(0.05, 0.2), l=(0.05, 0.2)), W=(10, 0, 0), N=(12, 0, 0), RS=(-15, 0, 20), RE=(20, 0, 0),
                                LS=(-15, 0, -20), LE=(20, 0, 0))),
        (0.62, "Cubic Out", pose(stance(0.15, r=(0.05, 0.2), l=(0.05, 0.2)), W=(-8, 0, 0), N=(-5, 0, 0), RS=(10, 0, 8), RE=(40, 0, 0),
                                 LS=(10, 0, -8), LE=(40, 0, 0))),
        (1.00, "Sine InOut", pose(stance(0.08, r=(0.05, 0.2), l=(0.05, 0.2)), W=(-3, 0, 0), N=(0, 0, 0), RS=(5, 0, 8), RE=(20, 0, 0),
                                  LS=(5, 0, -8), LE=(20, 0, 0))),
    ]),
    "Kanto_Pose": dict(length=2.8, loop=True, keys=[  # Arms crossed on the corner, weight back, chin up; a slow "come on" tilt
        (0.0, "Sine InOut", pose(stance(0.06, r=(0.18, 0.2), l=(-0.12, 0.14), px=-0.1), W=(4, 10, 0), N=(6, -10, 0),
                                 RS=(14, 58, -6), RE=(96, 0, 0), LS=(18, -58, 6), LE=(86, 0, 0))),
        (1.0, "Sine InOut", pose(stance(0.03, r=(0.18, 0.2), l=(-0.12, 0.14), px=-0.12), W=(7, 10, 0), N=(8, -10, 0),
                                 RS=(16, 58, -7), LS=(20, -58, 7))),
        (1.5, "Cubic Out", pose(stance(0.06, r=(0.18, 0.2), l=(-0.12, 0.14), px=-0.1), W=(4, 14, 0), N=(14, -6, 12))),
        (2.1, "Sine InOut", pose(stance(0.06, r=(0.18, 0.2), l=(-0.12, 0.14), px=-0.1), N=(12, -6, 10))),
        (2.8, "Sine InOut", pose(stance(0.06, r=(0.18, 0.2), l=(-0.12, 0.14), px=-0.1), W=(4, 10, 0), N=(6, -10, 0),
                                 RS=(14, 58, -6), RE=(96, 0, 0), LS=(18, -58, 6), LE=(86, 0, 0))),
    ]),

    # ---------------- Bantay (born to guard) ----------------
    "Bantay_Q": dict(length=0.55, loop=False, keys=[  # Lunge: fencing lunge, open-hand thrust (slash 0.08)
        (0.00, "Quad Out", pose(stance(0.3, r=(0.0, 0.15), l=(0.0, 0.15)), W=(-8, 15, 0), RS=(30, 0, 10), RE=(70, 0, 0), LS=(20, 0, -15), LE=(40, 0, 0))),
        (0.09, "Cubic Out", pose(stance(0.8, r=(0.75, 0.12), l=(-0.75, 0.12), pz=-0.25), W=(-18, 0, 0), N=(10, 0, 0), RS=(88, 0, 0), RE=(0, 0, 0),
                                 RW=(0, 0, 0), LS=(-50, 0, -25), LE=(10, 0, 0))),
        (0.30, "Sine Out", pose(stance(0.78, r=(0.75, 0.12), l=(-0.75, 0.12), pz=-0.25), RS=(85, 0, 0))),
        (0.55, "Sine InOut", pose(stance(0.5, r=(0.5, 0.12), l=(-0.5, 0.12), pz=-0.1), W=(-10, 0, 0), N=(5, 0, 0), RS=(60, 0, 5), RE=(25, 0, 0),
                                  LS=(-20, 0, -15), LE=(20, 0, 0))),
    ]),
    "Bantay_E": dict(length=0.85, loop=False, keys=[  # Long Arm: arms cross, then snap wide across the line (ring 0.36)
        (0.00, "Quad Out", pose(stance(0.15, r=(0, 0.15), l=(0, 0.15)), W=(0, 0, 0))),
        (0.16, "Quad Out", pose(stance(0.25, r=(0, 0.15), l=(0, 0.15)), W=(-12, 0, 0), N=(-8, 0, 0), RS=(80, 0, -30), LS=(80, 0, 30),
                                RE=(30, 0, 0), LE=(30, 0, 0))),
        (0.36, "Cubic Out", pose(stance(0.45, r=(0, 0.4), l=(0, 0.4)), W=(8, 0, 0), N=(8, 0, 0), RS=(10, 0, 95), LS=(10, 0, -95),
                                 RE=(0, 0, 0), LE=(0, 0, 0))),
        (0.85, "Sine InOut", pose(stance(0.4, r=(0, 0.4), l=(0, 0.4)), W=(4, 0, 0), N=(4, 0, 0), RS=(8, 0, 88), LS=(8, 0, -88),
                                  RE=(5, 0, 0), LE=(5, 0, 0))),
    ]),
    "Bantay_Pose": dict(length=2.4, loop=True, keys=[  # Low guard on the line, arms wide; eyes track, then snap to a runner
        (0.0, "Sine InOut", pose(stance(0.4, r=(0, 0.42), l=(0, 0.42)), W=(-12, 0, 0), N=(6, 0, 0), RS=(25, 0, 45), RE=(25, 0, 0),
                                 LS=(25, 0, -45), LE=(25, 0, 0))),
        (0.7, "Sine InOut", pose(stance(0.43, r=(0, 0.42), l=(0, 0.42)), W=(-12, 8, 0), N=(6, 18, 0), RS=(25, 0, 48), LS=(25, 0, -42))),
        (1.0, "Cubic Out", pose(stance(0.46, r=(0, 0.42), l=(0, 0.42)), W=(-14, -10, 0), N=(4, -28, 0), RS=(28, 0, 52), LS=(28, 0, -52))),
        (1.6, "Sine Out", pose(stance(0.44, r=(0, 0.42), l=(0, 0.42)), W=(-13, -8, 0), N=(5, -24, 0))),
        (2.4, "Sine InOut", pose(stance(0.4, r=(0, 0.42), l=(0, 0.42)), W=(-12, 0, 0), N=(6, 0, 0), RS=(25, 0, 45), RE=(25, 0, 0),
                                 LS=(25, 0, -45), LE=(25, 0, 0))),
    ]),

    # ---------------- Sipa (kick past the line) ----------------
    "Sipa_Q": dict(length=0.5, loop=False, keys=[  # Hop: crouch, scissor kick in the air, land low
        (0.00, "Quad Out", pose(stance(0.4, r=(0, 0.12), l=(0, 0.12)), W=(-18, 0, 0), RS=(-25, 0, 15), LS=(-25, 0, -15), RE=(30, 0, 0), LE=(30, 0, 0))),
        (0.18, "Cubic Out", dict(R=root(0.5), RH=(100, 0, 0), RK=(-5, 0, 0), RA=(-25, 0, 0), LH=(-15, 0, 0), LK=(-70, 0, 0), LA=(-20, 0, 0),
                                 W=(-8, 0, 0), N=(-8, 0, 0), RS=(-20, 0, 45), LS=(30, 0, -40), RE=(30, 0, 0), LE=(60, 0, 0))),
        (0.32, "Quad In", dict(R=root(0.25), RH=(40, 0, 0), RK=(-40, 0, 0), RA=(0, 0, 0), LH=(10, 0, 0), LK=(-40, 0, 0), LA=(0, 0, 0))),
        (0.50, "Cubic Out", pose(stance(0.35, r=(0, 0.14), l=(0, 0.14)), W=(-15, 0, 0), N=(5, 0, 0), RS=(15, 0, 25), LS=(15, 0, -25),
                                 RE=(40, 0, 0), LE=(40, 0, 0))),
    ]),
    "Sipa_E": dict(length=0.75, loop=False, keys=[  # Takbo!: guard up, three knee strikes (dust 0.1 / 0.28 / 0.46), then go
        (0.00, "Quad Out", pose(stance(0.2, r=(0, 0.12), l=(0, 0.12)), W=(-8, 0, 0), RS=(60, 0, 20), RE=(110, 0, 0), LS=(60, 0, -20), LE=(110, 0, 0))),
        (0.10, "Cubic Out", pose(leg("L", 0.12, 0.0, 0.12), R=root(-0.12), RH=(95, 0, 0), RK=(-110, 0, 0), RA=(-15, 0, 0), W=(-15, 0, 0),
                                 RS=(40, 0, 15), RE=(100, 0, 0), LS=(40, 0, -15), LE=(100, 0, 0))),
        (0.19, "Quad In", pose(stance(0.2, r=(0, 0.12), l=(0, 0.12)), W=(-8, 0, 0), RS=(60, 0, 20), RE=(110, 0, 0), LS=(60, 0, -20), LE=(110, 0, 0))),
        (0.28, "Cubic Out", pose(leg("R", 0.12, 0.0, 0.12), R=root(-0.12), LH=(95, 0, 0), LK=(-110, 0, 0), LA=(-15, 0, 0), W=(-15, 0, 0),
                                 RS=(40, 0, 15), RE=(100, 0, 0), LS=(40, 0, -15), LE=(100, 0, 0))),
        (0.37, "Quad In", pose(stance(0.2, r=(0, 0.12), l=(0, 0.12)), W=(-8, 0, 0), RS=(60, 0, 20), RE=(110, 0, 0), LS=(60, 0, -20), LE=(110, 0, 0))),
        (0.46, "Cubic Out", pose(leg("L", 0.12, 0.0, 0.12), R=root(-0.12), RH=(95, 0, 0), RK=(-110, 0, 0), RA=(-15, 0, 0), W=(-15, 0, 0),
                                 RS=(40, 0, 15), RE=(100, 0, 0), LS=(40, 0, -15), LE=(100, 0, 0))),
        (0.75, "Quad In", pose(stance(0.15, r=(0, 0.12), l=(0, 0.12)), W=(-15, 0, 0), N=(5, 0, 0), RS=(-15, 0, 10), RE=(60, 0, 0),
                               LS=(15, 0, -10), LE=(60, 0, 0))),
    ]),
    "Sipa_Pose": dict(length=2.4, loop=True, keys=[  # Bladed stance, guard up, weight rocking; a sharp knee check
        (0.0, "Sine InOut", pose(stance(0.22, r=(-0.28, 0.14), l=(0.22, 0.12), px=-0.04), W=(-6, 18, 0), N=(2, -16, 0),
                                 RS=(55, 0, 22), RE=(105, 0, 0), LS=(62, 0, -14), LE=(98, 0, 0))),
        (0.6, "Sine InOut", pose(stance(0.25, r=(-0.28, 0.14), l=(0.22, 0.12), px=0.04), W=(-7, 16, 0), N=(2, -14, 0))),
        (1.0, "Sine In", pose(stance(0.2, r=(-0.28, 0.14), l=(0.22, 0.12), px=-0.1), W=(-6, 18, 0), N=(2, -16, 0))),
        (1.2, "Cubic Out", pose(leg("L", 0.14, 0.22, 0.02), R=root(-0.14, px=-0.1), RH=(92, 0, 8), RK=(-115, 0, 0), RA=(-20, 0, 0),
                                W=(-10, 22, 0), N=(4, -20, 0), RS=(48, 0, 18), RE=(110, 0, 0), LS=(58, 0, -12), LE=(100, 0, 0))),
        (1.5, "Sine Out", pose(leg("L", 0.15, 0.22, 0.02), R=root(-0.15, px=-0.1), RH=(88, 0, 8), RK=(-112, 0, 0))),
        (1.75, "Cubic Out", pose(stance(0.24, r=(-0.28, 0.14), l=(0.22, 0.12), px=-0.04), W=(-6, 18, 0), N=(2, -16, 0),
                                 RS=(55, 0, 22), RE=(105, 0, 0), LS=(62, 0, -14), LE=(98, 0, 0))),
        (2.4, "Sine InOut", pose(stance(0.22, r=(-0.28, 0.14), l=(0.22, 0.12), px=-0.04), W=(-6, 18, 0), N=(2, -16, 0),
                                 RS=(55, 0, 22), RE=(105, 0, 0), LS=(62, 0, -14), LE=(98, 0, 0))),
    ]),

    # ---------------- Tumbang (knock the can) ----------------
    "Tumbang_Q": dict(length=0.5, loop=False, keys=[  # Dash: diving reach for the can
        (0.00, "Quad Out", dict(R=root(-0.3), W=(-15, 0, 0), RS=(20, 0, 8), LS=(20, 0, -8), RE=(40, 0, 0), LE=(40, 0, 0),
                                RH=(25, 0, 0), RK=(-40, 0, 0), LH=(-10, 0, 0), LK=(-25, 0, 0))),
        (0.10, "Cubic Out", dict(R=root(-0.55, pz=-0.3), W=(-42, 0, 0), N=(28, 0, 0), RS=(125, 0, 10), LS=(110, 0, -10), RE=(5, 0, 0), LE=(15, 0, 0),
                                 RH=(35, 0, 0), RK=(-45, 0, 0), LH=(-40, 0, 0), LK=(-30, 0, 0))),
        (0.50, "Sine InOut", dict(R=root(-0.35), W=(-30, 0, 0), N=(18, 0, 0), RS=(95, 0, 10), LS=(85, 0, -10), RH=(20, 0, 0), LH=(-25, 0, 0))),
    ]),
    "Tumbang_E": dict(length=0.85, loop=False, keys=[  # Lata Shock: cocked arm whips through (can out 0.1, lands 0.32)
        (0.00, "Quad Out", pose(stance(0.1, r=(-0.3, 0.15), l=(0.35, 0.15)), W=(15, 30, 0), N=(8, -25, 0), RS=(160, 0, 30), RE=(75, 0, 0),
                                LS=(75, 0, -10), LE=(10, 0, 0))),
        (0.10, "Cubic Out", pose(stance(0.3, r=(-0.3, 0.15), l=(0.35, 0.15), pz=-0.08), W=(-10, -10, 0), N=(0, 5, 0), RS=(110, 0, 15),
                                 RE=(20, 0, 0), LS=(10, 0, -25), LE=(50, 0, 0))),
        (0.32, "Cubic Out", pose(stance(0.6, r=(-0.4, 0.15), l=(0.55, 0.15), pz=-0.12), W=(-40, -20, 0), N=(-5, 15, 0), RS=(35, 0, 10),
                                 RE=(10, 0, 0), LS=(-30, 0, -20), LE=(35, 0, 0))),
        (0.85, "Sine InOut", pose(stance(0.45, r=(-0.4, 0.15), l=(0.55, 0.15), pz=-0.08), W=(-28, -12, 0), N=(2, 10, 0), RS=(25, 0, 10),
                                  RE=(20, 0, 0))),
    ]),
    "Tumbang_Pose": dict(length=2.6, loop=True, keys=[  # Sighting the can: lead arm points, throwing arm cocked; a pump fake
        (0.0, "Sine InOut", pose(stance(0.14, r=(-0.3, 0.16), l=(0.32, 0.14), px=0.06), W=(4, -24, 0), N=(0, 22, 0),
                                 RS=(118, 0, 38), RE=(100, 0, 0), LS=(82, 0, -8), LE=(8, 0, 0))),
        (1.0, "Sine InOut", pose(stance(0.11, r=(-0.3, 0.16), l=(0.32, 0.14), px=0.08), W=(6, -26, 0), N=(2, 22, 0),
                                 RS=(124, 0, 40), LS=(84, 0, -8))),
        (1.3, "Cubic Out", pose(stance(0.2, r=(-0.3, 0.16), l=(0.32, 0.14), px=0.0, pz=-0.06), W=(-6, -10, 0), N=(0, 12, 0),
                                RS=(105, 0, 25), RE=(60, 0, 0), LS=(70, 0, -12), LE=(15, 0, 0))),
        (1.55, "Sine Out", pose(stance(0.19, r=(-0.3, 0.16), l=(0.32, 0.14), px=0.0, pz=-0.06))),
        (2.0, "Cubic Out", pose(stance(0.14, r=(-0.3, 0.16), l=(0.32, 0.14), px=0.06), W=(4, -24, 0), N=(0, 22, 0),
                                RS=(118, 0, 38), RE=(100, 0, 0), LS=(82, 0, -8), LE=(8, 0, 0))),
        (2.6, "Sine InOut", pose(stance(0.14, r=(-0.3, 0.16), l=(0.32, 0.14), px=0.06), W=(4, -24, 0), N=(0, 22, 0),
                                 RS=(118, 0, 38), RE=(100, 0, 0), LS=(82, 0, -8), LE=(8, 0, 0))),
    ]),

    # ---------------- Habagat (monsoon wind) ----------------
    "Habagat_Q": dict(length=0.5, loop=False, keys=[  # Gale Step: a tight pivot spin, arms tucked, one arm cuts out low at the end
        (0.00, "Quad Out", dict(R=root(-0.3), W=(-12, 0, 0), RS=(40, 0, -15), LS=(40, 0, 15), RE=(110, 0, 0), LE=(110, 0, 0),
                                RH=(20, 0, 0), RK=(-35, 0, 0), LH=(20, 0, 0), LK=(-35, 0, 0))),
        (0.15, "Linear", dict(R=root(0.1, ry=130), LH=(55, 0, 0), LK=(-85, 0, 0), RH=(0, 0, 0), RK=(-10, 0, 0))),
        (0.30, "Linear", dict(R=root(0.1, ry=250))),
        (0.50, "Cubic Out", dict(R=root(-0.35, ry=360), RH=(30, 0, 0), RK=(-50, 0, 0), RA=(20, 0, 0), LH=(30, 0, 0), LK=(-50, 0, 0), LA=(20, 0, 0),
                                 RS=(20, 0, 55), RE=(15, 0, 0), LS=(30, 0, -20), LE=(70, 0, 0))),
    ]),
    "Habagat_E": dict(length=0.9, loop=False, keys=[  # Monsoon: gather, rise, drive the storm into the ground (blast 0.42)
        (0.12, "Sine Out", pose(stance(0.3, r=(0, 0.2), l=(0, 0.2)), W=(-20, 0, 0), N=(-15, 0, 0), RS=(30, 0, -25), LS=(30, 0, 25),
                                RE=(40, 0, 0), LE=(40, 0, 0))),
        (0.30, "Sine InOut", pose(stance(0.05, r=(0, 0.2), l=(0, 0.2)), W=(12, 0, 0), N=(20, 0, 0), RS=(170, 0, -6), LS=(170, 0, 6),
                                  RE=(15, 0, 0), LE=(15, 0, 0))),
        (0.45, "Quad In", pose(stance(0.7, r=(0, 0.45), l=(0, 0.45)), W=(-28, 0, 0), N=(-5, 0, 0), RS=(60, 0, 50), LS=(60, 0, -50),
                               RE=(0, 0, 0), LE=(0, 0, 0))),
        (0.90, "Sine InOut", pose(stance(0.6, r=(0, 0.45), l=(0, 0.45)), W=(-20, 0, 0), N=(2, 0, 0), RS=(45, 0, 45), LS=(45, 0, -45))),
    ]),
    "Habagat_Pose": dict(length=3.2, loop=True, keys=[  # Centered and still: a slow breath, palms rise to the chest and press down
        (0.0, "Sine InOut", pose(stance(0.14, r=(0, 0.22), l=(0, 0.22)), W=(2, 0, 0), N=(0, 0, 0), RS=(8, 0, 16), RE=(22, 0, 0), RW=(0, 0, 0),
                                 LS=(8, 0, -16), LE=(22, 0, 0), LW=(0, 0, 0))),
        (1.2, "Sine InOut", pose(stance(0.08, r=(0, 0.22), l=(0, 0.22)), W=(5, 0, 0), N=(4, 0, 0), RS=(62, 0, 14), RE=(48, 0, 0), RW=(-25, 0, 0),
                                 LS=(62, 0, -14), LE=(48, 0, 0), LW=(-25, 0, 0))),
        (1.6, "Sine Out", pose(stance(0.08, r=(0, 0.22), l=(0, 0.22)), RS=(64, 0, 14), LS=(64, 0, -14))),
        (2.5, "Sine InOut", pose(stance(0.22, r=(0, 0.22), l=(0, 0.22)), W=(-2, 0, 0), N=(-2, 0, 0), RS=(12, 0, 20), RE=(12, 0, 0), RW=(-30, 0, 0),
                                 LS=(12, 0, -20), LE=(12, 0, 0), LW=(-30, 0, 0))),
        (3.2, "Sine InOut", pose(stance(0.14, r=(0, 0.22), l=(0, 0.22)), W=(2, 0, 0), N=(0, 0, 0), RS=(8, 0, 16), RE=(22, 0, 0), RW=(0, 0, 0),
                                 LS=(8, 0, -16), LE=(22, 0, 0), LW=(0, 0, 0))),
    ]),

    # ---------------- Anino (a shadow on the street) ----------------
    "Anino_Q": dict(length=0.45, loop=False, keys=[  # Dash: low shadow run, one hand trailing near the ground
        (0.00, "Quad Out", dict(R=root(-0.35), W=(-25, 0, 0), RH=(25, 0, 0), RK=(-45, 0, 0), LH=(15, 0, 0), LK=(-35, 0, 0))),
        (0.08, "Cubic Out", dict(R=root(-0.65), W=(-50, 0, 0), N=(38, 0, 0), RS=(-50, 0, 20), RE=(10, 0, 0), LS=(30, 0, -10), LE=(90, 0, 0),
                                 RH=(60, 0, 0), RK=(-90, 0, 0), LH=(-30, 0, 0), LK=(-40, 0, 0))),
        (0.45, "Sine InOut", dict(R=root(-0.5), W=(-40, 0, 0), N=(30, 0, 0), RS=(-40, 0, 15), LS=(20, 0, -10), RH=(35, 0, 0), RK=(-60, 0, 0),
                                  LH=(-20, 0, 0), LK=(-30, 0, 0))),
    ]),
    "Anino_E": dict(length=0.9, loop=False, keys=[  # Shadow Veil: drop into a cloaked crouch, arms wrapped over the head
        (0.00, "Quad Out", pose(stance(0.1, r=(0.1, 0.18), l=(-0.1, 0.18)), W=(-5, 0, 0))),
        (0.15, "Cubic Out", pose(stance(1.0, r=(0.3, 0.2), l=(-0.3, 0.2)), W=(-30, 0, 0), N=(-20, 0, 0), RS=(100, 0, -35), LS=(100, 0, 35),
                                 RE=(80, 0, 0), LE=(80, 0, 0))),
        (0.60, "Sine InOut", pose(stance(0.95, r=(0.3, 0.2), l=(-0.3, 0.2)), W=(-26, 0, 0), N=(-15, 0, 0))),
        (0.90, "Sine InOut", pose(stance(0.45, r=(0.2, 0.18), l=(-0.2, 0.18)), W=(-20, 0, 0), N=(10, 0, 0), RS=(40, 0, -10), LS=(40, 0, 10),
                                  RE=(50, 0, 0), LE=(50, 0, 0))),
    ]),
    "Anino_Pose": dict(length=2.4, loop=True, keys=[  # Low crouch, one hand on the asphalt, eyes up; a sharp tilt of the head
        (0.0, "Sine InOut", pose(stance(0.85, r=(0.32, 0.16), l=(-0.38, 0.2)), W=(-36, 0, 4), N=(34, 0, 0), RS=(-30, 0, 18), RE=(25, 0, 0),
                                 LS=(88, 0, -10), LE=(6, 0, 0))),
        (1.0, "Sine InOut", pose(stance(0.8, r=(0.32, 0.16), l=(-0.38, 0.2)), W=(-34, 0, -4), N=(36, 0, 0), RS=(-28, 0, 20), LS=(86, 0, -10))),
        (1.3, "Cubic Out", pose(stance(0.83, r=(0.32, 0.16), l=(-0.38, 0.2)), W=(-36, 6, 0), N=(36, -8, 14))),
        (1.8, "Sine Out", pose(stance(0.84, r=(0.32, 0.16), l=(-0.38, 0.2)), N=(35, -6, 12))),
        (2.4, "Sine InOut", pose(stance(0.85, r=(0.32, 0.16), l=(-0.38, 0.2)), W=(-36, 0, 4), N=(34, 0, 0), RS=(-30, 0, 18), RE=(25, 0, 0),
                                 LS=(88, 0, -10), LE=(6, 0, 0))),
    ]),

    # ---------------- Bathala (the street bows) ----------------
    "Bathala_Q": dict(length=0.55, loop=False, keys=[  # Divine Step: rise onto the toes, one open arm sweeps out (pillars 0.08)
        (0.00, "Quad Out", pose(stance(0.12, r=(0, 0.16), l=(0, 0.16)), W=(-5, 0, 0))),
        (0.10, "Cubic Out", dict(R=root(0.22), RH=(0, 0, 0), RK=(0, 0, 0), RA=(-25, 0, 0), LH=(0, 0, 0), LK=(0, 0, 0), LA=(-25, 0, 0),
                                 W=(8, 0, 0), N=(15, 0, 0), RS=(15, 0, 90), RE=(5, 0, 0), RW=(0, 0, 0), LS=(0, 0, -12), LE=(10, 0, 0))),
        (0.40, "Sine InOut", dict(R=root(0.2), N=(12, 0, 0))),
        (0.55, "Quad In", pose(stance(0.05, r=(0, 0.16), l=(0, 0.16)), W=(2, 0, 0), N=(5, 0, 0), RS=(10, 0, 30), RE=(15, 0, 0))),
    ]),
    "Bathala_E": dict(length=1.0, loop=False, keys=[  # Divine Halt: draw back, then one palm thrust out to stop the street (rune 0.33)
        (0.00, "Quad Out", pose(stance(0.1, r=(0, 0.2), l=(0, 0.2)), W=(0, 0, 0))),
        (0.15, "Quad Out", pose(stance(0.3, r=(0.25, 0.2), l=(-0.3, 0.2)), W=(-8, 15, 0), N=(-5, -10, 0), RS=(40, 0, -15), RE=(110, 0, 0),
                                RW=(0, 0, 0), LS=(-10, 0, -15), LE=(70, 0, 0))),
        (0.33, "Cubic Out", pose(stance(0.4, r=(0.4, 0.2), l=(-0.45, 0.2), pz=-0.1), W=(-6, -10, 0), N=(8, 5, 0), RS=(90, 0, 0), RE=(0, 0, 0),
                                 RW=(70, 0, 0), LS=(-15, 0, -20), LE=(85, 0, 0))),
        (0.85, "Sine InOut", pose(stance(0.4, r=(0.4, 0.2), l=(-0.45, 0.2), pz=-0.1), RS=(88, 0, 0), RW=(68, 0, 0))),
        (1.00, "Sine InOut", pose(stance(0.25, r=(0.25, 0.2), l=(-0.3, 0.2)), W=(-3, -5, 0), N=(4, 0, 0), RS=(60, 0, 5), RE=(25, 0, 0), RW=(20, 0, 0))),
    ]),
    "Bathala_Pose": dict(length=3.0, loop=True, keys=[  # Standing tall, chin up; the open palm slowly rises to halt the camera
        (0.0, "Sine InOut", pose(stance(0.03, r=(0.06, 0.18), l=(-0.06, 0.18)), W=(5, 0, 0), N=(8, 0, 0), RS=(18, 0, 12), RE=(55, 0, 0),
                                 RW=(25, 0, 0), LS=(2, 0, -10), LE=(10, 0, 0))),
        (0.8, "Sine InOut", pose(stance(0.0, r=(0.06, 0.18), l=(-0.06, 0.18)), W=(7, 0, 0), N=(10, 0, 0))),
        (1.5, "Cubic Out", pose(stance(0.05, r=(0.06, 0.18), l=(-0.06, 0.18)), W=(4, 4, 0), N=(8, -4, 0), RS=(78, 0, 8), RE=(18, 0, 0), RW=(62, 0, 0))),
        (2.2, "Sine Out", pose(stance(0.04, r=(0.06, 0.18), l=(-0.06, 0.18)), RS=(76, 0, 8), RW=(60, 0, 0))),
        (3.0, "Sine InOut", pose(stance(0.03, r=(0.06, 0.18), l=(-0.06, 0.18)), W=(5, 0, 0), N=(8, 0, 0), RS=(18, 0, 12), RE=(55, 0, 0),
                                 RW=(25, 0, 0), LS=(2, 0, -10), LE=(10, 0, 0))),
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
        out.append((t * TEMPO, ease, dict(current)))
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
        if bpy.data.actions.get(name):  # rebuild from scratch, or keys from an older version linger
            bpy.data.actions.remove(bpy.data.actions[name])
        action = bpy.data.actions.new(name)
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
        action.frame_range = (0, round(anim["length"] * TEMPO * fps))
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
        lines.append(f"        length = {anim['length'] * TEMPO:g}, looped = {'true' if anim['loop'] else 'false'},")
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
