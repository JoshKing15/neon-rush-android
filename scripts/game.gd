extends Node2D
## Neon Rush v0.1: asset-free 3-lane survival game.
## This prototype does not request or display real advertisements.

const WIDTH := 480.0
const HEIGHT := 854.0
const PLAYER_Y := 700.0
const LANES := [110.0, 240.0, 370.0]
const SAVE_PATH := "user://neon_rush.save"
const BG := Color("080d22")
const CYAN := Color("38eaff")
const PINK := Color("ff4386")
const GOLD := Color("ffe16b")

var lane := 1
var objects: Array[Dictionary] = []
var spawn_clock := 0.0
var elapsed := 0.0
var score_fraction := 0.0
var score := 0
var best := 0
var crystals := 0
var speed := 270.0
var running := false
var game_over := false
var continued := false
var hud: Label
var hint: Label
var overlay: PanelContainer
var title_label: Label
var subtitle_label: Label
var play_button: Button
var reward_button: Button
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load_best()
	_build_ui()
	_show_menu("NEON RUSH", "MOVE BETWEEN 3 LANES\nDodge pink blocks. Collect gold crystals.", "PLAY")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud = Label.new()
	hud.position = Vector2(20, 22)
	hud.add_theme_font_size_override("font_size", 25)
	hud.add_theme_color_override("font_color", CYAN)
	layer.add_child(hud)

	hint = Label.new()
	hint.position = Vector2(20, 82)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", GOLD)
	hint.text = "TAP OR SWIPE TO CHANGE LANES"
	layer.add_child(hint)

	overlay = PanelContainer.new()
	overlay.position = Vector2(35, 258)
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
	play_button.custom_minimum_size.y = 56.0
	play_button.pressed.connect(start_game)
	stack.add_child(play_button)

	reward_button = Button.new()
	reward_button.text = "REWARDED CONTINUE — COMING SOON"
	reward_button.custom_minimum_size.y = 50.0
	reward_button.disabled = true
	stack.add_child(reward_button)

	_refresh_hud()

func _show_menu(heading: String, message: String, action: String) -> void:
	title_label.text = heading
	subtitle_label.text = message
	play_button.text = action
	reward_button.visible = game_over and not continued
	overlay.visible = true

func start_game() -> void:
	lane = 1
	objects.clear()
	spawn_clock = 0.8
	elapsed = 0.0
	score_fraction = 0.0
	score = 0
	crystals = 0
	speed = 270.0
	running = true
	game_over = false
	continued = false
	hint.text = "TAP OR SWIPE TO CHANGE LANES"
	overlay.visible = false
	_refresh_hud()
	queue_redraw()

func _process(delta: float) -> void:
	if not running:
		return

	elapsed += delta
	score_fraction += delta * 15.0
	var gained := int(floor(score_fraction))
	if gained > 0:
		score += gained
		score_fraction -= float(gained)

	speed = minf(690.0, 270.0 + elapsed * 9.0)
	spawn_clock -= delta
	if spawn_clock <= 0.0:
		_spawn_wave()
		spawn_clock = maxf(0.36, 0.95 - elapsed * 0.012)

	for i in range(objects.size() - 1, -1, -1):
		var obj: Dictionary = objects[i]
		obj["y"] = float(obj["y"]) + speed * delta
		objects[i] = obj
		if absf(float(obj["y"]) - PLAYER_Y) < 35.0 and int(obj["lane"]) == lane:
			if obj["kind"] == "block":
				_end_game()
				break
			else:
				crystals += 1
				score += 50
				objects.remove_at(i)
		elif float(obj["y"]) > HEIGHT + 70.0:
			objects.remove_at(i)

	_refresh_hud()
	queue_redraw()

func _spawn_wave() -> void:
	# One obstacle per wave guarantees two safe lanes.
	var blocked := rng.randi_range(0, 2)
	objects.append({"lane": blocked, "y": -50.0, "kind": "block"})
	if rng.randf() < 0.7:
		var crystal_lane := (blocked + rng.randi_range(1, 2)) % 3
		objects.append({"lane": crystal_lane, "y": -50.0, "kind": "crystal"})

func _end_game() -> void:
	running = false
	game_over = true
	if score > best:
		best = score
		_save_best()
	_show_menu("GAME OVER", "SCORE %d   BEST %d\nCRYSTALS %d" % [score, best, crystals], "PLAY AGAIN")

func _refresh_hud() -> void:
	if hud != null:
		hud.text = "SCORE %d     BEST %d\nCRYSTALS %d" % [score, best, crystals]

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("move_left"):
		lane = maxi(0, lane - 1)
	elif event.is_action_pressed("move_right"):
		lane = mini(2, lane + 1)
	elif event is InputEventScreenTouch and event.pressed:
		lane = clampi(int(event.position.x / (WIDTH / 3.0)), 0, 2)
	elif event is InputEventScreenDrag:
		lane = clampi(int(event.position.x / (WIDTH / 3.0)), 0, 2)
	elif event is InputEventMouseButton and event.pressed:
		lane = clampi(int(event.position.x / (WIDTH / 3.0)), 0, 2)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), BG)
	for x in LANES:
		draw_line(Vector2(x, 115), Vector2(x, HEIGHT), Color("212b59"), 3.0)
	for y in range(135, 854, 85):
		draw_line(Vector2(50, y), Vector2(430, y), Color("182146"), 1.0)

	var px: float = LANES[lane]
	draw_circle(Vector2(px, PLAYER_Y), 33.0, Color(0.23, 0.92, 1.0, 0.2))
	draw_circle(Vector2(px, PLAYER_Y), 21.0, CYAN)
	draw_circle(Vector2(px - 7, PLAYER_Y - 8), 6.0, Color.WHITE)

	for obj in objects:
		var p := Vector2(LANES[int(obj["lane"])], float(obj["y"]))
		if obj["kind"] == "block":
			draw_rect(Rect2(p - Vector2(33, 26), Vector2(66, 52)), PINK)
			draw_rect(Rect2(p - Vector2(23, 17), Vector2(46, 34)), Color("831d51"))
		else:
			var diamond := PackedVector2Array([
				p + Vector2(0, -23),
				p + Vector2(18, 0),
				p + Vector2(0, 23),
				p + Vector2(-18, 0)
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
	# Reserved for a future Android plugin's VERIFIED earned-reward callback.
	# Never call this because an ad opened or closed without a reward.
	if not game_over or continued:
		return
	continued = true
	game_over = false
	running = true
	objects.clear()
	spawn_clock = 1.2
	hint.text = "SECOND CHANCE!"
	overlay.visible = false
