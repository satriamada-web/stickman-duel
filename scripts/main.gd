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
var dash_cooldown := 0.0
var dash_time := 0.0
var jump_height := 0.0
var jump_velocity := 0.0
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
var impact_effect_time := 0.0
var impact_effect_x := 0.0
var enemy_attack_cooldown := 0.0
var enemy_attack_windup := 0.0
var enemy_attack_heavy := false
var enemy_attack_count := 0
var move_direction := 0
var is_blocking := false
var stamina := MAX_STAMINA
var block_broken_time := 0.0
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
	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	enemy_attack_animation_time = maxf(0.0, enemy_attack_animation_time - delta)
	player_hit_flash = maxf(0.0, player_hit_flash - delta)
	enemy_hit_flash = maxf(0.0, enemy_hit_flash - delta)
	player_stun_time = maxf(0.0, player_stun_time - delta)
	enemy_stun_time = maxf(0.0, enemy_stun_time - delta)
	impact_effect_time = maxf(0.0, impact_effect_time - delta)
	block_broken_time = maxf(0.0, block_broken_time - delta)
	if is_blocking:
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
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if jump_height > 0.0 or jump_velocity > 0.0:
		jump_height += jump_velocity * delta
		jump_velocity -= 1500.0 * delta
		if jump_height <= 0.0:
			jump_height = 0.0
			jump_velocity = 0.0
	enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
	if enemy_attack_windup > 0.0:
		enemy_attack_windup = maxf(0.0, enemy_attack_windup - delta)
		if enemy_attack_windup <= 0.0:
			_resolve_enemy_attack()
	var stats: Dictionary = CHARACTERS[selected_character]
	if move_direction != 0 and player_stun_time <= 0.0:
		player_facing = move_direction
	var current_speed := float(stats["speed"])
	if player_stun_time <= 0.0:
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
	if enemy_stun_time > 0.0:
		pass
	elif distance > 125.0 and absf(enemy_knockback_velocity) <= 8.0:
		enemy_x = move_toward(enemy_x, player_x, 145.0 * delta)
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
	if absf(enemy_x - player_x) > 155.0:
		status_label.text = "SERANGAN LAWAN MELESET!"
		return
	if dash_time > 0.0 or jump_height >= 45.0:
		status_label.text = "BERHASIL MENGHINDAR!"
		return
	var base_damage := 14 if enemy_attack_heavy else 8
	var incoming_damage := (4 if enemy_attack_heavy else 2) if is_blocking else base_damage
	if is_blocking and stamina <= 0.0:
		incoming_damage = base_damage
	player_hp = maxi(0, player_hp - incoming_damage)
	if not is_blocking:
		player_x = clampf(player_x - float(player_facing) * (145.0 if enemy_attack_heavy else 95.0), 70.0, 1210.0)
		player_stun_time = 0.34 if enemy_attack_heavy else 0.20
	else:
		player_stun_time = 0.10 if enemy_attack_heavy else 0.06
	player_hit_flash = 0.28
	_shake_screen(5.0 if is_blocking else 8.0)
	_trigger_hit_stop(0.035 if is_blocking else 0.055)
	_play_sfx("block" if is_blocking else ("heavy" if enemy_attack_heavy else "impact"))
	impact_effect_time = 0.24
	impact_effect_x = player_x
	if is_blocking:
		status_label.text = ("SERANGAN KUAT DITAHAN! Damage %d." if enemy_attack_heavy else "BLOCK BERHASIL! Damage %d.") % incoming_damage
	else:
		status_label.text = ("TERKENA SERANGAN KUAT! -%d HP" if enemy_attack_heavy else "KAMU TERKENA SERANGAN! -%d HP") % incoming_damage

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
	_draw_fighter(player_x, FLOOR_Y - jump_height, player_tint, player_facing, str(player_stats["weapon"]), move_direction != 0 or dash_time > 0.0, maxf(attack_animation_time, skill_animation_time), 0.42 if skill_animation_time > attack_animation_time else attack_animation_duration, dash_time > 0.0, jump_height > 0.0, combo_step, player_hit_flash, selected_character)
	_draw_fighter(enemy_x, FLOOR_Y, enemy_tint, -1, "AXE", absf(enemy_x - player_x) > 125.0, enemy_attack_animation_time, 0.24, false, false, 1, enemy_hit_flash, "Axeman")
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

func _draw_fighter(x: float, floor_y: float, tint: Color, direction: int, weapon: String, walking: bool, attack_time: float, attack_duration: float, dashing: bool, airborne: bool, combo_style: int, hit_time: float, fighter_name: String) -> void:
	# Animasi prosedural dengan fase ancang-ancang, ayunan, dan pemulihan.
	var phase := animation_time * (13.0 if walking else 2.2)
	var stride := sin(phase) if walking else 0.0
	var idle_breath := sin(animation_time * 2.4)
	var idle_phase := animation_time * 1.7 + (0.0 if fighter_name == "Swordman" else (1.1 if fighter_name == "Axeman" else 2.0))
	var idle_sway := sin(idle_phase)
	var is_idle := not walking and attack_time <= 0.0 and not dashing and not airborne and hit_time <= 0.0
	var idle_strength := 1.0 if is_idle else 0.0
	var bob := absf(sin(phase * 2.0)) * 5.0 if walking else idle_breath * 1.8 + absf(idle_sway) * 1.2 * idle_strength
	var lean := 0.0
	if dashing:
		lean = -float(direction) * 13.0
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
	var front_knee := hip + Vector2(14.0 * direction + leg_swing, 25.0 + absf(stride) * 4.0)
	var back_knee := hip + Vector2(-12.0 * direction - leg_swing, 25.0 + absf(stride) * 4.0)
	var front_foot := front_knee + Vector2(13.0 * direction + leg_swing * 0.7, 21.0 - absf(stride) * 9.0)
	var back_foot := back_knee + Vector2(-10.0 * direction - leg_swing * 0.7, 21.0 - absf(stride) * 9.0)

	var front_elbow := shoulder + Vector2(18.0 * direction - stride * 9.0 + idle_sway * 2.0 * idle_strength, 17.0 + idle_breath * 2.0 * idle_strength)
	var front_hand := front_elbow + Vector2(13.0 * direction - stride * 7.0 + idle_sway * 1.5 * idle_strength, 13.0 + idle_breath * 2.5 * idle_strength)
	var back_elbow := shoulder + Vector2(-18.0 * direction + stride * 9.0 - idle_sway * 1.5 * idle_strength, 15.0)
	var back_hand := back_elbow + Vector2(-13.0 * direction + stride * 7.0, 14.0 + idle_breath * 2.0 * idle_strength)

	if attack_time > 0.0:
		var progress := 1.0 - clampf(attack_time / maxf(attack_duration, 0.01), 0.0, 1.0)
		var windup := 1.0 - clampf(progress / 0.28, 0.0, 1.0)
		var strike := sin(clampf((progress - 0.18) / 0.58, 0.0, 1.0) * PI)
		var reach := 58.0 * strike
		front_elbow = shoulder + Vector2((23.0 - 15.0 * windup + reach * 0.35) * direction, -7.0 - 7.0 * strike)
		front_hand = shoulder + Vector2((37.0 - 22.0 * windup + reach) * direction, -13.0 - 12.0 * strike)
		back_elbow = shoulder + Vector2(-22.0 * direction, 19.0)
		back_hand = back_elbow + Vector2(-14.0 * direction, 9.0)

		# Tiap senjata memiliki bentuk ayunan yang berbeda.
		if weapon == "SPEAR":
			front_elbow = shoulder + Vector2(34.0 * direction, -2.0)
			front_hand = shoulder + Vector2((72.0 if combo_style != 3 else 92.0) * direction, -4.0)
		elif weapon == "AXE":
			var axe_swing := 1.0 if combo_style == 3 else 0.65
			front_elbow = shoulder + Vector2(17.0 * direction, -24.0 * axe_swing)
			front_hand = shoulder + Vector2(40.0 * direction, -34.0 * axe_swing + 8.0)
		elif combo_style == 2:
			front_elbow = shoulder + Vector2(30.0 * direction, 12.0)
			front_hand = shoulder + Vector2(64.0 * direction, 19.0)
		elif combo_style == 3:
			front_elbow = shoulder + Vector2(30.0 * direction, -24.0)
			front_hand = shoulder + Vector2(76.0 * direction, -34.0)

		front_knee += Vector2(-5.0 * direction * windup, 0.0)
		front_foot += Vector2(-7.0 * direction * windup, 0.0)

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
		# Pose melayang: lutut terangkat dan kedua tangan terbuka untuk menjaga keseimbangan.
		front_knee = hip + Vector2(25.0 * direction, 7.0)
		front_foot = front_knee + Vector2(15.0 * direction, -16.0)
		back_knee = hip + Vector2(-19.0 * direction, 13.0)
		back_foot = back_knee + Vector2(-13.0 * direction, -15.0)
		front_elbow = shoulder + Vector2(23.0 * direction, -19.0)
		front_hand = front_elbow + Vector2(18.0 * direction, -10.0)
		back_elbow = shoulder + Vector2(-22.0 * direction, -15.0)
		back_hand = back_elbow + Vector2(-17.0 * direction, -8.0)

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
	var weapon_tip := front_hand + Vector2(48.0 * direction + idle_weapon_sway * 2.0, -12.0 + idle_breath * 2.0 * idle_strength)
	if weapon == "SPEAR":
		weapon_tip = front_hand + Vector2(78.0 * direction + idle_weapon_sway * 4.0, -5.0 + idle_breath * 3.0 * idle_strength)
		draw_line(front_hand, weapon_tip, Color("#f5d78e"), 5.0, true)
		draw_line(weapon_tip, weapon_tip + Vector2(12.0 * direction, -2.0), Color("#dce7f2"), 3.0, true)
	elif weapon == "AXE":
		weapon_tip = front_hand + Vector2(36.0 * direction + idle_weapon_sway * 3.0, -12.0 + idle_breath * 3.5 * idle_strength)
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
	is_blocking = value and game_started and not match_over and player_stun_time <= 0.0 and stamina > 0.0 and block_broken_time <= 0.0
	if is_blocking and not was_blocking:
		_play_sfx("block")
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
	player_facing = 1
	player_stun_time = 0.0
	enemy_stun_time = 0.0
	enemy_attack_cooldown = 0.0
	enemy_attack_windup = 0.0
	enemy_attack_heavy = false
	enemy_attack_count = 0
	move_direction = 0
	is_blocking = false
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
	if not game_started or match_over or attack_cooldown > 0.0 or player_stun_time > 0.0:
		return

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
		enemy_stun_time = 0.12 if combo_step == 1 else (0.20 if combo_step == 2 else 0.36)
		enemy_attack_windup = 0.0
		enemy_attack_animation_time = 0.0
		enemy_hit_flash = 0.18
		_shake_screen(10.0 if combo_step == 3 else 6.0)
		_trigger_hit_stop(0.065 if combo_step == 3 else 0.04)
		_play_sfx("heavy" if combo_step == 3 else "impact")
		impact_effect_time = 0.24
		impact_effect_x = enemy_x
		status_label.text = "%s — %s! Lawan kehilangan %d HP." % [selected_character.to_upper(), combo_names[combo_step], damage]
	else:
		status_label.text = "%s — %s meleset. Dekati lawan!" % [selected_character.to_upper(), combo_names[combo_step]]
	_update_ui()
	queue_redraw()



func _jump() -> void:
	if not game_started or match_over or jump_height > 0.0 or player_stun_time > 0.0:
		return
	jump_velocity = 620.0
	_play_sfx("jump")
	status_label.text = "LOMPAT!"
	queue_redraw()

func _use_dash() -> void:
	if not game_started or match_over or dash_cooldown > 0.0 or player_stun_time > 0.0:
		return
	if move_direction != 0:
		player_facing = move_direction
	dash_time = 0.18
	dash_cooldown = 2.5
	_play_sfx("dash")
	status_label.text = "DASH!"
	queue_redraw()

func _use_skill() -> void:
	if not game_started or match_over or skill_cooldown > 0.0 or player_stun_time > 0.0:
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
	_play_sfx("skill")
	if absf(enemy_x - player_x) <= skill_range:
		enemy_hp = maxi(0, enemy_hp - skill_damage)
		enemy_stun_time = 0.30
		enemy_attack_windup = 0.0
		enemy_attack_animation_time = 0.0
		enemy_knockback_velocity = (1.0 if enemy_x >= player_x else -1.0) * 520.0
		enemy_hit_flash = 0.28
		_shake_screen(9.0)
		_trigger_hit_stop(0.06)
		_play_sfx("impact")
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
