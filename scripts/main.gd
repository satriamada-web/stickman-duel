extends Node2D

const FLOOR_Y := 570.0
const PLAYER_SPEED := 360.0
const MATCH_LENGTH := 90.0

var player_x := 300.0
var enemy_x := 960.0
var player_hp := 100
var enemy_hp := 100
var time_left := MATCH_LENGTH
var attack_cooldown := 0.0
var enemy_attack_cooldown := 0.0
var move_direction := 0
var match_over := false

var status_label: Label
var player_hp_label: Label
var enemy_hp_label: Label
var timer_label: Label

func _ready() -> void:
	_build_ui()
	queue_redraw()

func _process(delta: float) -> void:
	if match_over:
		return
	time_left = maxf(0.0, time_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
	player_x = clampf(player_x + move_direction * PLAYER_SPEED * delta, 70.0, 1210.0)

	var distance := absf(enemy_x - player_x)
	if distance > 115.0:
		enemy_x = move_toward(enemy_x, player_x, 150.0 * delta)
	elif enemy_attack_cooldown <= 0.0:
		player_hp = maxi(0, player_hp - 8)
		enemy_attack_cooldown = 1.4

	if time_left <= 0.0 or player_hp <= 0 or enemy_hp <= 0:
		_finish_match()
	_update_ui()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#172033"))
	draw_rect(Rect2(0, FLOOR_Y, 1280, 150), Color("#26364b"))
	draw_line(Vector2(0, FLOOR_Y), Vector2(1280, FLOOR_Y), Color("#8da3bd"), 4.0)
	for i in range(0, 1280, 80):
		draw_line(Vector2(i, FLOOR_Y + 35), Vector2(i + 35, FLOOR_Y + 35), Color("#40536a"), 2.0)
	_draw_fighter(player_x, FLOOR_Y, Color("#55c7ff"), 1)
	_draw_fighter(enemy_x, FLOOR_Y, Color("#ff687d"), -1)

func _draw_fighter(x: float, floor_y: float, tint: Color, direction: int) -> void:
	var center := Vector2(x, floor_y)
	var head := center + Vector2(0, -112)
	var body_top := center + Vector2(0, -88)
	var body_bottom := center + Vector2(0, -42)
	var arm_end := center + Vector2(38 * direction, -68)
	draw_circle(head, 17, tint)
	draw_line(body_top, body_bottom, tint, 8.0, true)
	draw_line(body_top + Vector2(0, 8), arm_end, tint, 7.0, true)
	draw_line(body_bottom, center + Vector2(-22, 0), tint, 7.0, true)
	draw_line(body_bottom, center + Vector2(25, 0), tint, 7.0, true)
	draw_line(arm_end, arm_end + Vector2(48 * direction, -12), Color("#f5d78e"), 6.0, true)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var title := _make_label(root, "STICKMAN DUEL | TRAINING ARENA", Vector2(30, 18), 26, Color.WHITE)
	player_hp_label = _make_label(root, "PLAYER 1 | HP: 100", Vector2(30, 68), 22, Color("#55c7ff"))
	enemy_hp_label = _make_label(root, "OPPONENT | HP: 100", Vector2(930, 68), 22, Color("#ff687d"))
	timer_label = _make_label(root, "90", Vector2(610, 35), 34, Color.WHITE)
	status_label = _make_label(root, "Kalahkan lawan latihan!", Vector2(470, 105), 20, Color.WHITE)
	_add_button(root, "KIRI", Vector2(35, 590), Vector2(115, 80), func(): move_direction = -1)
	_add_button(root, "KANAN", Vector2(165, 590), Vector2(115, 80), func(): move_direction = 1)
	_add_button(root, "BERHENTI", Vector2(295, 590), Vector2(115, 80), func(): move_direction = 0)
	_add_button(root, "SERANG", Vector2(1080, 575), Vector2(160, 100), _attack)

func _make_label(parent: Control, value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_button(parent: Control, value: String, pos: Vector2, button_size: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)

func _attack() -> void:
	if match_over or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.65
	if absf(enemy_x - player_x) <= 155.0:
		enemy_hp = maxi(0, enemy_hp - 15)
		status_label.text = "SERANGAN MASUK! Lawan kehilangan 15 HP."
	else:
		status_label.text = "Terlalu jauh! Dekati lawan terlebih dahulu."

func _update_ui() -> void:
	player_hp_label.text = "PLAYER 1 | HP: %d" % player_hp
	enemy_hp_label.text = "OPPONENT | HP: %d" % enemy_hp
	timer_label.text = str(ceili(time_left))

func _finish_match() -> void:
	match_over = true
	if player_hp > enemy_hp:
		status_label.text = "KAMU MENANG!"
	elif player_hp < enemy_hp:
		status_label.text = "KAMU KALAH!"
	else:
		status_label.text = "HASIL SERI!"
	move_direction = 0
