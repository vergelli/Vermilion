import os
import shutil
import subprocess
import sys
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
DEFAULT_SV = os.path.join(os.path.expanduser("~"), "Documents", "Elder Scrolls Online", "live",
                          "SavedVariables", "Vermilion.lua")
DEFAULT_TRACES = os.path.abspath(os.path.join(ROOT, "..", "VermilionWorkingdir", "traces"))


def main(argv):
    sv = DEFAULT_SV
    traces = DEFAULT_TRACES
    open_report = False
    skip_suite = False
    for a in argv:
        if a == "--open":
            open_report = True
        elif a == "--no-suite":
            skip_suite = True
        elif a.startswith("--traces="):
            traces = os.path.abspath(a.split("=", 1)[1])
        elif a.endswith(".lua"):
            sv = os.path.abspath(a)
    if not os.path.isfile(sv):
        print("SavedVariables not found: " + sv)
        print("Run /vermilion flush in game first, or pass the path as an argument.")
        return 2
    os.makedirs(traces, exist_ok=True)
    lua = shutil.which("lua") or shutil.which("lua5.4") or "lua"
    print("SavedVariables: %s (%.1f MB)" % (sv, os.path.getsize(sv) / 1e6))
    print("corpus:         " + traces)
    proc = subprocess.run([lua, os.path.join(HERE, "ingest_extract.lua"), sv, traces], cwd=ROOT)
    if proc.returncode != 0:
        return proc.returncode
    if skip_suite:
        return 0
    out = os.path.join(HERE, "robot", "output")
    proc = subprocess.run([sys.executable, "-m", "robot", "--outputdir", out,
                           os.path.join(HERE, "robot", "gate.robot")], cwd=ROOT)
    if open_report:
        webbrowser.open("file:///" + os.path.join(out, "report.html").replace("\\", "/"))
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
