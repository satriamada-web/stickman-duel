extends Node2D

const FLOOR_Y := 570.0
const MATCH_LENGTH := 90.0
const CHARACTERS := {
	"Swordman": {"hp": 100, "speed": 360.0, "damage": 15, "color": "#55c7ff", "weapon": "SWORD"},
	"Axeman": {"hp": 110, "speed": 300.0, "damage": 22, "color": "#ffb45c", "weapon": "AXE"},
	"Spearman": {"hp": 90, "speed": 390.0, "damage": 12, "color": "#8ee09b", "weapon": "SPEAR"}
}

var selected_character := "Swordman"
var player_x := 300.0
var enemy_x := 960.0
var player_hp := 100
var enemy_hp := 100
var player_max_hp := 100
var time_left := MATCH_LENGTH
var attack_cooldown := 0.0
var attack_animation_time := 0.0
var animation_time := 0.0
var enemy_attack_cooldown := 0.0
var move_direction := 0
var match_over := false
var game_started := false

var menu_ui: Control
var game_ui: Control
var status_label: Label
var player_hp_label: Label
var enemy_hp_label: Label
var timer_label: Label
var selection_label: Label
var result_button: Button

func _ready() -> void:
	_build_ui()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not game_started or match_over:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			move_direction = -1
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			move_direction = 1
		elif event.keycode == KEY_SPACE:
			_attack()
	elif event is InputEventKey and not event.pressed:
		if event.keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
			move_direction = 0

func _process(delta: float) -> void:
	if not game_started or match_over:
		return
	animation_time += delta
	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	time_left = maxf(0.0, time_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
	var stats: Dictionary = CHARACTERS[selected_character]
	player_x = clampf(player_x + move_direction * float(stats["speed"]) * delta, 70.0, 1210.0)

	var distance := absf(enemy_x - player_x)
	if distance > 125.0:
		enemy_x = move_toward(enemy_x, player_x, 145.0 * delta)
	elif enemy_attack_cooldown <= 0.0:
		player_hp = maxi(0, player_hp - 8)
		enemy_attack_cooldown = 1.35

	if time_left <= 0.0 or player_hp <= 0 or enemy_hp <= 0:
		_finish_match()
	_update_ui()
	queue_redraw()

func _draw() -> void:
	if not game_started:
		return
	draw_rect(Rect2(0, 0, 1280, 720), Color("#172033"))
	draw_rect(Rect2(0, FLOOR_Y, 1280, 150), Color("#26364b"))
	draw_line(Vector2(0, FLOOR_Y), Vector2(1280, FLOOR_Y), Color("#8da3bd"), 4.0)
	for i in range(0, 1280, 80):
		draw_line(Vector2(i, FLOOR_Y + 35), Vector2(i + 35, FLOOR_Y + 35), Color("#40536a"), 2.0)
	var player_stats: Dictionary = CHARACTERS[selected_character]
	_draw_fighter(player_x, FLOOR_Y, Color(player_stats["color"]), 1, str(player_stats["weapon"]), move_direction != 0, attack_animation_time > 0.0)
	_draw_fighter(enemy_x, FLOOR_Y, Color("#ff687d"), -1, "AXE", absf(enemy_x - player_x) > 125.0, false)

func _draw_fighter(x: float, floor_y: float, tint: Color, direction: int, weapon: String, walking: bool, attacking: bool) -> void:
	# Animasi prosedural sederhana: badan naik-turun dan tangan/kaki mengayun.
	var phase := animation_time * (9.0 if walking else 2.2)
	var stride := sin(phase) * 15.0 if walking else 0.0
	var bob := absf(sin(phase * 2.0)) * 4.0 if walking else sin(phase) * 1.5
	var center := Vector2(x, floor_y - bob)
	var head := center + Vector2(0, -112)
	var body_top := center + Vector2(0, -88)
	var body_bottom := center + Vector2(0, -42)
	var front_arm := center + Vector2(38 * direction, -68 + (stride * 0.45 if walking else 0.0))
	var back_arm := center + Vector2(-30 * direction, -65 - (stride * 0.45 if walking else 0.0))
	var front_leg := center + Vector2(25 * direction + stride, 0)
	var back_leg := center + Vector2(-22 * direction - stride, 0)

	if attacking:
		front_arm = center + Vector2(58 * direction, -83)
		back_arm = center + Vector2(-25 * direction, -58)

	draw_circle(head, 17, tint)
	draw_line(body_top, body_bottom, tint, 8.0, true)
	draw_line(body_top + Vector2(0, 8), front_arm, tint, 7.0, true)
	draw_line(body_top + Vector2(0, 8), back_arm, tint, 6.0, true)
	draw_line(body_bottom, front_leg, tint, 7.0, true)
	draw_line(body_bottom, back_leg, tint, 7.0, true)

	var weapon_tip := front_arm + Vector2(48 * direction, -12)
	if weapon == "SPEAR":
		weapon_tip = front_arm + Vector2(78 * direction, -5)
		draw_line(front_arm, weapon_tip, Color("#f5d78e"), 5.0, true)
	elif weapon == "AXE":
		weapon_tip = front_arm + Vector2(36 * direction, -12)
		draw_line(front_arm, weapon_tip, Color("#b8c3d1"), 7.0, true)
		draw_line(weapon_tip + Vector2(-4 * direction, 0), weapon_tip + Vector2(7 * direction, -17), Color("#b8c3d1"), 11.0, true)
	else:
		draw_line(front_arm, weapon_tip, Color("#f5d78e"), 6.0, true)

	if attacking:
		draw_arc(center + Vector2(35 * direction, -78), 52.0, -0.9, 0.9, 18, Color("#fff0a6"), 5.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	menu_ui = Control.new()
	menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu_ui)
	_make_label(menu_ui, "STICKMAN DUEL", Vector2(430, 90), 48, Color.WHITE)
	_make_label(menu_ui, "PILIH PETARUNGMU", Vector2(505, 180), 25, Color("#c8d7e8"))
	selection_label = _make_label(menu_ui, "Dipilih: Swordman", Vector2(520, 490), 22, Color("#55c7ff"))

	_add_button(menu_ui, "SWORDMAN\nSeimbang | 100 HP", Vector2(170, 285), Vector2(280, 145), func(): _select_character("Swordman"))
	_add_button(menu_ui, "AXEMAN\nDamage tinggi | 110 HP", Vector2(500, 285), Vector2(280, 145), func(): _select_character("Axeman"))
	_add_button(menu_ui, "SPEARMAN\nJangkauan | 90 HP", Vector2(830, 285), Vector2(280, 145), func(): _select_character("Spearman"))
	_add_button(menu_ui, "MULAI BERTARUNG", Vector2(490, 550), Vector2(300, 80), _start_match)

	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.visible = false
	root.add_child(game_ui)
	_make_label(game_ui, "STICKMAN DUEL | TRAINING ARENA", Vector2(30, 18), 26, Color.WHITE)
	player_hp_label = _make_label(game_ui, "PLAYER 1 | HP: 100", Vector2(30, 68), 22, Color("#55c7ff"))
	enemy_hp_label = _make_label(game_ui, "OPPONENT | HP: 100", Vector2(930, 68), 22, Color("#ff687d"))
	timer_label = _make_label(game_ui, "90", Vector2(610, 35), 34, Color.WHITE)
	status_label = _make_label(game_ui, "Kalahkan lawan latihan!", Vector2(470, 105), 20, Color.WHITE)
	_add_move_button(game_ui, "KIRI", Vector2(35, 590), Vector2(115, 80), -1)
	_add_move_button(game_ui, "KANAN", Vector2(165, 590), Vector2(115, 80), 1)
	_add_button(game_ui, "BERHENTI", Vector2(295, 590), Vector2(115, 80), func(): move_direction = 0)
	_add_button(game_ui, "SERANG", Vector2(1080, 575), Vector2(160, 100), _attack)
	result_button = _add_button(game_ui, "KEMBALI KE MENU", Vector2(510, 470), Vector2(260, 70), _return_to_menu)
	result_button.visible = false

func _select_character(character_name: String) -> void:
	selected_character = character_name
	var stats: Dictionary = CHARACTERS[selected_character]
	selection_label.text = "Dipilih: %s | %d HP | %d damage" % [selected_character, stats["hp"], stats["damage"]]
	selection_label.add_theme_color_override("font_color", Color(stats["color"]))

func _start_match() -> void:
	var stats: Dictionary = CHARACTERS[selected_character]
	player_max_hp = int(stats["hp"])
	player_hp = player_max_hp
	enemy_hp = 100
	player_x = 300.0
	enemy_x = 960.0
	time_left = MATCH_LENGTH
	attack_cooldown = 0.0
	enemy_attack_cooldown = 0.0
	move_direction = 0
	match_over = false
	game_started = true
	menu_ui.visible = false
	game_ui.visible = true
	result_button.visible = false
	status_label.text = "Lawan latihan: Axeman"
	_update_ui()
	queue_redraw()

func _return_to_menu() -> void:
	game_started = false
	match_over = false
	menu_ui.visible = true
	game_ui.visible = false
	queue_redraw()

func _add_move_button(parent: Control, value: String, pos: Vector2, button_size: Vector2, direction: int) -> void:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.button_down.connect(func(): move_direction = direction)
	button.button_up.connect(func(): move_direction = 0)
	parent.add_child(button)

func _make_label(parent: Control, value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_button(parent: Control, value: String, pos: Vector2, button_size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _attack() -> void:
	if not game_started or match_over or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.65
	attack_animation_time = 0.22
	var stats: Dictionary = CHARACTERS[selected_character]
	var attack_range := 190.0 if selected_character == "Spearman" else 155.0
	if absf(enemy_x - player_x) <= attack_range:
		enemy_hp = maxi(0, enemy_hp - int(stats["damage"]))
		status_label.text = "SERANGAN %s! Lawan kehilangan %d HP." % [selected_character.to_upper(), stats["damage"]]
	else:
		status_label.text = "Terlalu jauh! Dekati lawan terlebih dahulu."

func _update_ui() -> void:
	player_hp_label.text = "%s | HP: %d/%d" % [selected_character.to_upper(), player_hp, player_max_hp]
	enemy_hp_label.text = "OPPONENT | HP: %d" % enemy_hp
	timer_label.text = str(ceili(time_left))

func _finish_match() -> void:
	match_over = true
	move_direction = 0
	if player_hp > enemy_hp:
		status_label.text = "KAMU MENANG!"
	elif player_hp < enemy_hp:
		status_label.text = "KAMU KALAH!"
	else:
		status_label.text = "HASIL SERI!"
	result_button.visible = true
