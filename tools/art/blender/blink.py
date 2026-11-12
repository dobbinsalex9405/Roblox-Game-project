"""The blink in the design viewer's idle clip (build.py bake_clip).

The game blinks by hiding a creature's eyes for a moment (CreatureView); the
viewer's clip closes them instead, squashing each `blink` part to a sliver
and back. A scale on a joint squashes about the joint, and the eyes' joint
sits at the head's hinge, usually well below or behind the eyes, so the
squash used to pull them down to the hinge's height: off the face and out
through the body (Alex, Nov 12). Each key now also lifts the joint by what
the squash takes away, so the eyes close about their own middle and never
leave the space the open eyes fill.

No bpy here, so tools/art/tests can check it."""

START = 1.5  # seconds into the idle clip
# The eyes' height, a frame at a time: open, closing, shut, opening, open.
SHAPE = (1.0, 0.54, 0.08, 0.54, 1.0)


def middle(spans):
    """The middle height of the eyes, from their meshes' (low, high) heights
    above the joint: the point the squash holds still."""
    lo = min(a for a, _ in spans)
    hi = max(b for _, b in spans)
    return (lo + hi) / 2


def keys(fps, mid):
    """[(frame, height scale, lift)]: frames from 0; lift is added to the
    joint's rest height so a point `mid` above the joint stays where it is
    while the eyes squash about it."""
    f0 = int(START * fps)
    return [(f0 + i, s, (1 - s) * mid) for i, s in enumerate(SHAPE)]
