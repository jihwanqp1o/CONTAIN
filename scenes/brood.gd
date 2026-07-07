extends CharacterBody2D

enum State { ROAM, SWARM, SEARCH, FLEE }
var current_state: State = State.ROAM

const BODY_RADIUS: float             = 14.0
const PLAYER_RADIUS: float           = 45.0
const RING_RADIUS_BASE: float        = 110.0
const RING_RADIUS_MIN: float         = 45.0
const ORBIT_RADIUS: float            = 200.0    # 알파 궤도 초기 반경
const ORBIT_RADIUS_MIN: float        = 100.0    # C안: 궤도 최소 반경
const ORBIT_SHRINK_AMOUNT: float     = 20.0     # C안: 회당 축소량
const ORBIT_SHRINK_INTERVAL: float   = 15.0     # C안: 축소 주기 (초)
const ALPHA_AURA_RANGE: float        = 250.0    # A안: 스테미나 압박 반경
const ALPHA_AURA_PRESSURE: float     = 0.45     # A안: 회복 배율 (55% 감소)
const RECALL_INTERVAL: float         = 4.0      # B안: 귀환 소환 주기 (초)
const ALPHA_DAZZLE_TIME: float       = 1.5
const COMMAND_INTERVAL: float        = 3.5
const COMMAND_INTERVAL_RAGE: float   = 1.8
const COMMAND_BOOST_MULT_BASE: float = 1.45
const COMMAND_BOOST_MULT_RAGE: float = 1.70
const COMMAND_BOOST_DURATION: float  = 2.5

@export_group("Pack")
@export var pack_id: int          = -1
@export var is_alpha: bool        = false
@export var is_subordinate: bool  = false
@export var patrol_bounds: Rect2  = Rect2(0, 0, 9999, 9999)

@export_group("Detection")
@export var detection_range: float    = 240.0
@export var lose_range: float         = 500.0
@export var pack_signal_range: float  = 280.0
@export var fl_cone_rad: float        = 0.60
@export var fl_cone_range: float      = 350.0
@export var sound_range: float        = 130.0   # D안: 알파 소리 감지 거리

@export_group("Movement")
@export var roam_speed: float        = 55.0
@export var swarm_speed: float       = 235.0
@export var flee_speed: float        = 210.0
@export var separation_radius: float = 38.0

@export_group("Timing")
@export var search_duration: float      = 5.0
@export var flee_flash_duration: float  = 0.8
@export var flee_scare_duration: float  = 2.2

# ── 공통 ──────────────────────────────
var _roam_timer:         float   = 0.0
var _roam_dir:           Vector2 = Vector2.RIGHT
var _search_timer:       float   = 0.0
var _flee_timer:         float   = 0.0
var _flee_dir:           Vector2 = Vector2.ZERO
var _last_pos:           Vector2 = Vector2.ZERO
var _home_pos:           Vector2 = Vector2.ZERO
var _brood_hit_cooldown: float   = 0.0

# ── 일반 개체 전용 ────────────────────
var _ring_angle:          float = 0.0
var _ring_assigned:       bool  = false
var _boost_timer:         float = 0.0
var _command_boost_mult:  float = COMMAND_BOOST_MULT_BASE
var _alpha_check_timer:   float = 0.8
var _orphaned_flee:       bool  = false
var _current_ring_radius: float = RING_RADIUS_BASE   # C안

# ── 알파 전용 ─────────────────────────
var _alpha_dazzle:          float = 0.0
var _command_timer:         float = 2.0
var _orbit_dir:             float = 1.0
var _recall_timer:          float = RECALL_INTERVAL      # B안: 귀환 소환 쿨다운
var _orbit_radius_current:  float = ORBIT_RADIUS         # C안: 현재 궤도 반경
var _orbit_shrink_timer:    float = ORBIT_SHRINK_INTERVAL # C안: 축소 주기 타이머
var _swarm_elapsed:         float = 0.0                  # D안: SWARM 경과 시간
var _surround_check_timer:  float = 1.0                  # E안
var _is_enraged_surround:   bool  = false                # E안

# ── UI ───────────────────────────────
var _alert_label:  Label = null
var _alert_active: bool  = false
var _cached_brood:      Array = []
var _brood_cache_timer: float = 0.0

# ════════════════════════════════════
func _ready():
	add_to_group("enemy")
	add_to_group("brood")
	_build_visual()
	_setup_alert_label()
	_randomize_roam()
	_home_pos = global_position
	if is_alpha:
		detection_range *= 1.5
		scale = Vector2(1.35, 1.35)
		call_deferred("_connect_sound_signal")

func _connect_sound_signal():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("sound_emitted"):
		player.sound_emitted.connect(_on_sound_emitted)

# D안: 알파만 소리 반응 (짧은 범위)
func _on_sound_emitted(pos: Vector2, intensity: float):
	if current_state != State.ROAM: return
	if intensity < 0.44: return
	if global_position.distance_to(pos) > sound_range: return
	_last_pos = pos
	_enter_swarm()
	_notify_pack()

func _physics_process(delta):
	_brood_hit_cooldown = max(0.0, _brood_hit_cooldown - delta)
	_brood_cache_timer -= delta
	if _brood_cache_timer <= 0.0:
		_brood_cache_timer = 0.25
		_cached_brood = _cached_brood

	match current_state:
		State.ROAM:   _roam_logic(delta)
		State.SWARM:  _swarm_logic(delta)
		State.SEARCH: _search_logic(delta)
		State.FLEE:   _flee_logic(delta)

	move_and_slide()

	if _boost_timer > 0.0:
		_boost_timer = max(0.0, _boost_timer - delta)
		if _boost_timer <= 0.0:
			modulate = Color(1.0, 0.28, 0.08, 1.0)

	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-8.0, -42.0)

# ─────────────────────────────
# 상태 로직
# ─────────────────────────────

func _roam_logic(delta):
	if _orphaned_flee:
		_roam_timer -= delta
		if _roam_timer <= 0.0: _randomize_roam()
		velocity = _roam_dir * flee_speed
		rotation = lerp_angle(rotation, velocity.angle(), delta * 5.0)
		return

	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_randomize_roam()

	if not is_alpha and not is_subordinate:
		var alpha = _find_pack_alpha()
		if alpha != null and global_position.distance_to(alpha.global_position) > 200.0:
			velocity = (alpha.global_position - global_position).normalized() * roam_speed * 1.8
		else:
			velocity = _roam_dir * roam_speed
	else:
		velocity = _roam_dir * roam_speed

	rotation = lerp_angle(rotation, velocity.angle(), delta * 4.0)

	var player = _get_player()
	if not player: return
	var dist = global_position.distance_to(player.global_position)
	if dist - BODY_RADIUS <= detection_range:
		_last_pos = player.global_position
		_enter_swarm()
		_notify_pack()

func _swarm_logic(delta):
	if is_alpha:
		_alpha_orbit_logic(delta)
		return

	# ── 일반 개체 ──────────────────────
	_alpha_check_timer -= delta
	if _alpha_check_timer <= 0.0:
		_alpha_check_timer = 0.8
		if not is_subordinate and _ring_assigned and not _has_alpha():
			var sentinel = _find_sentinel()
			if is_instance_valid(sentinel):
				is_subordinate = true
				sentinel.add_subordinate(self, global_position)
			else:
				_orphaned_flee = true
				panic_flee()
			return

	# C안: 포위망 수축
	_current_ring_radius = max(RING_RADIUS_MIN, _current_ring_radius - 4.0 * delta)

	var player = _get_player()

	if player and _is_in_flashlight_cone(player):
		_enter_flee(player.global_position, flee_flash_duration)
		return

	if not player:
		_enter_search()
		return

	var dist = global_position.distance_to(player.global_position)
	if dist > lose_range:
		_enter_search()
		return

	_last_pos = player.global_position
	_amplify_surround_fear(player, delta)

	# 스테미나 갉아먹기
	if dist < BODY_RADIUS + PLAYER_RADIUS and _brood_hit_cooldown <= 0.0:
		_drain_player_stamina(player, 12.0)
		_brood_hit_cooldown = 0.5

	velocity = _calc_swarm_velocity(player)
	if velocity.length() > 0.1:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 6.0)

func _alpha_orbit_logic(delta):
	var player = _get_player()
	if player and _is_in_flashlight_cone(player):
		_alpha_dazzle += delta
		if _alpha_dazzle >= ALPHA_DAZZLE_TIME:
			_alpha_dazzle = 0.0
			_enter_flee(player.global_position, flee_flash_duration * 2.5)
			return
	else:
		_alpha_dazzle = max(0.0, _alpha_dazzle - delta * 2.5)

	if not player:
		_enter_search()
		return

	var dist = global_position.distance_to(player.global_position)
	if dist > lose_range:
		_enter_search()
		return

	_last_pos      = player.global_position
	_swarm_elapsed += delta  # D안: 경과 시간 누적

	# A안: 아우라 — 250px 이내면 플레이어 스테미나 회복 감소
	if dist <= ALPHA_AURA_RANGE:
		player._alpha_stamina_pressure = ALPHA_AURA_PRESSURE

	# E안: 포위 격노 체크 (1초 주기)
	_surround_check_timer -= delta
	if _surround_check_timer <= 0.0:
		_surround_check_timer = 1.0
		_check_surround_rage(player)

	# B안: 귀환 소환 — 흩어진 팩원 강제 복귀
	_recall_timer -= delta
	if _recall_timer <= 0.0:
		_recall_timer = RECALL_INTERVAL + randf_range(-0.5, 0.5)
		_send_recall()

	# C안: 궤도 축소 — 15초마다 20px 좁아짐 (최소 100px)
	_orbit_shrink_timer -= delta
	if _orbit_shrink_timer <= 0.0:
		_orbit_shrink_timer   = ORBIT_SHRINK_INTERVAL
		_orbit_radius_current = max(ORBIT_RADIUS_MIN, _orbit_radius_current - ORBIT_SHRINK_AMOUNT)

	# 명령 발신 (D안: 시간 경과 배율 / E안: 격노 시 쿨다운 단축)
	var cmd_interval = COMMAND_INTERVAL_RAGE if _is_enraged_surround else COMMAND_INTERVAL
	_command_timer -= delta
	if _command_timer <= 0.0:
		_command_timer = cmd_interval + randf_range(-0.4, 0.4)
		_issue_pack_command()

	# 궤도 이동 (C안: 가변 반경 사용)
	var to_player  = player.global_position - global_position
	var dist_to_pl = to_player.length()
	var radial     = to_player.normalized() * (dist_to_pl - _orbit_radius_current) * 0.08
	var tangent    = Vector2(-to_player.normalized().y, to_player.normalized().x) * _orbit_dir
	velocity = (tangent + radial).normalized() * swarm_speed * 0.85
	rotation = lerp_angle(rotation, velocity.angle(), delta * 5.0)

	_amplify_surround_fear(player, delta)

func _search_logic(delta):
	_search_timer -= delta
	var to_last = _last_pos - global_position
	if to_last.length() > 10.0:
		velocity = to_last.normalized() * (swarm_speed * 0.6)
		rotation = lerp_angle(rotation, velocity.angle(), delta * 4.0)
	else:
		velocity = Vector2.ZERO

	var player = _get_player()
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist - BODY_RADIUS <= detection_range:
			_last_pos = player.global_position
			_enter_swarm()
			return

	if _search_timer <= 0.0:
		_enter_roam()

func _flee_logic(delta):
	_flee_timer -= delta
	velocity = _flee_dir * flee_speed
	rotation = lerp_angle(rotation, velocity.angle(), delta * 7.0)
	if _flee_timer <= 0.0:
		var player = _get_player()
		if player and global_position.distance_to(player.global_position) < lose_range:
			_enter_swarm()
		else:
			_enter_roam()

# ─────────────────────────────
# 포위망 이동 계산
# ─────────────────────────────

func _calc_swarm_velocity(player: Node2D) -> Vector2:
	# 항상 자신의 링 슬롯을 목표로 이동 — 안쪽에 있으면 물러나고, 바깥에 있으면 가까이 가는 구조
	var ring_pos = player.global_position + Vector2.from_angle(_ring_angle) * _current_ring_radius
	var approach = (ring_pos - global_position).normalized()

	var sep = Vector2.ZERO
	for b in _cached_brood:
		if b == self or b.current_state != State.SWARM: continue
		if b.pack_id != pack_id: continue
		var to_b = b.global_position - global_position
		var d    = to_b.length()
		if d < separation_radius and d > 0.5:
			sep -= to_b / (d * d) * separation_radius

	var sep_v = sep.normalized() * 0.50 if sep.length() > 0.1 else Vector2.ZERO
	var spd   = swarm_speed * (_command_boost_mult if _boost_timer > 0.0 else 1.0)
	return (approach + sep_v).normalized() * spd

# ─────────────────────────────
# E안: 포위 격노 체크
# ─────────────────────────────

func _check_surround_rage(player: Node2D) -> void:
	var sectors = [false, false, false, false, false, false, false, false]
	for b in _cached_brood:
		if b == self or b.pack_id != pack_id or b.is_alpha: continue
		if b.current_state != State.SWARM: continue
		var angle  = (b.global_position - player.global_position).angle()
		var sector = int(fmod(rad_to_deg(angle) + 360.0, 360.0) / 45.0)
		sectors[clamp(sector, 0, 7)] = true
	var covered = 0
	for s in sectors:
		if s: covered += 1
	_is_enraged_surround = covered >= 6

# ─────────────────────────────
# 알파 명령 시스템
# ─────────────────────────────

func _issue_pack_command():
	var base_mult = _get_escalation_mult()  # D안
	for b in _cached_brood:
		if b == self or not is_instance_valid(b): continue
		if b.pack_id != pack_id: continue
		if b.has_method("receive_alpha_command"):
			b.receive_alpha_command(_is_enraged_surround, base_mult)
	_spawn_command_wave()

# D안: 경과 시간에 따라 명령 부스트 배율 점층
func _get_escalation_mult() -> float:
	if   _swarm_elapsed < 60.0:  return 1.45
	elif _swarm_elapsed < 120.0: return 1.65
	else:                        return 1.85

# B안: 흩어진 팩원을 SWARM으로 강제 복귀
func _send_recall():
	var recalled = 0
	for b in _cached_brood:
		if b == self or not is_instance_valid(b): continue
		if b.pack_id != pack_id: continue
		if b.current_state == State.FLEE or b.current_state == State.SEARCH:
			b.join_swarm(_last_pos)
			recalled += 1
	if recalled > 0:
		_spawn_command_wave()

func receive_alpha_command(enraged: bool = false, base_mult: float = COMMAND_BOOST_MULT_BASE):
	if current_state != State.SWARM: return
	_boost_timer        = COMMAND_BOOST_DURATION
	_command_boost_mult = COMMAND_BOOST_MULT_RAGE if enraged else base_mult
	modulate = Color(1.0, 0.45 if enraged else 0.62, 0.05, 1.0)

func panic_flee():
	var flee_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	_enter_flee(global_position - flee_dir * 50.0, flee_scare_duration * 2.5)

func _has_alpha() -> bool:
	for b in _cached_brood:
		if is_instance_valid(b) and b.is_alpha and b.pack_id == pack_id:
			return true
	return false

func _find_sentinel() -> Node:
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and n.has_method("add_subordinate"):
			return n
	return null

func _find_pack_alpha() -> Node2D:
	var nearest: Node2D  = null
	var nearest_dist: float = pack_signal_range * 2.5
	for b in _cached_brood:
		if not is_instance_valid(b) or not b.is_alpha: continue
		if b.pack_id != pack_id: continue
		var d = global_position.distance_to(b.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = b
	return nearest

func _spawn_command_wave():
	var steps = 28
	var ring  = Line2D.new()
	ring.width         = 3.5
	ring.default_color = Color(1.0, 0.70, 0.0, 0.85)
	ring.z_index       = 6
	for i in range(steps + 1):
		var a = float(i) / float(steps) * TAU
		ring.add_point(Vector2(cos(a), sin(a)) * 10.0)
	add_child(ring)
	var tw = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale",      Vector2(20.0, 20.0), 0.55)
	tw.tween_property(ring, "modulate:a", 0.0, 0.55)
	tw.finished.connect(ring.queue_free)

# ─────────────────────────────
# 군집 신호
# ─────────────────────────────

func _notify_pack():
	for b in _cached_brood:
		if b == self: continue
		if b.pack_id != pack_id: continue
		if global_position.distance_to(b.global_position) <= pack_signal_range:
			b.join_swarm(_last_pos)

func join_swarm(target: Vector2):
	if current_state == State.SWARM or current_state == State.FLEE: return
	_last_pos = target
	_enter_swarm()

# ─────────────────────────────
# 상태 전환
# ─────────────────────────────

func _enter_swarm():
	if _orphaned_flee: return
	_current_ring_radius = RING_RADIUS_BASE  # C안 리셋
	if is_alpha:
		_orbit_radius_current = ORBIT_RADIUS   # C안 궤도 리셋
		_orbit_shrink_timer   = ORBIT_SHRINK_INTERVAL
		_swarm_elapsed        = 0.0            # D안 타이머 리셋
		_recall_timer         = RECALL_INTERVAL
	if not is_alpha and not _ring_assigned:
		var pack     = _cached_brood
		var regulars: Array = []
		for b in pack:
			if is_instance_valid(b) and not b.is_alpha and b.pack_id == pack_id:
				regulars.append(b)
		var total = max(regulars.size(), 1)
		var idx   = 0
		for b in regulars:
			if b == self: break
			idx += 1
		_ring_angle  = (float(idx) / float(total)) * TAU
		_ring_angle += randf_range(-0.08, 0.08)
		_ring_assigned = true

	current_state = State.SWARM
	modulate = Color(1.0, 0.28, 0.08, 1.0)
	GlobalSave.mark_seen("brood_seen")
	_show_alert("!", Color(1.0, 0.38, 0.05))

func _enter_search():
	current_state = State.SEARCH
	_search_timer = search_duration
	modulate      = Color(0.85, 0.70, 0.35, 1.0)
	velocity      = Vector2.ZERO

func _enter_flee(scare_pos: Vector2, duration: float):
	current_state        = State.FLEE
	_flee_timer          = duration
	_flee_dir            = (global_position - scare_pos).normalized()
	if _flee_dir.length() < 0.1:
		_flee_dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
	_current_ring_radius = RING_RADIUS_BASE  # C안 리셋
	modulate = Color(0.5, 0.6, 1.0, 1.0)

func _enter_roam():
	current_state        = State.ROAM
	_ring_assigned       = false
	_current_ring_radius = RING_RADIUS_BASE
	_is_enraged_surround = false
	modulate = Color(0.55, 0.55, 0.70, 0.85) if _orphaned_flee else Color(1.0, 1.0, 1.0, 1.0)
	if is_alpha:
		_orbit_radius_current = ORBIT_RADIUS   # C안 궤도 리셋
		_swarm_elapsed        = 0.0
		# 귀환: home_pos에서 멀면 복귀 방향으로
		if global_position.distance_to(_home_pos) > 400.0:
			_roam_dir   = (_home_pos - global_position).normalized()
			_roam_timer = 3.0
			return
	_randomize_roam()

func _randomize_roam():
	_roam_timer = randf_range(1.2, 2.8)
	if is_alpha:
		var b  = patrol_bounds
		var bw = b.size.x
		var bh = b.size.y
		var m  = 100.0
		if bw > m * 2.0 and bh > m * 2.0:
			var target = Vector2(
				b.position.x + randf_range(m, bw - m),
				b.position.y + randf_range(m, bh - m)
			)
			_roam_dir = (target - global_position).normalized()
			return
	_roam_dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()

# ─────────────────────────────
# 공통 메서드
# ─────────────────────────────

func stop_chasing_forced():
	_enter_search()

func recall_to_home(home_pos: Vector2) -> void:
	if current_state == State.FLEE: return
	_last_pos = home_pos
	_enter_search()

func alert_by_herald():
	var player = _get_player()
	if player and current_state == State.ROAM:
		_last_pos = player.global_position
		_enter_swarm()
		_notify_pack()

func scare(origin: Vector2):
	_enter_flee(origin, flee_scare_duration)

func receive_flare_hit():
	if not is_in_group("enemy"): return
	remove_from_group("enemy")
	remove_from_group("brood")
	set_physics_process(false)
	var col = get_node_or_null("CollisionShape2D")
	if col: col.set_deferred("disabled", true)
	_play_death_sfx()
	modulate = Color(2.5, 0.8, 0.1, modulate.a)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.0, 0.0), 0.38)
	tw.parallel().tween_property(self, "scale", Vector2(1.7, 1.7), 0.38)
	tw.tween_callback(queue_free)

func receive_flare_bang(origin: Vector2):
	scare(origin)

func receive_rock_hit():
	receive_flare_hit()

# ─────────────────────────────
# 스테미나 갉아먹기
# ─────────────────────────────

func _drain_player_stamina(player: Node2D, amount: float) -> void:
	player.note_attacker("무리")
	player.current_stamina = max(0.0, player.current_stamina - amount)

# ─────────────────────────────
# 포위 공포 증폭
# ─────────────────────────────

func _amplify_surround_fear(player: Node2D, delta: float):
	if not player.has_method("add_fear_from_brood"): return
	var dist = global_position.distance_to(player.global_position)
	if dist > 220.0: return
	var fear_amt   = remap(dist, 0.0, 220.0, 10.0, 2.0)
	var player_fwd = Vector2.RIGHT.rotated(player.rotation)
	var to_self    = (global_position - player.global_position).normalized()
	if player_fwd.dot(to_self) < 0.0:
		fear_amt *= 1.6
	player.add_fear_from_brood(fear_amt * delta)

# ─────────────────────────────
# 알림 레이블
# ─────────────────────────────

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
	_alert_label.scale      = Vector2(2.0, 2.0)
	_alert_label.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(_alert_label, "scale",      Vector2(1.0, 1.0), 0.15)
	tw.tween_interval(0.35)
	tw.tween_property(_alert_label, "modulate:a", 0.0, 0.20)
	tw.tween_callback(func(): _alert_active = false)

# ─────────────────────────────
# 유틸
# ─────────────────────────────

func _is_in_flashlight_cone(player: Node2D) -> bool:
	if not player.flashlight_on: return false
	var dist = global_position.distance_to(player.global_position)
	if dist > fl_cone_range: return false
	var player_fwd = Vector2.RIGHT.rotated(player.rotation)
	var to_self    = (global_position - player.global_position).normalized()
	return player_fwd.dot(to_self) > cos(fl_cone_rad)

func _get_player():
	var p = get_tree().get_first_node_in_group("player")
	if not p or not p.is_alive: return null
	if "is_hidden_state" in p and p.is_hidden_state: return null
	if "is_in_safe_zone" in p and p.is_in_safe_zone: return null
	return p

func _play_death_sfx() -> void:
	var p = AudioStreamPlayer.new()
	p.stream = load("res://assets/monster_death.mp3")
	p.volume_db = -8.0
	if get_parent(): get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ─────────────────────────────
# 비주얼
# ─────────────────────────────

func _build_visual():
	if is_alpha:
		_build_alpha_visual()
	else:
		_build_regular_visual()

func _build_regular_visual():
	var outer = Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2( 15.0,  0.0), Vector2(  5.0, -9.0),
		Vector2(-10.0, -7.0), Vector2(-14.0,  0.0),
		Vector2(-10.0,  7.0), Vector2(  5.0,  9.0),
	])
	outer.color = Color(0.12, 0.10, 0.16)
	add_child(outer)

	var inner = Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(  9.0,  0.0), Vector2(  2.0, -5.5),
		Vector2( -6.0, -4.5), Vector2( -9.0,  0.0),
		Vector2( -6.0,  4.5), Vector2(  2.0,  5.5),
	])
	inner.color = Color(0.38, 0.22, 0.45)
	add_child(inner)

	var eye = Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(15.0, 0.0), Vector2(9.0, -3.5), Vector2(9.0, 3.5),
	])
	eye.color = Color(0.85, 0.35, 1.0)
	add_child(eye)

func _build_alpha_visual():
	var outer = Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2( 15.0,  0.0), Vector2(  7.0, -11.0),
		Vector2( -9.0, -9.0), Vector2(-14.0,  0.0),
		Vector2( -9.0,  9.0), Vector2(  7.0,  11.0),
	])
	outer.color = Color(0.28, 0.04, 0.06)
	add_child(outer)

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2( 10.0,  0.0), Vector2(  4.0, -7.0),
		Vector2( -6.0, -5.5), Vector2(-10.0,  0.0),
		Vector2( -6.0,  5.5), Vector2(  4.0,  7.0),
	])
	body.color = Color(0.62, 0.12, 0.16)
	add_child(body)

	var eye = Polygon2D.new()
	eye.polygon = PackedVector2Array([
		Vector2(14.5, 0.0), Vector2(8.0, -5.0), Vector2(8.0, 5.0),
	])
	eye.color = Color(1.0, 0.78, 0.0)
	add_child(eye)

	var crown_tips  = [Vector2(-5.0, -16.0), Vector2(0.0, -20.0), Vector2(5.0, -16.0)]
	var crown_bases = [
		[Vector2(-7.0, -10.0), Vector2(-3.0, -10.0)],
		[Vector2(-2.5, -10.5), Vector2(2.5,  -10.5)],
		[Vector2( 3.0, -10.0), Vector2( 7.0, -10.0)],
	]
	for i in range(3):
		var spike = Polygon2D.new()
		spike.polygon = PackedVector2Array([
			crown_bases[i][0], crown_bases[i][1], crown_tips[i],
		])
		spike.color = Color(1.0, 0.72, 0.05)
		add_child(spike)
