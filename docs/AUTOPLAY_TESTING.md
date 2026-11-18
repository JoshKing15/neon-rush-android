# Neon Rush Auto-Play QA (Godot 4)

This opt-in test tool runs the existing Endless Mode logic in a **headless Godot process** and captures its console output. It does not change `scripts/game.gd`, normal gameplay, or the approved v0.5 World Adventure scope.

## Prerequisites
- Godot 4 executable (Godot 4.7.2 preferred)
- Python 3.9+
- Run commands from the repository root

## Run

```sh
python tools/run_autoplay.py --godot /path/to/godot --runs 100 --seconds 45
```

On Windows, quote the executable path:
```powershell
py tools/run_autoplay.py --godot "C:\\path\\to\\Godot_v4.7.2-stable_win64_console.exe" --runs 100 --seconds 45
```

For a fast first smoke test: `python tools/run_autoplay.py --runs 3 --seconds 15`.

The runner copies the project to a temporary directory, gives it a different project name and redirects OS user-data directories. **It does not delete or write your existing Neon Rush saves.** It creates timestamped output under `reports/`:
- `autoplay_*.log`: complete Godot stdout/stderr
- `autoplay_*.json`: per-run duration, score, gems, lane moves, death flag, invariants
- `autoplay_*_summary.json`: PASS/FAIL, exit code, console error/warning counts, excerpts

The test fails on a nonzero Godot exit, missing gameplay report, detected console errors, or failed invariants. Warnings are recorded but do not fail by default. Expected gameplay deaths are **not** treated as software errors. Timeout returns a failed report. The bot uses a basic obstacle-avoidance heuristic, so deaths may reflect imperfect decisions.

## What this DOES NOT prove
- No real Android APK/device, touch input, FPS/GPU rendering or battery performance is tested.
- Headless simulated frame steps are not equivalent to human playtesting.
- It does not verify the proposed World Adventure levels, which have not been implemented.
- No claim of successful test execution should be made until the command runs on a machine with Godot and the reports are inspected.

## Next QA improvements
- Deterministic seeded obstacle/fairness test scenarios
- Save migration, mission reward and shop purchase assertions
- Android device smoke tests and screenshots/video review
- CI workflow after the local smoke test is confirmed

Please attach the `*_summary.json` and `.log` files when reporting failures.
