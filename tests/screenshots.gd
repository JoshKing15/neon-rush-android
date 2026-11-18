extends SceneTree
## Rendered visual checkpoints for CI under Xvfb (not headless).
const GAME = preload("res://scenes/main.tscn")
var game: Node
var output_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> bool:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("SCREENSHOT ERROR: empty image at " + name)
		return false
	var path := output_dir.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		printerr("SCREENSHOT ERROR: failed to save " + path + " code " + str(error))
		return false
	print("SCREENSHOT SAVED: " + path)
	return true

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.substr(9)
	if output_dir.is_empty():
		printerr("SCREENSHOT ERROR: --output=PATH required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var count := 0
	if await _capture("01_main_menu"):
		count += 1
	game.start_game()
	game.spawn_clock = 999.0
	game.powerup_clock = 999.0
	game.objects.clear()
	game.objects.append_array([
		{"lane": 0, "y": 280.0, "kind": "block", "near": false},
		{"lane": 2, "y": 450.0, "kind": "crystal"},
		{"lane": 1, "y": 160.0, "kind": "block", "near": false}
	])
	if await _capture("02_gameplay_obstacles"):
		count += 1
	game.objects.clear()
	game.shield_charges = 1
	game._refresh_hud()
	if await _capture("03_shield_active"):
		count += 1
	game.shield_charges = 0
	game.magnet_time = 8.0
	game.objects.clear()
	game.objects.append_array([{"lane": 0, "y": 525.0, "kind": "crystal"}, {"lane": 2, "y": 370.0, "kind": "crystal"}])
	game._refresh_hud()
	if await _capture("04_magnet_active"):
		count += 1
	game.objects.clear()
	game._end_game()
	if await _capture("05_game_over"):
		count += 1
	game.wallet = 100
	game._open_shop()
	game.shop_index = 1
	game._update_shop()
	if await _capture("06_skin_shop"):
		count += 1
	game._show_menu("NEON RUSH", "VISUAL QA - DAILY MISSIONS", "PLAY")
	if await _capture("07_daily_missions"):
		count += 1
	print("SCREENSHOT SUMMARY: %d/7 images" % count)
	quit(0 if count == 7 else 1)
