# Neon Rush — Godot 4 neon arcade game

Three-lane portrait arcade game for Android, developed in Godot 4. Dodge neon obstacles, collect crystals, build combos and chase a personal best.

**Current status (18 November 2026):** v0.4 features are committed to `main` but **not yet verified by a Godot runtime or Android device test**. v0.2 was previously played successfully in Godot 4.7.2. No Android release or AdMob integration exists.

## Current source features
- Three-lane Endless Mode with obstacle patterns, swept collision checks, near misses, crystal combos and high score
- v0.3 effects: trails, glow, particles and generated sounds (runtime QA pending)
- v0.4 power-ups: one-hit shield and timed crystal magnet (runtime QA pending)
- Persistent crystal wallet, four unlockable/equippable neon orb skins and three local daily missions (runtime QA pending)
- Best-score save compatibility; new v0.4 profile stored separately
- Rewarded continue placeholder remains disabled until an ad SDK is correctly integrated

## Run and test
1. Install Godot 4.7.2.
2. Clone/download the repository and import `project.godot` in Godot Project Manager.
3. Press F5. Use A/D, arrow keys or click the left/right half of the game window.
4. Follow `docs/V04_TESTING.md` to verify power-ups, shop, daily rewards and persistence.
5. Report compile/runtime errors before adding World Adventure.

## Approved direction
**v0.5 = World Adventure vertical slice:** ten playable Neon District levels, a level map, moving blocks, telegraphed laser gates, three-star progression, Prism Warden boss and safe persistence, while keeping Endless Mode working. Long-term vision: ten worlds / 100 levels.

**Android export and AdMob are deferred to later milestones.** No ads are currently integrated and no revenue can be earned from this source version.

See `docs/ROADMAP.md` for the approved 60-day planning baseline and project review rules.
