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


def replay(trace, rows, out, sv=None):
    chan = ','.join('%s=%d' % kv for kv in channels_of(rows).items())
    lua = shutil.which('lua') or 'lua'
    env = dict(os.environ)
    if sv:
        env['VERMILION_REPLAY_SV'] = sv
    p = subprocess.run([lua, 'test/simlab/replay_session.lua', '.', trace, out, chan], cwd=ROOT,
                       capture_output=True, text=True, errors='replace', env=env)
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


def local_units(rows):
    me = {r[2] for r in rows if len(r) > 4 and r[1] == 'UNIT_ADDED' and r[3] == 'PLAYER' and r[4] == 'T'}
    return me or {'1'}


def own_units(rows):
    me = local_units(rows)
    mine = set(me)
    for r in rows:
        if len(r) > 15 and r[1] == 'UNIT_ADDED' and r[15] in me:
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


def audit(rows, dump, export, c, window=None, recording=None):
    mine = own_units(rows)
    me = local_units(rows)
    names = {int(r[2]): r[3] for r in rows if len(r) > 3 and r[1] == 'ABILITY_INFO'}
    nm = lambda i: names.get(i, '#%d' % i)
    sec = sections_of(export)
    head = dump['HEAD'][0]
    exact = len(head) > 9 and head[9] == '1'
    clipped = len(head) > 10 and head[10] == '1'
    if window:
        lo, hi = window
    else:
        off = align(rows, dump, mine)
        if off is None:
            c.add('alignment with the log', 'none', 'none', False)
            return
        trace_hits = [int(h[0]) for h in dump['HIT']]
        lo, hi = min(trace_hits) + off - 400, max(trace_hits) + off + 400

    rlo, rhi = lo, hi
    if recording:
        rlo, rhi = min(lo, recording[0]), max(hi, recording[1])

    hits = []
    shields = []
    energize = collections.Counter()
    energy = []
    kills = set()
    overkill = 0
    live_name = {}
    for r in rows:
        if len(r) > 10 and r[1] == 'UNIT_ADDED':
            live_name[r[2]] = r[10].split('^')[0].replace(';', ',')
        if len(r) > 9 and r[1] == 'COMBAT_EVENT' and rlo <= int(r[0]) <= rhi:
            tgt = r[19] if len(r) > 19 else '*'
            inside = lo <= int(r[0]) <= hi
            if inside and r[2] in DMG and r[9] in mine and tgt not in mine and tgt != '*' and int(r[5]) > 0:
                hits.append((int(r[0]), int(r[5]), r[2], r[3], nm(int(r[8])), live_name.get(tgt, tgt)))
                overkill += int(r[6] or 0)
            elif inside and r[2] == 'DAMAGE_SHIELDED' and r[9] in mine and tgt not in mine and tgt != '*' and int(r[5]) > 0:
                shields.append((int(r[0]), int(r[5]), r[2], r[3], nm(int(r[8])), live_name.get(tgt, tgt)))
            elif r[2] == 'POWER_ENERGIZE' and (tgt in me or (r[9] in me and tgt == '*')):
                energize[r[4]] += int(r[5])
                energy.append((int(r[0]), r[4], int(r[5])))
            elif r[2] in KILL and r[9] in mine:
                kills.add(tgt)
    if not hits:
        c.add('hits in the window', 0, head[3], False)
        return
    output = sorted(hits + shields, key=lambda h: h[0])
    t0, t1 = output[0][0], output[-1][0]
    fight = (t1 - t0) / 1000
    total = sum(h[1] for h in hits)
    shield_total = sum(h[1] for h in shields)
    all_output = total + shield_total
    crits = [h for h in hits if h[2] in CRIT]

    c.add('damage total', total, head[2], str(total) == head[2])
    c.add('hits', len(hits), head[3], str(len(hits)) == head[3])
    c.add('crit hits', len(crits), head[4], str(len(crits)) == head[4])
    S = sec.get('Summary')
    v = cell(S, 'Total shield')
    c.add('shield cracked', shield_total, v, v is not None and v == shield_total)
    v = cell(S, 'Overkill')
    if v is not None:
        c.add('overkill', overkill, v, v == overkill)
    v = cell(S, 'Fight time')
    c.add('fight time s', round(fight, 1), v, v is not None and close(v, fight, 0.3))
    v = cell(S, 'Average output')
    c.add('average per second', round(all_output / fight), v, v is not None and abs(v / (all_output / fight) - 1) <= 0.001 + 0.3 / fight)
    v = cell(S, 'Crit rate')
    c.add('crit rate %', round(len(crits) / len(hits) * 100, 1), v, v is not None and close(v, len(crits) / len(hits) * 100, 0.1))
    dc = sum(h[1] for h in crits) / total * 100
    v = cell(S, 'Damage from crits')
    c.add('damage from crits %', round(dc, 1), v, v is not None and close(v, dc, 0.06 if exact else 0.5))
    bytype = collections.Counter()
    for h in hits:
        bytype[h[3]] += h[1]
    top_val = bytype.most_common(1)[0][1]
    v = cell(S, 'Main damage type', 2)
    c.add('main damage type %', round(top_val / total * 100, 1), v, v is not None and close(v, top_val / total * 100, (0.06 if exact else 0.5) + shield_total / all_output * 100))

    ts = [h[0] for h in output]
    cum = [0]
    for h in output:
        cum.append(cum[-1] + h[1])
    peak = 0
    for t in ts:
        i = bisect.bisect_left(ts, t - 5000)
        j = bisect.bisect_right(ts, t)
        peak = max(peak, (cum[j] - cum[i]) / 5)
    v = cell(S, 'Peak output')
    c.add('peak rolling 5 s', round(peak), v, v is not None and 0.75 * peak <= v <= 1.01 * peak, 'highest sample, reads lower than the true top')

    truth = collections.Counter()
    for h in hits:
        truth[h[4]] += h[1]
    addon = collections.Counter()
    for a in dump['ABIL']:
        addon[a[2] or nm(int(a[0]))] += float(a[1])
    ta = sum(addon.values()) or 1
    worst, worst_n = 0, ''
    for n, val in truth.items():
        gap = abs(val / all_output - addon[n] / ta) * 100
        if shield_total:
            gap = max(0, gap - shield_total / all_output * 100)
        if gap > worst:
            worst, worst_n = gap, n
    c.add('skill shares, worst gap', '0', '%.2f' % worst, worst <= (0.01 if exact else 0.5), worst_n)
    sumrow = cell(sec.get('Skills'), 'Sum of the table')
    c.add('skills sum against total', all_output, sumrow, sumrow is not None and (abs(sumrow - all_output) <= 1 if exact else abs(sumrow / all_output - 1) <= 0.01 + 5000 / all_output))

    bytgt = collections.Counter()
    for h in output:
        bytgt[h[5]] += h[1]
    seen_targets = collections.Counter()
    for r in sec.get('Targets') or []:
        if len(r) >= 4:
            seen_targets[r[0]] += 1
            if r[0] in bytgt and seen_targets[r[0]] == 1:
                share = bytgt[r[0]] / all_output * 100
                try:
                    c.add('target ' + r[0], round(share, 1), r[3], close(float(r[3]), share, 0.06 if exact else 1.0))
                except ValueError:
                    pass
    dupes = [n for n, k in seen_targets.items() if k > 1 and n not in ('', 'Time on the top target %', 'Target switches')]
    c.add('target rows unique', 0, len(dupes), len(dupes) == 0, ','.join(dupes)[:40])

    state = []
    for r in rows:
        if len(r) > 13 and r[1] == 'COMBAT_EVENT' and r[9] in me:
            state.append((int(r[0]), r[11], r[12], r[13], r[10]))
        elif len(r) > 23 and r[1] == 'COMBAT_EVENT' and r[19] in me:
            state.append((int(r[0]), r[21], r[22], r[23], r[20]))
        elif len(r) > 10 and r[1] == 'BEGIN_CAST' and r[6] in me:
            state.append((int(r[0]), r[8], r[9], r[10], r[7]))
    state.sort(key=lambda s: s[0])

    def share_of(field, test):
        under = whole = 0
        for k in range(len(state) - 1):
            a0, a1 = max(state[k][0], t0), min(state[k + 1][0], t1)
            if a1 > a0 and not state[k][4].startswith('0/'):
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
        c.add(name, round(s, 1), v, v is not None and close(v, s, max(3.5, 150 / fight)))

    costs = [int(x[0]) for x in dump['ULTCOST']]
    if costs and costs[0] > 0:
        s = share_of(3, lambda u: int(u.split('/')[0]) >= costs[0])
        v = cell(sec.get('Ultimate'), 'Time ready')
        c.add('ultimate ready % of fight', round(s, 1), v, v is not None and close(v, s, 3))

    drops = 0
    prev = None
    for st in state:
        if rlo <= st[0] <= rhi:
            u = int(st[3].split('/')[0])
            if prev is not None and prev - u >= 50:
                drops += 1
            prev = u
    ult = dump['ULT'][0][0] if dump['ULT'] else '?'
    c.add('ultimate casts', drops, ult, str(drops) == ult)

    casts = collections.defaultdict(set)
    for r in rows:
        if len(r) > 6 and r[1] == 'BEGIN_CAST' and r[6] in me and rlo <= int(r[0]) <= (t1 + 100 if clipped else rhi):
            casts[nm(int(r[5]))].add(r[4])
    per = collections.Counter()
    drains = collections.Counter()
    spend = collections.Counter()
    for x in dump['CAST']:
        pool, cost, tick, name = x[2], int(x[3]), x[4], x[5]
        if pool in ('1', '2'):
            if tick == '0':
                per[name] += 1
            else:
                drains[name] += 1
            spend[pool] += cost
    for n, val in per.most_common():
        real = len(casts.get(n, ()))
        slack = 0.4 if drains[n] else 0.1
        c.add('casts ' + n, real, val, abs(real - val) <= max(1, slack * real), 'a cancelled channel can read as drains' if drains[n] else '')
    pools = {x[0]: (float(x[1]), float(x[2])) for x in dump['POOL']}
    for p, label in (('1', 'magicka'), ('2', 'stamina')):
        if p in pools and pools[p][1] > 0:
            ratio = spend[p] / pools[p][1]
            c.add('spend table within pool, ' + label, round(pools[p][1]), spend[p], ratio <= 1.03, 'rest is dodge, block, sprint')
    rest = collections.Counter()
    for x in dump['REST']:
        rest[x[1]] += int(x[2])
    for label, flag, pool in (('restored magicka', FLAG_MAG, '1'), ('restored stamina', FLAG_STA, '2')):
        if clipped:
            least = sum(x[2] for x in energy if x[1] == flag and t0 <= x[0] <= t1)
            most = sum(x[2] for x in energy if x[1] == flag and t0 - 100 <= x[0] <= t1 + 100)
            c.add(label, least, rest[pool], least <= rest[pool] <= most, 'first hit to last hit')
        else:
            c.add(label, energize[flag], rest[pool], energize[flag] == rest[pool])

    open_, spans = {}, collections.defaultdict(list)
    shared = set()
    for r in rows:
        if len(r) > 16 and r[1] == 'EFFECT_CHANGED' and lo <= int(r[0]) <= hi:
            if r[6] not in me or r[16] == '*' or r[16] in me:
                shared.add(nm(int(r[5])))
        if len(r) > 16 and r[1] == 'EFFECT_CHANGED' and r[6] in me and r[16] != '*' and r[16] not in me:
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
        if n in up and n not in shared:
            a = union(up[n]) / 1000
            c.add('uptime s ' + n, round(tr, 1), round(a, 1), close(a, tr, max(1.2, 0.015 * tr, 0.45 * len(val))))
    for x in dump['DEBUFF']:
        n = x[0]
        if n in spans and n not in shared:
            tr = union(spans[n]) / 1000
            a = float(x[1]) / 1000
            c.add('debuff s ' + n, round(tr, 1), round(a, 1), close(a, tr, max(1.2, 0.015 * tr, 0.45 * len(spans[n]))))
            m = merged(spans[n])
            edges = [m[0][0] - t0, t1 - m[-1][1]] + [m[i + 1][0] - m[i][1] for i in range(len(m) - 1)]
            g = max(edges) / 1000
            ag = float(x[3]) / 1000
            c.add('longest gap s ' + n, round(g, 1), round(ag, 1), close(ag, g, 2))
    for r in sec.get('Debuffs') or []:
        n = r[0]
        if n in spans and n not in shared and len(r) > 1:
            p = min(100, union(spans[n]) / 1000 / fight * 100)
            try:
                c.add('debuff % of fight ' + n, round(p, 1), r[1], close(float(r[1]), p, max(1, 45 * len(spans[n]) / fight)))
            except ValueError:
                pass
    k = dump['KILLS'][0][0] if dump['KILLS'] else '0'
    c.add('kills, at least the log', len(kills), k, int(k) >= len(kills), 'the log writes fewer than the game event')
    last_kill = {}
    repeated = 0
    for x in dump['KILL']:
        t, uid = int(x[0]), x[1]
        if uid in last_kill and t - last_kill[uid] < 1500:
            repeated += 1
        last_kill[uid] = t
    c.add('no kill counted twice', 0, repeated, repeated == 0)


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


def locate(hits, end, span, total):
    near = [h for h in hits if h[0] <= end + 15000]
    best = None
    i, acc = 0, 0
    for j, h in enumerate(near):
        acc += h[1]
        while h[0] - near[i][0] > span + 300:
            acc -= near[i][1]
            i += 1
        gap = abs(acc - total)
        if best is None or gap <= best[0]:
            best = (gap, near[i][0], h[0])
    return best


def run_saved(log_path, sv_path):
    rows_all = read_log(log_path)
    names = {}
    for r in rows_all:
        if len(r) > 3 and r[1] == 'ABILITY_INFO':
            names[r[2]] = r[3]
    lua = shutil.which('lua') or 'lua'
    failed = audited = skipped = older = 0
    with tempfile.TemporaryDirectory() as tmp:
        names_file = os.path.join(tmp, 'names.tsv')
        with open(names_file, 'w', encoding='utf-8') as f:
            for k, v in names.items():
                f.write('%s\t%s\n' % (k, v.replace('\t', ' ')))
        p = subprocess.run([lua, 'test/simlab/saved_sessions.lua', '.', sv_path, tmp, names_file], cwd=ROOT,
                           capture_output=True, text=True, errors='replace')
        if p.returncode != 0:
            print('AUDIT: FAIL could not read the sessions ' + p.stdout[-400:] + p.stderr[-400:])
            return 1
        blocks = []
        for rows in blocks_of(rows_all):
            if rows and len(rows[0]) > 2 and rows[0][1] == 'BEGIN_LOG':
                mine = own_units(rows)
                hits = [(int(r[0]), int(r[5])) for r in rows
                        if len(r) > 19 and r[1] == 'COMBAT_EVENT' and r[2] in DMG and r[9] in mine
                        and r[19] not in mine and r[19] != '*' and int(r[5]) > 0]
                blocks.append((rows, int(rows[0][2]), hits))
        for name in sorted(os.listdir(tmp)):
            if not name.endswith('.tsv') or name == 'names.tsv':
                continue
            dump, export = read_dump(os.path.join(tmp, name))
            head = dump['HEAD'][0]
            ts, dur, total, fight = int(head[0]), int(head[1]), int(head[2]), int(float(head[5]))
            zone = head[6][:22]
            first_gap = int(float(head[8])) if len(head) > 8 else -1
            if len(head) > 9 and head[9] == '1' and fight <= 0:
                skipped += 1
                print('%s  %-22s %s hit, no fight to compare' % (name[:3], zone, head[3]))
                continue
            if fight <= 0 or first_gap < 0:
                older += 1
                print('%s  %-22s recorded before the fight time, not compared' % (name[:3], zone))
                continue
            found = None
            for rows, epoch, hits in blocks:
                best = locate(hits, ts * 1000 - epoch, fight, total)
                if best and (found is None or best[0] <= found[0]):
                    found = (best[0], rows, best[1], best[2])
            if not found or found[0] > 0.02 * total or found[3] - found[2] < fight - 5000:
                skipped += 1
                print('%s  %-22s %d damage, no fight in this log comes close' % (name[:3], zone, total))
                continue
            c = Checks()
            start = found[2] - first_gap
            audit(found[1], dump, export, c, (found[2] - 100, found[3] + 100), (start - 100, start + dur + 100))
            audited += 1
            print('%s  %-22s %d checks, %d differ' % (name[:3], zone, len(c.rows), len(c.failed)))
            for row in c.rows:
                if not row[3]:
                    print('     FAIL %-44s log %-12s addon %s' % (row[0][:44], row[1], row[2]))
            if c.failed:
                failed += 1
    print('%d sessions compared, %d differ, %d not found in this log, %d older' % (audited, failed, skipped, older))
    print('AUDIT: ok' if failed == 0 and audited > 0 else 'AUDIT: FAIL')
    return 0 if failed == 0 and audited > 0 else 1


def self_check(log_path, trace_path):
    rows = blocks_of(read_log(log_path))[0]
    with tempfile.TemporaryDirectory() as tmp:
        out, sv = os.path.join(tmp, 'dump.tsv'), os.path.join(tmp, 'sv.lua')
        replay(trace_path, rows, out, sv)
        dump, _ = read_dump(out)
        off = align(rows, dump, own_units(rows))
        if off is None:
            print('AUDIT: FAIL no alignment')
            return 1
        ts = (int(rows[0][2]) + max(int(h[0]) for h in dump['HIT']) + off) // 1000 + 60
        with open(sv, encoding='utf-8', errors='surrogateescape', newline='') as f:
            text = f.read()
        with open(sv, 'w', encoding='utf-8', errors='surrogateescape', newline='') as f:
            f.write(text.replace('"@TS@"', str(ts)))
        return run_saved(log_path, sv)


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--saved' in sys.argv:
        sys.exit(run_saved(os.path.abspath(args[0]), os.path.abspath(args[1])))
    if '--self-check' in sys.argv:
        sys.exit(self_check(os.path.abspath(args[0]), os.path.abspath(args[1])))
    slice_to = next((a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--slice=')), None)
    if len(args) != 2:
        print('usage: python qa/encounter_audit.py <Encounter.log> <trace.lua> [--slice=out.log]')
        sys.exit(2)
    sys.exit(run(os.path.abspath(args[0]), os.path.abspath(args[1]), slice_to and os.path.abspath(slice_to)))
