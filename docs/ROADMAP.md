# Neon Rush — approved development roadmap

**Decision approved:** 18 November 2026. World Adventure is the official **v0.5** milestone. Android export and AdMob are deferred to later milestones. Preserve Endless Mode and all existing player saves.

## Current verified baseline
- [x] v0.2 gameplay previously play-tested in Godot 4.7.2
- [x] v0.3 neon visuals, feedback and generated sounds committed
- [ ] v0.3 full runtime/device QA
- [x] v0.4 shield, magnet, persistent crystals, four skins and three daily missions committed
- [ ] v0.4 runtime QA, save migration, gameplay balance and UI checks (see `docs/V04_TESTING.md`)
- [ ] No verified Android APK, AdMob integration, production release or analytics

## v0.5 — World Adventure vertical slice (APPROVED)
Goal: one **polished ten-level World 1**, expandable toward 100 levels in ten themed worlds.

- [ ] Stabilize v0.4 and fix regressions before refactoring
- [ ] Separate gameplay, level management, progression, missions and persistence into maintainable components
- [ ] Preserve the existing Endless Mode and migrate saves without losing best score, crystals, skins or mission data
- [ ] Build data-driven level definitions, level-selection UI and completion/progress persistence
- [ ] Author and test World 1: Neon District, levels 1–10
- [ ] Introduce two readable hazards: moving blocks and telegraphed laser gates
- [ ] Add three-star level goals and replay support
- [ ] Implement and play-test Prism Warden, a three-lane boss with clearly warned attack phases
- [ ] Validate level fairness, pause/retry behavior, screen readability and performance in Godot

**Acceptance gate:** All ten levels are playable and completable; stars and unlocks persist; no known impossible obstacle waves; Endless Mode still works; v0.4 saves remain intact; no critical runtime errors. Committed code is **not** equivalent to play-tested functionality.

## Long-term World Adventure vision (NOT v0.5 scope)
- [ ] Ten themed worlds × ten levels = 100 levels
- [ ] Five distinct boss concepts, with later remixed encounters
- [ ] XP, achievements, weekly challenges and optional daily seeded courses
- [ ] Retention analytics and playtesting-driven difficulty tuning
- [ ] Expand content only after World 1 meets quality and fairness gates

## Later milestone — Android and monetization (DEFERRED)
- [ ] Android export and device testing, meeting applicable Play target API and native library page-size requirements
- [ ] AdMob **test ads**, consent handling, opt-in rewarded continues, verified reward callbacks and carefully capped interstitials
- [ ] Privacy policy, crash/retention analytics, Google Play testing and release preparation
- [ ] No live ads or release until the build and policies are verified

## 60-day planning baseline (not a verified deadline)
| Days | Planned outcome |
| --- | --- |
| 1–7 | v0.4 QA, save-safety tests, refactor foundation |
| 8–14 | Level manager, world map, levels 1–5 |
| 15–21 | Moving blocks, laser gates, fairness tests, three-star goals |
| 22–30 | World 1 levels 1–10, Prism Warden, polish |
| 31–40 | Prototype/expand Worlds 2–3 only if World 1 is stable |
| 41–47 | XP/achievements and analytics groundwork |
| 48–54 | Android export investigation and device optimization |
| 55–60 | Player testing, tuning and release-scope review |

**Scope guard:** The 60-day target is one polished world and approximately 20–30 testable levels if time allows, **not** a promise to finish all 100 levels. Android/AdMob work is downstream of the v0.5 World Adventure gate.

## Project-management review protocol
For every progress review: inspect latest commits and relevant source files; compare eight phases (stabilization, architecture, World 1, mechanics, boss, expansion, analytics, Android/ads); label each Complete, In Progress, Blocked or Not Started; distinguish committed code from runtime-tested features; identify risks and scope changes; recommend three next tasks. Do not modify code, publish, or change approved scope without explicit authorization.
