import bisect
import collections
import csv
import sys

DMG = {'DAMAGE', 'CRITICAL_DAMAGE', 'DOT_TICK', 'DOT_TICK_CRITICAL', 'BLOCKED_DAMAGE'}
CRIT = {'CRITICAL_DAMAGE', 'DOT_TICK_CRITICAL'}


def union(spans):
    total, a, b = 0, None, None
    for x, y in sorted(spans):
        if a is not None and x <= b:
            b = max(b, y)
        else:
            if a is not None:
                total += b - a
            a, b = x, y
    return total + (b - a if a is not None else 0)


def main(log_path, dump_path, start=None, end=None):
    rows = list(csv.reader(open(log_path, encoding='utf-8', errors='replace')))
    names = {int(r[2]): r[3] for r in rows if len(r) > 3 and r[1] == 'ABILITY_INFO'}
    nm = lambda i: names.get(i, '#%d' % i)
    dump = [line.strip().split(',') for line in open(dump_path)]
    head = next(x for x in dump if x[0] == 'HEAD')
    dur = int(head[2])

    casts = [(int(x[1]), int(x[2]), int(x[3]), int(x[4]), int(x[5])) for x in dump if x[0] == 'CAST']
    begins = collections.defaultdict(list)
    for r in rows:
        if len(r) > 6 and r[1] == 'BEGIN_CAST' and r[6] == '1':
            begins[nm(int(r[5]))].append(int(r[0]))
    for k in begins:
        begins[k].sort()

    def score(off):
        s = 0
        for t, i, p, c, tick in casts:
            a = begins.get(nm(i))
            if a and not tick:
                j = bisect.bisect_left(a, t + off - 800)
                if j < len(a) and a[j] <= t + off + 100:
                    s += 1
        return s

    last_time = max(int(r[0]) for r in rows if r and r[0].isdigit())
    if start is None:
        start = max(range(0, last_time, 25), key=score)
    if end is None:
        end = start + dur
    inside = lambda t: start <= t <= end + 6000
    print('zone %s  log window %d to %d' % (head[6], start, end))

    total = hits = crits = crit_dmg = 0
    truth = collections.Counter()
    energize = collections.Counter()
    fails = collections.defaultdict(collections.Counter)
    for r in rows:
        if len(r) > 9 and r[1] == 'COMBAT_EVENT' and inside(int(r[0])):
            if r[2] in DMG and r[9] == '1':
                h = int(r[5])
                total += h
                hits += 1
                truth[nm(int(r[8]))] += h
                if r[2] in CRIT:
                    crits += 1
                    crit_dmg += h
            elif r[2] == 'POWER_ENERGIZE' and r[9] == '1':
                energize[r[4]] += int(r[5])
            elif r[2] in ('ABILITY_ON_COOLDOWN', 'INSUFFICIENT_RESOURCE', 'BUSY', 'QUEUED'):
                fails[nm(int(r[8]))][r[2]] += 1
    print('damage  log %d  addon %s' % (total, head[3]))
    print('hits    log %d  addon %s' % (hits, head[4]))
    print('crits   log %d  addon %s' % (crits, head[5]))

    addon = collections.Counter()
    for x in dump:
        if x[0] == 'ABIL':
            addon[nm(int(x[1]))] += float(x[2])
    ta, worst = sum(addon.values()) or 1, 0
    for n, v in truth.most_common():
        gap = abs(v / (total or 1) - addon[n] / ta) * 100
        worst = max(worst, gap)
    print('skill shares: worst gap %.2f points over %d skills' % (worst, len(truth)))
    for n, v in truth.most_common(12):
        print('  %-32s log %9d %5.1f%%  addon %9.0f %5.1f%%' % (n, v, v / (total or 1) * 100, addon[n], addon[n] / ta * 100))

    print('skill | pool | casts | drains | spend | game BEGIN_CAST | failed presses')
    per = {}
    for t, i, p, c, tick in casts:
        e = per.setdefault(nm(i), [p, 0, 0, 0])
        if tick:
            e[2] += 1
        else:
            e[1] += 1
        e[3] += c
    spend = collections.Counter()
    for n, e in sorted(per.items(), key=lambda kv: -kv[1][3]):
        seen = sum(1 for t in begins.get(n, []) if inside(t))
        spend[e[0]] += e[3]
        print('  %-30s %d %5d %5d %8d %5d  %s' % (n, e[0], e[1], e[2], e[3], seen, dict(fails.get(n, {}))))
    for x in dump:
        if x[0] == 'POOL':
            p = int(x[1])
            print('pool %d: table spend %d, pool spent %s, gained %s' % (p, spend[p], x[3], x[2]))
    rest = collections.Counter()
    for x in dump:
        if x[0] == 'REST':
            rest[x[3]] += int(x[4])
    print('energize log by power type', dict(energize), ' addon by pool', dict(rest))

    open_, spans = {}, collections.defaultdict(list)
    for r in rows:
        if len(r) > 16 and r[1] == 'EFFECT_CHANGED' and r[6] == '1' and r[16] not in ('*', '1') and inside(int(r[0])):
            k = (nm(int(r[5])), r[5], r[16])
            if r[2] == 'GAINED' and k not in open_:
                open_[k] = int(r[0])
            elif r[2] == 'FADED' and k in open_:
                spans[k[0]].append((open_.pop(k), int(r[0])))
    up = collections.defaultdict(list)
    deb = {}
    for x in dump:
        if x[0] == 'SPAN':
            up[nm(int(x[1]))].append((int(x[2]), int(x[3])))
        elif x[0] == 'DEBUFF':
            deb[nm(int(x[1]))] = float(x[2])
    print('effect | log s | uptime s | debuff s')
    for n in sorted(spans, key=lambda k: -union(spans[k])):
        if n in up or n in deb:
            print('  %-30s %7.1f %8s %8s' % (n, union(spans[n]) / 1000,
                  '%.1f' % (union(up[n]) / 1000) if n in up else '-',
                  '%.1f' % (deb[n] / 1000) if n in deb else '-'))
    ult = next((x[1] for x in dump if x[0] == 'ULT'), '?')
    print('ultimate casts addon', ult)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('usage: python qa/encounter_audit.py <Encounter.log> <session_dump.csv> [log_start_ms] [log_end_ms]')
        sys.exit(2)
    a = [int(v) for v in sys.argv[3:5]]
    main(sys.argv[1], sys.argv[2], *a)
