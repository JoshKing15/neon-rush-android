# Neon Rush — v0.2 gameplay prototype

Godot 4 portrait arcade game for Android. Dodge neon obstacles, collect crystals, build combos, and chase a personal best.

**Status:** v0.2 source update. Not yet tested in Godot or on an Android phone. No live or test ads are integrated.

## v0.2 changes
- Safer swept vertical collision detection and clamped frame delta
- Death-screen retry lockout, pause button, app focus/background pause
- Smooth one-lane-per-tap movement (A/D, arrows, left/right half of screen)
- Tiered obstacle patterns (easy, medium, hard), reachability validation and speed-scaled spacing
- Crystal combo scoring and near-miss bonuses
- HUD text only updates when values change
- Disabled rewarded continue placeholder remains hidden until ads are implemented

## Run
1. Install Godot 4.3+ from https://godotengine.org/download
2. Clone or download this repository
3. Import `project.godot` into Godot Project Manager
4. Press F5 and use A/D, arrow keys, or click the left/right half of the window

## Known limitations
- Gameplay must be validated in the Godot editor and on Android hardware.
- The prototype still uses a legacy best-score-only save file.
- No audio, haptics, missions, cosmetic progression, ad SDK, Android export preset or Play Store build yet.
- Pattern reachability is based on one-lane transitions and does not guarantee real-world timing fairness; playtesting and tuning are required.
- No ad revenue can be earned from this source version.

See `docs/ROADMAP.md` and `docs/ADMOB_SETUP.md` for next steps.
