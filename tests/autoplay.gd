extends SceneTree
## Isolated Godot gameplay smoke/stress driver. Launched only by tools/run_autoplay.py.
## Simulates frames directly so it does not require real-time gameplay.

const GAME_SCENE := preload("res://scenes/main.tscn")
const LANES := [110.0, 240.0, 370.0]
const PLAYER_Y := 700.0
const STEP := 0.05

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runs := 100
	var seconds := 45.0
	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = int(arg.substr(7))
		elif arg.begins_with("--seconds="):
			seconds = float(arg.substr(10))
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
	game.rng.seed = 124891
	var failures: Array[String] = []
	var records: Array[Dictionary] = []
	var total_crystals := 0
	var total_deaths := 0
	for run_id in range(runs):
		game.start_game()
		var steps := int(ceil(seconds / STEP))
		var simulated := 0.0
		var moves := 0
		for frame in range(steps):
			if not game.running or game.game_over:
				break
			var target_lane := _choose_lane(game)
			if target_lane != game.lane:
				game._step(signi(target_lane - game.lane))
				moves += 1
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
	# Consider only imminent obstacles. Move a maximum of one lane per frame.
	var blocked := [false, false, false]
	var rewards := [0.0, 0.0, 0.0]
	for obj in game.objects:
		var y := float(obj["y"])
		var lane_id := int(obj["lane"])
		if lane_id < 0 or lane_id > 2:
			continue
		if obj["kind"] == "block" and y > PLAYER_Y - 250.0 and y < PLAYER_Y + 45.0:
			blocked[lane_id] = true
		elif obj["kind"] == "crystal" and y > PLAYER_Y - 240.0 and y < PLAYER_Y:
			rewards[lane_id] += 1.0
		elif (obj["kind"] == "shield" or obj["kind"] == "magnet") and y > PLAYER_Y - 240.0 and y < PLAYER_Y:
			rewards[lane_id] += 0.7
	var best_lane: int = game.lane
	var best_value := -100000.0
	for candidate in range(3):
		var value: float = float(rewards[candidate]) * 2.0 - absf(float(candidate - game.lane)) * 0.8
		if blocked[candidate]:
			value -= 1000.0
		# Penalize crossing a blocked adjacent lane.
		if abs(candidate - game.lane) == 2 and blocked[1]:
			value -= 1000.0
		if value > best_value:
			best_value = value
			best_lane = candidate
	return best_lane
