import os
import re
import shutil
import subprocess


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
