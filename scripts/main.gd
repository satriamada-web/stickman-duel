extends Node2D

const FLOOR_Y := 570.0
const MATCH_LENGTH := 90.0
const MAX_STAMINA := 100.0
const BLOCK_DRAIN_RATE := 28.0
const STAMINA_REGEN_RATE := 18.0
const CHARACTERS := {
	"Swordman": {"hp": 100, "speed": 360.0, "damage": 15, "color": "#55c7ff", "weapon": "SWORD"},
	"Axeman": {"hp": 110, "speed": 300.0, "damage": 22, "color": "#ffb45c", "weapon": "AXE"},
	"Spearman": {"hp": 90, "speed": 390.0, "damage": 12, "color": "#8ee09b", "weapon": "SPEAR"}
}

var selected_character := "Swordman"
var player_x := 300.0
var enemy_x := 960.0
var enemy_knockback_velocity := 0.0
var player_hp := 100
var enemy_hp := 100
var player_max_hp := 100
var time_left := MATCH_LENGTH
var attack_cooldown := 0.0
var skill_cooldown := 0.0
var skill_animation_time := 0.0
var skill_cinematic_time := 0.0
var skill_cinematic_x := 0.0
var skill_cinematic_color := Color.WHITE
var dash_cooldown := 0.0
var dash_time := 0.0
var jump_height := 0.0
var jump_velocity := 0.0
var landing_time := 0.0
var jump_takeoff_time := 0.0
var player_facing := 1
var attack_animation_time := 0.0
var attack_animation_duration := 0.32
var combo_step := 0
var combo_window := 0.0
var enemy_attack_animation_time := 0.0
var animation_time := 0.0
var player_hit_flash := 0.0
var enemy_hit_flash := 0.0
var player_stun_time := 0.0
var enemy_stun_time := 0.0
var player_knockdown_time := 0.0
var enemy_knockdown_time := 0.0
var player_ragdoll_blend := 0.0
var enemy_ragdoll_blend := 0.0
var impact_effect_time := 0.0
var impact_effect_x := 0.0
var impact_effect_color := Color("#ffe08a")
var impact_effect_heavy := false
var enemy_attack_cooldown := 0.0
var enemy_attack_windup := 0.0
var enemy_attack_heavy := false
var enemy_attack_count := 0
var move_direction := 0
var is_blocking := false
var stamina := MAX_STAMINA
var block_broken_time := 0.0
var block_hold_time := 0.0
var perfect_parry_flash := 0.0
var counter_window := 0.0
var enemy_facing := -1
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
var block_button: Button
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var stamina_bar: ProgressBar
var stamina_label: Label
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_library: Dictionary = {}
var sfx_next_player := 0
var screen_shake_tween: Tween
var hit_stop_id := 0

func _ready() -> void:
	_setup_audio()
	_build_ui()
	queue_redraw()

func _setup_audio() -> void:
	# Semua efek suara dibuat secara prosedural agar tidak membutuhkan file audio tambahan.
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		sfx_players.append(player)
	sfx_library["sword"] = _make_sfx(620.0, 0.16, 0.24, 1.1)
	sfx_library["axe"] = _make_sfx(155.0, 0.25, 0.48, 0.55)
	sfx_library["spear"] = _make_sfx(430.0, 0.14, 0.12, 1.5)
	sfx_library["impact"] = _make_sfx(115.0, 0.13, 0.62, 0.8)
	sfx_library["heavy"] = _make_sfx(72.0, 0.24, 0.78, 0.9)
	sfx_library["jump"] = _make_sfx(310.0, 0.17, 0.10, 0.8)
	sfx_library["dash"] = _make_sfx(920.0, 0.14, 0.32, 0.45)
	sfx_library["block"] = _make_sfx(245.0, 0.11, 0.42, 0.7)
	sfx_library["skill"] = _make_sfx(510.0, 0.23, 0.28, 1.4)

func _make_sfx(start_frequency: float, duration: float, noise_mix: float, pitch_sweep: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var envelope := pow(1.0 - t, 2.2)
		var frequency := start_frequency * (1.0 + pitch_sweep * t)
		phase += frequency / float(sample_rate)
		var tone := sin(TAU * phase)
		var noise := randf_range(-1.0, 1.0)
		var value := (tone * (1.0 - noise_mix * 0.55) + noise * noise_mix * 0.55) * envelope
		samples.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream

func _play_sfx(sound_name: String) -> void:
	if not sfx_library.has(sound_name) or sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = sfx_players[sfx_next_player]
	sfx_next_player = (sfx_next_player + 1) % sfx_players.size()
	player.stop()
	player.stream = sfx_library[sound_name]
	player.play()

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
		elif event.keycode == KEY_SHIFT:
			_set_blocking(true)
	elif event is InputEventKey and not event.pressed:
		if event.keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
			move_direction = 0
		elif event.keycode == KEY_SHIFT:
			_set_blocking(false)

func _process(delta: float) -> void:
	if not game_started or match_over:
		return
	animation_time += delta
	landing_time = maxf(0.0, landing_time - delta)
	jump_takeoff_time = maxf(0.0, jump_takeoff_time - delta)
	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	enemy_attack_animation_time = maxf(0.0, enemy_attack_animation_time - delta)
	player_hit_flash = maxf(0.0, player_hit_flash - delta)
	enemy_hit_flash = maxf(0.0, enemy_hit_flash - delta)
	player_stun_time = maxf(0.0, player_stun_time - delta)
	enemy_stun_time = maxf(0.0, enemy_stun_time - delta)
	player_knockdown_time = maxf(0.0, player_knockdown_time - delta)
	enemy_knockdown_time = maxf(0.0, enemy_knockdown_time - delta)
	player_ragdoll_blend = move_toward(player_ragdoll_blend, 0.0, delta * 2.8)
	enemy_ragdoll_blend = move_toward(enemy_ragdoll_blend, 0.0, delta * 2.8)
	impact_effect_time = maxf(0.0, impact_effect_time - delta)
	block_broken_time = maxf(0.0, block_broken_time - delta)
	perfect_parry_flash = maxf(0.0, perfect_parry_flash - delta)
	counter_window = maxf(0.0, counter_window - delta)
	if is_blocking:
		block_hold_time += delta
		stamina = maxf(0.0, stamina - BLOCK_DRAIN_RATE * delta)
		if stamina <= 0.0:
			is_blocking = false
			block_broken_time = 1.5
			if block_button != null:
				block_button.text = "LELAH!"
	else:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN_RATE * delta)
	time_left = maxf(0.0, time_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_step = 0
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	skill_animation_time = maxf(0.0, skill_animation_time - delta)
	skill_cinematic_time = maxf(0.0, skill_cinematic_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if jump_height > 0.0 or jump_velocity > 0.0:
		var previous_jump_height := jump_height
		jump_height += jump_velocity * delta
		jump_velocity -= 1500.0 * delta
		if jump_height <= 0.0:
			jump_height = 0.0
			jump_velocity = 0.0
			if previous_jump_height > 0.0:
				landing_time = 0.18
				_play_sfx("block")
	enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
	if enemy_attack_windup > 0.0:
		enemy_attack_windup = maxf(0.0, enemy_attack_windup - delta)
		if enemy_attack_windup <= 0.0:
			_resolve_enemy_attack()
	var stats: Dictionary = CHARACTERS[selected_character]
	if move_direction != 0 and player_stun_time <= 0.0 and player_knockdown_time <= 0.0:
		player_facing = move_direction
	var current_speed := float(stats["speed"])
	if player_stun_time <= 0.0 and player_knockdown_time <= 0.0:
		if dash_time > 0.0:
			current_speed = 900.0
			player_x = clampf(player_x + player_facing * current_speed * delta, 70.0, 1210.0)
		else:
			player_x = clampf(player_x + move_direction * current_speed * delta, 70.0, 1210.0)
	else:
		dash_time = 0.0

	if absf(enemy_knockback_velocity) > 8.0:
		enemy_x = clampf(enemy_x + enemy_knockback_velocity * delta, 70.0, 1210.0)
		enemy_knockback_velocity = move_toward(enemy_knockback_velocity, 0.0, 1250.0 * delta)
	else:
		enemy_knockback_velocity = 0.0

	var distance := absf(enemy_x - player_x)
	enemy_facing = 1 if player_x > enemy_x else -1
	if enemy_stun_time > 0.0 or enemy_knockdown_time > 0.0:
		pass
	elif distance > 125.0 and absf(enemy_knockback_velocity) <= 8.0:
		enemy_x = move_toward(enemy_x, player_x, 165.0 * delta)
	elif distance <= 125.0 and enemy_attack_cooldown <= 0.0 and enemy_attack_windup <= 0.0 and absf(enemy_knockback_velocity) <= 8.0:
		enemy_attack_count += 1
		enemy_attack_heavy = enemy_attack_count % 3 == 0
		enemy_attack_windup = 0.48 if enemy_attack_heavy else 0.28
		enemy_attack_animation_time = enemy_attack_windup
		enemy_attack_cooldown = 1.65 if enemy_attack_heavy else 1.25
		status_label.text = "AWAS! LAWAN MENYIAPKAN SERANGAN KUAT!" if enemy_attack_heavy else "Lawan bersiap menyerang..."

	if time_left <= 0.0 or player_hp <= 0 or enemy_hp <= 0:
		_finish_match()
	_update_ui()
	queue_redraw()


func _shake_screen(strength: float) -> void:
	if screen_shake_tween != null and screen_shake_tween.is_running():
		screen_shake_tween.kill()
	position = Vector2.ZERO
	screen_shake_tween = create_tween()
	for i in range(3):
		var shake_offset := Vector2(randf_range(-strength, strength), randf_range(-strength * 0.55, strength * 0.55))
		screen_shake_tween.tween_property(self, "position", shake_offset, 0.025)
	screen_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.045)


func _trigger_hit_stop(duration: float) -> void:
	hit_stop_id += 1
	var current_id := hit_stop_id
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	if current_id == hit_stop_id:
		Engine.time_scale = 1.0

func _resolve_enemy_attack() -> void:
	var attack_reach := 190.0 if enemy_attack_heavy else 155.0
	if absf(enemy_x - player_x) > attack_reach:
		status_label.text = "SERANGAN LAWAN MELESET!"
		return
	if dash_time > 0.0 or jump_height >= 45.0:
		status_label.text = "BERHASIL MENGHINDAR!"
		return
	var base_damage := 14 if enemy_attack_heavy else 8
	var incoming_damage := base_damage
	var perfect_parry := is_blocking and block_hold_time <= 0.18 and stamina > 0.0
	if perfect_parry:
		incoming_damage = 0
		player_stun_time = 0.12
		enemy_stun_time = 0.85
		enemy_attack_cooldown = maxf(enemy_attack_cooldown, 1.0)
		counter_window = 1.1
		perfect_parry_flash = 0.32
		_shake_screen(11.0)
		_trigger_hit_stop(0.085)
		_play_sfx("heavy")
		impact_effect_time = 0.30
		impact_effect_x = player_x
		impact_effect_color = Color("#8df5ff")
		impact_effect_heavy = true
		status_label.text = "PERFECT PARRY! BALAS SEKARANG! (BONUS DAMAGE)"
		_update_ui()
		queue_redraw()
		return
	incoming_damage = (4 if enemy_attack_heavy else 2) if is_blocking else base_damage
	if is_blocking and stamina <= 0.0:
		incoming_damage = base_damage
	player_hp = maxi(0, player_hp - incoming_damage)
	player_ragdoll_blend = 1.0
	if not is_blocking:
		player_x = clampf(player_x + (1.0 if player_x > enemy_x else -1.0) * (145.0 if enemy_attack_heavy else 95.0), 70.0, 1210.0)
		player_stun_time = 1.15 if enemy_attack_heavy else 0.20
		if enemy_attack_heavy:
			player_knockdown_time = 1.15
	else:
		player_stun_time = 0.10 if enemy_attack_heavy else 0.06
	player_hit_flash = 0.28
	_shake_screen(5.0 if is_blocking else 8.0)
	_trigger_hit_stop(0.035 if is_blocking else 0.055)
	_play_sfx("block" if is_blocking else ("heavy" if enemy_attack_heavy else "impact"))
	impact_effect_time = 0.24
	impact_effect_x = player_x
	impact_effect_color = Color("#7ee8ff") if is_blocking else Color("#ff7185")
	impact_effect_heavy = enemy_attack_heavy
	if is_blocking:
		status_label.text = ("SERANGAN KUAT DITAHAN! Damage %d." if enemy_attack_heavy else "BLOCK BERHASIL! Damage %d.") % incoming_damage
	else:
		status_label.text = ("TERKENA SERANGAN KUAT! -%d HP" if enemy_attack_heavy else "KAMU TERKENA SERANGAN! -%d HP") % incoming_damage

func _draw() -> void:
	if not game_started:
		return
	_draw_arena_background()
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
	_draw_fighter(player_x, FLOOR_Y - jump_height, player_tint, player_facing, str(player_stats["weapon"]), move_direction != 0 or dash_time > 0.0, maxf(attack_animation_time, skill_animation_time), 0.42 if skill_animation_time > attack_animation_time else attack_animation_duration, dash_time > 0.0, jump_height > 0.0, combo_step, player_hit_flash, selected_character, landing_time, jump_velocity, jump_takeoff_time, is_blocking, player_knockdown_time, enemy_x, player_ragdoll_blend)
	_draw_fighter(enemy_x, FLOOR_Y, enemy_tint, enemy_facing, "AXE", absf(enemy_x - player_x) > 125.0, enemy_attack_animation_time, 0.24, false, false, 1, enemy_hit_flash, "Axeman", 0.0, 0.0, 0.0, false, enemy_knockdown_time, player_x, enemy_ragdoll_blend)
	if enemy_attack_windup > 0.0:
		var tell_progress := 1.0 - clampf(enemy_attack_windup / (0.48 if enemy_attack_heavy else 0.28), 0.0, 1.0)
		var tell_color := Color("#ffb45c") if enemy_attack_heavy else Color("#ff687d")
		draw_arc(Vector2(enemy_x, FLOOR_Y - 78.0), 34.0 + tell_progress * 12.0, 0.0, TAU, 28, tell_color, 3.0)
		draw_rect(Rect2(enemy_x - 34.0, FLOOR_Y - 155.0, 68.0 * tell_progress, 6.0), tell_color)
		if enemy_attack_heavy:
			draw_circle(Vector2(enemy_x, FLOOR_Y - 78.0), 43.0, Color(1.0, 0.45, 0.15, 0.08))
	if perfect_parry_flash > 0.0:
		var parry_alpha := perfect_parry_flash / 0.32
		draw_arc(Vector2(player_x, FLOOR_Y - 78.0), 52.0 + (1.0 - parry_alpha) * 25.0, 0.0, TAU, 32, Color(0.50, 0.95, 1.0, parry_alpha), 5.0)
		draw_string(ThemeDB.fallback_font, Vector2(player_x - 82.0, FLOOR_Y - 170.0), "PARRY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.65, 0.96, 1.0, parry_alpha))
	if counter_window > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(player_x - 70.0, FLOOR_Y - 188.0), "COUNTER READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a8f0c6"))
	if skill_cinematic_time > 0.0:
		var cinematic_progress := 1.0 - skill_cinematic_time / 0.62
		var cinematic_alpha := clampf(skill_cinematic_time / 0.62, 0.0, 1.0)
		var cinematic_radius := 28.0 + cinematic_progress * 145.0
		var cinematic_tint := skill_cinematic_color
		cinematic_tint.a = cinematic_alpha * 0.82
		draw_arc(Vector2(skill_cinematic_x, FLOOR_Y - 82.0), cinematic_radius, -1.15, 1.15, 36, cinematic_tint, 5.0)
		draw_arc(Vector2(skill_cinematic_x, FLOOR_Y - 82.0), cinematic_radius * 0.72, 1.9, 4.35, 30, Color(1.0, 1.0, 1.0, cinematic_alpha * 0.65), 2.5)
		for ray_index in range(12):
			var ray_angle := TAU * float(ray_index) / 12.0 + cinematic_progress * 0.35
			var ray_start := Vector2(cos(ray_angle), sin(ray_angle)) * (cinematic_radius * 0.72)
			var ray_end := Vector2(cos(ray_angle), sin(ray_angle)) * (cinematic_radius + 15.0)
			draw_line(Vector2(skill_cinematic_x, FLOOR_Y - 82.0) + ray_start, Vector2(skill_cinematic_x, FLOOR_Y - 82.0) + ray_end, cinematic_tint, 2.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(skill_cinematic_x - 72.0, FLOOR_Y - 205.0), "SPECIAL MOVE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, cinematic_tint)

	if impact_effect_time > 0.0:
		var impact_y := FLOOR_Y - 78.0
		var impact_progress := 1.0 - impact_effect_time / 0.24
		var burst_radius := 10.0 + impact_progress * (42.0 if impact_effect_heavy else 28.0)
		var burst_alpha := clampf(impact_effect_time / 0.24, 0.0, 1.0)
		var burst_color := impact_effect_color
		burst_color.a = burst_alpha
		draw_arc(Vector2(impact_effect_x, impact_y), burst_radius, 0.0, TAU, 24, burst_color, 4.0 if impact_effect_heavy else 2.5)
		for ray in range(10 if impact_effect_heavy else 7):
			var angle := TAU * float(ray) / float(10 if impact_effect_heavy else 7) + impact_progress * 0.7
			var ray_start := Vector2(cos(angle), sin(angle)) * (burst_radius * 0.55)
			var ray_end := Vector2(cos(angle), sin(angle)) * (burst_radius + (22.0 if impact_effect_heavy else 13.0))
			draw_line(Vector2(impact_effect_x, impact_y) + ray_start, Vector2(impact_effect_x, impact_y) + ray_end, burst_color, 3.5 if impact_effect_heavy else 2.0, true)
		for spark in range(5):
			var spark_angle := TAU * float(spark) / 5.0 - impact_progress * 2.0
			var spark_distance := burst_radius + 8.0 + impact_progress * 24.0
			var spark_position := Vector2(impact_effect_x, impact_y) + Vector2(cos(spark_angle), sin(spark_angle)) * spark_distance
			draw_circle(spark_position, (3.5 if impact_effect_heavy else 2.5) * burst_alpha, Color.WHITE)


func _draw_arena_background() -> void:
	# Langit berlapis dengan cahaya arena yang bergerak perlahan.
	draw_rect(Rect2(0, 0, 1280, FLOOR_Y), Color("#111b31"))
	draw_rect(Rect2(0, 0, 1280, 210), Color("#1b2945"))
	draw_rect(Rect2(0, 210, 1280, 180), Color("#253451"))
	draw_rect(Rect2(0, 390, 1280, 180), Color("#303d53"))
	draw_circle(Vector2(640, 175), 76.0, Color(0.40, 0.67, 0.91, 0.10))
	draw_circle(Vector2(640, 175), 48.0, Color("#a9d8f2"))
	draw_circle(Vector2(640, 175), 39.0, Color("#d4eaff"))

	var beam_shift := sin(animation_time * 0.42) * 34.0
	var beam_color := Color(0.35, 0.72, 1.0, 0.055)
	draw_colored_polygon(PackedVector2Array([
		Vector2(105, 0), Vector2(210, 0), Vector2(440 + beam_shift, FLOOR_Y),
		Vector2(285 + beam_shift, FLOOR_Y)
	]), beam_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1090, 0), Vector2(1190, 0), Vector2(995 + beam_shift, FLOOR_Y),
		Vector2(850 + beam_shift, FLOOR_Y)
	]), Color(0.95, 0.57, 0.30, 0.045))

	# Siluet gedung dan tribun di kejauhan.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 430), Vector2(110, 350), Vector2(215, 420),
		Vector2(330, 330), Vector2(455, 425), Vector2(570, 365),
		Vector2(700, 430), Vector2(830, 345), Vector2(960, 425),
		Vector2(1090, 355), Vector2(1280, 430), Vector2(1280, FLOOR_Y),
		Vector2(0, FLOOR_Y)
	]), Color("#202d43"))
	draw_rect(Rect2(0, 438, 1280, 132), Color("#18263b"))
	for x in range(20, 1280, 42):
		var crowd_height := 8.0 + float((x * 7) % 17)
		draw_circle(Vector2(float(x), 493.0 - crowd_height), 5.0, Color("#52647c"))
		draw_line(Vector2(float(x), 500.0 - crowd_height), Vector2(float(x), 520.0), Color("#52647c"), 3.0)

	# Lampu sorot dan papan arena.
	for lamp_x in [85.0, 1195.0]:
		draw_rect(Rect2(lamp_x - 5.0, 265.0, 10.0, 165.0), Color("#64748b"))
		draw_rect(Rect2(lamp_x - 27.0, 255.0, 54.0, 18.0), Color("#a9c5df"))
		draw_circle(Vector2(lamp_x, 264.0), 18.0, Color(0.70, 0.88, 1.0, 0.13))
	draw_rect(Rect2(470, 315, 340, 54), Color("#111d30"))
	draw_rect(Rect2(476, 321, 328, 42), Color("#344b68"))
	draw_string(ThemeDB.fallback_font, Vector2(535, 349), "TRAINING ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d7eaff"))

	# Lantai arena dengan garis perspektif dan garis batas.
	draw_rect(Rect2(0, FLOOR_Y, 1280, 150), Color("#26364b"))
	draw_rect(Rect2(0, FLOOR_Y, 1280, 8), Color("#8da3bd"))
	draw_line(Vector2(0, FLOOR_Y + 4), Vector2(1280, FLOOR_Y + 4), Color("#b5d5ef"), 2.0)
	for i in range(0, 1280, 80):
		draw_line(Vector2(i, FLOOR_Y + 35), Vector2(i + 35, FLOOR_Y + 35), Color("#40536a"), 2.0)
	for x in range(0, 1281, 160):
		draw_line(Vector2(float(x), FLOOR_Y + 8), Vector2(640.0 + (float(x) - 640.0) * 1.35, 720.0), Color(0.55, 0.68, 0.82, 0.10), 1.0)
	draw_line(Vector2(0, 710), Vector2(1280, 710), Color("#40536a"), 2.0)

func _solve_knee_2d(hip_point: Vector2, foot_point: Vector2, upper_length: float, lower_length: float, bend_direction: float) -> Vector2:
	var offset := foot_point - hip_point
	var distance := maxf(offset.length(), 0.01)
	var direction_to_foot := offset / distance
	var safe_distance := clampf(distance, absf(upper_length - lower_length) + 0.01, upper_length + lower_length - 0.01)
	var along := (upper_length * upper_length - lower_length * lower_length + safe_distance * safe_distance) / (2.0 * safe_distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var perpendicular := Vector2(-direction_to_foot.y, direction_to_foot.x)
	return hip_point + direction_to_foot * along + perpendicular * height * bend_direction


func _draw_fighter(x: float, floor_y: float, tint: Color, direction: int, weapon: String, walking: bool, attack_time: float, attack_duration: float, dashing: bool, airborne: bool, combo_style: int, hit_time: float, fighter_name: String, landing: float = 0.0, vertical_velocity: float = 0.0, takeoff: float = 0.0, blocking: bool = false, knockdown: float = 0.0, target_x: float = 0.0, ragdoll_blend: float = 0.0) -> void:
	# Rig prosedural: ritme langkah, pusat berat, dan pose serangan dibangun dari waktu.
	var gait_rate := 18.0 if dashing else (11.5 if walking else 2.2)
	var phase := animation_time * gait_rate
	var stride := sin(phase) if walking or dashing else 0.0
	var landing_weight := clampf(landing / 0.18, 0.0, 1.0)
	var landing_squash := sin(landing_weight * PI) * 8.0
	var idle_breath := sin(animation_time * 2.4)
	var idle_phase := animation_time * 1.7 + (0.0 if fighter_name == "Swordman" else (1.1 if fighter_name == "Axeman" else 2.0))
	var idle_sway := sin(idle_phase)
	var is_idle := not walking and attack_time <= 0.0 and not dashing and not airborne and hit_time <= 0.0
	var idle_strength := 1.0 if is_idle else 0.0
	var bob := absf(sin(phase * 2.0)) * (7.0 if dashing else 5.0) if walking or dashing else idle_breath * 1.8 + absf(idle_sway) * 1.2 * idle_strength
	bob += landing_squash
	var lean := 0.0
	if dashing:
		lean = float(direction) * 18.0
	elif walking:
		lean = float(direction) * (5.0 + absf(stride) * 2.0)
	elif blocking:
		lean = -float(direction) * 5.0
	elif attack_time > 0.0:
		var attack_progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		# Sedikit mundur saat persiapan, condong ke depan saat ayunan.
		lean = float(direction) * (sin(attack_progress * PI) * 12.0 - 5.0 * (1.0 - attack_progress))
	var center := Vector2(x + idle_sway * 1.8 * idle_strength, floor_y - bob)
	var head := center + Vector2(lean * 0.45 + idle_sway * 1.2 * idle_strength, -112 + idle_breath * 1.2 * idle_strength)
	var shoulder := center + Vector2(lean + idle_sway * 2.2 * idle_strength, -86 + idle_breath * 1.8 * idle_strength)
	var hip := center + Vector2(lean * 0.35 - idle_sway * 1.0 * idle_strength, -43)

	if hit_time > 0.0:
		var reaction := clampf(hit_time / 0.22, 0.0, 1.0)
		lean = -float(direction) * 19.0 * reaction
		center.x += lean * 0.25
		head = center + Vector2(lean * 0.45, -112)
		shoulder = center + Vector2(lean, -86)
		hip = center + Vector2(lean * 0.35, -43)

	# Kaki bergantian melangkah; saat diam, lutut tetap sedikit menekuk.
	var leg_swing := stride * 23.0
	var step_lift := absf(cos(phase)) * (11.0 if dashing else 7.0) if walking or dashing else 0.0
	var front_knee := hip + Vector2(14.0 * direction + leg_swing, 24.0 + absf(stride) * 5.0)
	var back_knee := hip + Vector2(-12.0 * direction - leg_swing, 24.0 + absf(stride) * 5.0)
	var front_foot := front_knee + Vector2(13.0 * direction + leg_swing * 0.7, 21.0 - step_lift)
	var back_foot := back_knee + Vector2(-10.0 * direction - leg_swing * 0.7, 21.0 - step_lift)

	var front_elbow := shoulder + Vector2(18.0 * direction - stride * 9.0 + idle_sway * 2.0 * idle_strength, 17.0 + idle_breath * 2.0 * idle_strength)
	var front_hand := front_elbow + Vector2(13.0 * direction - stride * 7.0 + idle_sway * 1.5 * idle_strength, 13.0 + idle_breath * 2.5 * idle_strength)
	var back_elbow := shoulder + Vector2(-18.0 * direction + stride * 9.0 - idle_sway * 1.5 * idle_strength, 15.0)
	var back_hand := back_elbow + Vector2(-13.0 * direction + stride * 7.0, 14.0 + idle_breath * 2.0 * idle_strength)

	# Stance netral berbeda untuk tiap jenis senjata.
	if attack_time <= 0.0 and not blocking and not airborne and not dashing and knockdown <= 0.0:
		if weapon == "SPEAR":
			front_elbow = shoulder + Vector2(21.0 * direction, 3.0)
			front_hand = shoulder + Vector2(38.0 * direction, -4.0)
			back_elbow = shoulder + Vector2(-13.0 * direction, 13.0)
			back_hand = shoulder + Vector2(5.0 * direction, 19.0)
		elif weapon == "AXE":
			front_elbow = shoulder + Vector2(19.0 * direction, -12.0)
			front_hand = shoulder + Vector2(34.0 * direction, -25.0)
			back_elbow = shoulder + Vector2(-17.0 * direction, 14.0)
			back_hand = shoulder + Vector2(-2.0 * direction, 3.0)
		else:
			front_elbow = shoulder + Vector2(19.0 * direction, 5.0)
			front_hand = shoulder + Vector2(34.0 * direction, -8.0)
			back_elbow = shoulder + Vector2(-17.0 * direction, 14.0)
			back_hand = shoulder + Vector2(-2.0 * direction, 5.0)

	if attack_time > 0.0:
		var progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		# 0-25% anticipation
# 25-68% strike, 68-100% follow-through.
		var anticipation := 1.0 - clampf(progress / 0.25, 0.0, 1.0)
		var strike_progress := clampf((progress - 0.25) / 0.43, 0.0, 1.0)
		var strike := sin(strike_progress * PI * 0.5)
		var follow := clampf((progress - 0.68) / 0.32, 0.0, 1.0)
		var reach := 62.0 * strike - 13.0 * follow
		front_elbow = shoulder + Vector2((24.0 - 19.0 * anticipation + reach * 0.32) * direction, -8.0 - 8.0 * strike + 5.0 * follow)
		front_hand = shoulder + Vector2((39.0 - 31.0 * anticipation + reach) * direction, -12.0 - 15.0 * strike + 8.0 * follow)
		back_elbow = shoulder + Vector2((-22.0 + 7.0 * anticipation) * direction, 18.0)
		back_hand = back_elbow + Vector2(-14.0 * direction, 9.0)

		# Siluet ayunan disesuaikan dengan karakter senjata.
		if weapon == "SPEAR":
			# Tusukan: siku tetap rapat, tangan memanjang tajam ke depan.
			var spear_reach := 48.0 if combo_style == 3 else 30.0
			front_elbow = shoulder + Vector2((25.0 + 13.0 * strike - 5.0 * follow) * direction, -3.0)
			front_hand = shoulder + Vector2((48.0 + spear_reach * strike - 10.0 * follow) * direction, -5.0 - 5.0 * strike)
		elif weapon == "AXE":
			# Kapak mengangkat tinggi saat persiapan lalu turun dengan bobot besar.
			var axe_swing := 1.0 if combo_style == 3 else 0.72
			front_elbow = shoulder + Vector2((17.0 + 8.0 * strike) * direction, -18.0 * axe_swing + 15.0 * follow)
			front_hand = shoulder + Vector2((35.0 + 24.0 * strike - 10.0 * follow) * direction, -31.0 * axe_swing + 28.0 * strike + 12.0 * follow)
			back_hand += Vector2(-5.0 * direction * anticipation, -8.0 * anticipation)
		elif combo_style == 2:
			front_elbow += Vector2(5.0 * direction, 10.0)
			front_hand += Vector2(10.0 * direction, 22.0)
		elif combo_style == 3:
			front_elbow += Vector2(8.0 * direction, -12.0)
			front_hand += Vector2(17.0 * direction, -22.0)

		front_knee += Vector2(-7.0 * direction * anticipation + 3.0 * direction * follow, 0.0)
		front_foot += Vector2(-10.0 * direction * anticipation, -2.0 * strike)

	# Procedural aiming: tangan depan mengikuti jarak target.
	var target_distance := absf(target_x - x)
	var aim_weight := (1.0 - clampf((target_distance - 95.0) / 300.0, 0.0, 1.0)) if target_x > 0.0 else 0.0
	if aim_weight > 0.0 and not airborne and not dashing and not blocking and attack_time <= 0.0 and hit_time <= 0.0 and knockdown <= 0.0:
		var aim_reach := 9.0 + aim_weight * 13.0
		front_elbow = front_elbow.lerp(shoulder + Vector2(23.0 * direction, 5.0), aim_weight * 0.55)
		front_hand = front_hand.lerp(shoulder + Vector2((37.0 + aim_reach) * direction, -8.0), aim_weight * 0.7)
		back_hand = back_hand.lerp(back_elbow + Vector2(-8.0 * direction, 5.0), aim_weight * 0.25)

	if blocking:
		# Pose guard: siku rapat, senjata terangkat melindungi bagian atas tubuh.
		front_knee = hip + Vector2(17.0 * direction, 29.0)
		front_foot = front_knee + Vector2(8.0 * direction, 18.0)
		back_knee = hip + Vector2(-15.0 * direction, 27.0)
		back_foot = back_knee + Vector2(-7.0 * direction, 19.0)
		front_elbow = shoulder + Vector2(25.0 * direction, -22.0)
		front_hand = shoulder + Vector2(37.0 * direction, -42.0)
		back_elbow = shoulder + Vector2(-13.0 * direction, -12.0)
		back_hand = shoulder + Vector2(17.0 * direction, -34.0)

	if hit_time > 0.0:
		# Reaksi terpukul: badan mundur, lutut menekuk, tangan terangkat.
		front_knee = hip + Vector2(17.0 * direction, 30.0)
		front_foot = front_knee + Vector2(5.0 * direction, 18.0)
		back_knee = hip + Vector2(-18.0 * direction, 30.0)
		back_foot = back_knee + Vector2(-8.0 * direction, 18.0)
		front_elbow = shoulder + Vector2(24.0 * direction, -24.0)
		front_hand = front_elbow + Vector2(10.0 * direction, -17.0)
		back_elbow = shoulder + Vector2(-24.0 * direction, -20.0)
		back_hand = back_elbow + Vector2(-12.0 * direction, -16.0)

	if airborne:
		# Pose udara berubah: menolak saat naik, lebih rapat dan siap mendarat saat turun.
		var falling := vertical_velocity <= 0.0
		var air_tuck := 1.0 if falling else 0.0
		front_knee = hip + Vector2(22.0 * direction, 9.0 + air_tuck * 8.0)
		front_foot = front_knee + Vector2(13.0 * direction, -14.0 + air_tuck * 7.0)
		back_knee = hip + Vector2(-18.0 * direction, 13.0 + air_tuck * 7.0)
		back_foot = back_knee + Vector2(-12.0 * direction, -13.0 + air_tuck * 8.0)
		front_elbow = shoulder + Vector2(23.0 * direction, -19.0 + air_tuck * 10.0)
		front_hand = front_elbow + Vector2(18.0 * direction, -10.0 + air_tuck * 13.0)
		back_elbow = shoulder + Vector2(-22.0 * direction, -15.0 + air_tuck * 9.0)
		back_hand = back_elbow + Vector2(-17.0 * direction, -8.0 + air_tuck * 12.0)
		if takeoff > 0.0:
			var push := clampf(takeoff / 0.12, 0.0, 1.0)
			front_knee.y += 9.0 * push
			back_knee.y += 9.0 * push
			front_hand.y -= 8.0 * push
			back_hand.y -= 8.0 * push

	if dashing and not airborne:
		# Pose dodge: badan rendah dan miring, tangan tertarik ke belakang.
		front_knee = hip + Vector2(25.0 * direction, 34.0)
		front_foot = front_knee + Vector2(20.0 * direction, 12.0)
		back_knee = hip + Vector2(-22.0 * direction, 20.0)
		back_foot = back_knee + Vector2(-18.0 * direction, 18.0)
		front_elbow = shoulder + Vector2(-5.0 * direction, -22.0)
		front_hand = front_elbow + Vector2(-25.0 * direction, -12.0)
		back_elbow = shoulder + Vector2(-25.0 * direction, 5.0)
		back_hand = back_elbow + Vector2(-27.0 * direction, 8.0)

	# Foot IK: telapak kaki tetap menyentuh lantai saat fase pijakan.
	if not airborne and not dashing and knockdown <= 0.0:
		var front_lift := maxf(0.0, cos(phase)) * (11.0 if walking else 0.0)
		var back_lift := maxf(0.0, cos(phase + PI)) * (11.0 if walking else 0.0)
		front_foot.y = floor_y - front_lift
		back_foot.y = floor_y - back_lift
		front_knee = _solve_knee_2d(hip, front_foot, 32.0, 27.0, -1.0 * direction)
		back_knee = _solve_knee_2d(hip, back_foot, 32.0, 27.0, 1.0 * direction)

	if knockdown > 0.0:
		# Timer 1.15 dtk: rebah, tahan pose, lalu bangkit selama 0.35 dtk terakhir.
		var getup_blend := clampf(knockdown / 0.35, 0.0, 1.0)
		var prone_center := center + Vector2(0.0, 31.0)
		var prone_head := prone_center + Vector2(-42.0 * direction, -18.0)
		var prone_shoulder := prone_center + Vector2(-12.0 * direction, -8.0)
		var prone_hip := prone_center + Vector2(27.0 * direction, -5.0)
		var prone_front_elbow := prone_shoulder + Vector2(8.0 * direction, -18.0)
		var prone_front_hand := prone_front_elbow + Vector2(22.0 * direction, 4.0)
		var prone_back_elbow := prone_shoulder + Vector2(-10.0 * direction, 17.0)
		var prone_back_hand := prone_back_elbow + Vector2(-19.0 * direction, 8.0)
		var prone_front_knee := prone_hip + Vector2(20.0 * direction, 13.0)
		var prone_front_foot := prone_front_knee + Vector2(25.0 * direction, 2.0)
		var prone_back_knee := prone_hip + Vector2(-14.0 * direction, 18.0)
		var prone_back_foot := prone_back_knee + Vector2(-24.0 * direction, 3.0)
		center = center.lerp(prone_center, getup_blend)
		head = head.lerp(prone_head, getup_blend)
		shoulder = shoulder.lerp(prone_shoulder, getup_blend)
		hip = hip.lerp(prone_hip, getup_blend)
		front_elbow = front_elbow.lerp(prone_front_elbow, getup_blend)
		front_hand = front_hand.lerp(prone_front_hand, getup_blend)
		back_elbow = back_elbow.lerp(prone_back_elbow, getup_blend)
		back_hand = back_hand.lerp(prone_back_hand, getup_blend)
		front_knee = front_knee.lerp(prone_front_knee, getup_blend)
		front_foot = front_foot.lerp(prone_front_foot, getup_blend)
		back_knee = back_knee.lerp(prone_back_knee, getup_blend)
		back_foot = back_foot.lerp(prone_back_foot, getup_blend)

	# Secondary motion: kepala dan bahu sedikit terlambat mengikuti gerak utama.
	if knockdown <= 0.0 and hit_time <= 0.0 and not blocking:
		var body_follow := sin(phase - 0.65) * (2.2 if walking else 0.8)
		if attack_time > 0.0:
			var follow_progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
			body_follow += sin(follow_progress * PI) * 2.8
		head += Vector2(-float(direction) * body_follow * 0.45, absf(body_follow) * 0.35)
		shoulder += Vector2(-float(direction) * body_follow * 0.3, body_follow * 0.25)

	# Active-ragdoll ringan: momentum benturan menggeser rig lalu mereda.
	if ragdoll_blend > 0.0 and knockdown <= 0.0:
		var recoil := ragdoll_blend
		var wobble := sin(animation_time * 24.0) * recoil
		var recoil_x := -float(direction) * (13.0 * recoil + 3.0 * wobble)
		center.x += recoil_x * 0.45
		head += Vector2(recoil_x * 0.65, 5.0 * recoil)
		shoulder += Vector2(recoil_x, 7.0 * recoil)
		hip += Vector2(recoil_x * 0.28, 3.0 * recoil)
		front_elbow += Vector2(-float(direction) * 10.0 * recoil, -12.0 * recoil)
		front_hand += Vector2(-float(direction) * 17.0 * recoil, -18.0 * recoil + wobble * 5.0)
		back_elbow += Vector2(-float(direction) * 7.0 * recoil, -8.0 * recoil)
		back_hand += Vector2(-float(direction) * 13.0 * recoil, -13.0 * recoil - wobble * 4.0)
		front_knee += Vector2(-float(direction) * 5.0 * recoil, -4.0 * recoil)
		back_knee += Vector2(float(direction) * 4.0 * recoil, -2.0 * recoil)

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
	var idle_weapon_sway := idle_sway * idle_strength
	var aim_weapon_lift := aim_weight * 5.0 if not blocking and attack_time <= 0.0 and knockdown <= 0.0 else 0.0
	# Senjata punya sedikit keterlambatan rotasi/posisi setelah gerak tangan.
	var weapon_follow := 0.0
	if attack_time > 0.0:
		var weapon_progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		weapon_follow = sin(weapon_progress * PI) * 8.0
	var weapon_idle_lag := sin(animation_time * 8.5 - 0.9) * (2.8 if walking else 1.5 if idle_strength > 0.0 else 0.0)
	var weapon_tip := front_hand + Vector2(48.0 * direction + idle_weapon_sway * 2.0 + weapon_idle_lag * direction, -12.0 - aim_weapon_lift + idle_breath * 2.0 * idle_strength + weapon_follow)
	if weapon == "SPEAR":
		weapon_tip = front_hand + Vector2(78.0 * direction + idle_weapon_sway * 4.0 + weapon_idle_lag * direction, -5.0 + idle_breath * 3.0 * idle_strength + weapon_follow * 0.65)
		draw_line(front_hand, weapon_tip, Color("#f5d78e"), 5.0, true)
		draw_line(weapon_tip, weapon_tip + Vector2(12.0 * direction, -2.0), Color("#dce7f2"), 3.0, true)
	elif weapon == "AXE":
		weapon_tip = front_hand + Vector2(36.0 * direction + idle_weapon_sway * 3.0 + weapon_idle_lag * direction, -12.0 + idle_breath * 3.5 * idle_strength + weapon_follow * 1.25)
		draw_line(front_hand, weapon_tip, Color("#b8c3d1"), 7.0, true)
		draw_line(weapon_tip + Vector2(-4.0 * direction, 0), weapon_tip + Vector2(7.0 * direction, -17.0), Color("#b8c3d1"), 11.0, true)
	else:
		draw_line(front_hand, weapon_tip, Color("#f5d78e"), 6.0, true)
		draw_line(weapon_tip, weapon_tip + Vector2(8.0 * direction, -2.0), Color("#dce7f2"), 3.0, true)

	if attack_time > 0.0:
		var progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		var slash_alpha := sin(progress * PI)
		if slash_alpha > 0.05:
			if weapon == "SPEAR":
				var thrust_start := center + Vector2(42.0 * direction, -83.0)
				var thrust_end := thrust_start + Vector2(92.0 * direction, -4.0)
				draw_line(thrust_start, thrust_end, Color(0.65, 1.0, 0.78, slash_alpha), 7.0, true)
				draw_line(thrust_start, thrust_end, Color(1.0, 1.0, 1.0, slash_alpha * 0.8), 2.0, true)
			elif weapon == "AXE":
				draw_arc(center + Vector2(30.0 * direction, -83.0), 61.0 + slash_alpha * 13.0, -1.35, 1.0, 22, Color(1.0, 0.68, 0.32, slash_alpha), 7.0)
				draw_arc(center + Vector2(30.0 * direction, -83.0), 48.0 + slash_alpha * 10.0, -1.2, 0.8, 22, Color(1.0, 0.94, 0.72, slash_alpha * 0.8), 2.5)
			else:
				draw_arc(center + Vector2(37.0 * direction, -79.0), 49.0 + slash_alpha * 10.0, -0.95, 0.95, 20, Color(0.48, 0.82, 1.0, slash_alpha), 6.0)
				draw_arc(center + Vector2(37.0 * direction, -79.0), 43.0 + slash_alpha * 8.0, -0.9, 0.9, 20, Color(1.0, 1.0, 1.0, slash_alpha * 0.75), 2.0)

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
	_make_label(game_ui, "STICKMAN DUEL | TRAINING ARENA", Vector2(30, 18), 24, Color.WHITE)
	player_hp_label = _make_label(game_ui, "PLAYER 1 | HP: 100", Vector2(30, 60), 19, Color("#55c7ff"))
	enemy_hp_label = _make_label(game_ui, "OPPONENT | HP: 100", Vector2(930, 60), 19, Color("#ff687d"))
	player_hp_bar = ProgressBar.new()
	player_hp_bar.position = Vector2(30, 88)
	player_hp_bar.size = Vector2(330, 18)
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = 100
	player_hp_bar.show_percentage = false
	game_ui.add_child(player_hp_bar)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.position = Vector2(920, 88)
	enemy_hp_bar.size = Vector2(330, 18)
	enemy_hp_bar.min_value = 0
	enemy_hp_bar.max_value = 100
	enemy_hp_bar.show_percentage = false
	game_ui.add_child(enemy_hp_bar)
	timer_label = _make_label(game_ui, "90", Vector2(610, 24), 32, Color.WHITE)
	status_label = _make_label(game_ui, "Kalahkan lawan latihan!", Vector2(455, 92), 18, Color.WHITE)

	stamina_label = _make_label(game_ui, "STAMINA", Vector2(30, 118), 14, Color("#a8f0c6"))
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(30, 140)
	stamina_bar.size = Vector2(230, 12)
	stamina_bar.min_value = 0
	stamina_bar.max_value = MAX_STAMINA
	stamina_bar.value = MAX_STAMINA
	stamina_bar.show_percentage = false
	game_ui.add_child(stamina_bar)

	# Tombol kiri dikelompokkan di sisi kiri bawah.
	_add_move_button(game_ui, "◀\nKIRI", Vector2.ZERO, Vector2.ZERO, -1)
	_set_ui_rect(game_ui.get_child(game_ui.get_child_count() - 1), 0.025, 0.80, 0.105, 0.96)
	_add_move_button(game_ui, "KANAN\n▶", Vector2.ZERO, Vector2.ZERO, 1)
	_set_ui_rect(game_ui.get_child(game_ui.get_child_count() - 1), 0.115, 0.80, 0.195, 0.96)
	_add_button(game_ui, "STOP", Vector2.ZERO, Vector2.ZERO, func(): move_direction = 0)
	_set_ui_rect(game_ui.get_child(game_ui.get_child_count() - 1), 0.205, 0.80, 0.275, 0.96)

	# Pertahanan di tengah, tombol aksi utama dalam susunan 2 x 2 di kanan.
	block_button = Button.new()
	block_button.text = "BLOCK"
	block_button.button_down.connect(func(): _set_blocking(true))
	block_button.button_up.connect(func(): _set_blocking(false))
	game_ui.add_child(block_button)
	_set_ui_rect(block_button, 0.625, 0.82, 0.735, 0.96)
	_style_game_button(block_button, Color("#3b8b78"), 18)

	jump_button = _add_button(game_ui, "LOMPAT", Vector2.ZERO, Vector2.ZERO, _jump)
	_set_ui_rect(jump_button, 0.765, 0.765, 0.875, 0.875)
	_style_game_button(jump_button, Color("#426b9b"), 16)
	dash_button = _add_button(game_ui, "DASH", Vector2.ZERO, Vector2.ZERO, _use_dash)
	_set_ui_rect(dash_button, 0.885, 0.765, 0.975, 0.875)
	_style_game_button(dash_button, Color("#426b9b"), 16)
	skill_button = _add_button(game_ui, "SKILL", Vector2.ZERO, Vector2.ZERO, _use_skill)
	_set_ui_rect(skill_button, 0.765, 0.89, 0.875, 0.99)
	_style_game_button(skill_button, Color("#8b5ca8"), 16)
	var attack_button := _add_button(game_ui, "SERANG", Vector2.ZERO, Vector2.ZERO, _attack)
	_set_ui_rect(attack_button, 0.885, 0.89, 0.975, 0.99)
	_style_game_button(attack_button, Color("#b94f5b"), 17)

	result_button = _add_button(game_ui, "KEMBALI KE MENU", Vector2.ZERO, Vector2.ZERO, _return_to_menu)
	_set_ui_rect(result_button, 0.39, 0.58, 0.61, 0.72)
	result_button.visible = false
	_style_game_button(result_button, Color("#426b9b"), 18)

func _set_ui_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _style_game_button(button: Button, base_color: Color, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = base_color.lightened(0.25)
	normal.content_margin_left = 5.0
	normal.content_margin_right = 5.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.14)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.18)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)


func _set_blocking(value: bool) -> void:
	var was_blocking := is_blocking
	is_blocking = value and game_started and not match_over and player_stun_time <= 0.0 and player_knockdown_time <= 0.0 and stamina > 0.0 and block_broken_time <= 0.0
	if is_blocking and not was_blocking:
		block_hold_time = 0.0
		_play_sfx("block")
	elif not is_blocking:
		block_hold_time = 0.0
	if block_button != null:
		block_button.text = "BERTAHAN" if is_blocking else ("LELAH!" if block_broken_time > 0.0 else "BLOCK")
	queue_redraw()


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
	enemy_knockback_velocity = 0.0
	time_left = MATCH_LENGTH
	attack_cooldown = 0.0
	combo_step = 0
	combo_window = 0.0
	attack_animation_duration = 0.32
	skill_cooldown = 0.0
	skill_animation_time = 0.0
	dash_cooldown = 0.0
	dash_time = 0.0
	jump_height = 0.0
	jump_velocity = 0.0
	landing_time = 0.0
	jump_takeoff_time = 0.0
	player_facing = 1
	player_stun_time = 0.0
	enemy_stun_time = 0.0
	player_knockdown_time = 0.0
	enemy_knockdown_time = 0.0
	player_ragdoll_blend = 0.0
	enemy_ragdoll_blend = 0.0
	enemy_attack_cooldown = 0.0
	enemy_attack_windup = 0.0
	enemy_attack_heavy = false
	enemy_attack_count = 0
	enemy_facing = -1
	move_direction = 0
	is_blocking = false
	block_hold_time = 0.0
	perfect_parry_flash = 0.0
	counter_window = 0.0
	stamina = MAX_STAMINA
	block_broken_time = 0.0
	if block_button != null:
		block_button.text = "BLOCK"
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
	button.button_down.connect(func(): move_direction = direction)
	button.button_up.connect(func(): move_direction = 0)
	parent.add_child(button)
	_style_game_button(button, Color("#344e70"), 16)
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
	button.pressed.connect(action)
	parent.add_child(button)
	_style_game_button(button, Color("#344e70"), 18)
	return button
func _attack() -> void:
	if not game_started or match_over or attack_cooldown > 0.0 or player_stun_time > 0.0 or player_knockdown_time > 0.0 or is_blocking:
		return
	player_facing = 1 if enemy_x >= player_x else -1

	# Tiga input berurutan dalam jendela waktu membentuk combo.
	if combo_window > 0.0:
		combo_step = (combo_step % 3) + 1
	else:
		combo_step = 1
	combo_window = 0.85
	attack_cooldown = 0.28
	attack_animation_duration = 0.32
	attack_animation_time = attack_animation_duration
	_play_sfx("sword" if selected_character == "Swordman" else ("axe" if selected_character == "Axeman" else "spear"))

	var stats: Dictionary = CHARACTERS[selected_character]
	var base_damage := int(stats["damage"])
	var combo_multiplier := 1.0
	match combo_step:
		2:
			combo_multiplier = 1.2
		3:
			combo_multiplier = 1.55
			attack_animation_duration = 0.42
			attack_animation_time = attack_animation_duration
	var damage := roundi(float(base_damage) * combo_multiplier)
	var is_counter := counter_window > 0.0
	if is_counter:
		damage = roundi(float(damage) * 1.5)
		counter_window = 0.0
	var attack_range := 190.0 if selected_character == "Spearman" else 155.0
	var combo_names := ["", "TEBASAN 1", "TEBASAN 2", "FINISHER!"]

	if absf(enemy_x - player_x) <= attack_range:
		enemy_hp = maxi(0, enemy_hp - damage)
		var knockback_direction := 1.0 if enemy_x >= player_x else -1.0
		var knockback_strength := 260.0
		if combo_step == 2:
			knockback_strength = 360.0
		elif combo_step == 3:
			knockback_strength = 620.0
		enemy_knockback_velocity = knockback_direction * knockback_strength
		enemy_stun_time = 1.15 if combo_step == 3 else (0.12 if combo_step == 1 else 0.20)
		if combo_step == 3:
			enemy_knockdown_time = 1.15
		enemy_attack_windup = 0.0
		enemy_attack_animation_time = 0.0
		enemy_hit_flash = 0.18
		enemy_ragdoll_blend = 1.0
		_shake_screen(10.0 if combo_step == 3 else 6.0)
		_trigger_hit_stop(0.065 if combo_step == 3 else 0.04)
		_play_sfx("heavy" if combo_step == 3 else "impact")
		impact_effect_time = 0.24
		impact_effect_x = enemy_x
		impact_effect_color = Color(CHARACTERS[selected_character]["color"])
		impact_effect_heavy = combo_step == 3
		status_label.text = "%s — %s! %sLawan kehilangan %d HP." % [selected_character.to_upper(), combo_names[combo_step], "COUNTER! " if is_counter else "", damage]
	else:
		status_label.text = "%s — %s meleset. Dekati lawan!" % [selected_character.to_upper(), combo_names[combo_step]]
	_update_ui()
	queue_redraw()



func _jump() -> void:
	if not game_started or match_over or jump_height > 0.0 or player_stun_time > 0.0 or player_knockdown_time > 0.0:
		return
	jump_velocity = 620.0
	jump_takeoff_time = 0.12
	_play_sfx("jump")
	status_label.text = "LOMPAT!"
	queue_redraw()

func _use_dash() -> void:
	if not game_started or match_over or dash_cooldown > 0.0 or player_stun_time > 0.0 or player_knockdown_time > 0.0:
		return
	if move_direction != 0:
		player_facing = move_direction
	dash_time = 0.18
	dash_cooldown = 2.5
	_play_sfx("dash")
	status_label.text = "DASH!"
	queue_redraw()

func _use_skill() -> void:
	if not game_started or match_over or skill_cooldown > 0.0 or player_stun_time > 0.0 or player_knockdown_time > 0.0 or is_blocking:
		return
	player_facing = 1 if enemy_x >= player_x else -1
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
	var skill_counter := counter_window > 0.0
	if skill_counter:
		skill_damage = roundi(float(skill_damage) * 1.5)
		counter_window = 0.0
	skill_cooldown = 6.0
	skill_animation_time = 0.58
	skill_cinematic_time = 0.62
	skill_cinematic_x = player_x
	skill_cinematic_color = Color(CHARACTERS[selected_character]["color"])
	_play_sfx("skill")
	if absf(enemy_x - player_x) <= skill_range:
		enemy_hp = maxi(0, enemy_hp - skill_damage)
		enemy_stun_time = 0.30
		enemy_attack_windup = 0.0
		enemy_attack_animation_time = 0.0
		enemy_knockback_velocity = (1.0 if enemy_x >= player_x else -1.0) * 520.0
		enemy_hit_flash = 0.28
		enemy_ragdoll_blend = 1.0
		_shake_screen(9.0)
		_trigger_hit_stop(0.06)
		_play_sfx("impact")
		impact_effect_time = 0.24
		impact_effect_x = enemy_x
		impact_effect_color = Color(CHARACTERS[selected_character]["color"])
		impact_effect_heavy = true
		status_label.text = "%s! %sLawan kehilangan %d HP." % [skill_name, "COUNTER! " if skill_counter else "", skill_damage]
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
	if stamina_bar != null:
		stamina_bar.value = stamina
	if stamina_label != null:
		stamina_label.text = "STAMINA: %d%%" % roundi(stamina)
	if block_button != null and not is_blocking:
		block_button.text = "LELAH!" if block_broken_time > 0.0 else "BLOCK"

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
