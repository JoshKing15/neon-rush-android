extends SceneTree
## Isolated Godot gameplay smoke/stress driver. Launched only by tools/run_autoplay.py.
## Simulates frames directly so it does not require real-time gameplay.

const GAME_SCENE := preload("res://scenes/main.tscn")
const LANES := [110.0, 240.0, 370.0]
const PLAYER_Y := 700.0
const STEP := 0.05
const REACTION_STEPS := 4
const HORIZON := 24

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runs := 100
	var seconds := 45.0
	var report_path := ""
	var base_seed := 124891
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = int(arg.substr(7))
		elif arg.begins_with("--seconds="):
			seconds = float(arg.substr(10))
		elif arg.begins_with("--seed="):
			base_seed = int(arg.substr(7))
		elif arg.begins_with("--report="):
			report_path = arg.substr(9)
	if runs < 1 or runs > 10000 or seconds <= 0.0 or seconds > 600.0 or report_path.is_empty():
		printerr("AUTOPLAY CONFIG ERROR: use --runs=1..10000 --seconds=0..600 --report=PATH")
		quit(2)
		return

	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false) # Avoid double-advancing frames while manually simulating.
	var failures: Array[String] = []
	var records: Array[Dictionary] = []
	var total_crystals := 0
	var total_deaths := 0
	for run_id in range(runs):
		var run_seed := base_seed + run_id
		game.rng.seed = run_seed
		game.fx_rng.seed = run_seed
		game.start_game()
		var cooldown := REACTION_STEPS
		var no_plan_frames := 0
		var steps := int(ceil(seconds / STEP))
		var simulated := 0.0
		var moves := 0
		for frame in range(steps):
			if not game.running or game.game_over:
				break
			if cooldown > 0:
				cooldown -= 1
			else:
				var target_lane := _choose_lane(game)
				if target_lane < 0:
					no_plan_frames += 1
				elif target_lane != game.lane:
					game._step(signi(target_lane - game.lane))
					moves += 1
					cooldown = REACTION_STEPS - 1
			game._process(STEP)
			simulated += STEP
			if game.lane < 0 or game.lane > 2:
				failures.append("Run %d: lane outside 0..2" % (run_id + 1))
				break
			if game.wallet < 0 or game.crystals < 0:
				failures.append("Run %d: negative crystal balance" % (run_id + 1))
				break
			if game.shield_charges < 0 or game.shield_charges > 1:
				failures.append("Run %d: invalid shield charges" % (run_id + 1))
				break
		var died: bool = game.game_over
		if died:
			total_deaths += 1
		total_crystals += game.crystals
		records.append({
			"run": run_id + 1,
			"seed": run_seed,
			"reaction_seconds": STEP * REACTION_STEPS,
			"no_plan_decisions": no_plan_frames,
			"collision": game.last_collision.duplicate(true),
			"death_objects": game.objects.duplicate(true) if died else [],
			"seconds_simulated": snappedf(simulated, 0.01),
			"score": game.score,
			"crystals": game.crystals,
			"lane_moves": moves,
			"died": died,
			"shield_remaining": game.shield_charges
		})
		print("AUTOPLAY RUN %d/%d: %.2fs score=%d crystals=%d moves=%d died=%s" % [
			run_id + 1, runs, simulated, game.score, game.crystals, moves, str(died)])
	var report := {
		"test_type": "simulated_godot_gameplay",
		"runs_requested": runs,
		"runs_completed": records.size(),
		"seconds_per_run_target": seconds,
		"total_deaths": total_deaths,
		"full_duration_survivors": records.size() - total_deaths,
		"base_seed": base_seed,
		"total_crystals_collected": total_crystals,
		"invariant_failures": failures,
		"runs": records,
		"limitations": [
			"Simulates gameplay logic in headless Godot, not human taps or Android rendering",
			"Deaths are expected outcomes and are not automatically software errors",
			"Console errors and warnings are classified by the external Python runner",
			"Bot is heuristic; survival does not prove all obstacle patterns are fair"
		]
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("AUTOPLAY ERROR: cannot write JSON report to " + report_path)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("AUTOPLAY REPORT: " + report_path)
	quit(1 if not failures.is_empty() else 0)

func _choose_lane(game: Node) -> int:
	# Receding horizon search using the actual movement and swept hit geometry.
	# A missing plan is diagnostic, not proof that a human cannot escape.
	var states: Array[Dictionary] = [{"x": float(game.player_x), "lane": int(game.lane), "cool": 0, "first": int(game.lane), "cost": 0}]
	var blocks: Array[Dictionary] = []
	for obj in game.objects:
		if obj["kind"] == "block" and float(obj["y"]) <= PLAYER_Y + game.HIT_Y:
			blocks.append(obj)
	var distance := 0.0
	for tick in range(HORIZON):
		var predicted_speed := minf(680.0, 270.0 + (float(game.elapsed) + (tick + 1) * STEP) * 7.0)
		var next_distance := distance + predicted_speed * STEP
		var next_states: Dictionary = {}
		for state in states:
			var current := int(state["lane"])
			var cool := int(state["cool"])
			for candidate in range(maxi(0, current - 1), mini(2, current + 1) + 1):
				if cool > 0 and candidate != current:
					continue
				var x0 := float(state["x"])
				var x1 := move_toward(x0, float(LANES[candidate]), float(game.MOVE_SPEED) * STEP)
				var safe := true
				for block in blocks:
					var y := float(block["y"])
					if game._swept_hit(x0, x1, y + distance, y + next_distance, float(LANES[int(block["lane"])])):
						safe = false
						break
				if not safe:
					continue
				var next_cool := REACTION_STEPS - 1 if candidate != current else maxi(0, cool - 1)
				var first := candidate if tick == 0 else int(state["first"])
				var cost := int(state["cost"]) + (1 if candidate != current else 0)
				var key := "%d:%d:%d" % [roundi(x1), candidate, next_cool]
				if not next_states.has(key) or cost < int(next_states[key]["cost"]):
					next_states[key] = {"x": x1, "lane": candidate, "cool": next_cool, "first": first, "cost": cost}
		if next_states.is_empty():
			return -1
		states.clear()
		for state in next_states.values():
			states.append(state)
		distance = next_distance
	var best := states[0]
	for state in states:
		if int(state["cost"]) < int(best["cost"]):
			best = state
	return int(best["first"])
