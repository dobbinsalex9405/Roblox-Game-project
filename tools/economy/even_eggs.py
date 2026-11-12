"""Even egg odds: rewrites the tier weights of Hatchery Heist's coin eggs so
every creature in a tier has the same whole weight, and so the same "1 in N"
and percentage on its odds card, while each tier stays as close as whole
numbers allow to its target chance below.

    python3 tools/economy/even_eggs.py           rewrite config/eggs.luau
    python3 tools/economy/even_eggs.py --check   exit 1 if it is out of date

Run it after every change to who is in an egg's pool (tools/art/to_config.py
or a hand edit in config/creatures.luau). Eggs.spec fails while any tier is
split unevenly.

Why the totals stay powers of ten: the odds screen prints percentages in
steps of 1 / total, and paid random items must show odds that add up to
exactly 100%. So the total is fixed and the tiers absorb the rounding: each
tier's weight is (members x a whole number), and the few weight points left
over move to the tiers where they shift the odds least (Common and Uncommon
first). The Premium Egg is checked, not rewritten.

Targets are the odds tuned Nov 5-7 (ops/ECONOMY.md); change them here.
"""
import itertools
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, 'games', 'hatchery-heist', 'config')
CREATURES = os.path.join(GAME, 'creatures.luau')
EGGS = os.path.join(GAME, 'eggs.luau')

# Egg -> (pool, total, {tier: chance}). A chance given as ('each', p) is per
# creature: the tier's chance grows with its members (every Godly is exactly
# 1 in 1,000,000 however many there are).
TARGETS = {
    'BasicEgg': ('Barnyard', 1_000_000, {
        'Common': 0.92, 'Uncommon': 0.07, 'Rare': 0.008, 'Ultra Rare': 0.0018,
        'Epic': 0.00018, 'Legendary': 0.00002}),
    'MeadowEgg': ('Meadow', 1_000_000, {
        'Common': 0.67, 'Uncommon': 0.31, 'Rare': 0.017, 'Ultra Rare': 0.0028,
        'Epic': 0.00017, 'Legendary': 0.00003}),
    'MoonlitEgg': ('Moonlit', 10_000_000, {
        'Uncommon': 0.58, 'Rare': 0.38, 'Ultra Rare': 0.037, 'Epic': 0.0029,
        'Legendary': 0.00008, 'Godly': ('each', 0.000001)}),
    # Alex, Nov 12: far better odds, nothing below Epic (economy thread).
    # Pool 'All' is every creature in any egg pool (src/shared/Eggs.ALL).
    'GiantEgg': ('All', 1_000_000, {'Epic': 0.795, 'Legendary': 0.20, 'Godly': 0.005}),
}
CHECK_ONLY = {'PremiumEgg': 'Premium'}
TIERS = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Epic', 'Legendary', 'Godly']


def members():
    """{(pool, tier): count} from config/creatures.luau."""
    with open(CREATURES) as f:
        src = f.read()
    if re.search(r'^\s*weight\s*=', src, re.M):
        raise SystemExit('a creature has an in-tier weight: even_eggs.py assumes every weight is 1')
    out = {}
    for m in re.finditer(r'\b(\w+) = \{\s*rarity = "([^"]+)",(.*?)pools = \{([^}]*)\}', src, re.S):
        pools = re.findall(r'"(\w+)"', m.group(4))
        for pool in pools:
            out[(pool, m.group(2))] = out.get((pool, m.group(2)), 0) + 1
        if pools:
            out[('All', m.group(2))] = out.get(('All', m.group(2)), 0) + 1
    return out


def solve(total, chances, counts):
    """{tier: weight}: each weight a whole multiple of its count, summing to
    total, each tier as close to its chance as that allows."""
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
    deficit = total - sum(each[t] * counts[t] for t in tiers)
    # Move the leftover points: search small whole steps on the flexible
    # tiers, cheapest (largest weight, so smallest relative shift) first.
    flex = sorted((t for t in tiers if t not in fixed), key=lambda t: -each[t] * counts[t])
    best = None
    for size in range(0, len(flex) + 1):
        for chosen in itertools.combinations(flex[:4], size):
            if size == 0:
                if deficit == 0:
                    best = (0, {})
                continue
            *free, last = chosen
            span = range(-60, 61)
            for steps in itertools.product(span, repeat=len(free)):
                rest = deficit - sum(s * counts[t] for s, t in zip(steps, free))
                if rest % counts[last]:
                    continue
                k = dict(zip(free, steps))
                k[last] = rest // counts[last]
                if any(each[t] + k[t] < 1 for t in k):
                    continue
                cost = max(abs(k[t]) / each[t] for t in k)
                if best is None or cost < best[0]:
                    best = (cost, k)
        if best is not None:
            break
    if best is None:
        raise SystemExit(f'no even split found for counts {counts}')
    return {t: (each[t] + best[1].get(t, 0)) * counts[t] for t in tiers}


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


def premium_even(src, counts):
    start = src.index('id = "PremiumEgg"')
    block = src[src.index('tiers = {', start):src.index('\n\t\t},', start)]
    bad = []
    for a, b, v in re.findall(r'(?:\["([^"]+)"\]|(\w+)) = (\d+)', block):
        key, value = a or b, int(v)
        n = counts.get(('Premium', key), 0)
        if n and value % n:
            bad.append(f'PremiumEgg {key} {value} for {n} creatures')
    return bad


def main():
    counts = members()
    with open(EGGS) as f:
        src = f.read()
    out = src
    for egg, (pool, total, chances) in TARGETS.items():
        c = {t: counts.get((pool, t), 0) for t in chances}
        weights = solve(total, chances, c)
        out = render(out, egg, total, weights, c)
    bad = premium_even(out, counts)
    if bad:
        raise SystemExit('uneven, set by hand: ' + '; '.join(bad))
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
