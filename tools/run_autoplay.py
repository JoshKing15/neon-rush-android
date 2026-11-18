#!/usr/bin/env python3
"""Run Godot headless auto-play in an isolated project/user-data directory."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ERROR_RE = re.compile(r"(?im)^\s*(?:ERROR:|SCRIPT ERROR:|FATAL:|.*\bERROR\b.*)")
WARN_RE = re.compile(r"(?im)^\s*(?:WARNING:|WARN:|.*\bWARNING\b.*)")

def main():
    p = argparse.ArgumentParser(description="Neon Rush isolated Godot auto-play and console reporter")
    p.add_argument("--godot", default=None, help="Godot executable (default: search PATH)")
    p.add_argument("--suite", choices=("autoplay", "features"), default="autoplay")
    p.add_argument("--runs", type=int, default=100)
    p.add_argument("--seconds", type=float, default=45.0, help="Simulated seconds per run")
    p.add_argument("--timeout", type=int, default=600, help="Wall-clock subprocess timeout in seconds")
    p.add_argument("--output", type=Path, default=ROOT / "reports")
    args = p.parse_args()
    if not (1 <= args.runs <= 10000 and 0 < args.seconds <= 600 and args.timeout > 0):
        p.error("runs must be 1..10000, seconds 0..600, timeout > 0")
    godot = args.godot or next((shutil.which(n) for n in ("godot", "godot4", "Godot", "Godot_v4.7.2-stable_win64_console.exe") if shutil.which(n)), None)
    if not godot:
        print("Godot executable not found. Install Godot 4 and use --godot PATH.", file=sys.stderr)
        return 2
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    prefix = f"{args.suite}_{stamp}"
    log_path = output / (prefix + ".log")
    report_path = output / (prefix + ".json")
    summary_path = output / (prefix + "_summary.json")
    with tempfile.TemporaryDirectory(prefix="neon-rush-qa-") as tmp:
        tmp_path = Path(tmp)
        project = tmp_path / "project"
        project.mkdir()
        for folder in ("scripts", "scenes", "tests"):
            shutil.copytree(ROOT / folder, project / folder)
        shutil.copy2(ROOT / "project.godot", project / "project.godot")
        # Distinct project name and OS data directories protect existing player saves.
        cfg = (project / "project.godot").read_text(encoding="utf-8")
        cfg = cfg.replace('config/name="Neon Rush"', 'config/name="Neon Rush QA Isolated"')
        (project / "project.godot").write_text(cfg, encoding="utf-8")
        env = os.environ.copy()
        for name in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"):
            directory = tmp_path / name
            directory.mkdir()
            env[name] = str(directory)
        cmd = [str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(project), "--quit-after", "1200" if args.suite == "features" else "24000", "--script", ("res://tests/features_v04.gd" if args.suite == "features" else "res://tests/autoplay.gd"),
               "--", f"--runs={args.runs}", f"--seconds={args.seconds}", f"--report={report_path}"]
        timed_out = False
        try:
            proc = subprocess.run(cmd, cwd=project, env=env, capture_output=True,
                                  text=True, errors="replace", timeout=args.timeout, check=False)
            output_text = proc.stdout + "\n" + proc.stderr
            exit_code = proc.returncode
        except subprocess.TimeoutExpired as exc:
            timed_out = True
            exit_code = 124
            def as_text(value):
                return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
            output_text = as_text(exc.stdout) + "\n" + as_text(exc.stderr) + "\nAUTOPLAY TIMEOUT"
    log_path.write_text(output_text, encoding="utf-8")
    errors = [line for line in output_text.splitlines() if ERROR_RE.search(line)]
    warnings = [line for line in output_text.splitlines() if WARN_RE.search(line) and not ERROR_RE.search(line)]
    game_report = None
    if report_path.exists():
        try:
            game_report = json.loads(report_path.read_text(encoding="utf-8"))
        except (ValueError, OSError) as exc:
            errors.append(f"Invalid gameplay report: {exc}")
    passed = exit_code == 0 and not errors and game_report is not None and not game_report.get("invariant_failures")
    commit_sha = os.environ.get("GITHUB_SHA", "unknown-local")
    summary = {
        "git_commit_sha": commit_sha,
        "godot_version_target": "4.4.1 (CI)",
        "timestamp_utc": stamp,
        "status": "PASS" if passed else "FAIL",
        "godot_exit_code": exit_code,
        "timed_out": timed_out,
        "suite": args.suite,
        "runs_requested": 1 if args.suite == "features" else args.runs,
        "runs_completed": game_report.get("runs_completed", 0) if game_report else 0,
        "console_error_count": len(errors),
        "console_warning_count": len(warnings),
        "console_errors": errors,
        "console_warnings": warnings,
        "invariant_failures": game_report.get("invariant_failures", []) if game_report else ["Gameplay report missing"],
        "log_file": str(log_path),
        "gameplay_report": str(report_path) if game_report else None,
        "notes": "Godot headless simulation; not Android device QA or a human playability verdict"
    }
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("QA COMMIT: " + commit_sha)
    print(f"Neon Rush {args.suite}: {summary['status']} | runs {summary['runs_completed']}/{summary['runs_requested']} | "
          f"errors {len(errors)} | warnings {len(warnings)}")
    print(f"Console: {log_path}\nSummary: {summary_path}")
    if game_report:
        print(f"Gameplay: {report_path}")
    if errors:
        print("First console error: " + errors[0])
    if not passed:
        print("Diagnostic tail:")
        print("\n".join(output_text.splitlines()[-35:]))
    return 0 if passed else 1

if __name__ == "__main__":
    sys.exit(main())
