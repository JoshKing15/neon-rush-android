# Neon Rush for Roblox

This prototype ports the Godot game's portrait Endless Mode. It uses a local UI and keeps your best score for the current play session. This build includes lane switching, obstacle patterns, crystal combos, near misses and retry.

1. Open a new Baseplate in Roblox Studio.
2. In Explorer, add a **LocalScript** under **StarterPlayer → StarterPlayerScripts**.
3. Replace its contents with `NeonRush.client.luau` and click **Play**.
4. Press **Play** in the game. Use **A/D**, the **left/right arrow keys**, or the on-screen buttons.

Check that collecting a crystal increases score, passing close to an obstacle awards a near miss, colliding ends the run, and Retry resets the run. Use Studio's phone emulator to check the buttons in portrait.
