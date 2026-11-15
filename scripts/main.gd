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
var skill_cooldown := 0.0
var skill_animation_time := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var jump_height := 0.0
var jump_velocity := 0.0
var player_facing := 1
var attack_animation_time := 0.0
var enemy_attack_animation_time := 0.0
var animation_time := 0.0
var player_hit_flash := 0.0
var enemy_hit_flash := 0.0
var impact_effect_time := 0.0
var impact_effect_x := 0.0
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
var skill_button: Button
var dash_button: Button
var jump_button: Button
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar

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
		elif event.keycode == KEY_W or event.keycode == KEY_UP:
			_jump()
	elif event is InputEventKey and not event.pressed:
		if event.keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
			move_direction = 0

func _process(delta: float) -> void:
	if not game_started or match_over:
		return
	animation_time += delta
	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	enemy_attack_animation_time = maxf(0.0, enemy_attack_animation_time - delta)
	player_hit_flash = maxf(0.0, player_hit_flash - delta)
	enemy_hit_flash = maxf(0.0, enemy_hit_flash - delta)
	impact_effect_time = maxf(0.0, impact_effect_time - delta)
	time_left = maxf(0.0, time_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	skill_animation_time = maxf(0.0, skill_animation_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if jump_height > 0.0 or jump_velocity > 0.0:
		jump_height += jump_velocity * delta
		jump_velocity -= 1500.0 * delta
		if jump_height <= 0.0:
			jump_height = 0.0
			jump_velocity = 0.0
	enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
	var stats: Dictionary = CHARACTERS[selected_character]
	if move_direction != 0:
		player_facing = move_direction
	var current_speed := float(stats["speed"])
	if dash_time > 0.0:
		current_speed = 900.0
		player_x = clampf(player_x + player_facing * current_speed * delta, 70.0, 1210.0)
	else:
		player_x = clampf(player_x + move_direction * current_speed * delta, 70.0, 1210.0)

	var distance := absf(enemy_x - player_x)
	if distance > 125.0:
		enemy_x = move_toward(enemy_x, player_x, 145.0 * delta)
	elif enemy_attack_cooldown <= 0.0:
		enemy_attack_animation_time = 0.24
		enemy_attack_cooldown = 1.35
		if dash_time <= 0.0 and jump_height < 45.0:
			player_hp = maxi(0, player_hp - 8)
			player_hit_flash = 0.22
			impact_effect_time = 0.24
			impact_effect_x = player_x
		else:
			status_label.text = "BERHASIL MENGHINDAR!"

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
	var player_tint := Color("#ffffff") if player_hit_flash > 0.0 else Color(player_stats["color"])
	var enemy_tint := Color("#ffffff") if enemy_hit_flash > 0.0 else Color("#ff687d")
	if dash_time > 0.0:
		var trail_color := Color(player_stats["color"])
		trail_color.a = clampf(dash_time / 0.18, 0.0, 0.75)
		for trail_index in range(1, 5):
			var trail_offset := float(trail_index) * 17.0 * float(player_facing)
			draw_line(Vector2(player_x - trail_offset, FLOOR_Y - 75.0), Vector2(player_x - trail_offset - 24.0 * float(player_facing), FLOOR_Y - 75.0), trail_color, 5.0 - float(trail_index) * 0.7, true)
	draw_circle(Vector2(player_x, FLOOR_Y - 3.0), 23.0 - minf(jump_height * 0.035, 12.0), Color(0.02, 0.04, 0.08, 0.28))
	_draw_fighter(player_x, FLOOR_Y - jump_height, player_tint, player_facing, str(player_stats["weapon"]), move_direction != 0 or dash_time > 0.0, maxf(attack_animation_time, skill_animation_time), 0.42 if skill_animation_time > attack_animation_time else 0.22, dash_time > 0.0)
	_draw_fighter(enemy_x, FLOOR_Y, enemy_tint, -1, "AXE", absf(enemy_x - player_x) > 125.0, enemy_attack_animation_time, 0.24, false)
	if impact_effect_time > 0.0:
		var impact_y := FLOOR_Y - 78.0
		var impact_progress := 1.0 - impact_effect_time / 0.24
		var burst_radius := 12.0 + impact_progress * 25.0
		var burst_alpha := clampf(impact_effect_time / 0.24, 0.0, 1.0)
		var burst_color := Color(1.0, 0.88, 0.48, burst_alpha)
		draw_arc(Vector2(impact_effect_x, impact_y), burst_radius, 0.0, TAU, 20, burst_color, 3.0)
		for ray in range(8):
			var angle := TAU * float(ray) / 8.0
			var ray_start := Vector2(cos(angle), sin(angle)) * (burst_radius + 3.0)
			var ray_end := Vector2(cos(angle), sin(angle)) * (burst_radius + 12.0)
			draw_line(Vector2(impact_effect_x, impact_y) + ray_start, Vector2(impact_effect_x, impact_y) + ray_end, burst_color, 3.0)

func _draw_fighter(x: float, floor_y: float, tint: Color, direction: int, weapon: String, walking: bool, attack_time: float, attack_duration: float, dashing: bool) -> void:
	# Animasi prosedural dengan fase ancang-ancang, ayunan, dan pemulihan.
	var phase := animation_time * (13.0 if walking else 2.2)
	var stride := sin(phase) if walking else 0.0
	var idle_breath := sin(animation_time * 2.4)
	var bob := absf(sin(phase * 2.0)) * 5.0 if walking else idle_breath * 1.8
	var lean := 0.0
	if dashing:
		lean = -float(direction) * 13.0
	elif attack_time > 0.0:
		var attack_progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		# Sedikit mundur saat persiapan, condong ke depan saat ayunan.
		lean = float(direction) * (sin(attack_progress * PI) * 12.0 - 5.0 * (1.0 - attack_progress))
	var center := Vector2(x, floor_y - bob)
	var head := center + Vector2(lean * 0.45, -112)
	var shoulder := center + Vector2(lean, -86)
	var hip := center + Vector2(lean * 0.35, -43)

	# Kaki bergantian melangkah; saat diam, lutut tetap sedikit menekuk.
	var leg_swing := stride * 23.0
	var front_knee := hip + Vector2(14.0 * direction + leg_swing, 25.0 + absf(stride) * 4.0)
	var back_knee := hip + Vector2(-12.0 * direction - leg_swing, 25.0 + absf(stride) * 4.0)
	var front_foot := front_knee + Vector2(13.0 * direction + leg_swing * 0.7, 21.0 - absf(stride) * 9.0)
	var back_foot := back_knee + Vector2(-10.0 * direction - leg_swing * 0.7, 21.0 - absf(stride) * 9.0)

	var front_elbow := shoulder + Vector2(18.0 * direction - stride * 9.0, 17.0)
	var front_hand := front_elbow + Vector2(13.0 * direction - stride * 7.0, 13.0)
	var back_elbow := shoulder + Vector2(-18.0 * direction + stride * 9.0, 15.0)
	var back_hand := back_elbow + Vector2(-13.0 * direction + stride * 7.0, 14.0)

	if attack_time > 0.0:
		var progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		var windup := 1.0 - clampf(progress / 0.28, 0.0, 1.0)
		var strike := sin(clampf((progress - 0.18) / 0.58, 0.0, 1.0) * PI)
		var reach := 58.0 * strike
		front_elbow = shoulder + Vector2((23.0 - 15.0 * windup + reach * 0.35) * direction, -7.0 - 7.0 * strike)
		front_hand = shoulder + Vector2((37.0 - 22.0 * windup + reach) * direction, -13.0 - 12.0 * strike)
		back_elbow = shoulder + Vector2(-22.0 * direction, 19.0)
		back_hand = back_elbow + Vector2(-14.0 * direction, 9.0)
		front_knee += Vector2(-5.0 * direction * windup, 0.0)
		front_foot += Vector2(-7.0 * direction * windup, 0.0)

	draw_line(hip, back_knee, tint, 7.0, true)
	draw_line(back_knee, back_foot, tint, 7.0, true)
	draw_line(shoulder, back_elbow, tint, 6.0, true)
	draw_line(back_elbow, back_hand, tint, 6.0, true)
	draw_line(hip, front_knee, tint, 7.0, true)
	draw_line(front_knee, front_foot, tint, 7.0, true)
	draw_line(shoulder, hip, tint, 8.0, true)
	draw_circle(head, 17.0, tint)
	draw_line(shoulder, front_elbow, tint, 7.0, true)
	draw_line(front_elbow, front_hand, tint, 7.0, true)
	draw_circle(front_elbow, 3.5, tint)
	draw_circle(front_hand, 4.0, tint)

	# Senjata mengikuti tangan sepanjang animasi.
	var weapon_tip := front_hand + Vector2(48.0 * direction, -12.0)
	if weapon == "SPEAR":
		weapon_tip = front_hand + Vector2(78.0 * direction, -5.0)
		draw_line(front_hand, weapon_tip, Color("#f5d78e"), 5.0, true)
		draw_line(weapon_tip, weapon_tip + Vector2(12.0 * direction, -2.0), Color("#dce7f2"), 3.0, true)
	elif weapon == "AXE":
		weapon_tip = front_hand + Vector2(36.0 * direction, -12.0)
		draw_line(front_hand, weapon_tip, Color("#b8c3d1"), 7.0, true)
		draw_line(weapon_tip + Vector2(-4.0 * direction, 0), weapon_tip + Vector2(7.0 * direction, -17.0), Color("#b8c3d1"), 11.0, true)
	else:
		draw_line(front_hand, weapon_tip, Color("#f5d78e"), 6.0, true)
		draw_line(weapon_tip, weapon_tip + Vector2(8.0 * direction, -2.0), Color("#dce7f2"), 3.0, true)

	if attack_time > 0.0:
		var progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		var slash_alpha := sin(progress * PI)
		if slash_alpha > 0.05:
			draw_arc(center + Vector2(37.0 * direction, -79.0), 49.0 + slash_alpha * 10.0, -0.95, 0.95, 20, Color(1.0, 0.9, 0.58, slash_alpha), 4.0)

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
	player_hp_bar = ProgressBar.new()
	player_hp_bar.position = Vector2(30, 100)
	player_hp_bar.size = Vector2(330, 22)
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = 100
	player_hp_bar.show_percentage = false
	game_ui.add_child(player_hp_bar)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(920, 100)
	enemy_hp_bar.size = Vector2(330, 22)
	enemy_hp_bar.min_value = 0
	enemy_hp_bar.max_value = 100
	enemy_hp_bar.show_percentage = false
	game_ui.add_child(enemy_hp_bar)
	timer_label = _make_label(game_ui, "90", Vector2(610, 35), 34, Color.WHITE)
	status_label = _make_label(game_ui, "Kalahkan lawan latihan!", Vector2(470, 105), 20, Color.WHITE)
	_add_move_button(game_ui, "KIRI", Vector2(35, 590), Vector2(115, 80), -1)
	_add_move_button(game_ui, "KANAN", Vector2(165, 590), Vector2(115, 80), 1)
	_add_button(game_ui, "BERHENTI", Vector2(295, 590), Vector2(115, 80), func(): move_direction = 0)
	jump_button = _add_button(game_ui, "LOMPAT", Vector2(445, 590), Vector2(125, 85), _jump)
	dash_button = _add_button(game_ui, "DASH", Vector2(735, 590), Vector2(145, 85), _use_dash)
	skill_button = _add_button(game_ui, "SKILL", Vector2(900, 590), Vector2(150, 85), _use_skill)
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
	skill_cooldown = 0.0
	skill_animation_time = 0.0
	dash_cooldown = 0.0
	dash_time = 0.0
	jump_height = 0.0
	jump_velocity = 0.0
	player_facing = 1
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
		enemy_hit_flash = 0.18
		impact_effect_time = 0.24
		impact_effect_x = enemy_x
		status_label.text = "SERANGAN %s! Lawan kehilangan %d HP." % [selected_character.to_upper(), stats["damage"]]
	else:
		status_label.text = "Terlalu jauh! Dekati lawan terlebih dahulu."



func _jump() -> void:
	if not game_started or match_over or jump_height > 0.0:
		return
	jump_velocity = 620.0
	status_label.text = "LOMPAT!"
	queue_redraw()

func _use_dash() -> void:
	if not game_started or match_over or dash_cooldown > 0.0:
		return
	if move_direction != 0:
		player_facing = move_direction
	dash_time = 0.18
	dash_cooldown = 2.5
	status_label.text = "DASH!"
	queue_redraw()

func _use_skill() -> void:
	if not game_started or match_over or skill_cooldown > 0.0:
		return
	var skill_name := ""
	var skill_damage := 0
	var skill_range := 0.0
	match selected_character:
		"Swordman":
			skill_name = "QUICK SLASH"
			skill_damage = 25
			skill_range = 190.0
		"Axeman":
			skill_name = "HEAVY STRIKE"
			skill_damage = 38
			skill_range = 165.0
		"Spearman":
			skill_name = "SPEAR THRUST"
			skill_damage = 22
			skill_range = 260.0
	skill_cooldown = 6.0
	skill_animation_time = 0.42
	if absf(enemy_x - player_x) <= skill_range:
		enemy_hp = maxi(0, enemy_hp - skill_damage)
		enemy_hit_flash = 0.28
		impact_effect_time = 0.24
		impact_effect_x = enemy_x
		status_label.text = "%s! Lawan kehilangan %d HP." % [skill_name, skill_damage]
	else:
		status_label.text = "%s meleset! Dekati lawan." % skill_name
	_update_ui()
	queue_redraw()

func _update_ui() -> void:
	player_hp_label.text = "%s | HP: %d/%d" % [selected_character.to_upper(), player_hp, player_max_hp]
	enemy_hp_label.text = "OPPONENT | HP: %d/100" % enemy_hp
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp
	timer_label.text = str(ceili(time_left))
	if skill_button != null:
		skill_button.text = "SKILL" if skill_cooldown <= 0.0 else "SKILL\n%d dtk" % ceili(skill_cooldown)
	if dash_button != null:
		dash_button.text = "DASH" if dash_cooldown <= 0.0 else "DASH\n%d dtk" % ceili(dash_cooldown)

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
