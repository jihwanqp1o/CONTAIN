# ACU-07 "ECHO" — 청각 실험체. 소리로 사냥하고, 빛 앞에서 물러선다.
extends CharacterBody2D

enum State { PATROL, INVESTIGATE, CHASE, RETREAT }
var current_state: State = State.PATROL

@export_group("Speed Settings")
@export var patrol_speed:      float = 45.0
@export var investigate_speed: float = 90.0
@export var chase_speed:       float = 195.0
@export var retreat_speed:     float = 75.0

@export_group("Detection Settings")
@export var sound_range:           float = 580.0
@export var close_detection_range: float = 110.0
@export var light_detection_range: float = 380.0

@export_group("Sound Effects")
@export var sfx_detect: AudioStream
@export var sfx_blind:  AudioStream

@onready var status_label   = $StatusLabel
@onready var detection_area = $DetectionArea

@export var patrol_bounds: Rect2 = Rect2(0, 0, 9999, 9999)

var _target_pos:    Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_wait:   float   = 0.0

var _shield_stagger_timer: float   = 0.0
var _shield_knockback_vel: Vector2 = Vector2.ZERO
var _stun_timer:           float   = 0.0
var _lunge_timer:          float   = 0.0
var _lunge_duration:       float   = 0.55   # 예고 총 시간
var _lunge_ready:          bool    = false
var _attack_ring:          Node2D  = null
var _hit_cooldown:         float   = 0.0
var _chase_sound_timer:    float   = 0.0
const CHASE_LOSE_TIME:     float   = 5.0

var _sfx_player:    AudioStreamPlayer
var _alert_label:   Label = null
var _alert_active:  bool  = false
var _attack_icon:   Label = null
var _los_check_timer: float = 0.0
var _last_in_light:   bool  = false
var _sfx_cries: Array = []

func _ready():
	add_to_group("enemy")
	modulate.a = 0.45
	collision_layer = 2   # 플레이어(레이어 1)와 물리 충돌 분리
	collision_mask  = 4   # 벽(레이어 3)만 감지
	_build_visual()
	_setup_alert_label()
	if status_label: status_label.text = ""

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

	_build_attack_icon()
	_pick_patrol_target()
	call_deferred("_connect_sound_signal")
	_sfx_cries = [load("res://assets/monster_cry1.mp3"), load("res://assets/monster_cry2.mp3")]

func _connect_sound_signal():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("sound_emitted"):
		player.sound_emitted.connect(_on_sound_emitted)

# 발소리가 들렸다. 그쪽으로 간다.
func _on_sound_emitted(pos: Vector2, intensity: float):
	if intensity < 0.40: return
	if current_state == State.RETREAT: return
	var _p = get_tree().get_first_node_in_group("player")
	if _p and _p.get("is_in_safe_zone"): return
	var dist = global_position.distance_to(pos)
	if dist > sound_range: return
	_target_pos = pos
	_chase_sound_timer = 0.0
	_enter_chase()

# =====================
# 메인 루프
# =====================
func _physics_process(delta):
	_update_light_reaction(delta)

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_label()
		return

	_hit_cooldown = max(0.0, _hit_cooldown - delta)

	if _shield_stagger_timer > 0:
		_shield_stagger_timer -= delta
		velocity = _shield_knockback_vel
	else:
		match current_state:
			State.PATROL:      _patrol_logic(delta)
			State.INVESTIGATE: _investigate_logic()
			State.CHASE:       _chase_logic()
			State.RETREAT:     _retreat_logic()

	move_and_slide()
	_sync_label()

func _sync_label():
	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-15.0, -70.0)
	if _attack_icon and _attack_icon.visible:
		_attack_icon.rotation        = 0.0
		_attack_icon.global_position = global_position + Vector2(-18.0, -90.0)
	if _attack_ring and _attack_ring.visible:
		_attack_ring.global_position = global_position

# 빛에 노출되면 물러난다. 빛이 사라지면 마지막으로 들은 곳으로 돌아온다.
func _update_light_reaction(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	if player.get("is_in_safe_zone"): return

	_los_check_timer -= delta
	if _los_check_timer <= 0.0:
		_los_check_timer = 0.12
		_last_in_light = _is_in_flashlight(player)
	var in_light = _last_in_light

	if in_light:
		modulate.a = move_toward(modulate.a, 1.0, 2.5 * delta)
		if current_state != State.RETREAT:
			_enter_retreat()
	else:
		if current_state == State.RETREAT:
			if _target_pos != Vector2.ZERO:
				_enter_investigate()
			else:
				_enter_patrol()
		modulate.a = move_toward(modulate.a, 0.45, 1.0 * delta)

func _patrol_logic(delta):
	if status_label: status_label.text = ""
	var to_tgt = _patrol_target - global_position
	if to_tgt.length() > 28.0:
		velocity = to_tgt.normalized() * patrol_speed
		rotation = to_tgt.normalized().angle()
	else:
		velocity = Vector2.ZERO
		_patrol_wait -= delta
		if _patrol_wait <= 0.0:
			_pick_patrol_target()

func _investigate_logic():
	if status_label: status_label.text = "?"
	var to_tgt = _target_pos - global_position
	if to_tgt.length() > 30.0:
		velocity = to_tgt.normalized() * investigate_speed
		rotation = to_tgt.normalized().angle()
	else:
		_target_pos = Vector2.ZERO
		_enter_patrol()

func _chase_logic():
	if status_label: status_label.text = "!"
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive or player.is_hidden_state:
		_lunge_timer = 0.0
		_lunge_ready = false
		_hide_attack_icon()
		_burst_attack_ring()
		_enter_investigate()
		return

	# 소리 없이 일정 시간 경과 → 포기
	_chase_sound_timer += get_physics_process_delta_time()
	if _chase_sound_timer >= CHASE_LOSE_TIME:
		_chase_sound_timer = 0.0
		_lunge_timer = 0.0
		_lunge_ready = false
		_hide_attack_icon()
		_burst_attack_ring()
		_enter_investigate()
		return

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	# 예고 진행 중 — 플레이어 방향으로 돌진
	if _lunge_timer > 0.0:
		_lunge_timer -= get_physics_process_delta_time()
		velocity = to_player.normalized() * 350.0
		if status_label: status_label.text = ""
		var progress = 1.0 - (_lunge_timer / _lunge_duration)
		_update_attack_ring(progress)
		if _lunge_timer <= 0.0:
			_lunge_ready = true
		return

	# 예고 완료 → 피해 판정
	if _lunge_ready:
		_lunge_ready = false
		modulate = Color(1.0, 1.0, 1.0)
		_hide_attack_icon()
		_burst_attack_ring()
		if dist < 85.0:
			player.note_attacker("Shade")
			player.take_damage()
			_hit_cooldown = 1.5
		return

	# 65px 이내 → 예고 시작 + 정확한 위치 갱신
	if dist < 65.0 and _lunge_timer <= 0.0:
		_target_pos = player.global_position
		_chase_sound_timer = 0.0
		_lunge_timer = _lunge_duration
		player.play_attack_sfx()
		_show_attack_icon()
		_show_attack_ring()
		return

	# 마지막으로 들은 위치로 이동 (플레이어 직접 추적 X)
	var move_to = _target_pos if _target_pos != Vector2.ZERO else player.global_position
	var to_move = move_to - global_position
	velocity = to_move.normalized() * chase_speed
	rotation = to_move.normalized().angle()

func _show_attack_ring():
	if not _attack_ring: return
	_attack_ring.visible = true
	for child in _attack_ring.get_children(): child.queue_free()
	var line = Line2D.new()
	line.width = 3.5
	line.default_color = Color(1.0, 0.22, 0.08, 0.90)
	var steps = 24
	for i in range(steps + 1):
		var a = (float(i) / float(steps)) * TAU
		line.add_point(Vector2(cos(a), sin(a)) * 75.0)
	line.closed = false
	_attack_ring.add_child(line)

func _update_attack_ring(progress: float):
	if not _attack_ring or not _attack_ring.visible: return
	_attack_ring.global_position = global_position
	# 반경: 75 → 15px 수축, 점점 빨개지며 두꺼워짐
	var r = lerp(75.0, 15.0, progress)
	var line = _attack_ring.get_child(0) if _attack_ring.get_child_count() > 0 else null
	if not line: return
	line.clear_points()
	var steps = 24
	for i in range(steps + 1):
		var a = (float(i) / float(steps)) * TAU
		line.add_point(Vector2(cos(a), sin(a)) * r)
	line.width = lerp(3.5, 6.0, progress)
	line.default_color = Color(1.0, lerp(0.22, 0.05, progress), lerp(0.08, 0.05, progress), 0.90)

func _burst_attack_ring():
	if not _attack_ring: return
	_attack_ring.visible = false
	for child in _attack_ring.get_children(): child.queue_free()

func _build_attack_icon():
	_attack_icon = Label.new()
	_attack_icon.text = "!!"
	_attack_icon.add_theme_font_size_override("font_size", 72)
	_attack_icon.add_theme_color_override("font_color", Color(1.0, 0.18, 0.08))
	_attack_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack_icon.z_index = 30
	_attack_icon.visible = false
	get_tree().root.add_child(_attack_icon)

	_attack_ring = Node2D.new()
	_attack_ring.z_index = 25
	_attack_ring.visible = false
	get_tree().root.add_child(_attack_ring)

func _show_attack_icon():
	if not _attack_icon: return
	_attack_icon.visible = true
	_attack_icon.scale   = Vector2(1.3, 1.3)
	var tw = create_tween()
	tw.tween_property(_attack_icon, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT)

func _hide_attack_icon():
	if not _attack_icon: return
	_attack_icon.visible = false

func _retreat_logic():
	if status_label: status_label.text = "~"
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_enter_patrol()
		return
	var away = (global_position - player.global_position).normalized()
	velocity = away * retreat_speed
	rotation = away.angle()

func _enter_patrol():
	current_state = State.PATROL
	if status_label: status_label.text = ""
	_pick_patrol_target()

func _enter_investigate():
	if current_state == State.INVESTIGATE: return
	current_state = State.INVESTIGATE
	_show_alert("?", Color(1.0, 0.85, 0.20))

# 소리의 원점을 향해 돌진한다. 도망쳐도 소용없다 — 귀는 거짓말하지 않는다.
func _enter_chase():
	if current_state == State.CHASE: return
	current_state = State.CHASE
	_chase_sound_timer = 0.0
	_play_random_cry()
	GlobalSave.mark_seen("shade_seen")
	_show_alert("!", Color(1.0, 0.15, 0.10))

# 빛 앞에서만 겁쟁이가 된다.
func _enter_retreat():
	if current_state == State.RETREAT: return
	current_state = State.RETREAT
	_play_sfx(sfx_blind)
	_show_alert("~", Color(0.55, 0.75, 1.0))

# 시야가 없어도 너무 가까우면 감지한다.
func _check_close_player():
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive or player.is_hidden_state: return
	if player.get("is_in_safe_zone"): return
	var dist = global_position.distance_to(player.global_position)
	if dist < close_detection_range and _has_los_to(player.global_position):
		_target_pos = player.global_position
		_enter_chase()

func receive_shield_block(player_pos: Vector2):
	var dir = (global_position - player_pos).normalized()
	_shield_knockback_vel = dir * 280.0
	_shield_stagger_timer = 0.6
	_show_alert("!", Color(1.0, 0.6, 0.0))

func stop_chasing_forced():
	_target_pos  = Vector2.ZERO
	velocity     = Vector2.ZERO
	_lunge_timer = 0.0
	_lunge_ready = false
	_hide_attack_icon()
	_burst_attack_ring()
	current_state = State.PATROL
	_pick_patrol_target()

func alert_by_herald():
	if current_state != State.PATROL: return
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive: return
	_target_pos = player.global_position
	_enter_chase()

func attract_to_noise(pos: Vector2) -> void:
	if current_state == State.RETREAT: return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_in_safe_zone"): return
	_target_pos = pos
	_chase_sound_timer = 0.0
	_enter_chase()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_attack_icon): _attack_icon.queue_free()
		if is_instance_valid(_attack_ring): _attack_ring.queue_free()

# 불에는 버티지 못한다.
func receive_flare_hit():
	if not is_in_group("enemy"): return
	_hide_attack_icon()
	remove_from_group("enemy")
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	if col: col.set_deferred("disabled", true)
	_play_death_sfx()
	modulate = Color(2.5, 0.8, 0.1, modulate.a)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.0, 0.0), 0.38)
	tw.parallel().tween_property(self, "scale", Vector2(1.7, 1.7), 0.38)
	tw.tween_callback(queue_free)

# 폭발음을 빛과 구분하지 못한다 — 소리가 나면 그리로 간다.
func receive_flare_bang(origin: Vector2):
	if not is_in_group("enemy"): return
	if current_state == State.RETREAT or current_state == State.CHASE: return
	_target_pos = origin
	if current_state != State.INVESTIGATE:
		_enter_investigate()

func receive_rock_hit():
	receive_flare_hit()

# =====================
# 유틸
# =====================
func _pick_patrol_target() -> void:
	var m = 80.0
	var b = patrol_bounds
	_patrol_target = Vector2(
		randf_range(b.position.x + m, b.end.x - m),
		randf_range(b.position.y + m, b.end.y - m)
	)
	_patrol_wait = randf_range(0.8, 2.2)

func _has_los_to(target_pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	params.collision_mask = 4
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

func _is_in_flashlight(player) -> bool:
	if not player.flashlight_on: return false
	var to_self = global_position - player.global_position
	var dist = to_self.length()
	if dist > light_detection_range: return false
	var player_fwd = Vector2.RIGHT.rotated(player.rotation)
	if player_fwd.dot(to_self.normalized()) < cos(0.42): return false
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(player.global_position, global_position)
	params.collision_mask = 4
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

func _play_sfx(stream: AudioStream):
	if stream == null: return
	_sfx_player.stream = stream
	_sfx_player.play()

func _play_random_cry() -> void:
	if _sfx_cries.is_empty(): return
	var p = AudioStreamPlayer.new()
	p.stream = _sfx_cries[randi() % _sfx_cries.size()]
	p.volume_db = -10.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _play_death_sfx() -> void:
	var p = AudioStreamPlayer.new()
	p.stream = load("res://assets/monster_death.mp3")
	p.volume_db = -8.0
	if get_parent(): get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _setup_alert_label():
	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 52)
	_alert_label.z_index    = 20
	_alert_label.modulate.a = 0.0
	add_child(_alert_label)

func _show_alert(text: String, color: Color):
	if _alert_active or not _alert_label: return
	_alert_active = true
	_alert_label.text = text
	_alert_label.add_theme_color_override("font_color", color)
	_alert_label.scale      = Vector2(2.2, 2.2)
	_alert_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(_alert_label, "scale",      Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(0.65)
	tween.tween_property(_alert_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): _alert_active = false)

# =====================
# 비주얼
# =====================
func _build_visual():
	add_child(_make_circle_poly(28.0, 8, Color(0.60, 0.05, 0.0)))
	add_child(_make_circle_poly(24.0, 8, Color(1.0, 0.50, 0.05)))
	var eye = _make_circle_poly(5.0, 8, Color(1.0, 1.0, 0.0))
	eye.position = Vector2(14.0, 0.0)
	add_child(eye)

func _make_circle_poly(radius: float, segments: int, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts  = PackedVector2Array()
	for i in range(segments):
		var angle = (2.0 * PI * i) / segments
		pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	poly.polygon = pts
	poly.color   = color
	return poly
