# Neon Rush v0.4 manual test plan

Use Godot 4.7.2. Import `project.godot` and press F5. **This code has not been executed by the assistant in Godot; test before release.**

1. Confirm existing movement, collisions, score, near misses, pause/resume, sound and restart still work.
2. Run until a ring pickup appears (~11 seconds, then 13–19 seconds apart). Cyan ring = shield; violet ring = magnet.
3. Collect shield; HUD shows SHIELD 1. Hit one pink block: the shield should be consumed, the run continues and temporary invulnerability applies. A second collision after invulnerability ends should end the run.
4. Collect magnet; HUD shows remaining seconds and nearby crystals in other lanes should be collected for eight seconds.
5. Collect a crystal: RUN GEMS and BANK both increase by one. Close/reopen the game; BANK must remain, RUN GEMS must reset.
6. On menu, open SKIN SHOP; press NEXT SKIN to browse CYAN (free), VIOLET (25), LIME (50), SUNSET (75). Attempt an unaffordable purchase; balance must not change. Purchase an affordable skin and equip it. Restart the game; color, ownership and balance should persist.
7. On menu or game-over screen, read three daily missions: collect 12 crystals (15 bank gems), survive 120 cumulative seconds (20), perform 20 near misses (25). Each automatically pays once when completed. Verify the reward is not repeated after restart.
8. Change the device date **only on a test machine** and relaunch to confirm the missions reset for a new local calendar day, without resetting bank or skins. Note: local clock can be manipulated; a server-backed clock would be needed for competitive rewards.
9. Test old `user://neon_rush.save` best score migration. Do not delete existing save data; new profile is `user://neon_rush_profile_v1.json`.
10. Run for 10+ minutes on a budget Android device when an APK is available, watching frame time, sound and UI layout.

Known limitations: local save is editable; no cloud sync; missions use local device date; ads are not implemented; shop UI is simple; no automated Godot runtime test yet.
