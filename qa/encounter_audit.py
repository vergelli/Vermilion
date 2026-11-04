import bisect
import collections
import csv
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
DMG = {'DAMAGE', 'CRITICAL_DAMAGE', 'DOT_TICK', 'DOT_TICK_CRITICAL', 'BLOCKED_DAMAGE'}
CRIT = {'CRITICAL_DAMAGE', 'DOT_TICK_CRITICAL'}
KILL = {'DIED', 'DIED_XP', 'KILLING_BLOW'}
FLAG_MAG, FLAG_STA = '1', '4'
LOW = 0.15


def read_log(path):
    return list(csv.reader(open(path, encoding='utf-8', errors='replace')))


def blocks_of(rows):
    starts = [i for i, r in enumerate(rows) if len(r) > 1 and r[1] == 'BEGIN_LOG']
    if not starts:
        return [rows]
    return [rows[s:(starts[k + 1] if k + 1 < len(starts) else len(rows))] for k, s in enumerate(starts)]


def channels_of(rows):
    out = {}
    for r in rows:
        if len(r) > 6 and r[1] == 'BEGIN_CAST' and r[3] == 'T' and int(r[2]) > 0:
            out[r[5]] = int(r[2])
    return out


def replay(trace, rows, out):
    chan = ','.join('%s=%d' % kv for kv in channels_of(rows).items())
    lua = shutil.which('lua') or 'lua'
    p = subprocess.run([lua, 'test/simlab/replay_session.lua', '.', trace, out, chan], cwd=ROOT,
                       capture_output=True, text=True, errors='replace')
    if p.returncode != 0:
        raise RuntimeError('replay failed: ' + p.stdout[-800:] + p.stderr[-800:])


def read_dump(path):
    d = collections.defaultdict(list)
    export = []
    in_export = False
    for raw in open(path, encoding='utf-8', errors='replace'):
        line = raw.rstrip('\r\n')
        if in_export:
            export.append(line)
        elif line == 'EXPORT':
            in_export = True
        else:
            f = line.split('\t')
            d[f[0]].append(f[1:])
    return d, export


def sections_of(export):
    out = {}
    cur = None
    for line in export:
        if line.startswith('## '):
            cur = line[3:]
            out[cur] = []
        elif cur and line:
            out[cur].append(line.split(';'))
    return out


def own_units(rows):
    mine = {'1'}
    for r in rows:
        if len(r) > 15 and r[1] == 'UNIT_ADDED' and r[15] == '1':
            mine.add(r[2])
    return mine


def unit_names(rows):
    return {r[2]: r[10] for r in rows if len(r) > 10 and r[1] == 'UNIT_ADDED'}


def align(rows, dump, mine):
    want = collections.defaultdict(list)
    for h in dump['HIT']:
        want[(h[1], h[2])].append(int(h[0]))
    votes = collections.Counter()
    for r in rows:
        if len(r) > 9 and r[1] == 'COMBAT_EVENT' and r[9] in mine and r[2] in DMG:
            for t in want.get((r[8], r[5]), [])[:40]:
                votes[(int(r[0]) - t) // 50] += 1
    if not votes:
        return None
    return votes.most_common(1)[0][0] * 50 + 25


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


def merged(spans):
    out = []
    for x, y in sorted(spans):
        if out and x <= out[-1][1]:
            out[-1][1] = max(out[-1][1], y)
        else:
            out.append([x, y])
    return out


class Checks:
    def __init__(self):
        self.rows = []
        self.failed = []

    def add(self, name, log_v, addon_v, ok, note=''):
        self.rows.append((name, log_v, addon_v, ok, note))
        if not ok:
            self.failed.append(name)

    def show(self):
        for name, l, a, ok, note in self.rows:
            print('%-4s %-46s log %-14s addon %-14s %s' % ('ok' if ok else 'FAIL', name[:46], l, a, note))


def close(a, b, tol):
    return abs(a - b) <= tol


def cell(rows, label, col=1):
    for r in rows or []:
        if r and r[0].startswith(label):
            try:
                return float(r[col])
            except (ValueError, IndexError):
                return None
    return None


def audit(rows, dump, export, c):
    mine = own_units(rows)
    names = {int(r[2]): r[3] for r in rows if len(r) > 3 and r[1] == 'ABILITY_INFO'}
    nm = lambda i: names.get(i, '#%d' % i)
    units = unit_names(rows)
    sec = sections_of(export)
    head = dump['HEAD'][0]
    off = align(rows, dump, mine)
    if off is None:
        c.add('alignment with the log', 'none', 'none', False)
        return
    trace_hits = [int(h[0]) for h in dump['HIT']]
    lo, hi = min(trace_hits) + off - 400, max(trace_hits) + off + 400

    hits = []
    energize = collections.Counter()
    kills = set()
    for r in rows:
        if len(r) > 9 and r[1] == 'COMBAT_EVENT' and lo <= int(r[0]) <= hi:
            tgt = r[19] if len(r) > 19 else '*'
            if r[2] in DMG and r[9] in mine and tgt not in mine and tgt != '*' and int(r[5]) > 0:
                hits.append((int(r[0]), int(r[5]), r[2], r[3], nm(int(r[8])), tgt))
            elif r[2] == 'POWER_ENERGIZE' and (tgt == '1' or (r[9] == '1' and tgt == '*')):
                energize[r[4]] += int(r[5])
            elif r[2] in KILL and r[9] in mine:
                kills.add(tgt)
    if not hits:
        c.add('hits in the window', 0, head[3], False)
        return
    t0, t1 = hits[0][0], hits[-1][0]
    fight = (t1 - t0) / 1000
    total = sum(h[1] for h in hits)
    crits = [h for h in hits if h[2] in CRIT]

    c.add('damage total', total, head[2], str(total) == head[2])
    c.add('hits', len(hits), head[3], str(len(hits)) == head[3])
    c.add('crit hits', len(crits), head[4], str(len(crits)) == head[4])
    S = sec.get('Summary')
    v = cell(S, 'Fight time')
    c.add('fight time s', round(fight, 1), v, v is not None and close(v, fight, 0.3))
    v = cell(S, 'Average output')
    c.add('average per second', round(total / fight), v, v is not None and abs(v / (total / fight) - 1) <= 0.001 + 0.3 / fight)
    v = cell(S, 'Crit rate')
    c.add('crit rate %', round(len(crits) / len(hits) * 100, 1), v, v is not None and close(v, len(crits) / len(hits) * 100, 0.1))
    dc = sum(h[1] for h in crits) / total * 100
    v = cell(S, 'Damage from crits')
    c.add('damage from crits %', round(dc, 1), v, v is not None and close(v, dc, 0.5))
    bytype = collections.Counter()
    for h in hits:
        bytype[h[3]] += h[1]
    top_val = bytype.most_common(1)[0][1]
    v = cell(S, 'Main damage type', 2)
    c.add('main damage type %', round(top_val / total * 100, 1), v, v is not None and close(v, top_val / total * 100, 0.5))

    ts = [h[0] for h in hits]
    cum = [0]
    for h in hits:
        cum.append(cum[-1] + h[1])
    peak = 0
    for t in ts:
        i = bisect.bisect_left(ts, t - 5000)
        j = bisect.bisect_right(ts, t)
        peak = max(peak, (cum[j] - cum[i]) / 5)
    v = cell(S, 'Peak output')
    c.add('peak rolling 5 s', round(peak), v, v is not None and 0.93 * peak <= v <= 1.01 * peak, 'sampled, can read lower')

    truth = collections.Counter()
    for h in hits:
        truth[h[4]] += h[1]
    addon = collections.Counter()
    for a in dump['ABIL']:
        addon[a[2] or nm(int(a[0]))] += float(a[1])
    ta = sum(addon.values()) or 1
    worst, worst_n = 0, ''
    for n, val in truth.items():
        gap = abs(val / total - addon[n] / ta) * 100
        if gap > worst:
            worst, worst_n = gap, n
    c.add('skill shares, worst gap', '0', '%.2f' % worst, worst <= 0.5, worst_n)
    sumrow = cell(sec.get('Skills'), 'Sum of the table')
    c.add('skills sum against total', total, sumrow, sumrow is not None and abs(sumrow / total - 1) <= 0.01)

    bytgt = collections.Counter()
    for h in hits:
        bytgt[units.get(h[5], h[5]).split('^')[0].replace(';', ',')] += h[1]
    for r in sec.get('Targets') or []:
        if len(r) >= 4 and r[0] in bytgt:
            share = bytgt[r[0]] / total * 100
            try:
                c.add('target ' + r[0], round(share, 1), r[3], close(float(r[3]), share, 0.5))
            except ValueError:
                pass

    state = []
    for r in rows:
        if len(r) > 13 and r[1] == 'COMBAT_EVENT' and r[9] == '1':
            state.append((int(r[0]), r[11], r[12], r[13]))
        elif len(r) > 23 and r[1] == 'COMBAT_EVENT' and r[19] == '1':
            state.append((int(r[0]), r[21], r[22], r[23]))
        elif len(r) > 10 and r[1] == 'BEGIN_CAST' and r[6] == '1':
            state.append((int(r[0]), r[8], r[9], r[10]))
    state.sort(key=lambda s: s[0])

    def share_of(field, test):
        under = whole = 0
        for k in range(len(state) - 1):
            a0, a1 = max(state[k][0], t0), min(state[k + 1][0], t1)
            if a1 > a0:
                whole += a1 - a0
                if test(state[k][field]):
                    under += a1 - a0
        return under / whole * 100 if whole else 0

    def low(s):
        v0, m = s.split('/')
        return int(m) > 0 and int(v0) / int(m) < LOW

    R = sec.get('Resources')
    for label, field, name in (('Magicka', 1, 'magicka under 15% of fight'), ('Stamina', 2, 'stamina under 15% of fight')):
        v = cell(R, label, 4)
        s = share_of(field, low)
        c.add(name, round(s, 1), v, v is not None and close(v, s, 3))

    costs = [int(x[0]) for x in dump['ULTCOST']]
    if costs and costs[0] > 0:
        s = share_of(3, lambda u: int(u.split('/')[0]) >= costs[0])
        v = cell(sec.get('Ultimate'), 'Time ready')
        c.add('ultimate ready % of fight', round(s, 1), v, v is not None and close(v, s, 3))

    drops = 0
    prev = None
    for st in state:
        if lo <= st[0] <= hi:
            u = int(st[3].split('/')[0])
            if prev is not None and prev - u >= 50:
                drops += 1
            prev = u
    ult = dump['ULT'][0][0] if dump['ULT'] else '?'
    c.add('ultimate casts', drops, ult, str(drops) == ult)

    casts = collections.defaultdict(set)
    for r in rows:
        if len(r) > 6 and r[1] == 'BEGIN_CAST' and r[6] == '1' and lo <= int(r[0]) <= hi:
            casts[nm(int(r[5]))].add(r[4])
    per = collections.Counter()
    spend = collections.Counter()
    for x in dump['CAST']:
        pool, cost, tick, name = x[2], int(x[3]), x[4], x[5]
        if pool in ('1', '2'):
            if tick == '0':
                per[name] += 1
            spend[pool] += cost
    for n, val in per.most_common():
        real = len(casts.get(n, ()))
        c.add('casts ' + n, real, val, abs(real - val) <= max(1, 0.1 * real))
    pools = {x[0]: (float(x[1]), float(x[2])) for x in dump['POOL']}
    for p, label in (('1', 'magicka'), ('2', 'stamina')):
        if p in pools and pools[p][1] > 0:
            ratio = spend[p] / pools[p][1]
            c.add('spend table against pool, ' + label, round(pools[p][1]), spend[p], abs(ratio - 1) <= 0.03)
    rest = collections.Counter()
    for x in dump['REST']:
        rest[x[1]] += int(x[2])
    c.add('restored magicka', energize[FLAG_MAG], rest['1'], energize[FLAG_MAG] == rest['1'])
    c.add('restored stamina', energize[FLAG_STA], rest['2'], energize[FLAG_STA] == rest['2'])

    open_, spans = {}, collections.defaultdict(list)
    for r in rows:
        if len(r) > 16 and r[1] == 'EFFECT_CHANGED' and r[6] == '1' and r[16] not in ('*', '1'):
            t = int(r[0])
            k = (nm(int(r[5])), r[5], r[16])
            if r[2] == 'GAINED' and k not in open_:
                open_[k] = t
            elif r[2] == 'FADED' and k in open_:
                a0 = open_.pop(k)
                if a0 <= hi and t >= lo:
                    spans[k[0]].append((a0, t))
    up = collections.defaultdict(list)
    for x in dump['SPAN']:
        up[x[0]].append((int(x[1]), int(x[2])))
    for n, val in sorted(spans.items()):
        tr = union(val) / 1000
        if n in up:
            a = union(up[n]) / 1000
            c.add('uptime s ' + n, round(tr, 1), round(a, 1), close(a, tr, max(1, 0.015 * tr)))
    for x in dump['DEBUFF']:
        n = x[0]
        if n in spans:
            tr = union(spans[n]) / 1000
            a = float(x[1]) / 1000
            c.add('debuff s ' + n, round(tr, 1), round(a, 1), close(a, tr, max(1, 0.015 * tr)))
            m = merged(spans[n])
            edges = [m[0][0] - t0, t1 - m[-1][1]] + [m[i + 1][0] - m[i][1] for i in range(len(m) - 1)]
            g = max(edges) / 1000
            ag = float(x[3]) / 1000
            c.add('longest gap s ' + n, round(g, 1), round(ag, 1), close(ag, g, 1.5))
    for r in sec.get('Debuffs') or []:
        n = r[0]
        if n in spans and len(r) > 1:
            p = min(100, union(spans[n]) / 1000 / fight * 100)
            try:
                c.add('debuff % of fight ' + n, round(p, 1), r[1], close(float(r[1]), p, 1))
            except ValueError:
                pass
    k = dump['KILLS'][0][0] if dump['KILLS'] else '0'
    c.add('kills', len(kills), k, str(len(kills)) == k)


def run(log_path, trace_path, slice_to=None, quiet=False):
    rows_all = read_log(log_path)
    best = None
    for rows in blocks_of(rows_all):
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, 'dump.tsv')
            replay(trace_path, rows, out)
            dump, export = read_dump(out)
            mine = own_units(rows)
            off = align(rows, dump, mine)
            if off is None:
                continue
            c = Checks()
            audit(rows, dump, export, c)
            if best is None or len(c.failed) < len(best[0].failed):
                best = (c, rows, off, dump)
    if best is None:
        print('AUDIT: FAIL no block of the log matches this trace')
        return 1
    c, rows, off, dump = best
    if not quiet:
        c.show()
    if slice_to:
        ts = [int(h[0]) for h in dump['HIT']]
        lo, hi = min(ts) + off - 60000, max(ts) + off + 15000
        with open(slice_to, 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f, lineterminator='\n')
            for r in rows:
                if len(r) < 2:
                    continue
                if r[1] in ('COMBAT_EVENT', 'EFFECT_CHANGED', 'BEGIN_CAST', 'END_CAST', 'HEALTH_REGEN', 'BEGIN_COMBAT', 'END_COMBAT'):
                    if not (lo <= int(r[0]) <= hi):
                        continue
                w.writerow(r)
    if c.failed:
        print('AUDIT: FAIL ' + '; '.join(c.failed))
        return 1
    print('AUDIT: ok, %d checks' % len(c.rows))
    return 0


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    slice_to = next((a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--slice=')), None)
    if len(args) != 2:
        print('usage: python qa/encounter_audit.py <Encounter.log> <trace.lua> [--slice=out.log]')
        sys.exit(2)
    sys.exit(run(os.path.abspath(args[0]), os.path.abspath(args[1]), slice_to and os.path.abspath(slice_to)))
