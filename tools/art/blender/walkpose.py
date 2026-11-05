"""The game's walk (games/hatchery-heist/src/shared/Walk.luau, Walk.pose and
friends) in Python, so the Blender walk clips in the design viewer move every
creature exactly as the game does. Plain Python, no Blender.

`samples()` lists poses at fixed inputs; luau.py writes them to
tests/WalkMirror.luau and Walk.spec.luau checks Walk.pose gives the same
numbers, so the two can never drift apart. Change one, change the other."""
import math
import os
import re

CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'games', 'hatchery-heist',
                      'config', 'atmosphere.luau')


def wander_speed():
    """Studs a second a creature walks (config/atmosphere.luau, wander.speed)."""
    with open(CONFIG) as f:
        m = re.search(r'wander = \{.*?\bspeed = ([0-9.]+)', f.read(), re.S)
    if not m:
        raise SystemExit(f'no wander.speed in {CONFIG}')
    return float(m.group(1))

GAITS = ('trot', 'waddle', 'hop', 'scuttle', 'slither', 'hover', 'swim')

# Studs moved per full step cycle, as a share of the creature's height.
STRIDE = {'trot': 0.9, 'waddle': 0.5, 'hop': 0.8, 'scuttle': 0.4, 'slither': 1.2, 'hover': 1.0, 'swim': 1.0}

LEG_SETS = {
    'legFL': 1, 'legBR': 1, 'legFR': -1, 'legBL': -1, 'legL': 1, 'legR': -1,
    'leg1L': 1, 'leg2R': 1, 'leg3L': 1, 'leg4R': 1, 'leg5L': 1, 'leg6R': 1,
    'leg1R': -1, 'leg2L': -1, 'leg3R': -1, 'leg4L': -1, 'leg5R': -1, 'leg6L': -1,
}

LEG_SHARE = 0.3
HOP_AIR = 0.6
STILL = (0.0, 0.0, 0.0, 0.0, 0.0)  # rx, ry, rz, dx, dy


def is_leg(anim):
    return anim in LEG_SETS


def _sideways(anim):
    if re.fullmatch(r'leg\d[LR]', anim):
        return 1 if anim.endswith('R') else -1
    return None


def _dip(h, angle):
    return h * LEG_SHARE * (1 - math.cos(angle))


def _hop_arc(phase):
    u = phase % 1
    return math.sin(u / HOP_AIR * math.pi) if u < HOP_AIR else 0.0


def phase(gait, travelled, height):
    return travelled / max(0.2, STRIDE.get(gait, 1) * height)


def wing_rate(gait, moving):
    return 1 + (0.8 if gait == 'hover' else 0.3) * moving


def pose(gait, anim, ph, moving, h, legged):
    """(rx, ry, rz, dx, dy): Walk.pose."""
    if moving <= 0:
        return STILL
    a = ph * 2 * math.pi
    s = math.sin(a)
    side = LEG_SETS.get(anim)
    if side:
        out = _sideways(anim)
        if out and gait in ('scuttle', 'trot', 'waddle'):
            lift = max(0.0, side * math.cos(a))
            return (0.0, 0.45 * moving * side * s * out, 0.3 * moving * lift * out, 0.0, 0.0)
        if gait == 'trot':
            return (0.55 * moving * side * s, 0.0, 0.0, 0.0, 0.0)
        if gait == 'waddle':
            return (0.6 * moving * side * s, 0.0, 0.0, 0.0, 0.0)
        if gait == 'scuttle':
            return (0.4 * moving * side * s, 0.0, 0.0, 0.0, 0.0)
        if gait == 'hop':
            return (-0.7 * moving * _hop_arc(ph), 0.0, 0.0, 0.0, 0.0)
        if gait == 'hover':
            return (moving * (-0.3 + 0.12 * side * s), 0.0, 0.0, 0.0, 0.0)
        return STILL
    if anim == 'body':
        if gait == 'trot':
            pitch = 0.04 * moving * math.sin(2 * a)
            if legged:
                return (pitch, 0.0, 0.0, 0.0, -_dip(h, 0.55 * moving * s))
            bounce = (1 - math.cos(2 * a)) / 2
            return (pitch, 0.0, 0.0, 0.0, h * 0.08 * moving * bounce)
        if gait == 'waddle':
            dy = -_dip(h, 0.6 * moving * s) if legged else h * 0.04 * moving * (1 - math.cos(2 * a)) / 2
            return (0.0, 0.06 * moving * s, 0.14 * moving * s, 0.0, dy)
        if gait == 'hop':
            u = ph % 1
            if u < HOP_AIR:
                pitch = -0.25 * math.cos(u / HOP_AIR * math.pi)
            else:
                pitch = 0.25 * math.cos((u - HOP_AIR) / (1 - HOP_AIR) * math.pi)
            return (pitch * moving, 0.0, 0.0, 0.0, h * 0.35 * moving * _hop_arc(ph))
        if gait == 'scuttle':
            jitter = (1 - math.cos(4 * a)) / 2
            return (0.0, 0.06 * moving * s, 0.0, 0.0, h * 0.015 * moving * jitter)
        if gait == 'slither':
            surge = (1 - math.cos(2 * a)) / 2
            return (0.0, 0.1 * moving * s, 0.0, h * 0.04 * moving * s, h * 0.02 * moving * surge)
        if gait == 'hover':
            return (-0.14 * moving, 0.0, 0.05 * moving * s, 0.0, h * 0.06 * moving)
        if gait == 'swim':
            return (0.0, -0.12 * moving * s, 0.0, h * 0.03 * moving * s, 0.0)
    elif anim == 'head':
        if gait == 'waddle':
            return (0.12 * moving * max(0.0, math.sin(2 * a)), 0.0, 0.0, 0.0, 0.0)
        if gait == 'slither':
            return (0.0, -0.12 * moving * s, 0.0, 0.0, 0.0)
    elif anim == 'tail':
        if gait == 'slither':
            return (0.0, 0.5 * moving * math.sin(a - 1.2), 0.0, 0.0, 0.0)
        if gait == 'swim':
            return (0.0, 0.55 * moving * math.sin(a - 0.8), 0.0, 0.0, 0.0)
        if gait == 'hover':
            return (0.1 * moving, 0.25 * moving * math.sin(a - 0.8), 0.0, 0.0, 0.0)
    elif anim in ('wingL', 'wingR'):
        if gait == 'waddle':
            flick = 0.18 * moving * (1 - math.cos(2 * a)) / 2
            return (0.0, 0.0, flick if anim == 'wingL' else -flick, 0.0, 0.0)
    elif anim in ('finL', 'finR'):
        if gait == 'swim':
            paddle = 0.4 * moving * math.sin(a + (0 if anim == 'finL' else math.pi))
            return (0.0, 0.0, paddle if anim == 'finL' else -paddle, 0.0, 0.0)
    return STILL


SAMPLE_ANIMS = ('body', 'head', 'tail', 'ears', 'wingL', 'wingR', 'finL', 'finR',
                'legFL', 'legFR', 'legBL', 'legBR', 'legL', 'legR', 'leg1L', 'leg2R', 'leg4L', 'leg6R')


def samples():
    """[(gait, anim, phase, moving, h, legged, pose)] over every gait."""
    out = []
    for gait in GAITS:
        for anim in SAMPLE_ANIMS:
            for i, (ph, moving, legged) in enumerate(((0.13, 1.0, True), (0.41, 0.6, True), (0.77, 1.0, False))):
                h = 2.0 + i * 0.7
                out.append((gait, anim, ph, moving, h, legged, pose(gait, anim, ph, moving, h, legged)))
    return out
