import os
import re
import shutil
import subprocess
import sys


class VermilionGate:
    ROBOT_LIBRARY_SCOPE = "SUITE"

    def __init__(self, root=None):
        here = os.path.dirname(os.path.abspath(__file__))
        self.root = os.path.abspath(root or os.path.join(here, "..", ".."))
        self.lua = shutil.which("lua") or shutil.which("lua5.4") or "lua"
        self.luac = shutil.which("luac") or shutil.which("luac5.4") or "luac"

    def _run(self, args, cwd=None, timeout=600):
        proc = subprocess.run(args, cwd=cwd or self.root, capture_output=True, text=True, timeout=timeout)
        return proc.returncode, (proc.stdout or "") + (proc.stderr or "")

    def _traces_dir(self, traces_dir=None):
        traces = traces_dir or os.path.join(self.root, "..", "traces")
        return os.path.abspath(traces)

    def random_sessions_hold_the_rules(self, seeds=40, steps=400):
        expected = [
            "export_stays_after_the_end", "fight_inside_recording", "fight_matches_ledger", "hover_rows_add_up",
            "hover_rows_have_share", "hover_rows_named", "hover_value_colour", "lines_agree_across_views",
            "new_is_empty", "no_damage_before_the_fight", "no_median_while_recording", "nothing_moves_after_the_end",
            "opening_changes_nothing", "report_stays_after_the_end", "round_trip_chip", "round_trip_export",
            "round_trip_report", "round_trip_screen", "same_session_same_screen", "saved_fight_matches",
            "saved_matches_recorded", "saved_shield_matches", "shields_match_ledger", "skills_add_up",
            "stopped_stays_still", "totals_match_ledger", "uptime_icon_matches_name",
        ]
        totals = {}
        runs = 0
        for mode in ("0", "1"):
            for seed in range(1, int(seeds) + 1):
                rc, out = self._run([self.lua, "test/simlab/monkey.lua", ".", str(seed), str(steps), mode])
                if rc != 0:
                    raise AssertionError(out[-1800:])
                runs += 1
                line = re.search(r"^RULES (.*)$", out, re.M)
                for name, count in re.findall(r"(\w+)=(\d+)", line.group(1) if line else ""):
                    totals[name] = totals.get(name, 0) + int(count)
        idle = [name for name in expected if totals.get(name, 0) == 0]
        if idle:
            raise AssertionError("rules that never ran: " + ", ".join(idle))
        return "%d random sessions, %d rule checks" % (runs, sum(totals.values()))

    def random_sessions_catch_the_known_bugs(self):
        rc, out = self._run([sys.executable, "qa/monkey_mutants.py"], timeout=900)
        if rc != 0:
            raise AssertionError(out[-1800:])
        return out.strip().splitlines()[-1]

    def every_lua_file_parses(self):
        bad = []
        for dirpath, dirnames, filenames in os.walk(self.root):
            dirnames[:] = [d for d in dirnames if d not in (".git", "output", "__pycache__")]
            for f in filenames:
                if f.endswith(".lua"):
                    code, _ = self._run([self.luac, "-p", os.path.join(dirpath, f)])
                    if code != 0:
                        bad.append(os.path.relpath(os.path.join(dirpath, f), self.root))
        if bad:
            raise AssertionError("files that do not parse: " + ", ".join(bad))
        return "all lua files parse"

    def harness_passes(self, debug="1"):
        code, out = self._run([self.lua, "test/harness/run.lua", ".", str(debug)])
        last = out.strip().splitlines()[-1] if out.strip() else ""
        m = re.search(r"== (\d+) passed, (\d+) failed", last)
        if not m or int(m.group(2)) != 0 or code != 0:
            fails = [l for l in out.splitlines() if l.startswith("FAIL") or l.startswith("      ")]
            raise AssertionError("harness failed: " + last + "\n" + "\n".join(fails))
        return "%s cases passed (DEBUG=%s)" % (m.group(1), debug)

    def fights_match_the_game_log(self, traces_dir=None):
        return self._audit_fights(traces_dir, [], "fights match the game log")

    def saved_sessions_match_the_game_log(self, traces_dir=None):
        return self._audit_fights(traces_dir, ["--self-check"], "saved sessions match the game log")

    def _audit_fights(self, traces_dir, flags, done):
        traces = self._traces_dir(traces_dir)
        if not os.path.isdir(traces):
            return "no traces directory at %s, nothing audited" % traces
        n = 0
        failures = []
        for f in sorted(os.listdir(traces)):
            if not f.endswith(".encounter.log"):
                continue
            trace = os.path.join(traces, f[:-len(".encounter.log")] + ".lua")
            if not os.path.isfile(trace):
                failures.append("%s has no trace" % f)
                continue
            code, out = self._run([sys.executable, "qa/encounter_audit.py"] + flags + [os.path.join(traces, f), trace])
            verdict = [l for l in out.splitlines() if l.startswith("AUDIT:")]
            print("%s -> %s" % (f, verdict[0] if verdict else "no verdict"))
            if code != 0:
                failures.append("%s: %s" % (f, verdict[0] if verdict else out[-1500:]))
                continue
            n += 1
        if failures:
            raise AssertionError(chr(10).join(failures))
        return "%d %s" % (n, done)

    def differences_with_the_reference_are_explained(self):
        script = os.path.abspath(os.path.join(self.root, "..", "tools", "reference_compare", "invariants.py"))
        if not os.path.isfile(script):
            return "no frozen reference fights here, nothing checked"
        code, out = self._run([sys.executable, script])
        verdict = [l for l in out.splitlines() if l.startswith("REFERENCE:")]
        print("\n".join(verdict))
        if code != 0:
            raise AssertionError(out[-3000:])
        return verdict[0] if verdict else "no verdict"

    def traces_match_their_events(self, traces_dir=None):
        traces = self._traces_dir(traces_dir)
        if not os.path.isdir(traces):
            return "no traces directory at %s, nothing audited" % traces
        n = 0
        failures = []
        for f in sorted(os.listdir(traces)):
            if not f.endswith(".lua") or f.startswith("harness_"):
                continue
            code, out = self._run([self.lua, "test/simlab/audit.lua", ".", os.path.join(traces, f)])
            verdict = [l for l in out.splitlines() if l.startswith("AUDIT:")]
            print("%s -> %s" % (f, verdict[0] if verdict else "no verdict"))
            if code != 0 or not verdict or verdict[0] != "AUDIT: ok":
                failures.append("%s: %s\n%s" % (f, verdict[0] if verdict else "no verdict", out[-1500:]))
                continue
            n += 1
        if failures:
            raise AssertionError("\n".join(failures))
        return "%d traces match their raw events" % n

    def traces_replay_clean(self, traces_dir=None):
        traces = self._traces_dir(traces_dir)
        if not os.path.isdir(traces):
            return "no traces directory at %s, nothing replayed" % traces
        n, worst = 0, 0.0
        failures = []
        for f in sorted(os.listdir(traces)):
            if not f.endswith(".lua"):
                continue
            code, out = self._run([self.lua, "test/simlab/replay.lua", ".", os.path.join(traces, f)])
            oracle = [l for l in out.splitlines() if l.startswith("oracle:")]
            numeric = [l for l in out.splitlines() if l.startswith("numeric:")]
            verdict = [l for l in out.splitlines() if l.startswith("NUMERIC:")]
            print("%s -> %s | %s" % (f, oracle[0] if oracle else "no oracle line", numeric[0] if numeric else "no numeric line"))
            if code != 0 or not verdict or not verdict[0].startswith("NUMERIC: ok"):
                failures.append("%s: %s\n%s" % (f, verdict[0] if verdict else "no verdict", out[-1500:]))
                continue
            n += 1
            for m in re.finditer(r"rel=([0-9.]+e[-+]?\d+)", (numeric[0] if numeric else "") + (oracle[0] if oracle else "")):
                worst = max(worst, float(m.group(1)))
        if failures:
            raise AssertionError("\n".join(failures))
        return "%d traces replayed at zero divergence, worst relative error %.1e" % (n, worst)
