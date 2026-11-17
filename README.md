# Neon Rush 🟦

**A three-lane neon arcade game for Android, built with Godot 4.** Dodge pink obstacles, collect gold crystals, beat your best score. No purchased assets required.

> **Status:** v0.1 playable source prototype; not yet tested in Godot or exported to Android. No real advertising is connected.

## Features

- Portrait 480 × 854 game area, adaptable to phone display
- Tap/swipe between lanes on mobile, A/D or arrows on desktop
- Infinite obstacle waves; one blocked lane per wave leaves escape routes
- Crystals give +50 points, survival gives time-based points (frame-rate independent)
- Speed and spawn interval increase with survival time
- Local personal-best save across launches
- Game-over/restart screen

## Run it locally
1. Install [Godot 4.3 or later](https://godotengine.org/download) (standard editor).
2. Clone this repo or download its ZIP from GitHub.
3. Godot Project Manager → **Import** → select `project.godot`.
4. Press **F6** or **F5**. Use A/D, arrow keys, or mouse clicks.

## Android export
Install matching Godot export templates, the supported Android SDK and JDK, and configure an Android export preset with your own unique package name. Test with an Android phone before producing a Play Store build. Keep app signing keys outside Git.

## Advertising
Ads are **not implemented**, and this project does **not** earn money yet. The rewarded-continue button is intentionally disabled. Read [AdMob integration guide](docs/ADMOB_SETUP.md) before connecting SDKs; use test ads in development, and grant a continue only after a verified rewarded callback.

## Next milestones
See [Roadmap](docs/ROADMAP.md). No guarantee of players, ad revenue or store approval.

## Source tree
- `project.godot` — Godot configuration
- `scenes/main.tscn` — root game scene
- `scripts/game.gd` — prototype game loop, UI and rendering
- `docs/ADMOB_SETUP.md` — ad implementation and compliance checklist
- `docs/ROADMAP.md` — future release milestones

© 2026 Neon Rush project owner. All gameplay and visuals in this prototype are programmatically drawn.
