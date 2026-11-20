extends Node2D
## Neon Rush v0.3 — gameplay polish, particles, procedural sound and feedback.
## Ads are intentionally NOT integrated in this prototype.

const WIDTH := 480.0
const HEIGHT := 854.0
const PLAYER_Y := 700.0
const LANES := [110.0, 240.0, 370.0]
const SAVE_PATH := "user://neon_rush.save"
const PROFILE_PATH := "user://neon_rush_profile_v1.json"
const SKIN_NAMES := ["CYAN", "VIOLET", "LIME", "SUNSET"]
const SKIN_COLORS := [Color("38eaff"), Color("ba7aff"), Color("78ff8c"), Color("ff9959")]
const SKIN_COSTS := [0, 25, 50, 75]
const MISSION_TARGETS := [12, 120, 20]
const MISSION_REWARDS := [15, 20, 25]
const BG := Color("080d22")
const CYAN := Color("38eaff")
const PINK := Color("ff4386")
const GOLD := Color("ffe16b")
const HIT_Y := 35.0
const HIT_X := 44.0
const NEAR_X := 145.0
const MOVE_SPEED := 1800.0
const ROW_GAP := 190.0

# Every row uses X=block, .=open; C marks a collectible in an open lane.
# Rows are scheduled sequentially; a path must exist for one-step movement.
const EASY := [["X.."], [".X."], ["..X"], ["X.C"], ["C.X"]]
const MEDIUM := [["XX."], ["X.X"], [".XX"], ["X..", ".X."], ["..X", ".X."], [".X.", "X.."]]
const HARD := [["XX.", ".X.", "X.."], [".XX", "X..", "..X"], ["X.X", ".X.", "X.X"], ["..X", "X..", "..X"]]

var rng := RandomNumberGenerator.new()
var objects: Array[Dictionary] = []
var lane := 1
var player_x := 240.0
var elapsed := 0.0
var spawn_clock := 0.9
var score_fraction := 0.0
var score := 0
var best := 0
var crystals := 0
var combo := 0
var speed := 270.0
var running := false
var paused := false
var game_over := false
var continued := false
var retry_lock := 0.0
var invulnerable := 0.0
var last_hud := ""
var last_safe_lane := 1
var queued_rows: Array[String] = []
var sparks: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var pulse := 0.0
var feedback := ""
var feedback_timer := 0.0
var sound_player: AudioStreamPlayer
var sound_stream: AudioStreamGeneratorPlayback
var wallet := 0
var owned_skins: Array[int] = [0]
var selected_skin := 0
var shield_charges := 0
var magnet_time := 0.0
var powerup_clock := 11.0
var mission_day := ""
var mission_progress: Array[int] = [0, 0, 0]
var mission_claimed: Array[bool] = [false, false, false]
var mission_seconds := 0.0
var menu_mode := "main"
var mission_label: Label
var skin_preview: Label
var shop_button: Button
var next_skin_button: Button
var shop_index := 0
var hud: Label
var hint: Label
var overlay: PanelContainer
var title_label: Label
var subtitle_label: Label
var play_button: Button
var reward_button: Button
var pause_button: Button

func _ready() -> void:
	rng.randomize()
	_load_best()
	_load_profile()
	_build_ui()
	_setup_audio()
	_show_menu("NEON RUSH", "TAP LEFT OR RIGHT TO STEP ONE LANE\nDodge blocks. Chain crystals and near-misses.", "PLAY")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 18)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", CYAN)
	layer.add_child(hud)

	hint = Label.new()
	hint.position = Vector2(20, 108)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", GOLD)
	layer.add_child(hint)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.position = Vector2(405, 20)
	pause_button.custom_minimum_size = Vector2(64, 64)
	pause_button.add_theme_font_size_override("font_size", 24)
	pause_button.pressed.connect(_toggle_pause)
	pause_button.visible = false
	layer.add_child(pause_button)

	overlay = PanelContainer.new()
	overlay.position = Vector2(30, 190)
	overlay.custom_minimum_size = Vector2(420, 390)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("111c38")
	panel_style.border_color = CYAN.darkened(0.35)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	overlay.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(overlay)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	overlay.add_child(stack)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", CYAN)
	stack.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(subtitle_label)
	skin_preview = Label.new()
	skin_preview.text = "●"
	skin_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skin_preview.add_theme_font_size_override("font_size", 64)
	skin_preview.visible = false
	stack.add_child(skin_preview)
	play_button = Button.new()
	play_button.custom_minimum_size.y = 64
	play_button.add_theme_font_size_override("font_size", 23)
	play_button.pressed.connect(_primary_action)
	stack.add_child(play_button)
	reward_button = Button.new()
	reward_button.text = "REWARDED CONTINUE — NOT ENABLED"
	reward_button.disabled = true
	reward_button.visible = false
	stack.add_child(reward_button)
	mission_label = Label.new()
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.add_theme_font_size_override("font_size", 17)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(mission_label)
	shop_button = Button.new()
	shop_button.text = "SKIN SHOP"
	shop_button.custom_minimum_size.y = 54
	shop_button.add_theme_font_size_override("font_size", 20)
	shop_button.pressed.connect(_open_shop)
	stack.add_child(shop_button)
	next_skin_button = Button.new()
	next_skin_button.text = "NEXT SKIN"
	next_skin_button.custom_minimum_size.y = 54
	next_skin_button.add_theme_font_size_override("font_size", 20)
	next_skin_button.pressed.connect(_next_skin)
	next_skin_button.visible = false
	stack.add_child(next_skin_button)
	_refresh_hud()

func _show_menu(heading: String, message: String, action: String) -> void:
	menu_mode = "pause" if paused else "main"
	title_label.text = heading
	subtitle_label.text = message
	mission_label.text = _mission_summary()
	skin_preview.visible = false
	shop_button.visible = not paused
	next_skin_button.visible = false
	play_button.text = action
	overlay.visible = true
	pause_button.visible = false
	reward_button.visible = false

func _primary_action() -> void:
	if retry_lock > 0.0:
		return
	if menu_mode == "shop":
		_shop_action()
	elif paused:
		_resume()
	else:
		start_game()

func start_game() -> void:
	lane = 1
	player_x = LANES[lane]
	last_safe_lane = 1
	objects.clear()
	queued_rows.clear()
	sparks.clear()
	trails.clear()
	feedback = ""
	feedback_timer = 0.0
	shield_charges = 0
	magnet_time = 0.0
	powerup_clock = 11.0
	mission_seconds = 0.0
	_check_daily_reset()
	elapsed = 0.0
	spawn_clock = 0.9
	score_fraction = 0.0
	score = 0
	crystals = 0
	combo = 0
	speed = 270.0
	running = true
	paused = false
	game_over = false
	continued = false
	invulnerable = 0.0
	retry_lock = 0.0
	hint.text = "TAP LEFT / RIGHT • A / D"
	overlay.visible = false
	pause_button.visible = true
	_refresh_hud()
	queue_redraw()

func _process(delta: float) -> void:
	if retry_lock > 0.0:
		retry_lock = maxf(0.0, retry_lock - delta)
		if retry_lock <= 0.0 and game_over:
			play_button.disabled = false
	if not running or paused:
		return

	_animate_fx(delta)
	# Cap simulation delta to avoid collision tunnelling and huge resume jumps.
	var dt := minf(delta, 0.05)
	elapsed += dt
	invulnerable = maxf(0.0, invulnerable - dt)
	magnet_time = maxf(0.0, magnet_time - dt)
	mission_seconds += dt
	if mission_seconds >= 1.0:
		var seconds := int(mission_seconds)
		mission_seconds -= float(seconds)
		_advance_mission(1, seconds)
	player_x = move_toward(player_x, LANES[lane], MOVE_SPEED * dt)
	trails.append({"position": Vector2(player_x, PLAYER_Y), "life": 0.22})
	if trails.size() > 12:
		trails.pop_front()
	pulse += dt
	score_fraction += dt * (15.0 + float(mini(combo, 10)))
	var gained := int(floor(score_fraction))
	if gained > 0:
		score += gained
		score_fraction -= float(gained)

	# Speed rises with time; later tiers introduce more difficult patterns.
	speed = minf(680.0, 270.0 + elapsed * 7.0)
	powerup_clock -= dt
	if powerup_clock <= 0.0:
		_spawn_powerup()
		powerup_clock = rng.randf_range(13.0, 19.0)
	spawn_clock -= dt
	if spawn_clock <= 0.0:
		_spawn_row()
		# Maintain a fixed spatial gap so high speeds do not make patterns impossible.
		spawn_clock = ROW_GAP / speed

	for i in range(objects.size() - 1, -1, -1):
		var obj: Dictionary = objects[i]
		var previous_y: float = float(obj["y"])
		var next_y: float = previous_y + speed * dt
		obj["y"] = next_y
		var crosses := previous_y <= PLAYER_Y + HIT_Y and next_y >= PLAYER_Y - HIT_Y
		var dx := absf(player_x - LANES[int(obj["lane"])])
		if crosses and obj["kind"] == "block" and dx <= HIT_X and invulnerable <= 0.0:
			if shield_charges > 0:
				shield_charges -= 1
				invulnerable = 1.0
				_burst(Vector2(player_x, PLAYER_Y), CYAN, 20)
				_feedback("SHIELD SAVED YOU!")
				objects.remove_at(i)
				continue
			objects[i] = obj
			_end_game()
			break
		if crosses and (obj["kind"] == "shield" or obj["kind"] == "magnet") and dx <= HIT_X:
			if obj["kind"] == "shield":
				shield_charges = 1
				_feedback("SHIELD READY")
			else:
				magnet_time = 8.0
				_feedback("MAGNET 8 SECONDS")
			_burst(Vector2(player_x, PLAYER_Y), CYAN, 14)
			_tone(820.0, 0.12)
			objects.remove_at(i)
			continue
		if crosses and obj["kind"] == "crystal" and (dx <= HIT_X or (magnet_time > 0.0 and dx <= 145.0)):
			crystals += 1
			wallet += 1
			_advance_mission(0, 1)
			_save_profile()
			combo += 1
			score += 50 * mini(combo, 5)
			hint.text = "CRYSTAL COMBO x%d" % mini(combo, 5)
			_burst(Vector2(LANES[int(obj["lane"])], PLAYER_Y), GOLD, 14)
			_feedback("+%d CRYSTAL" % (50 * mini(combo, 5)))
			_tone(660.0 + float(mini(combo, 6)) * 70.0, 0.08)
			objects.remove_at(i)
			continue
		if previous_y <= PLAYER_Y and next_y > PLAYER_Y and obj["kind"] == "block" and not bool(obj.get("near", false)):
			if dx > HIT_X and dx <= NEAR_X:
				obj["near"] = true
				_advance_mission(2, 1)
				combo += 1
				score += 25 * mini(combo, 5)
				hint.text = "NEAR MISS! COMBO x%d" % mini(combo, 5)
				_burst(Vector2(LANES[int(obj["lane"])], PLAYER_Y), PINK, 6)
				_feedback("NEAR MISS +%d" % (25 * mini(combo, 5)))
				_tone(480.0, 0.05)
		if next_y > HEIGHT + 70.0:
			objects.remove_at(i)
		else:
			objects[i] = obj

	_refresh_hud()
	queue_redraw()

func _spawn_row() -> void:
	if queued_rows.is_empty():
		var tier := 0
		if elapsed >= 60.0:
			tier = 2
		elif elapsed >= 25.0:
			tier = 1
		var patterns: Array = EASY if tier == 0 else (MEDIUM if tier == 1 else HARD)
		var candidates: Array = []
		for pattern in patterns:
			if _pattern_reachable(pattern, last_safe_lane) and _pattern_fits_gap(pattern, last_safe_lane):
				candidates.append(pattern)
		if candidates.is_empty():
			queued_rows.append("...")
		else:
			var selected: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
			for row in selected:
				queued_rows.append(row)
	var row: String = queued_rows.pop_front()
	var safe: Array[int] = []
	for n in range(3):
		if row.substr(n, 1) != "X":
			safe.append(n)
		else:
			objects.append({"lane": n, "y": -55.0, "kind": "block", "near": false})
	# Prefer reachable safe lane closest to previous planned path.
	var reachable: Array[int] = []
	for n in safe:
		if absi(n - last_safe_lane) <= 1:
			reachable.append(n)
	if not reachable.is_empty():
		last_safe_lane = reachable[rng.randi_range(0, reachable.size() - 1)]
	if safe.size() > 0:
		var crystal_lane: int = safe[rng.randi_range(0, safe.size() - 1)]
		if row.contains("C"):
			crystal_lane = row.find("C")
		if rng.randf() < 0.75:
			objects.append({"lane": crystal_lane, "y": -55.0, "kind": "crystal"})

func _pattern_reachable(pattern: Array, initial_lane: int) -> bool:
	var reachable: Array[int] = [initial_lane]
	for row in pattern:
		var next_lanes: Array[int] = []
		for n in range(3):
			if row.substr(n, 1) == "X":
				continue
			for previous in reachable:
				if absi(n - previous) <= 1 and not next_lanes.has(n):
					next_lanes.append(n)
		if next_lanes.is_empty():
			return false
		reachable = next_lanes
	return true

func _pattern_fits_gap(pattern: Array, initial_lane: int) -> bool:
	# Dynamic programming: retain all physically reachable safe lanes per row.
	var reachable: Array[int] = [initial_lane]
	var max_steps: int = maxi(0, int(floor((ROW_GAP / maxf(speed, 1.0)) * MOVE_SPEED / 130.0)))
	for row in pattern:
		var next_lanes: Array[int] = []
		for candidate in range(3):
			if row.substr(candidate, 1) == "X":
				continue
			for previous in reachable:
				if absi(candidate - previous) <= max_steps and not next_lanes.has(candidate):
					next_lanes.append(candidate)
		if next_lanes.is_empty():
			return false
		reachable = next_lanes
	return true

func _end_game() -> void:
	running = false
	game_over = true
	combo = 0
	_burst(Vector2(player_x, PLAYER_Y), PINK, 25)
	_tone(150.0, 0.18)
	if score > best:
		best = score
		_save_best()
	_save_profile()
	_show_menu("GAME OVER", "SCORE %d   BEST %d\nRUN CRYSTALS %d  BANK %d" % [score, best, crystals, wallet], "PLAY AGAIN")
	# Prevent a death-time tap from instantly triggering a restart.
	retry_lock = 0.65
	play_button.disabled = true

func _refresh_hud() -> void:
	var value := "SCORE %d    BEST %d\nGEMS %d    BANK %d    COMBO x%d\nSHIELD %d    MAGNET %.0fs" % [score, best, crystals, wallet, mini(combo, 5), shield_charges, magnet_time]
	if hud != null and value != last_hud:
		hud.text = value
		last_hud = value

func _toggle_pause() -> void:
	if paused:
		_resume()
	elif running:
		_pause()

func _pause() -> void:
	if not running:
		return
	paused = true
	_show_menu("PAUSED", "TAKE YOUR TIME", "RESUME")

func _resume() -> void:
	paused = false
	overlay.visible = false
	pause_button.visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if running and not paused:
			_pause()

func _unhandled_input(event: InputEvent) -> void:
	if not running or paused:
		return
	if event.is_action_pressed("move_left"):
		_step(-1)
	elif event.is_action_pressed("move_right"):
		_step(1)
	elif event is InputEventScreenTouch and event.pressed:
		_step(-1 if event.position.x < WIDTH * 0.5 else 1)
	elif event is InputEventMouseButton and event.pressed and not DisplayServer.is_touchscreen_available():
		_step(-1 if event.position.x < WIDTH * 0.5 else 1)

func _step(direction: int) -> void:
	var old_lane := lane
	lane = clampi(lane + direction, 0, 2)
	if old_lane != lane:
		_burst(Vector2(player_x, PLAYER_Y), CYAN, 4)
		_tone(320.0, 0.03)

func _spawn_powerup() -> void:
	# Spawn only in a lane with no newly spawned obstacle; pickups are optional.
	var free_lanes: Array[int] = [0, 1, 2]
	for obj in objects:
		if absf(float(obj["y"]) + 55.0) < ROW_GAP * 0.6 and obj["kind"] == "block":
			free_lanes.erase(int(obj["lane"]))
	if free_lanes.is_empty():
		return
	var target: int = free_lanes[rng.randi_range(0, free_lanes.size() - 1)]
	objects.append({"lane": target, "y": -55.0, "kind": "shield" if rng.randf() < 0.5 else "magnet"})

func _setup_audio() -> void:
	sound_player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.3
	sound_player.stream = generator
	sound_player.volume_db = -12.0
	add_child(sound_player)
	sound_player.play()
	sound_stream = sound_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _tone(frequency: float, duration: float) -> void:
	if sound_stream == null:
		return
	var count := mini(int(duration * 22050.0), sound_stream.get_frames_available())
	for i in range(count):
		var t := float(i) / 22050.0
		var envelope := 1.0 - float(i) / float(maxi(count, 1))
		var value := sin(TAU * frequency * t) * envelope * 0.16
		sound_stream.push_frame(Vector2(value, value))

func _burst(origin: Vector2, tint: Color, count: int) -> void:
	for i in range(count):
		if sparks.size() >= 80:
			sparks.pop_front()
		var angle := rng.randf_range(0.0, TAU)
		sparks.append({"position": origin, "velocity": Vector2(cos(angle), sin(angle)) * rng.randf_range(65.0, 180.0), "life": 0.4, "color": tint})

func _feedback(message: String) -> void:
	feedback = message
	feedback_timer = 0.8

func _animate_fx(delta: float) -> void:
	var dt := minf(delta, 0.05)
	feedback_timer = maxf(0.0, feedback_timer - dt)
	for i in range(sparks.size() - 1, -1, -1):
		var fx: Dictionary = sparks[i]
		fx["life"] = float(fx["life"]) - dt
		if float(fx["life"]) <= 0.0:
			sparks.remove_at(i)
		else:
			fx["position"] = Vector2(fx["position"]) + Vector2(fx["velocity"]) * dt
			sparks[i] = fx
	for i in range(trails.size() - 1, -1, -1):
		var fx: Dictionary = trails[i]
		fx["life"] = float(fx["life"]) - dt
		if float(fx["life"]) <= 0.0:
			trails.remove_at(i)
		else:
			trails[i] = fx
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), BG)
	for x in LANES:
		draw_line(Vector2(x, 115), Vector2(x, HEIGHT), Color(0.0, 0.7, 1.0, 0.13), 10.0)
		draw_line(Vector2(x, 115), Vector2(x, HEIGHT), Color("286c9e"), 2.0)
	var offset := fmod(elapsed * speed * 0.2, 85.0)
	for y in range(135, 950, 85):
		var yy := float(y) + offset
		if yy < HEIGHT:
			draw_line(Vector2(50, yy), Vector2(430, yy), Color("193357"), 1.0)
	for fx in trails:
		var alpha := float(fx["life"]) / 0.22
		draw_circle(Vector2(fx["position"]), 19.0 * alpha, Color(0.1, 0.9, 1.0, alpha * 0.24))
	draw_circle(Vector2(player_x, PLAYER_Y), 40.0 + sin(pulse * 9.0) * 2.0, Color(0.1, 0.9, 1.0, 0.13))
	draw_circle(Vector2(player_x, PLAYER_Y), 33.0, Color(0.23, 0.92, 1.0, 0.2))
	var orb_color: Color = SKIN_COLORS[selected_skin]
	draw_circle(Vector2(player_x, PLAYER_Y), 21.0, orb_color if invulnerable <= 0.0 else GOLD)
	if shield_charges > 0:
		draw_circle(Vector2(player_x, PLAYER_Y), 48.0, Color(0.1, 0.9, 1.0, 0.09))
		draw_arc(Vector2(player_x, PLAYER_Y), 37.0, 0.0, TAU, 48, CYAN, 5.0)
		draw_arc(Vector2(player_x, PLAYER_Y), 43.0, 0.0, TAU, 48, Color(0.2, 0.9, 1.0, 0.4), 2.0)
	if magnet_time > 0.0:
		var magnet_tint := Color("ba7aff")
		draw_arc(Vector2(player_x, PLAYER_Y), 53.0, -PI * 0.8 + pulse * 1.6, PI * 0.8 + pulse * 1.6, 36, magnet_tint, 4.0)
		draw_arc(Vector2(player_x, PLAYER_Y), 59.0, PI * 0.2 - pulse * 1.6, PI * 1.4 - pulse * 1.6, 36, Color(0.73, 0.48, 1.0, 0.6), 3.0)
	draw_circle(Vector2(player_x - 7, PLAYER_Y - 8), 6.0, Color.WHITE)
	for obj in objects:
		var p := Vector2(LANES[int(obj["lane"])], float(obj["y"]))
		if obj["kind"] == "shield" or obj["kind"] == "magnet":
			var tint: Color = CYAN if obj["kind"] == "shield" else Color("ad70ff")
			draw_circle(p, 23.0, Color(tint.r, tint.g, tint.b, 0.18))
			draw_arc(p, 17.0, 0.0, TAU, 24, tint, 4.0)
			draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), tint, 3.0)
		elif obj["kind"] == "block":
			draw_rect(Rect2(p - Vector2(40, 33), Vector2(80, 66)), Color(1.0, 0.1, 0.5, 0.13))
			draw_rect(Rect2(p - Vector2(33, 26), Vector2(66, 52)), PINK)
			draw_rect(Rect2(p - Vector2(23, 17), Vector2(46, 34)), Color("831d51"))
		else:
			draw_circle(p, 29.0, Color(1.0, 0.85, 0.25, 0.12))
			var scale := 1.0 + 0.08 * sin(pulse * 8.0 + p.y * 0.03)
			var diamond := PackedVector2Array([p + Vector2(0, -23) * scale, p + Vector2(18, 0) * scale, p + Vector2(0, 23) * scale, p + Vector2(-18, 0) * scale])
			draw_colored_polygon(diamond, GOLD)
	for fx in sparks:
		var alpha := float(fx["life"]) / 0.4
		var tint: Color = fx["color"]
		tint.a = alpha
		draw_circle(Vector2(fx["position"]), 3.0 + 2.0 * alpha, tint)
	if feedback_timer > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(100, PLAYER_Y - 80.0 - (0.8 - feedback_timer) * 30.0), feedback, HORIZONTAL_ALIGNMENT_CENTER, 280, 23, GOLD)

func _check_daily_reset() -> void:
	var today := Time.get_date_string_from_system(false)
	if mission_day != today:
		mission_day = today
		mission_progress = [0, 0, 0]
		mission_claimed = [false, false, false]
		_save_profile()

func _advance_mission(index: int, amount: int) -> void:
	_check_daily_reset()
	if mission_claimed[index]:
		return
	mission_progress[index] = mini(MISSION_TARGETS[index], mission_progress[index] + amount)
	if mission_progress[index] >= MISSION_TARGETS[index]:
		mission_claimed[index] = true
		wallet += MISSION_REWARDS[index]
		_feedback("DAILY MISSION +%d GEMS" % MISSION_REWARDS[index])
		_save_profile()

func _mission_summary() -> String:
	_check_daily_reset()
	return "DAILY MISSIONS  •  AUTO REWARDS\nGEMS  %d/%d   •   SURVIVE  %ds/%ds\nNEAR MISSES  %d/%d" % [mission_progress[0], MISSION_TARGETS[0], mission_progress[1], MISSION_TARGETS[1], mission_progress[2], MISSION_TARGETS[2]]

func _open_shop() -> void:
	if running or paused:
		return
	menu_mode = "shop"
	shop_index = selected_skin
	shop_button.visible = false
	next_skin_button.visible = true
	mission_label.text = ""
	skin_preview.visible = true
	_update_shop()

func _next_skin() -> void:
	shop_index = (shop_index + 1) % SKIN_NAMES.size()
	_update_shop()

func _update_shop() -> void:
	var owned := owned_skins.has(shop_index)
	title_label.text = "NEON SHOP"
	subtitle_label.text = "%s ORB\nBANK: %d GEMS\n%s" % [SKIN_NAMES[shop_index], wallet, "OWNED" if owned else "COST: %d GEMS" % SKIN_COSTS[shop_index]]
	skin_preview.add_theme_color_override("font_color", SKIN_COLORS[shop_index])
	play_button.text = "EQUIP" if owned else "BUY"

func _shop_action() -> void:
	if owned_skins.has(shop_index):
		selected_skin = shop_index
		_save_profile()
		_show_menu("NEON RUSH", "SKIN EQUIPPED: %s" % SKIN_NAMES[selected_skin], "PLAY")
	elif wallet >= SKIN_COSTS[shop_index]:
		wallet -= SKIN_COSTS[shop_index]
		owned_skins.append(shop_index)
		selected_skin = shop_index
		_save_profile()
		_show_menu("NEON RUSH", "UNLOCKED: %s" % SKIN_NAMES[selected_skin], "PLAY")
	else:
		subtitle_label.text = "NOT ENOUGH GEMS\nBANK: %d / COST: %d" % [wallet, SKIN_COSTS[shop_index]]

func _save_profile() -> void:
	var profile := {"version": 1, "best": best, "wallet": wallet, "owned": owned_skins, "selected": selected_skin, "day": mission_day, "progress": mission_progress, "claimed": mission_claimed}
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile))

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		_check_daily_reset()
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var profile: Dictionary = parsed
	best = maxi(best, int(profile.get("best", 0)))
	wallet = maxi(0, int(profile.get("wallet", 0)))
	owned_skins = [0]
	for item in profile.get("owned", []):
		var index := int(item)
		if index >= 0 and index < SKIN_NAMES.size() and not owned_skins.has(index):
			owned_skins.append(index)
	selected_skin = int(profile.get("selected", 0))
	if not owned_skins.has(selected_skin):
		selected_skin = 0
	mission_day = str(profile.get("day", ""))
	var progress: Array = profile.get("progress", [])
	var claimed: Array = profile.get("claimed", [])
	for i in range(3):
		if i < progress.size():
			mission_progress[i] = clampi(int(progress[i]), 0, MISSION_TARGETS[i])
		if i < claimed.size():
			mission_claimed[i] = bool(claimed[i])
	_check_daily_reset()

func _save_best() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(best)

func _load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			best = int(file.get_32())

func grant_rewarded_continue() -> void:
	# Future integration: ONLY call after verified reward_earned signal.
	if not game_over or continued:
		return
	continued = true
	game_over = false
	running = true
	paused = false
	lane = 1
	player_x = LANES[lane]
	last_safe_lane = lane
	objects.clear()
	queued_rows.clear()
	spawn_clock = 1.2
	invulnerable = 2.0
	hint.text = "SECOND CHANCE!"
	overlay.visible = false
	pause_button.visible = true
