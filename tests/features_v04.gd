extends SceneTree
const GAME = preload("res://scenes/main.tscn")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var game: Node

func check_case(name: String, ok: bool) -> void:
	checks.append({"name": name, "passed": ok})
	print("FEATURE %s: %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		failures.append(name)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	if report_path.is_empty():
		printerr("Missing --report")
		quit(2)
		return
	var legacy := FileAccess.open("user://neon_rush.save", FileAccess.WRITE)
	legacy.store_32(1234)
	legacy.close()
	game = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check_case("Legacy best score loads", game.best == 1234)
	game.start_game()
	game.spawn_clock = 999.0
	game.powerup_clock = 999.0
	game.objects.append({"lane": 1, "y": 690.0, "kind": "shield"})
	game._process(0.05)
	check_case("Shield pickup", game.shield_charges == 1)
	game.objects.append({"lane": 1, "y": 690.0, "kind": "block", "near": false})
	game._process(0.05)
	check_case("Shield blocks one collision", game.running and game.shield_charges == 0)
	game.invulnerable = 0.0
	game.objects.append({"lane": 1, "y": 690.0, "kind": "block", "near": false})
	game._process(0.05)
	check_case("Next unshielded collision ends run", game.game_over)
	game.start_game()
	game.spawn_clock = 999.0
	game.powerup_clock = 999.0
	game.objects.append({"lane": 1, "y": 690.0, "kind": "magnet"})
	game._process(0.05)
	check_case("Magnet pickup", game.magnet_time > 7.9)
	var before: int = game.wallet
	game.objects.append({"lane": 0, "y": 690.0, "kind": "crystal"})
	game._process(0.05)
	check_case("Magnet collects adjacent crystal", game.crystals == 1 and game.wallet == before + 1)
	game.magnet_time = 0.0
	game.objects.append({"lane": 0, "y": 690.0, "kind": "crystal"})
	game._process(0.05)
	check_case("Expired magnet does not collect", game.crystals == 1)
	game.mission_day = Time.get_date_string_from_system(false)
	game.mission_progress = [0, 0, 0]
	game.mission_claimed = [false, false, false]
	before = game.wallet
	game._advance_mission(0, 12)
	check_case("Crystal mission reward", game.wallet == before + 15)
	game._advance_mission(0, 12)
	check_case("No repeated crystal mission payout", game.wallet == before + 15)
	game._advance_mission(1, 120)
	check_case("Survival mission reward", game.wallet == before + 35)
	game._advance_mission(2, 20)
	check_case("Near miss mission reward", game.wallet == before + 60)
	game.mission_day = "2000-01-01"
	game._check_daily_reset()
	check_case("New day resets missions", game.mission_progress == [0, 0, 0] and game.mission_claimed == [false, false, false])
	game.running = false
	game.paused = false
	game.wallet = 10
	game._open_shop()
	game.shop_index = 1
	game._shop_action()
	check_case("Cannot buy unaffordable skin", game.wallet == 10 and not game.owned_skins.has(1))
	game.wallet = 100
	game._open_shop()
	game.shop_index = 1
	game._shop_action()
	check_case("Violet skin purchase", game.wallet == 75 and game.selected_skin == 1)
	game._open_shop()
	game.shop_index = 1
	game._shop_action()
	check_case("Owned skin equips free", game.wallet == 75)
	game._open_shop()
	game.shop_index = 2
	game._shop_action()
	check_case("Lime skin purchase", game.wallet == 25 and game.selected_skin == 2)
	game.best = 2345
	game._save_best()
	game._save_profile()
	var restored = GAME.instantiate()
	root.add_child(restored)
	await process_frame
	restored.set_process(false)
	check_case("Wallet persists after reload", restored.wallet == 25)
	check_case("Skins persist after reload", restored.owned_skins.has(1) and restored.owned_skins.has(2) and restored.selected_skin == 2)
	check_case("Best score persists after reload", restored.best == 2345)
	var report := {"test_type": "v04_features", "runs_completed": 1, "checks": checks, "passed": checks.size() - failures.size(), "failed": failures.size(), "invariant_failures": failures}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("Could not write feature report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("FEATURE SUMMARY: %d passed / %d failed" % [report["passed"], report["failed"]])
	quit(1 if not failures.is_empty() else 0)
