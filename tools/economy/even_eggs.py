"""Even egg odds: rewrites the tier weights of Hatchery Heist's eggs so every
creature in a tier has the same whole weight, and so the same "1 in N" and
percentage on its odds card, while each tier stays as close as whole numbers
and the rules below allow to its target chance.

    python3 tools/economy/even_eggs.py           rewrite config/eggs.luau
    python3 tools/economy/even_eggs.py --check   exit 1 if it is out of date

Run it after every change to the roster (tools/art/to_config.py or a hand
edit in config/creatures.luau). Eggs.spec fails while any tier is split
unevenly.

Every egg hatches from one pool, "All" (Alex, Nov 12: every egg can pull
every creature), so the eggs differ only by their tier odds. The coin eggs
roll all seven tiers; the Premium Egg starts at Rare.

Why the totals stay powers of ten: the odds screen prints percentages in
steps of 1 / total, and paid random items must show odds that add up to
exactly 100%. So the total is fixed and the tiers absorb the rounding: each
tier's weight is (members x a whole number), and the few weight points left
over move to the tiers where they shift the odds least (Common and Uncommon
first). 10,000,000 is the most a total can be (Schemas; Hatchery's fixed
order multiplies two weights and must stay exact).

Rarer is rarer: from Rare up, each creature of a tier is less likely than
each creature of the tier below, and each tier as a whole is less likely
than the tier below (Common and Uncommon are free, so a dearer
egg can favour Uncommon). A thin tier (two
Legendaries) would otherwise make each of its creatures likelier than each
Epic; its chance is cut to EVEN_STEP times below the tier under it until
more creatures join, and the cut points go to the common tiers. And up the
coin-egg ladder (Basic, Meadow, Moonlit), every creature from Rare up is at
least as likely in the dearer egg.

Targets are the pacing odds from tools/economy (ops/ECONOMY.md); change
them here and tell the odds-screen owners.
"""
import itertools
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, 'games', 'hatchery-heist', 'config')
CREATURES = os.path.join(GAME, 'creatures.luau')
EGGS = os.path.join(GAME, 'eggs.luau')

POOL = 'All'
# Egg -> (total, {tier: chance}). A chance given as ('each', p) is per
# creature: the tier's chance grows with its members (each Godly is exactly
# 1 in 1,000,000 from the Moonlit Egg however many there are).
TARGETS = {
    'BasicEgg': (10_000_000, {
        'Common': 0.92, 'Uncommon': 0.072, 'Rare': 0.007, 'Ultra Rare': 0.0009,
        'Epic': 0.00008, 'Legendary': 0.00002, 'Godly': ('each', 0.0000001)}),
    # The step up from Basic: Rare 1 in 22, so it is worth buying.
    'MeadowEgg': (10_000_000, {
        'Common': 0.58, 'Uncommon': 0.37, 'Rare': 0.045, 'Ultra Rare': 0.0045,
        'Epic': 0.00045, 'Legendary': 0.00005, 'Godly': ('each', 0.0000001)}),
    # Mostly Uncommon and Rare; a regular player's first Epic lands on day 2,
    # and each Godly is 1 in 1,000,000 (Alex, Nov 7).
    'MoonlitEgg': (10_000_000, {
        'Common': 0.02, 'Uncommon': 0.646, 'Rare': 0.30, 'Ultra Rare': 0.032,
        'Epic': 0.0019, 'Legendary': 0.0001, 'Godly': ('each', 0.0000005)}),
    # Robux: Rare and up only.
    'PremiumEgg': (1_000_000, {
        'Rare': 0.65, 'Ultra Rare': 0.28, 'Epic': 0.065, 'Legendary': 0.0049, 'Godly': 0.0001}),
}
LADDER = ['BasicEgg', 'MeadowEgg', 'MoonlitEgg']
# A tier cut by "rarer is rarer" lands this many times below the tier under it.
EVEN_STEP = 1.5
TIERS = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']


def members():
    """{(pool, tier): count} from config/creatures.luau."""
    with open(CREATURES) as f:
        src = f.read()
    if re.search(r'^\s*weight\s*=', src, re.M):
        raise SystemExit('a creature has an in-tier weight: even_eggs.py assumes every weight is 1')
    out = {}
    for m in re.finditer(r'\b(\w+) = \{\s*rarity = "([^"]+)",(.*?)pools = \{([^}]*)\}', src, re.S):
        for pool in re.findall(r'"(\w+)"', m.group(4)):
            out[(pool, m.group(2))] = out.get((pool, m.group(2)), 0) + 1
    return out


def first_ranked(tiers):
    """Index of the egg's first tier at Rare or above: from there up, rarer
    creatures are each rarer. Common and Uncommon are free, so a dearer egg
    can favour Uncommon over Common."""
    return next(i for i, t in enumerate(tiers) if TIERS.index(t) >= TIERS.index('Rare'))


def rarer_is_rarer(tiers, each, counts=None):
    """True when, from Rare up, every tier's creatures are each less likely
    than the tier below's, and (given counts) every tier as a whole is less
    likely than the tier below, so the odds card never reads upside down."""
    start = first_ranked(tiers)
    pairs = [(tiers[i - 1], tiers[i]) for i in range(start + 1, len(tiers))]
    if not all(each[t] < each[b] for b, t in pairs):
        return False
    return counts is None or all(each[t] * counts[t] < each[b] * counts[b] for b, t in pairs)


def solve(total, chances, counts):
    """{tier: weight}: each weight a whole multiple of its count, summing to
    total, rarer creatures each rarer from Rare up, and each tier
    as close to its chance as that allows."""
    tiers = [t for t in TIERS if t in chances]
    for t in tiers:
        if counts.get(t, 0) == 0:
            raise SystemExit(f'no creature in tier {t}: drop it from TARGETS or add one')
    each = {}
    for t in tiers:
        c = chances[t]
        p = c[1] * counts[t] if isinstance(c, tuple) else c
        each[t] = max(1, round(p * total / counts[t]))
    fixed = {t for t in tiers if isinstance(chances[t], tuple)}
    # Rarer is rarer: cut a tier whose creatures would each be at least as
    # likely as the tier below's (a thin tier, such as two Legendaries).
    cut = set()
    for i in range(first_ranked(tiers) + 1, len(tiers)):
        t, below = tiers[i], tiers[i - 1]
        if each[t] < each[below]:
            continue
        if t in fixed:
            raise SystemExit(f'{t} is set per creature at {each[t]}, not below {below} ({each[below]}): '
                             'lower its target or raise the tier below')
        each[t] = int(each[below] / EVEN_STEP)
        if each[t] < 1:
            raise SystemExit(f'{t} cannot sit below {below} ({each[below]} each) with total {total}')
        cut.add(t)
    # And as a whole: a cut tier must still outweigh the tier above it (two
    # Legendaries cut to 8 each would read rarer than 20 Godlies at 1 each).
    start = first_ranked(tiers)
    for i in range(len(tiers) - 2, start - 1, -1):
        t, rarer = tiers[i], tiers[i + 1]
        if each[t] * counts[t] > each[rarer] * counts[rarer]:
            continue
        need = each[rarer] * counts[rarer] // counts[t] + 1
        if t in fixed or (i > start and need >= each[tiers[i - 1]]):
            raise SystemExit(f'{t} ({counts[t]} creatures) cannot outweigh {rarer} as a tier and stay '
                             f'rarer per creature than {tiers[i - 1]}: change the targets')
        each[t] = need
        cut.add(t)
    deficit = total - sum(each[t] * counts[t] for t in tiers)
    # Move the leftover points: try small whole steps on up to three tiers
    # and keep the split that keeps rarer creatures rarer and shifts the
    # rarest tiers least (relative to their own size), so Rare-and-up barely
    # move and Common and Uncommon take most of it.
    # A cut tier may only move down (its whole weight must stay even, so it
    # sometimes gives a point or two).
    flex = [t for t in tiers if t not in fixed]
    best = ((0,) * len(tiers), {}) if deficit == 0 else None
    for size in range(1, min(3, len(flex)) + 1):
        for chosen in itertools.combinations(flex, size):
            for last in chosen:
                free = [t for t in chosen if t != last]
                for steps in itertools.product(range(-60, 61), repeat=len(free)):
                    rest = deficit - sum(s * counts[t] for s, t in zip(steps, free))
                    if rest % counts[last]:
                        continue
                    k = dict(zip(free, steps))
                    k[last] = rest // counts[last]
                    if any(each[t] + k[t] < 1 or (t in cut and k[t] > 0) for t in k):
                        continue
                    # Rarest tier first: keep it on target, then the next.
                    cost = tuple(abs(k.get(t, 0)) / each[t] for t in reversed(tiers))
                    if best is not None and cost >= best[0]:
                        continue
                    if not rarer_is_rarer(tiers, {t: each[t] + k.get(t, 0) for t in tiers}, counts):
                        continue
                    best = (cost, k)
    if best is None:
        raise SystemExit(f'no even split found for counts {counts}')
    return {t: (each[t] + best[1].get(t, 0)) * counts[t] for t in tiers}


def ladder_problems(solved):
    """Rare-and-up creatures that are each likelier from a cheaper coin egg."""
    bad = []
    for lo, hi in zip(LADDER, LADDER[1:]):
        (lo_total, lo_w, lo_n), (hi_total, hi_w, hi_n) = solved[lo], solved[hi]
        for t in TIERS[TIERS.index('Rare'):]:
            if t in lo_w and t in hi_w and lo_w[t] / lo_n[t] / lo_total > hi_w[t] / hi_n[t] / hi_total:
                bad.append(f'each {t} is likelier from {lo} than from {hi}')
    return bad


def one_in(weight, total):
    n = total / weight
    return f'{n:.1f}' if n < 100 else f'{round(n):,}'


def comment(tier, weight, total, count):
    pct = weight * 100 / total
    lead = f'{pct:g}%' if pct >= 1 else f'1 in {one_in(weight, total)}'
    return f'{lead} ({count} x {weight // count:,})'


def render(src, egg, total, weights, counts):
    start = src.index(f'id = "{egg}"')
    block_start = src.index('tiers = {', start)
    block_end = src.index('\n\t\t},', block_start)
    lines = []
    for t in TIERS:
        if t not in weights:
            continue
        key = f'["{t}"]' if ' ' in t else t
        lines.append(f'\t\t\t{key} = {weights[t]}, -- {comment(t, weights[t], total, counts[t])}')
    new_block = 'tiers = {\n' + '\n'.join(lines)
    out = src[:block_start] + new_block + src[block_end:]
    out = re.sub(r'(id = "' + egg + r'".*?total = )[^,\n]+,', lambda m: m.group(1) + f'{total},', out, count=1,
                 flags=re.S)
    return out


def main():
    counts = members()
    with open(EGGS) as f:
        src = f.read()
    out = src
    solved = {}
    for egg, (total, chances) in TARGETS.items():
        c = {t: counts.get((POOL, t), 0) for t in chances}
        weights = solve(total, chances, c)
        solved[egg] = (total, weights, c)
        out = render(out, egg, total, weights, c)
    bad = ladder_problems(solved)
    if bad:
        raise SystemExit('the coin-egg ladder is upside down: ' + '; '.join(bad))
    if '--check' in sys.argv:
        if out != src:
            print('config/eggs.luau tier weights are out of date: run python3 tools/economy/even_eggs.py')
            sys.exit(1)
        print('config/eggs.luau tier weights are even')
        return
    if out != src:
        with open(EGGS, 'w') as f:
            f.write(out)
        print('rewrote config/eggs.luau tier weights')
    else:
        print('config/eggs.luau tier weights already even')


if __name__ == '__main__':
    main()
