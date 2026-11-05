"""The `godly` plan for roster entries: the hand-built Godly showpieces
(godly_beasts.py, godly_skies.py; shared helpers and the standard they keep
in godly_common.py). An entry names its creature in `options.kind`, which
is its id:

    {"id": "SolarLion", "rarity": "Godly", "plan": "godly",
     "colors": {"col": "#F2B33D"}, "options": {"kind": "SolarLion"}}

`col` is the creature's main colour, for lists and checks; the drawing keeps
its own palette, so patterns and accessories do not apply to this plan."""
import godly_beasts
import godly_skies

DRAW = {**godly_beasts.BUILDERS, **godly_skies.BUILDERS}

PLANS = {'godly': ({'col'}, {'kind': set(DRAW)})}
BUILDERS = {'godly': lambda c, H, cols, opts: DRAW[opts['kind']](c, H)}
