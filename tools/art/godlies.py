"""The Godly showpieces from the approved master sheet (Nov 5), hand-built
like legends.py: each drawn by its own function in godly_beasts.py (on legs)
or godly_skies.py (fliers, floaters, swimmers), with the shared helpers and
the standard they keep in godly_common.py. creatures.py adds them to the
ROSTER, draws them 1.6x finer in the Blender build (FINER) and sets their
element (ELEMENT)."""
import godly_beasts
import godly_skies

# (id, element), in the master sheet's order
GODLIES = [
    ('ClockworkLeviathan', 'Storm'),
    ('SolarLion', 'Ember'),
    ('AuroraStag', 'Glacial'),
    ('WorldTurtle', 'Nature'),
    ('VoidKitsune', 'plain'),
    ('CandyColossus', 'plain'),
    ('ThunderKraken', 'Storm'),
    ('CrystalHydra', 'Glacial'),
    ('EclipseDragon', 'plain'),
    ('ChronoOwl', 'plain'),
    ('CosmicWhale', 'plain'),
    ('MagmaBehemoth', 'Ember'),
    ('CrystalSwan', 'Glacial'),
    ('ButterflyEmpress', 'Nature'),
    ('HurricaneRoc', 'Storm'),
    ('PrismAlicorn', 'plain'),
    ('MechaDragon', 'Ember'),
    ('OmegaChimera', 'plain'),
]
DRAW = {**godly_beasts.BUILDERS, **godly_skies.BUILDERS}
ROSTER = [(sid, 'Godly', DRAW[sid]) for sid, _ in GODLIES if sid in DRAW]
ELEMENT = {sid: el for sid, el in GODLIES if sid in DRAW}
FINER = {sid: 1.6 for sid, _, _ in ROSTER}
