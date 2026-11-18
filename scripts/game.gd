extends Node2D
## Neon Rush v0.2 — safer collisions, responsive movement, pattern tiers, combos.
## Ads are intentionally NOT integrated in this prototype.

const WIDTH := 480.0
const HEIGHT := 854.0
const PLAYER_Y := 700.0
const LANES := [110.0, 240.0, 370.0]
const SAVE_PATH := "user://neon_rush.save"
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
	_build_ui()
	_show_menu("NEON RUSH", "TAP LEFT OR RIGHT TO STEP ONE LANE\nDodge blocks. Chain crystals and near-misses.", "PLAY")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 25)
	hud.add_theme_font_size_override("font_size", 23)
	hud.add_theme_color_override("font_color", CYAN)
	layer.add_child(hud)

	hint = Label.new()
	hint.position = Vector2(20, 95)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", GOLD)
	layer.add_child(hint)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.position = Vector2(405, 20)
	pause_button.custom_minimum_size = Vector2(55, 55)
	pause_button.pressed.connect(_toggle_pause)
	pause_button.visible = false
	layer.add_child(pause_button)

	overlay = PanelContainer.new()
	overlay.position = Vector2(35, 245)
	overlay.custom_minimum_size = Vector2(410, 290)
	layer.add_child(overlay)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	overlay.add_child(stack)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", CYAN)
	stack.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 17)
	stack.add_child(subtitle_label)
	play_button = Button.new()
	play_button.custom_minimum_size.y = 56
	play_button.pressed.connect(_primary_action)
	stack.add_child(play_button)
	reward_button = Button.new()
	reward_button.text = "REWARDED CONTINUE — NOT ENABLED"
	reward_button.disabled = true
	reward_button.visible = false
	stack.add_child(reward_button)
	_refresh_hud()

func _show_menu(heading: String, message: String, action: String) -> void:
	title_label.text = heading
	subtitle_label.text = message
	play_button.text = action
	overlay.visible = true
	pause_button.visible = false
	reward_button.visible = false

func _primary_action() -> void:
	if retry_lock > 0.0:
		return
	if paused:
		_resume()
	else:
		start_game()

func start_game() -> void:
	lane = 1
	player_x = LANES[lane]
	last_safe_lane = 1
	objects.clear()
	queued_rows.clear()
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

	# Cap simulation delta to avoid collision tunnelling and huge resume jumps.
	var dt := minf(delta, 0.05)
	elapsed += dt
	invulnerable = maxf(0.0, invulnerable - dt)
	player_x = move_toward(player_x, LANES[lane], MOVE_SPEED * dt)
	score_fraction += dt * (15.0 + float(mini(combo, 10)))
	var gained := int(floor(score_fraction))
	if gained > 0:
		score += gained
		score_fraction -= float(gained)

	# Speed rises with time; later tiers introduce more difficult patterns.
	speed = minf(680.0, 270.0 + elapsed * 7.0)
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
			objects[i] = obj
			_end_game()
			break
		if crosses and obj["kind"] == "crystal" and dx <= HIT_X:
			crystals += 1
			combo += 1
			score += 50 * mini(combo, 5)
			hint.text = "CRYSTAL COMBO x%d" % mini(combo, 5)
			objects.remove_at(i)
			continue
		if previous_y <= PLAYER_Y and next_y > PLAYER_Y and obj["kind"] == "block" and not bool(obj.get("near", false)):
			if dx > HIT_X and dx <= NEAR_X:
				obj["near"] = true
				combo += 1
				score += 25 * mini(combo, 5)
				hint.text = "NEAR MISS! COMBO x%d" % mini(combo, 5)
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
			if _pattern_reachable(pattern, last_safe_lane):
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

func _end_game() -> void:
	running = false
	game_over = true
	combo = 0
	if score > best:
		best = score
		_save_best()
	_show_menu("GAME OVER", "SCORE %d   BEST %d\nCRYSTALS %d" % [score, best, crystals], "PLAY AGAIN")
	# Prevent a death-time tap from instantly triggering a restart.
	retry_lock = 0.65
	play_button.disabled = true

func _refresh_hud() -> void:
	var value := "SCORE %d   BEST %d\nCRYSTALS %d   COMBO x%d" % [score, best, crystals, mini(combo, 5)]
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
	lane = clampi(lane + direction, 0, 2)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), BG)
	for x in LANES:
		draw_line(Vector2(x, 115), Vector2(x, HEIGHT), Color("212b59"), 3.0)
	for y in range(135, 854, 85):
		draw_line(Vector2(50, y), Vector2(430, y), Color("182146"), 1.0)
	draw_circle(Vector2(player_x, PLAYER_Y), 33.0, Color(0.23, 0.92, 1.0, 0.2))
	draw_circle(Vector2(player_x, PLAYER_Y), 21.0, CYAN if invulnerable <= 0.0 else GOLD)
	draw_circle(Vector2(player_x - 7, PLAYER_Y - 8), 6.0, Color.WHITE)
	for obj in objects:
		var p := Vector2(LANES[int(obj["lane"])], float(obj["y"]))
		if obj["kind"] == "block":
			draw_rect(Rect2(p - Vector2(33, 26), Vector2(66, 52)), PINK)
			draw_rect(Rect2(p - Vector2(23, 17), Vector2(46, 34)), Color("831d51"))
		else:
			var diamond := PackedVector2Array([
				p + Vector2(0, -23), p + Vector2(18, 0),
				p + Vector2(0, 23), p + Vector2(-18, 0)
			])
			draw_colored_polygon(diamond, GOLD)

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
