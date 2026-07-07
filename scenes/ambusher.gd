extends CharacterBody2D

enum State { DORMANT, WARNING, CHARGE, COOLDOWN }
var current_state: State = State.DORMANT

const BODY_RADIUS: float   = 22.0  # 자기 몸 반경 — 모든 거리 기준에서 제외
const PLAYER_RADIUS: float = 45.0

@export_group("Detection")
@export var detection_range: float  = 120.0  # 몸 표면에서 플레이어 중심까지 (= charge_max_dist 와 동일 단위)
@export var escape_range: float     = 400.0  # 경고 중 이 거리 초과 시 재잠복

@export_group("Timing")
@export var warn_duration: float    = 0.8
@export var cooldown_duration: float = 1.8

@export_group("Movement")
@export var charge_speed: float     = 480.0
@export var charge_max_dist: float  = 120.0  # 몸 표면 기준 돌진 거리 (detection_range 와 동일 단위)
@export var hit_range: float        = 0.0    # 추가 피격 범위 (0 = 실제 접촉만)
@export var return_speed: float     = 90.0   # DORMANT 귀환 속도

var _warn_timer: float     = 0.0
var _cooldown_timer: float = 0.0
var _blink_timer: float    = 0.0
var _charge_dir: Vector2   = Vector2.ZERO
var _charge_start: Vector2 = Vector2.ZERO
var _charge_frames: int    = 0  # 첫 몇 프레임 벽 충돌 무시용
var _spawn_pos: Vector2    = Vector2.ZERO
var _spawn_captured: bool  = false
var _alert_label: Label    = null
var _alert_active: bool    = false
var _attack_ring: Node2D   = null
var _sfx_cries: Array      = []

func _ready():
	add_to_group("enemy")
	_build_visual()
	_setup_alert_label()
	_build_attack_ring()
	modulate = Color(1.0, 1.0, 1.0, 0.18)
	_sfx_cries = [load("res://assets/monster_cry1.mp3"), load("res://assets/monster_cry2.mp3")]

func _physics_process(delta):
	# 첫 물리 프레임에 스폰 위치 확정 — call_deferred보다 안전
	if not _spawn_captured:
		_spawn_pos      = global_position
		_spawn_captured = true

	match current_state:
		State.DORMANT:  _dormant_logic(delta)
		State.WARNING:  _warning_logic(delta)
		State.CHARGE:   _charge_logic(delta)
		State.COOLDOWN: _cooldown_logic(delta)

	move_and_slide()

	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-12.0, -62.0)

# ─────────────────────────────
# 상태 로직
# ─────────────────────────────

func _dormant_logic(delta):
	var to_spawn = _spawn_pos - global_position
	if to_spawn.length() > 6.0:
		# 귀환 중 — 스폰 도착 전까지 감지 없음
		velocity = to_spawn.normalized() * return_speed
		rotation = to_spawn.normalized().angle()
		return

	# 스폰 도착 — 대기 및 감지
	velocity = Vector2.ZERO
	rotation += delta * 1.2

	var player = _get_player()
	if not player: return

	var dist     = global_position.distance_to(player.global_position)
	var body_gap = dist - BODY_RADIUS
	var sneaking = "is_sneaking" in player and player.is_sneaking
	var eff_range = detection_range * 0.5 if sneaking else detection_range

	if body_gap <= eff_range and _has_los_to(player.global_position):
		_enter_warning(player)

func _warning_logic(delta):
	velocity = Vector2.ZERO
	_warn_timer  -= delta
	_blink_timer += delta

	var blink = sin(_blink_timer * 10.0) * 0.5 + 0.5
	modulate = Color(1.0, 0.28 + blink * 0.45, 0.04, 1.0)

	var progress = 1.0 - (_warn_timer / warn_duration)
	_update_attack_ring(progress)

	var player = _get_player()
	if player:
		var dist     = global_position.distance_to(player.global_position)
		var body_gap = dist - BODY_RADIUS
		if body_gap > escape_range:
			_enter_dormant()
			return
		var dir = player.global_position - global_position
		if dir.length() > 1.0:
			_charge_dir = dir.normalized()
			rotation    = _charge_dir.angle()

	if _warn_timer <= 0.0:
		_enter_charge()

func _charge_logic(_delta):
	velocity = _charge_dir * charge_speed
	_charge_frames += 1

	# 플레이어 피격 판정 최우선
	var player = _get_player()
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < BODY_RADIUS + PLAYER_RADIUS + hit_range:
			player.note_attacker("매복자")
			player.take_damage()
			_enter_cooldown()
			return

	# 최대 돌진 거리 초과 — charge_max_dist는 몸 표면 기준이므로 BODY_RADIUS 더해 센터-센터 변환
	if global_position.distance_to(_charge_start) >= charge_max_dist + BODY_RADIUS:
		_enter_cooldown()
		return

	# 벽 충돌 — 5프레임 이후부터 체크 (첫 프레임 false-positive 방지)
	if _charge_frames >= 5 and get_slide_collision_count() > 0:
		_enter_cooldown()
		return

func _cooldown_logic(delta):
	velocity = Vector2.ZERO
	_cooldown_timer -= delta
	modulate.a = move_toward(modulate.a, 0.18, delta * 1.2)
	modulate.r = move_toward(modulate.r, 1.0,  delta * 1.5)
	modulate.g = move_toward(modulate.g, 1.0,  delta * 1.5)
	modulate.b = move_toward(modulate.b, 1.0,  delta * 1.5)
	if _cooldown_timer <= 0.0:
		_enter_dormant()

# ─────────────────────────────
# 상태 전환
# ─────────────────────────────

func _enter_warning(player):
	current_state = State.WARNING
	_warn_timer   = warn_duration
	_blink_timer  = 0.0
	_charge_dir   = (player.global_position - global_position).normalized()
	rotation      = _charge_dir.angle()
	GlobalSave.mark_seen("ambusher_seen")
	_play_random_cry()
	_show_alert("!", Color(1.0, 0.55, 0.05))
	_show_attack_ring()

func _enter_charge():
	current_state  = State.CHARGE
	_charge_start  = global_position
	_charge_frames = 0
	modulate       = Color(1.3, 0.38, 0.05, 1.0)
	_burst_attack_ring()
	var p = _get_player()
	if p: p.play_attack_sfx()

func _enter_cooldown():
	current_state   = State.COOLDOWN
	_cooldown_timer = cooldown_duration
	velocity        = Vector2.ZERO

func _enter_dormant():
	current_state = State.DORMANT
	modulate      = Color(1.0, 1.0, 1.0, 0.18)
	_hide_attack_ring()

# ─────────────────────────────
# 공통 메서드 (Herald / Box 연동)
# ─────────────────────────────

func _has_los_to(target_pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	params.collision_mask = 4
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

func stop_chasing_forced():
	_enter_dormant()

func alert_by_herald():
	pass  # 매복자는 Herald 활성화 무시

func receive_flare_hit():
	if not is_in_group("enemy"): return
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

func receive_flare_bang(_origin: Vector2):
	if not is_in_group("enemy"): return
	_enter_dormant()

func receive_rock_hit():
	receive_flare_hit()

# ─────────────────────────────
# 유틸
# ─────────────────────────────

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_attack_ring): _attack_ring.queue_free()

func _get_player():
	var p = get_tree().get_first_node_in_group("player")
	if not p or not p.is_alive: return null
	if "is_hidden_state" in p and p.is_hidden_state: return null
	if "is_in_safe_zone" in p and p.is_in_safe_zone: return null
	return p

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
# 비주얼: 납작한 마름모 (바닥 밀착형)
# ─────────────────────────────

func _build_attack_ring():
	_attack_ring = Node2D.new()
	_attack_ring.z_index = 25
	_attack_ring.visible = false
	get_tree().root.add_child(_attack_ring)

func _show_attack_ring():
	if not _attack_ring: return
	_attack_ring.visible = true
	_attack_ring.global_position = global_position
	for child in _attack_ring.get_children(): child.queue_free()
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 0.55, 0.05, 0.85)
	for i in range(25):
		var a = (float(i) / 24.0) * TAU
		line.add_point(Vector2(cos(a), sin(a)) * 80.0)
	_attack_ring.add_child(line)

func _update_attack_ring(progress: float):
	if not _attack_ring or not _attack_ring.visible: return
	_attack_ring.global_position = global_position
	var r    = lerp(80.0, 20.0, progress)
	var line = _attack_ring.get_child(0) if _attack_ring.get_child_count() > 0 else null
	if not line: return
	line.clear_points()
	for i in range(25):
		var a = (float(i) / 24.0) * TAU
		line.add_point(Vector2(cos(a), sin(a)) * r)
	line.width         = lerp(3.0, 5.5, progress)
	line.default_color = Color(1.0, lerp(0.55, 0.15, progress), lerp(0.05, 0.02, progress), 0.85)

func _burst_attack_ring():
	if not _attack_ring: return
	_attack_ring.visible = false
	for child in _attack_ring.get_children(): child.queue_free()

func _hide_attack_ring():
	if not _attack_ring: return
	_attack_ring.visible = false

func _build_visual():
	var outer = Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2( 30.0,  0.0),
		Vector2(  9.0, -13.0),
		Vector2(-20.0,  0.0),
		Vector2(  9.0,  13.0),
	])
	outer.color = Color(0.20, 0.16, 0.12)
	add_child(outer)

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2( 24.0,  0.0),
		Vector2(  7.0, -9.0),
		Vector2(-14.0,  0.0),
		Vector2(  7.0,  9.0),
	])
	body.color = Color(0.40, 0.30, 0.20)
	add_child(body)

	var eye = Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(28.0,  0.0),
		Vector2(19.0, -4.5),
		Vector2(19.0,  4.5),
	])
	eye.color = Color(0.85, 0.38, 0.08)
	add_child(eye)
