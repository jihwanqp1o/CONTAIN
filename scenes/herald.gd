extends CharacterBody2D

enum State { PATROL, BROADCAST, FLEE }
var current_state: State = State.PATROL

const BODY_RADIUS: float   = 20.0
const PLAYER_RADIUS: float = 30.0

@export_group("Detection")
@export var detection_range: float        = 220.0  # FOV 감지, 몸 표면 기준
@export var fov_angle: float              = 120.0  # 전방 시야각
@export var sound_range: float            = 500.0  # 달리기 소리 감지 거리
@export var flashlight_sound_range: float = 300.0  # A안: 손전등 토글 감지 거리

@export_group("Broadcast")
@export var broadcast_radius: float   = 780.0   # 몬스터 활성화 반경
@export var broadcast_duration: float = 0.45    # 방송 지속 시간 (시각 효과)
@export var broadcast_cooldown_time: float = 3.0  # E안: 재방송 금지 시간

@export_group("Movement")
@export var patrol_speed: float = 90.0
@export var flee_speed: float   = 310.0
@export var flee_duration: float = 1.6

var _patrol_timer:    float   = 0.0
var _patrol_dir:      Vector2 = Vector2.RIGHT
var _broadcast_timer: float   = 0.0
var _flee_timer:      float   = 0.0
var _flee_dir:        Vector2 = Vector2.ZERO
var _player_last_pos: Vector2 = Vector2.ZERO
var _second_broadcast_used: bool  = false  # B안
var _zigzag_timer:          float = 0.0    # C안
var _broadcast_cooldown:    float = 0.0    # E안

var _alert_label:  Label    = null
var _alert_active: bool     = false
var _wave_ring:    Line2D   = null
var _wave_radius:  float    = 0.0
var _wave_active:  bool     = false
var _sfx_roar:     AudioStream = null

func _ready():
	add_to_group("enemy")
	_build_visual()
	_setup_alert_label()
	_randomize_patrol()
	_sfx_roar = load("res://assets/small_roar.mp3")
	call_deferred("_connect_sound_signal")

func _connect_sound_signal():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("sound_emitted"):
		player.sound_emitted.connect(_on_sound_emitted)

func _on_sound_emitted(pos: Vector2, intensity: float):
	if current_state != State.PATROL: return
	if _broadcast_cooldown > 0.0: return  # E안
	var dist = global_position.distance_to(pos)
	# A안: 손전등(0.65+)은 짧은 거리, 달리기(0.45+)는 긴 거리
	if intensity >= 0.64:
		if dist > flashlight_sound_range: return
	elif intensity >= 0.44:
		if dist > sound_range: return
	else:
		return
	_player_last_pos = pos
	_enter_broadcast()

# ─────────────────────────────
# 메인 루프
# ─────────────────────────────

func _physics_process(delta):
	_broadcast_cooldown = max(0.0, _broadcast_cooldown - delta)  # E안

	match current_state:
		State.PATROL:    _patrol_logic(delta)
		State.BROADCAST: _broadcast_logic(delta)
		State.FLEE:      _flee_logic(delta)

	move_and_slide()

	# 방송 링 확장
	if _wave_active:
		_wave_radius += 420.0 * delta
		_update_wave_ring()
		if _wave_radius >= broadcast_radius:
			_wave_active = false
			if _wave_ring: _wave_ring.visible = false

	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-12.0, -58.0)

# ─────────────────────────────
# 상태 로직
# ─────────────────────────────

func _patrol_logic(delta):
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_randomize_patrol()

	velocity = _patrol_dir * patrol_speed
	if velocity.length() > 0.1:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 5.0)

	# FOV 감지 — E안: 쿨다운 중 재방송 불가
	if _broadcast_cooldown > 0.0: return
	var player = _get_player()
	if not player: return
	var sneaking  = "is_sneaking" in player and player.is_sneaking
	var eff_range = detection_range * 0.25 if sneaking else detection_range
	var to_player = player.global_position - global_position
	var body_gap  = to_player.length() - BODY_RADIUS
	if body_gap > eff_range: return
	var ang_diff = abs(angle_difference(to_player.angle(), rotation))
	if ang_diff < deg_to_rad(fov_angle * 0.5) and _has_los_to(player.global_position):
		_player_last_pos = player.global_position
		_enter_broadcast()

func _broadcast_logic(delta):
	velocity          = Vector2.ZERO
	_broadcast_timer -= delta
	# 몸 빛남 효과
	var t    = 1.0 - clamp(_broadcast_timer / broadcast_duration, 0.0, 1.0)
	modulate = Color(1.0 + t * 0.6, 1.0 + t * 0.5, 0.4 + t * 0.2, 1.0)
	if _broadcast_timer <= 0.0:
		_enter_flee()

func _flee_logic(delta):
	_flee_timer -= delta

	# C안: 지그재그 도주
	_zigzag_timer -= delta
	if _zigzag_timer <= 0.0:
		_flee_dir     = _flee_dir.rotated(randf_range(-deg_to_rad(25.0), deg_to_rad(25.0)))
		_zigzag_timer = randf_range(0.3, 0.6)

	velocity = _flee_dir * flee_speed
	rotation = lerp_angle(rotation, velocity.angle(), delta * 8.0)

	# B안: 도주 중 재감지 → 2차 방송 (1회 한정)
	if not _second_broadcast_used:
		var player = _get_player()
		if player:
			var to_player = player.global_position - global_position
			var body_gap  = to_player.length() - BODY_RADIUS
			if body_gap <= detection_range:
				var ang_diff = abs(angle_difference(to_player.angle(), rotation))
				if ang_diff < deg_to_rad(fov_angle * 0.5):
					_second_broadcast()

	if _flee_timer <= 0.0:
		_enter_patrol()

# ─────────────────────────────
# 상태 전환
# ─────────────────────────────

func _enter_broadcast():
	current_state       = State.BROADCAST
	_broadcast_timer    = broadcast_duration
	_broadcast_cooldown = broadcast_cooldown_time  # E안
	velocity            = Vector2.ZERO
	modulate            = Color(1.5, 1.4, 0.5, 1.0)
	GlobalSave.mark_seen("herald_seen")
	_play_roar()
	_show_alert("▶▶", Color(1.0, 0.85, 0.15))

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self: continue
		if global_position.distance_to(enemy.global_position) <= broadcast_radius:
			enemy.alert_by_herald()

	_wave_radius = BODY_RADIUS
	_wave_active = true
	if _wave_ring: _wave_ring.visible = true

func _second_broadcast():
	_second_broadcast_used = true
	var radius = broadcast_radius * 1.5
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self: continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.alert_by_herald()
	_wave_radius = BODY_RADIUS
	_wave_active = true
	if _wave_ring: _wave_ring.visible = true
	_show_alert("▶▶▶", Color(1.0, 0.45, 0.1))

func _enter_flee():
	current_state = State.FLEE
	_flee_timer   = flee_duration
	_flee_dir     = (global_position - _player_last_pos).normalized()
	if _flee_dir.length() < 0.1:
		_flee_dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
	modulate = Color(0.7, 0.85, 1.0, 1.0)

func _enter_patrol():
	current_state          = State.PATROL
	_second_broadcast_used = false  # B안 플래그 리셋
	modulate               = Color(1.0, 1.0, 1.0, 1.0)
	_randomize_patrol()

func _randomize_patrol():
	_patrol_timer = randf_range(1.8, 3.5)
	_patrol_dir   = Vector2(randf() - 0.5, randf() - 0.5).normalized()

# ─────────────────────────────
# 공통 메서드
# ─────────────────────────────

func _has_los_to(target_pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	params.collision_mask = 4
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

func stop_chasing_forced():
	pass  # 전령은 플레이어를 추격하지 않음 — 무시

func alert_by_herald():
	pass  # 전령은 전령에게 반응하지 않음

func receive_flare_hit():
	if not is_in_group("enemy"): return
	remove_from_group("enemy")
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	if col: col.set_deferred("disabled", true)
	_play_roar()
	modulate = Color(2.5, 0.8, 0.1, modulate.a)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.0, 0.0), 0.38)
	tw.parallel().tween_property(self, "scale", Vector2(1.7, 1.7), 0.38)
	tw.tween_callback(queue_free)

func receive_flare_bang(_origin: Vector2):
	if not is_in_group("enemy"): return
	# D안: 패닉 방송 후 도주
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self: continue
		if global_position.distance_to(enemy.global_position) <= broadcast_radius:
			enemy.alert_by_herald()
	_wave_radius = BODY_RADIUS
	_wave_active = true
	if _wave_ring: _wave_ring.visible = true
	_show_alert("▶▶", Color(1.0, 0.3, 0.1))
	_enter_flee()

func receive_rock_hit():
	receive_flare_hit()

# ─────────────────────────────
# 유틸
# ─────────────────────────────

func _get_player():
	var p = get_tree().get_first_node_in_group("player")
	if not p or not p.is_alive: return null
	if "is_hidden_state" in p and p.is_hidden_state: return null
	if "is_in_safe_zone" in p and p.is_in_safe_zone: return null
	return p

func _play_roar() -> void:
	if not _sfx_roar: return
	var p = AudioStreamPlayer.new()
	p.stream = _sfx_roar
	p.volume_db = -8.0
	p.pitch_scale = 1.6
	if get_parent(): get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _update_wave_ring():
	if not _wave_ring: return
	_wave_ring.clear_points()
	var steps = 40
	for i in range(steps + 1):
		var a = (float(i) / float(steps)) * TAU
		_wave_ring.add_point(Vector2(cos(a), sin(a)) * _wave_radius)
	var t = clamp(_wave_radius / broadcast_radius, 0.0, 1.0)
	_wave_ring.default_color = Color(1.0, 0.85, 0.15, (1.0 - t) * 0.75)
	_wave_ring.width = 4.0 * (1.0 - t * 0.6)

func _setup_alert_label():
	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 36)
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
	var tw = create_tween()
	tw.tween_property(_alert_label, "scale",      Vector2(1.0, 1.0), 0.18)
	tw.tween_interval(0.5)
	tw.tween_property(_alert_label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _alert_active = false)

# ─────────────────────────────
# 비주얼: 날렵한 유선형 + 방송 링
# ─────────────────────────────

func _build_visual():
	# 방송 링 (확장 이펙트)
	_wave_ring         = Line2D.new()
	_wave_ring.width   = 4.0
	_wave_ring.default_color = Color(1.0, 0.85, 0.15, 0.7)
	_wave_ring.z_index = 3
	_wave_ring.visible = false
	add_child(_wave_ring)

	# 외곽 유선형 몸체
	var outer = Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2( 22.0,  0.0),
		Vector2(  6.0, -12.0),
		Vector2(-16.0, -7.0),
		Vector2(-20.0,  0.0),
		Vector2(-16.0,  7.0),
		Vector2(  6.0,  12.0),
	])
	outer.color = Color(0.14, 0.18, 0.24)
	add_child(outer)

	# 내부 몸체
	var inner = Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2( 14.0,  0.0),
		Vector2(  4.0, -7.5),
		Vector2(-10.0, -4.5),
		Vector2(-13.0,  0.0),
		Vector2(-10.0,  4.5),
		Vector2(  4.0,  7.5),
	])
	inner.color = Color(0.55, 0.72, 0.90)
	add_child(inner)

	# 전면 발광점
	var eye = Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(22.0,  0.0),
		Vector2(14.0, -5.0),
		Vector2(14.0,  5.0),
	])
	eye.color = Color(0.95, 0.88, 0.25)
	add_child(eye)
