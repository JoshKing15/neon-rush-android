extends SceneTree
## Deterministic, isolated QA bots. A death is a gameplay result, not an invariant failure.
const GAME_SCENE := preload("res://scenes/main.tscn")
const LANES := [110.0, 240.0, 370.0]
const PLAYER_Y := 700.0
const STEP := 0.05
const HIT_Y := 35.0
const HIT_X := 44.0
const MOVE_SPEED := 1800.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runs := 100
	var seconds := 45.0
	var report_path := ""
	var strategy := "competent"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = int(arg.substr(7))
		elif arg.begins_with("--seconds="):
			seconds = float(arg.substr(10))
		elif arg.begins_with("--report="):
			report_path = arg.substr(9)
		elif arg.begins_with("--strategy="):
			strategy = arg.substr(11)
	if runs < 1 or runs > 10000 or seconds <= 0.0 or seconds > 600.0 or report_path.is_empty() or not ["basic", "competent", "reference"].has(strategy):
		printerr("AUTOPLAY CONFIG ERROR: --runs=1..10000 --seconds=0..600 --report=PATH --strategy=basic|competent|reference")
		quit(2)
		return
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var failures: Array[String] = []
	var records: Array[Dictionary] = []
	var deaths := 0
	var total_crystals := 0
	for run_id in range(runs):
		game.rng.seed = 124891 + run_id
		game.start_game()
		var moves := 0
		var simulated := 0.0
		var last_threat_time := -1.0
		var reaction_time := -1.0
		var killer: Dictionary = {}
		var speed_at_death := 0.0
		var lane_at_death := -1
		var safe_at_death: Array[int] = []
		var avoidable := false
		var fairness_violations := 0
		for frame in range(int(ceil(seconds / STEP))):
			if not game.running or game.game_over:
				break
			var threats := _upcoming_rows(game, 1.4)
			if not threats.is_empty() and last_threat_time < 0.0:
				last_threat_time = simulated
			var target: int = _choose_lane(game, strategy, threats)
			if target != game.lane:
				game._step(signi(target - game.lane))
				moves += 1
				if last_threat_time >= 0.0:
					reaction_time = simulated - last_threat_time
					last_threat_time = -1.0
			# Capture collision candidates before _process, since death may update UI.
			var before := _collision_candidates(game)
			game._process(STEP)
			simulated += STEP
			if game.game_over:
				lane_at_death = game.lane
				speed_at_death = game.speed
				killer = _closest_killer(game, before)
				safe_at_death = _safe_lanes(game, 0.0)
				# A safe lane at the collision instant does NOT imply it was reachable.
				avoidable = _path_exists(game, 0.6)
				break
			if not _path_exists(game, 1.4):
				fairness_violations += 1
			if game.lane < 0 or game.lane > 2:
				failures.append("Run %d: invalid lane" % (run_id + 1))
				break
			if game.wallet < 0 or game.crystals < 0 or game.shield_charges < 0 or game.shield_charges > 1:
				failures.append("Run %d: invalid economy or shield state" % (run_id + 1))
				break
		var died: bool = game.game_over
		if died:
			deaths += 1
		total_crystals += game.crystals
		records.append({
			"run": run_id + 1, "seed": 124891 + run_id, "strategy": strategy,
			"seconds_simulated": snappedf(simulated, 0.01), "score": game.score,
			"crystals": game.crystals, "lane_moves": moves, "died": died,
			"death_lane": lane_at_death, "death_obstacle": killer,
			"safe_lanes_at_death": safe_at_death, "reaction_time": reaction_time,
			"avoidable_estimate": avoidable, "speed_at_death": speed_at_death,
			"fairness_probe_failures": fairness_violations,
			"shield_remaining": game.shield_charges
		})
		print("AUTOPLAY[%s] RUN %d/%d: %.2fs score=%d moves=%d died=%s fairness_probes=%d" % [strategy, run_id + 1, runs, simulated, game.score, moves, str(died), fairness_violations])
	var report := {
		"test_type": "simulated_godot_gameplay", "strategy": strategy,
		"runs_requested": runs, "runs_completed": records.size(),
		"seconds_per_run_target": seconds, "total_deaths": deaths,
		"total_crystals_collected": total_crystals,
		"invariant_failures": failures, "runs": records,
		"limitations": [
			"Headless simulation only, not Android device or human testing",
			"Fairness probes consider currently spawned blocks, not future random spawns",
			"Fairness probes and avoidability estimates are diagnostic, not proofs",
			"Deaths do not automatically fail the QA suite"
		]
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("AUTOPLAY ERROR: cannot write report " + report_path)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	game.queue_free()
	await process_frame
	print("AUTOPLAY REPORT: " + report_path)
	quit(1 if not failures.is_empty() else 0)

func _upcoming_rows(game: Node, horizon: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for obj in game.objects:
		if obj["kind"] != "block":
			continue
		var eta: float = (PLAYER_Y - float(obj["y"])) / maxf(float(game.speed), 1.0)
		if eta < -0.1 or eta > horizon:
			continue
		var found := false
		for row in rows:
			if absf(float(row["eta"]) - eta) < 0.08:
				row["blocked"].append(int(obj["lane"]))
				found = true
				break
		if not found:
			rows.append({"eta": eta, "blocked": [int(obj["lane"])]})
	rows.sort_custom(func(a, b): return float(a["eta"]) < float(b["eta"]))
	return rows

func _choose_lane(game: Node, strategy: String, rows: Array[Dictionary]) -> int:
	if rows.is_empty():
		return game.lane
	var lookahead := 0.35 if strategy == "basic" else (0.95 if strategy == "competent" else 1.4)
	var selected := game.lane
	var best_score := -INF
	for candidate in range(3):
		var travel: float = absf(LANES[candidate] - float(game.player_x)) / MOVE_SPEED
		var score_value := -float(absi(candidate - game.lane)) * 0.5
		var viable := true
		for row in rows:
			var eta: float = float(row["eta"])
			if eta > lookahead:
				continue
			if row["blocked"].has(candidate) and eta >= -0.05:
					viable = false
					break
			if eta < travel + 0.06:
					viable = false
					break
		if not viable:
			continue
		if strategy == "reference" and not _path_from_lane(candidate, rows, travel):
			continue
		for obj in game.objects:
			if int(obj["lane"]) == candidate and obj["kind"] == "crystal":
				var eta_reward: float = (PLAYER_Y - float(obj["y"])) / maxf(float(game.speed), 1.0)
				if eta_reward > travel and eta_reward < lookahead:
					score_value += 0.3
		if score_value > best_score:
			best_score = score_value
			selected = candidate
	return selected

func _path_from_lane(initial_lane: int, rows: Array[Dictionary], initial_time: float) -> bool:
	var states: Array[Dictionary] = [{"lane": initial_lane, "time": initial_time}]
	for row in rows:
		var eta: float = float(row["eta"])
		var next_states: Array[Dictionary] = []
		for state in states:
			for lane_id in range(3):
				if row["blocked"].has(lane_id):
					continue
				var required: float = absf(LANES[lane_id] - LANES[int(state["lane"])]) / MOVE_SPEED
				if float(state["time"]) + required + 0.05 <= eta:
					next_states.append({"lane": lane_id, "time": eta})
		if next_states.is_empty():
			return false
		states = next_states
	return true

func _path_exists(game: Node, horizon: float) -> bool:
	var rows := _upcoming_rows(game, horizon)
	if rows.is_empty():
		return true
	for candidate in range(3):
		var travel: float = absf(LANES[candidate] - float(game.player_x)) / MOVE_SPEED
		if _path_from_lane(candidate, rows, travel):
			return true
	return false

func _safe_lanes(game: Node, horizon: float) -> Array[int]:
	var result: Array[int] = [0, 1, 2]
	for obj in game.objects:
		if obj["kind"] != "block":
			continue
		var eta: float = (PLAYER_Y - float(obj["y"])) / maxf(float(game.speed), 1.0)
		if eta >= -0.05 and eta <= horizon + 0.05:
			result.erase(int(obj["lane"]))
	return result

func _collision_candidates(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj in game.objects:
		if obj["kind"] == "block":
			result.append(obj.duplicate())
	return result

func _closest_killer(game: Node, before: Array[Dictionary]) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := INF
	for obj in before:
		var distance: float = absf(float(obj["y"]) + float(game.speed) * STEP - PLAYER_Y)
		if distance < best_distance and absf(LANES[int(obj["lane"])] - float(game.player_x)) <= HIT_X:
			best_distance = distance
			nearest = {"lane": int(obj["lane"]), "y_before": float(obj["y"])}
	return nearest
