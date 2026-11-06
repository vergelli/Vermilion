import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SEEDS = 80
STEPS = 400

MUTANTS = [
    ("#172 UPTIME rows keep the icon of another skill", [
        ("ui/uptime.lua", "    if r.name ~= names[k] then r.id, r.icon, r.col = 0, nil, C_OTHER end\n", ""),
    ]),
    ("#181 damage keeps counting after Stop", [
        ("ui/graph.lua", "  Vermilion.Metrics.close_session()\n", ""),
    ]),
    ("#182 hover values inherit the colours of the last card", [
        ("ui/widgets/hover_card.lua", "    r.val:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)\n", ""),
        ("ui/graph.lua", "        local vc = ((ab.id or 0) > 0) and C_LINE_EDPS or C_SHDPS\n        row.val:SetColor(vc.r, vc.g, vc.b, 1.0)\n", ""),
    ]),
    ("#184 New leaves the lines on screen", [
        ("ui/graph.lua", "  hide_grid(controls.grid)\n  VIS.hide_lines()\n  refresh_button_colors()\n", "  hide_grid(controls.grid)\n  refresh_button_colors()\n"),
    ]),
    ("#186 TYPE lines leave shields out", [
        ("ui/graph.lua", "  VIS.avg_line(true, max_edps, ch_plot)\n  VIS.median_line(true, max_edps, ch_plot)\n", "  VIS.avg_line(false, max_edps, ch_plot)\n  VIS.median_line(false, max_edps, ch_plot)\n"),
    ]),
    ("#190 a waiting shield enters the next recording", [
        ("core/metrics.lua", "function M.session_mark()\n  if Vermilion.Pipeline and Vermilion.Pipeline.drop_pending then Vermilion.Pipeline.drop_pending() end\n", "function M.session_mark()\n"),
    ]),
    ("#191 the export duration changes after saving", [
        ("ui/graph.lua", "    dur_ms = Vermilion.SessionStore.live_duration(),\n", ""),
    ]),
    ("#191 reopening invents ultimate data", [
        ("core/ultimate.lua", "  saw_power = n_steps > 1\n", "  saw_power = n_steps > 0\n"),
        ("core/ultimate.lua", "return saw_power and n_steps > 1 end", "return saw_power and n_steps > 0 end"),
    ]),
    ("#192 ultimate after Stop adds data", [
        ("core/ultimate.lua", "  if recording then\n    saw_power = true\n    push_step(now_ms())\n  end\n", "  saw_power = true\n  if recording then push_step(now_ms()) end\n"),
        ("core/ultimate.lua", "return saw_power and n_steps > 1 end", "return saw_power and n_steps > 0 end"),
    ]),
    ("#193 an early ultimate change differs after reopening", [
        ("core/ultimate.lua", "return saw_power and n_steps > 1 end", "return saw_power and n_steps > 0 end"),
    ]),
    ("#194 #195 a hovered row stays lit", [
        ("ui/graph.lua", "    CV.clear_hover(); DV.clear_hover(); RV.clear_hover(); UV.clear_hover(); TV.clear_hover()\n", ""),
    ]),
    ("#196 hits before Record enter the chart", [
        ("core/metrics.lua", "  session_closed = false\n  damage_out_buf:reset()\n  shield_out_buf:reset()\nend\n", "  session_closed = false\nend\n"),
    ]),
    ("#198 a session keeps the film strip of another", [
        ("ui/graph.lua", "  Vermilion.FilmOverview.forget()\n", ""),
    ]),
    ("#197 a recording with no peak reads a negative time", [
        ("ui/graph.lua", "  SUM.peak_t_off = (peak > 0) and (peak_t - first_t) or 0\n", "  SUM.peak_t_off = peak_t - first_t\n"),
    ]),
]


def copy_tree(dst):
    keep = (".lua", ".xml", ".txt")

    def ignore(folder, names):
        out = []
        for name in names:
            path = os.path.join(folder, name)
            if os.path.isdir(path):
                if name in (".git", ".github", "assets", "output", "__pycache__", "docs", "specs"):
                    out.append(name)
            elif not name.endswith(keep):
                out.append(name)
        return out

    shutil.copytree(ROOT, dst, ignore=ignore)


def apply_mutation(base, edits):
    for rel, old, new in edits:
        path = os.path.join(base, rel)
        with open(path, encoding="utf-8", newline="") as f:
            text = f.read()
        for eol in ("\r\n", "\n"):
            a, b = old.replace("\n", eol), new.replace("\n", eol)
            if text.count(a) >= 1:
                text = text.replace(a, b)
                break
        else:
            raise SystemExit("MUTANT: the code no longer has: " + old[:70])
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(text)


def hunt(base, lua, seeds, steps):
    for seed in range(1, seeds + 1):
        p = subprocess.run([lua, "test/simlab/monkey.lua", ".", str(seed), str(steps), "0"], cwd=base,
                           capture_output=True, text=True, errors="replace", timeout=300)
        if p.returncode != 0:
            found = re.search(r"seed=(\d+) step=(\d+) rule=(\S+)", p.stdout)
            if found:
                return int(found.group(1)), int(found.group(2)), found.group(3)
            return seed, 0, "crash: " + (p.stdout + p.stderr)[-200:].replace("\n", " ")
    return None


def main():
    lua = shutil.which("lua") or shutil.which("lua5.4") or "lua"
    seeds = int(sys.argv[1]) if len(sys.argv) > 1 else SEEDS
    missed = 0
    with tempfile.TemporaryDirectory() as tmp:
        clean = os.path.join(tmp, "clean")
        copy_tree(clean)
        found = hunt(clean, lua, min(seeds, 10), STEPS)
        if found:
            print("MUTANTS: FAIL the clean code does not pass, seed %d step %d rule %s" % found)
            return 1
        for index, (name, edits) in enumerate(MUTANTS):
            base = os.path.join(tmp, "m%d" % index)
            shutil.copytree(clean, base)
            apply_mutation(base, edits)
            found = hunt(base, lua, seeds, STEPS)
            if found:
                print("found   %-52s seed %-3d step %-4d %s" % (name, found[0], found[1], found[2]))
            else:
                missed += 1
                print("MISSED  %-52s in %d seeds" % (name, seeds))
            shutil.rmtree(base)
    print("MUTANTS: %d of %d found" % (len(MUTANTS) - missed, len(MUTANTS)))
    return 1 if missed else 0


if __name__ == "__main__":
    sys.exit(main())
