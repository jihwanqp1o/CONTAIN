extends CharacterBody2D

enum State { GUARD, ALERT, SHOCKWAVE, SW_PAUSE, COOLDOWN }
var current_state: State = State.GUARD

const BODY_RADIUS: float   = 28.0
const PLAYER_RADIUS: float = 30.0

@export_group("Detection")
@export var detection_range: float = 340.0   # 몸 표면 기준 — 내부 위험 원과 일치

@export_group("Scanning")
@export var scan_speed: float    = 0.8
@export var scan_half_arc: float = 45.0

@export_group("Shockwave")
@export var alert_duration: float      = 1.2    # 충격파 발사 전 경고 시간
@export var shockwave_speed: float     = 300.0  # 충격파 확장 속도 px/s
@export var shockwave_thickness: float = 55.0   # 피격 두께
@export var cooldown_duration: float   = 2.8    # 재공격 전 대기
@export_group("Double Wave")
@export var second_wave_pause: float   = 0.8    # 1·2차 충격파 사이 간격
@export_group("Outer Detection")
@export var outer_detect_time: float   = 0.4    # 노란 원 진입 후 무리 파견까지 인식 시간

var _alert_timer:    float    = 0.0
var _blink_timer:    float    = 0.0
var _cooldown_timer: float    = 0.0
var _scan_dir:       float    = 1.0
var _base_rot:       float    = 0.0
var _spawn_captured: bool     = false

var _sw_radius:       float  = 0.0
var _sw_max:          float  = 0.0
var _sw_hit_done:     bool   = false
var _sw_ring:         Line2D = null
var _sw_wave:         int    = 1    # C안: 현재 충격파 번호 (1=빨간 원, 2=노란 원)
var _sw_pause_timer:  float  = 0.0
var _outer_detect_timer: float = 0.0  # B안: 노란 원 인식 누적

var _alert_label:  Label    = null
var _alert_active: bool     = false
var _fov_poly:     Polygon2D = null
var _charge_poly:  Polygon2D = null  # 경고 중 충전 시각화
var _flare_hp:     int      = 2
var _sfx_roar:     AudioStream = null

# ── 부하 관리 ─────────────────────────
var _patrol_radius: float  = 0.0   # 바깥 영역 원 반경 (시각 전용)
var _subordinates: Array   = []    # 파수꾼 부하 무리 목록
var _sub_homes: Dictionary = {}    # 부하별 서식 위치
var _subs_active: bool     = false # 부하 현재 활성화 여부

func _ready():
	add_to_group("enemy")
	_base_rot = rotation
	_build_visual()
	_setup_alert_label()
	_patrol_radius = (detection_range + BODY_RADIUS) * 2.1
	_sfx_roar = load("res://assets/small_roar.mp3")

func _physics_process(delta):
	if not _spawn_captured:
		_spawn_captured = true

	match current_state:
		State.GUARD:     _guard_logic(delta)
		State.ALERT:     _alert_logic(delta)
		State.SHOCKWAVE: _shockwave_logic(delta)
		State.SW_PAUSE:  _sw_pause_logic(delta)
		State.COOLDOWN:  _cooldown_logic(delta)

	move_and_slide()

	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-12.0, -68.0)

# ─────────────────────────────
# 상태 로직
# ─────────────────────────────

func _guard_logic(delta):
	velocity = Vector2.ZERO

	rotation += scan_speed * _scan_dir * delta
	var rel = angle_difference(rotation, _base_rot)
	if rel > deg_to_rad(scan_half_arc):
		_scan_dir = -1.0
	elif rel < -deg_to_rad(scan_half_arc):
		_scan_dir = 1.0

	var player = _get_player()

	# B안: 노란 원 — 0.4s 인식 후 무리 파견
	var in_territory = player != null and \
		global_position.distance_to(player.global_position) <= _patrol_radius
	if in_territory:
		if not _subs_active:
			_outer_detect_timer += delta
			if _outer_detect_timer >= outer_detect_time:
				_subs_active = true
				_outer_detect_timer = 0.0
				_activate_subordinates(player)
	else:
		_outer_detect_timer = 0.0
		if _subs_active:
			_subs_active = false
			_recall_subordinates()

	if not player: return
	var body_gap = global_position.distance_to(player.global_position) - BODY_RADIUS
	if body_gap <= detection_range and _has_los_to(player.global_position):
		_enter_alert()

func _alert_logic(delta):
	velocity      = Vector2.ZERO
	_alert_timer -= delta
	_blink_timer += delta

	# 몸체 붉은 깜빡임
	var blink = sin(_blink_timer * 14.0) * 0.5 + 0.5
	modulate = Color(1.0, 0.10 + blink * 0.25, 0.05, 1.0)

	# 충전 원 확장 (경고 진행률에 따라 커짐)
	var progress = 1.0 - clamp(_alert_timer / alert_duration, 0.0, 1.0)
	if _charge_poly:
		var r = (detection_range + BODY_RADIUS) * progress
		_update_circle_poly(_charge_poly, r)
		_charge_poly.color = Color(1.0, 0.3, 0.05, 0.18 * progress)

	# 플레이어 방향 추적
	var player = _get_player()
	if player:
		var dir = player.global_position - global_position
		if dir.length() > 1.0:
			rotation = dir.angle()

	if _alert_timer <= 0.0:
		_enter_shockwave()

func _shockwave_logic(delta):
	velocity = Vector2.ZERO
	_sw_radius += shockwave_speed * delta

	# 충격파 링 업데이트
	if _sw_ring:
		_sw_ring.clear_points()
		var steps = 40
		for i in range(steps + 1):
			var a = (float(i) / float(steps)) * TAU
			_sw_ring.add_point(Vector2(cos(a), sin(a)) * _sw_radius)
		var t = clamp(_sw_radius / _sw_max, 0.0, 1.0)
		_sw_ring.default_color = Color(1.0, 0.4 - t * 0.3, 0.05, 1.0 - t * 0.65)
		_sw_ring.width = shockwave_thickness * (1.0 - t * 0.4)

	# 피격 판정 (프레임당 1회)
	if not _sw_hit_done:
		var player = _get_player()
		if player:
			var dist  = global_position.distance_to(player.global_position)
			var inner = _sw_radius - shockwave_thickness * 0.5
			var outer = _sw_radius + shockwave_thickness * 0.5
			if dist >= inner and dist <= outer:
				player.note_attacker("파수꾼")
				player.take_damage()
				_sw_hit_done = true

	if _sw_radius >= _sw_max:
		if _sw_wave == 1:
			_enter_sw_pause()
		else:
			_enter_cooldown()

func _cooldown_logic(delta):
	velocity         = Vector2.ZERO
	_cooldown_timer -= delta
	modulate.r = move_toward(modulate.r, 1.0, delta * 1.5)
	modulate.g = move_toward(modulate.g, 1.0, delta * 1.5)
	modulate.b = move_toward(modulate.b, 1.0, delta * 1.5)
	if _cooldown_timer <= 0.0:
		_enter_guard()

# ─────────────────────────────
# 상태 전환
# ─────────────────────────────

func _enter_alert():
	current_state = State.ALERT
	_alert_timer  = alert_duration
	_blink_timer  = 0.0
	if _charge_poly: _charge_poly.visible = true
	GlobalSave.mark_seen("sentinel_seen")
	_show_alert("!", Color(1.0, 0.28, 0.05))

func _enter_shockwave(wave: int = 1):
	current_state = State.SHOCKWAVE
	_sw_wave      = wave
	_play_roar()
	_sw_radius    = 0.0
	_sw_hit_done  = false
	var p = _get_player()
	if p: p.play_attack_sfx()
	if wave == 1:
		_sw_max = detection_range + BODY_RADIUS + shockwave_thickness
	else:
		_sw_max = _patrol_radius + shockwave_thickness
	modulate = Color(1.0, 0.08, 0.04, 1.0)
	if _charge_poly:
		_charge_poly.visible = false
		_update_circle_poly(_charge_poly, 0.0)
	if _sw_ring: _sw_ring.visible = true
	_show_alert("!!" if wave == 1 else "!!!", Color(1.0, 0.03, 0.03))

func _enter_sw_pause():
	current_state   = State.SW_PAUSE
	_sw_pause_timer = second_wave_pause
	if _sw_ring: _sw_ring.visible = false

func _sw_pause_logic(delta):
	velocity         = Vector2.ZERO
	_sw_pause_timer -= delta
	if _sw_pause_timer <= 0.0:
		_enter_shockwave(2)

func _enter_cooldown():
	current_state   = State.COOLDOWN
	_cooldown_timer = cooldown_duration
	if _sw_ring: _sw_ring.visible = false

func _enter_guard():
	current_state = State.GUARD
	rotation      = _base_rot
	modulate      = Color(1.0, 1.0, 1.0, 1.0)
	if _fov_poly: _fov_poly.color = Color(0.9, 0.85, 0.08, 0.14)

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
	if current_state == State.ALERT:
		_enter_guard()

## 부하 등록 (World.gd에서 스폰 직후 호출)
func add_subordinate(brood: Node2D, home_pos: Vector2) -> void:
	_subordinates.append(brood)
	_sub_homes[brood] = home_pos

func _activate_subordinates(player: Node2D) -> void:
	for sub in _subordinates:
		if is_instance_valid(sub) and sub.has_method("join_swarm"):
			sub.join_swarm(player.global_position)

func _recall_subordinates() -> void:
	for sub in _subordinates:
		if is_instance_valid(sub) and sub.has_method("recall_to_home"):
			sub.recall_to_home(_sub_homes.get(sub, global_position))

func alert_by_herald():
	if current_state == State.GUARD:
		_enter_alert()

func receive_flare_hit():
	if not is_in_group("enemy"): return
	_flare_hp -= 1
	modulate = Color(2.5, 0.8, 0.1, modulate.a)
	if _flare_hp > 0:
		_show_alert("!", Color(1.0, 0.4, 0.0))
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, modulate.a), 0.35)
		return
	remove_from_group("enemy")
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	if col: col.set_deferred("disabled", true)
	_play_death_sfx()
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.0, 0.0), 0.38)
	tw.parallel().tween_property(self, "scale", Vector2(1.7, 1.7), 0.38)
	tw.tween_callback(queue_free)

func receive_flare_bang(_origin: Vector2):
	if not is_in_group("enemy"): return
	_enter_cooldown()
	_show_alert("×", Color(0.8, 0.8, 0.8))

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
	p.volume_db = -10.0
	p.pitch_scale = 0.6
	if get_parent(): get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _play_death_sfx() -> void:
	var p = AudioStreamPlayer.new()
	p.stream = load("res://assets/monster_death.mp3")
	p.volume_db = -8.0
	if get_parent(): get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _update_circle_poly(poly: Polygon2D, radius: float):
	if radius < 1.0:
		poly.polygon = PackedVector2Array()
		return
	var steps = 36
	var pts   = PackedVector2Array()
	for i in range(steps):
		var a = (float(i) / float(steps)) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts

func _setup_alert_label():
	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 44)
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
	tw.tween_interval(0.45)
	tw.tween_property(_alert_label, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): _alert_active = false)

# ─────────────────────────────
# 비주얼
# ─────────────────────────────

func _build_visual():
	# FOV 원뿔 (스캔 방향 장식)
	var half      = deg_to_rad(110.0 * 0.5)
	var fov_range = detection_range + BODY_RADIUS
	var fov_pts   = PackedVector2Array()
	fov_pts.append(Vector2.ZERO)
	for i in range(17):
		var a = lerp(-half, half, float(i) / 16.0)
		fov_pts.append(Vector2(cos(a), sin(a)) * fov_range)
	_fov_poly         = Polygon2D.new()
	_fov_poly.polygon = fov_pts
	_fov_poly.color   = Color(0.9, 0.85, 0.08, 0.10)
	_fov_poly.z_index = -1
	add_child(_fov_poly)

	# 충전 원 (ALERT 중 확장)
	_charge_poly         = Polygon2D.new()
	_charge_poly.z_index = 3
	_charge_poly.visible = false
	add_child(_charge_poly)

	# 충격파 링 (SHOCKWAVE 중 확장)
	_sw_ring         = Line2D.new()
	_sw_ring.width   = shockwave_thickness
	_sw_ring.default_color = Color(1.0, 0.4, 0.05, 0.9)
	_sw_ring.z_index = 4
	_sw_ring.visible = false
	add_child(_sw_ring)

	# 몸체 육각형
	var body_pts = PackedVector2Array()
	for i in range(6):
		var a = (float(i) / 6.0) * TAU + TAU / 12.0
		body_pts.append(Vector2(cos(a), sin(a)) * BODY_RADIUS)
	var body = Polygon2D.new()
	body.polygon = body_pts
	body.color   = Color(0.24, 0.30, 0.34)
	add_child(body)

	var inner_pts = PackedVector2Array()
	for i in range(6):
		var a = (float(i) / 6.0) * TAU + TAU / 12.0
		inner_pts.append(Vector2(cos(a), sin(a)) * 17.0)
	var inner = Polygon2D.new()
	inner.polygon = inner_pts
	inner.color   = Color(0.38, 0.46, 0.52)
	add_child(inner)

	var sensor = Polygon2D.new()
	sensor.polygon = PackedVector2Array([
		Vector2(BODY_RADIUS + 7.0,  0.0),
		Vector2(BODY_RADIUS - 3.0, -7.5),
		Vector2(BODY_RADIUS - 3.0,  7.5),
	])
	sensor.color = Color(0.92, 0.82, 0.08)
	add_child(sensor)
