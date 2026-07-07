extends CharacterBody2D

enum State { PATROL, WINDUP, CHASE, STUNNED }
var current_state: State = State.PATROL

const BODY_RADIUS: float   = 26.0
const PLAYER_RADIUS: float = 45.0

@export_group("Detection")
@export var detection_range: float = 320.0
@export var fov_angle: float       = 100.0

@export_group("Movement")
@export var patrol_speed: float    = 70.0
@export var charge_speed: float    = 380.0
@export var max_charge_dist: float = 550.0

@export_group("Timing")
@export var stun_duration: float   = 1.8
@export var windup_duration: float = 0.30  # A안: 돌진 전 조준 시간

var _patrol_timer:  float   = 0.0
var _windup_timer:  float   = 0.0
var _patrol_dir:    Vector2 = Vector2.RIGHT
var _charge_dir:    Vector2 = Vector2.ZERO
var _charge_start:  Vector2 = Vector2.ZERO
var _charge_frames: int     = 0
var _stun_timer:    float   = 0.0
var _stun_base_rot: float   = 0.0
var _stun_frames:   int     = 0

var _alert_label:  Label = null
var _alert_active: bool  = false
var _sfx_player: AudioStreamPlayer = null
var _sfx_cries: Array = []

func _ready():
	add_to_group("enemy")
	_build_visual()
	_setup_alert_label()
	_randomize_patrol()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = load("res://assets/dolzin.mp3")
	add_child(_sfx_player)
	_sfx_cries = [load("res://assets/monster_cry1.mp3"), load("res://assets/monster_cry2.mp3")]

func _physics_process(delta):
	match current_state:
		State.PATROL:  _patrol_logic(delta)
		State.WINDUP:  _windup_logic(delta)
		State.CHASE:   _chase_logic(delta)
		State.STUNNED: _stunned_logic(delta)

	move_and_slide()

	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-12.0, -65.0)

# ─────────────────────────────
# 상태 로직
# ─────────────────────────────

func _patrol_logic(delta):
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_randomize_patrol()

	velocity = _patrol_dir * patrol_speed
	if velocity.length() > 0.1:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 4.0)

	var player = _get_player()
	if not player: return
	var sneaking  = "is_sneaking" in player and player.is_sneaking
	var eff_range = detection_range * 0.3 if sneaking else detection_range
	var to_player = player.global_position - global_position
	var body_gap  = to_player.length() - BODY_RADIUS
	if body_gap > eff_range: return
	var ang_diff = abs(angle_difference(to_player.angle(), rotation))
	if ang_diff < deg_to_rad(fov_angle * 0.5) and _has_los_to(player.global_position):
		_enter_windup()

func _windup_logic(delta):
	velocity       = Vector2.ZERO
	_windup_timer -= delta

	# 움츠리는 스케일 효과
	var t = 1.0 - clamp(_windup_timer / windup_duration, 0.0, 1.0)
	scale = Vector2(lerp(0.80, 1.15, t), lerp(1.20, 0.80, t))

	if _windup_timer <= 0.0:
		_enter_chase(_charge_dir)

func _chase_logic(_delta):
	velocity = _charge_dir * charge_speed
	_charge_frames += 1

	# 속도감 스케일 (진행 방향으로 늘어남)
	scale = Vector2(1.28, 0.82)

	# 피격 판정 최우선
	var player = _get_player()
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < BODY_RADIUS + PLAYER_RADIUS:
			player.note_attacker("돌격병")
			player.take_damage()
			_enter_patrol()
			return

	# 최대 돌진 거리 초과
	if global_position.distance_to(_charge_start) >= max_charge_dist + BODY_RADIUS:
		_enter_patrol()
		return

	# 벽 충돌 (5프레임 이후 체크)
	if _charge_frames >= 5 and get_slide_collision_count() > 0:
		_enter_stunned()

func _stunned_logic(delta):
	velocity      = Vector2.ZERO
	_stun_timer  -= delta
	_stun_frames += 1

	# 기절 흔들림
	var shake = sin(float(_stun_frames) * 0.75) * deg_to_rad(18.0)
	rotation  = _stun_base_rot + shake

	# 색 복구
	modulate.r = move_toward(modulate.r, 1.0, delta * 0.8)
	modulate.g = move_toward(modulate.g, 1.0, delta * 0.8)
	modulate.b = move_toward(modulate.b, 1.0, delta * 0.8)

	if _stun_timer <= 0.0:
		rotation = _stun_base_rot
		scale    = Vector2.ONE
		_enter_patrol()

# ─────────────────────────────
# 상태 전환
# ─────────────────────────────

func _enter_windup():
	current_state = State.WINDUP
	_windup_timer = windup_duration
	scale         = Vector2(0.80, 1.20)
	modulate      = Color(1.2, 0.35, 0.12, 1.0)
	var player = _get_player()
	if player:
		_charge_dir = (player.global_position - global_position).normalized()
		rotation    = _charge_dir.angle()
	GlobalSave.mark_seen("charger_seen")
	_show_alert("!", Color(1.0, 0.22, 0.05))

func _enter_chase(dir: Vector2):
	current_state  = State.CHASE
	_charge_dir    = dir
	_charge_start  = global_position
	_charge_frames = 0
	rotation       = dir.angle()
	modulate       = Color(1.0, 0.18, 0.08, 1.0)
	_play_random_cry()
	if _sfx_player: _sfx_player.play()
	var p = _get_player()
	if p: p.play_attack_sfx()

func _enter_stunned():
	current_state = State.STUNNED
	_stun_timer   = stun_duration
	_stun_frames  = 0
	_stun_base_rot = rotation
	velocity       = Vector2.ZERO
	scale          = Vector2.ONE
	modulate       = Color(0.65, 0.60, 0.70, 1.0)
	_show_alert("x_x", Color(0.75, 0.70, 0.85))

func _enter_patrol():
	current_state = State.PATROL
	scale         = Vector2.ONE
	modulate      = Color(1.0, 1.0, 1.0, 1.0)
	_randomize_patrol()

func _randomize_patrol():
	_patrol_timer = randf_range(1.5, 3.2)
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
	_enter_patrol()

func alert_by_herald():
	if current_state == State.PATROL:
		_enter_windup()

func receive_flare_hit():
	if not is_in_group("enemy"): return
	remove_from_group("enemy")
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	_play_death_sfx()
	if col: col.set_deferred("disabled", true)
	modulate = Color(2.5, 0.8, 0.1, modulate.a)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.0, 0.0), 0.38)
	tw.parallel().tween_property(self, "scale", Vector2(1.7, 1.7), 0.38)
	tw.tween_callback(queue_free)

func receive_flare_bang(_origin: Vector2):
	if not is_in_group("enemy"): return
	_enter_stunned()

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
# 비주얼: 묵직한 충각형 몸체
# ─────────────────────────────

func _build_visual():
	var outer = Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2( 30,   0),
		Vector2( 14, -18),
		Vector2( -6, -22),
		Vector2(-22, -13),
		Vector2(-26,   0),
		Vector2(-22,  13),
		Vector2( -6,  22),
		Vector2( 14,  18),
	])
	outer.color = Color(0.28, 0.10, 0.08)
	add_child(outer)

	var inner = Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2( 20,   0),
		Vector2(  8, -11),
		Vector2( -4, -14),
		Vector2(-14,  -8),
		Vector2(-17,   0),
		Vector2(-14,   8),
		Vector2( -4,  14),
		Vector2(  8,  11),
	])
	inner.color = Color(0.72, 0.18, 0.12)
	add_child(inner)

	# 전면 충각 (뾰족한 앞)
	var tip = Polygon2D.new()
	tip.polygon = PackedVector2Array([
		Vector2(30,   0),
		Vector2(18,  -7),
		Vector2(18,   7),
	])
	tip.color = Color(0.92, 0.38, 0.10)
	add_child(tip)
