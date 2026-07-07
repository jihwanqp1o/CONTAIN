# APEX "COLOSSUS" — 미분류. 격리 불가능.
# 연구 기록 말미에 이런 문장이 있었다: "더 이상 관찰을 진행할 수 없음."
extends CharacterBody2D

enum State { PATROL, LUNGE_READY, CHARGE, STAGGER, CHASE, ROAR, DESTROY_BOX, TAIL_SWIPE, GROUND_WAVE }
var current_state: State = State.PATROL

@export_group("Speed Settings")
@export var walk_speed: float = 65.0
@export var charge_speed: float = 450.0
@export var charge_max_duration: float = 3.0

@export_group("Detection")
@export var detection_range: float = 500.0
@export var light_detection_range: float = 420.0

@export_group("Abilities")
@export var roar_cooldown: float = 8.0
@export var stagger_duration: float = 2.0
var roar_timer: float = 0.0
var _shield_stagger_timer: float = 0.0
var _shield_knockback_vel: Vector2 = Vector2.ZERO
var _stagger_bounce: Vector2 = Vector2.ZERO

@export_group("Sound Effects")
@export var sfx_roar: AudioStream
@export var sfx_charge: AudioStream

var target_player: CharacterBody2D = null
var target_box: StaticBody2D = null
var patrol_direction: Vector2 = Vector2.ZERO
var patrol_timer: float = 0.0
var _nav_agent: NavigationAgent2D = null
@export var patrol_bounds: Rect2 = Rect2(0, 0, 9999, 9999)
var lunge_ready_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_timer: float = 0.0
var _stagger_timer: float = 0.0
var _is_roaring: bool = false
var _trail_timer: float = 0.0
var _tail_timer: float = 0.0
var _tail_cooldown: float = 0.0
var _tail_hit_done: bool = false
var _panels_done: int = 0
var _enraged: bool = false
var boss_mode: bool = false
var _enrage_pulse: float = 0.0
var _base_walk_speed: float = 0.0
var _base_charge_speed: float = 0.0
var _wave_timer: float = 0.0
var _wave_fired: bool = false
var _wave_cooldown: float = 0.0
var _p2_charge_speed_mult: float = 1.0  # 벽 충돌마다 누적 가속
var _p2_enrage_done: bool = false       # HP 절반 이하 추가 광폭화
var _sfx_player: AudioStreamPlayer
var _sfx_roar_player: AudioStreamPlayer
var _sfx_rock: AudioStream = null
var _alert_label: Label = null
var _alert_active: bool = false

# ── 끼임 감지 ──
const STUCK_MOVE_MIN:   float = 5.0
const STUCK_DETECT_TIME: float = 0.40
var _stuck_timer:  float   = 0.0
var _stuck_origin: Vector2 = Vector2.ZERO

# ── 페이즈 / 약화 시스템 ──
signal boss_died
var _phase: int = 1
var _charge_cooldown: float = 0.0
var _charge_extra_cooldown: float = 0.0
var _roar_sealed: bool = false
var _panel_speed_mult: float = 1.0

# ── 체력 시스템 ──
@export var max_health: int = 5
var current_health: int = 0
var _flash_intensity: float = 0.0
var _is_dying: bool = false
var _health_root: Node2D = null
var _health_fill: Polygon2D = null

const HP_BAR_W = 90.0
const HP_BAR_H = 12.0

var is_attacking: bool:
	get: return current_state in [State.CHARGE, State.LUNGE_READY, State.TAIL_SWIPE, State.GROUND_WAVE]

var is_in_combat: bool:
	get: return current_state in [State.CHASE, State.CHARGE, State.ROAR, State.LUNGE_READY, State.TAIL_SWIPE, State.GROUND_WAVE, State.DESTROY_BOX]

func _ready():
	add_to_group("enemy")
	add_to_group("boss")
	modulate.a = 0.7
	_build_visual()
	_setup_alert_label()
	_setup_health_display()
	_base_walk_speed  = walk_speed
	_base_charge_speed = charge_speed

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_sfx_roar_player = AudioStreamPlayer.new()
	add_child(_sfx_roar_player)
	_sfx_rock   = load("res://assets/rock2.mp3")
	sfx_charge  = load("res://assets/dolzin.mp3")
	sfx_roar    = load("res://assets/bosszab.mp3")

	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 25.0
	_nav_agent.target_desired_distance = 50.0
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)
	call_deferred("_pick_patrol_target")

func _pick_patrol_target() -> void:
	if not _nav_agent: return
	var m = 80.0
	var b = patrol_bounds
	var t = Vector2(
		randf_range(b.position.x + m, b.end.x - m),
		randf_range(b.position.y + m, b.end.y - m)
	)
	_nav_agent.target_position = t
	patrol_timer = randf_range(3.0, 6.0)

func _physics_process(delta):
	if _health_root:
		_health_root.global_position = global_position + Vector2(0, -110)
		_health_root.rotation = 0

	if _is_dying: return

	roar_timer -= delta
	_update_visibility(delta)

	# ── 끼임 감지 (CHARGE / CHASE 중)
	if current_state in [State.CHARGE, State.CHASE]:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_DETECT_TIME:
			var moved = global_position.distance_to(_stuck_origin)
			if moved < STUCK_MOVE_MIN:
				_on_stuck_detected()
			_stuck_timer  = 0.0
			_stuck_origin = global_position
	else:
		_stuck_timer  = 0.0
		_stuck_origin = global_position

	if _shield_stagger_timer > 0:
		_shield_stagger_timer -= delta
		velocity = _shield_knockback_vel
	else:
		match current_state:
			State.PATROL:      _patrol_logic(delta)
			State.LUNGE_READY: _lunge_ready_logic(delta)
			State.CHARGE:      _charge_logic(delta)
			State.STAGGER:     _stagger_logic(delta)
			State.CHASE:       _chase_logic(delta)
			State.ROAR:        _roar_logic(delta)
			State.DESTROY_BOX: _destroy_box_logic(delta)
			State.TAIL_SWIPE:  _tail_swipe_logic(delta)
			State.GROUND_WAVE: _ground_wave_logic(delta)

	move_and_slide()

	if _shield_stagger_timer <= 0 and current_state == State.CHARGE:
		_check_charge_collisions()
	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation = -rotation
		_alert_label.global_position = global_position + Vector2(-15.0, -80.0)

# ═══════════════════════════
# 상태 로직
# ═══════════════════════════

func _patrol_logic(delta):
	patrol_timer -= delta
	if patrol_timer <= 0 or (_nav_agent and _nav_agent.is_navigation_finished()):
		_pick_patrol_target()
	if _nav_agent and not _nav_agent.is_navigation_finished():
		var next = _nav_agent.get_next_path_position()
		var to_next = next - global_position
		if to_next.length() > 5.0:
			var dir = to_next.normalized()
			velocity = dir * walk_speed
			rotation = dir.angle()
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	_check_surroundings()

# 500 단위 안에서 인기척을 감지하면 즉시 돌진을 준비한다. 숨어 있으면 범위가 줄어든다.
func _check_surroundings():
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive: return
	if player.is_hidden_state: return
	var dist = global_position.distance_to(player.global_position)
	var sneaking = "is_sneaking" in player and player.is_sneaking
	var eff_range = detection_range * 0.35 if sneaking else detection_range
	if dist > eff_range: return
	if not _has_los_to(player.global_position): return
	target_player = player
	GlobalSave.mark_seen("colossus_seen")
	_start_lunge_ready()

func _find_target_box():
	for box in get_tree().get_nodes_in_group("box"):
		if is_instance_valid(box) and global_position.distance_to(box.global_position) < detection_range:
			target_box = box
			current_state = State.DESTROY_BOX
			break

func _start_lunge_ready():
	if current_state == State.LUNGE_READY or current_state == State.CHARGE:
		return
	current_state = State.LUNGE_READY
	lunge_ready_timer = 0.35 if _phase == 2 else 0.5
	_play_sfx(sfx_charge)
	if target_player and is_instance_valid(target_player):
		target_player.play_attack_sfx()
	_show_alert("!", Color(1.0, 0.1, 0.1))

func _lunge_ready_logic(delta):
	velocity = Vector2.ZERO
	if target_player and is_instance_valid(target_player) and not target_player.is_hidden_state:
		rotation = (target_player.global_position - global_position).angle()
		_charge_dir = (target_player.global_position - global_position).normalized()
	lunge_ready_timer -= delta
	if lunge_ready_timer <= 0:
		_charge_timer = charge_max_duration
		_trail_timer = 0.0
		current_state = State.CHARGE

func _charge_logic(delta):
	_charge_timer -= delta
	_trail_timer -= delta
	velocity = _charge_dir * charge_speed
	rotation = _charge_dir.angle()
	if _trail_timer <= 0:
		_trail_timer = 0.05
		_spawn_afterimage()
	if _charge_timer <= 0:
		_charge_cooldown = 0.0 if _phase == 2 else 5.0 + _charge_extra_cooldown
		current_state = State.CHASE

## 보스전 모드: 실드 1칸 소모 / 일반 모드: 즉사
func _boss_hit_player(p) -> void:
	if not p.is_alive: return
	p.note_attacker("콜로서스")
	p.take_damage()

func _check_charge_collisions():
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if not collider: continue
		if collider.is_in_group("player"):
			_boss_hit_player(collider)
			return
		if collider.is_in_group("box"):
			collider.destroy()
			return
		if collider.is_in_group("enemy"):
			continue
		# 구조물/벽 충돌
		_spawn_fragment(global_position - _charge_dir * 80.0)
		_spawn_impact_ring(220.0, Color(1.0, 0.60, 0.05, 0.65))
		_stagger_bounce = -_charge_dir * 320.0  # 벽 반발력 — 끼임 방지
		if _phase == 2:
			_take_wall_damage()
		else:
			if target_player and is_instance_valid(target_player):
				if global_position.distance_to(target_player.global_position) < 220.0:
					_boss_hit_player(target_player)
			_show_alert("※", Color(0.0, 0.85, 0.95))
			_start_stagger()
		return

func _start_stagger():
	current_state = State.STAGGER
	_stagger_timer = stagger_duration
	velocity = Vector2.ZERO

func _stagger_logic(delta):
	_stagger_bounce = _stagger_bounce.move_toward(Vector2.ZERO, 700.0 * delta)
	velocity = _stagger_bounce
	_stagger_timer -= delta
	if _stagger_timer <= 0:
		_stagger_bounce = Vector2.ZERO
		current_state = State.CHASE

func _chase_logic(delta):
	if not target_player or not target_player.is_alive:
		current_state = State.PATROL
		_pick_patrol_target()
		_show_alert("?", Color(1.0, 0.85, 0.0))
		return

	var dist = global_position.distance_to(target_player.global_position)
	_tail_cooldown   -= delta
	_wave_cooldown   -= delta
	_charge_cooldown -= delta

	if _phase == 2:
		_chase_logic_phase2(delta)
		return

	# 근거리 (< 160): 꼬리 휘두르기 → knockback
	if dist < 160.0 and _tail_cooldown <= 0.0:
		current_state = State.TAIL_SWIPE
		_tail_timer = 0.40
		_tail_hit_done = false
		_show_alert("!", Color(1.0, 0.1, 0.1))
		return

	# 중거리 (160~450): 바닥 충격 + 돌 투척 — 쿨다운 중엔 걷기만
	if dist >= 160.0 and dist < 450.0 and _wave_cooldown <= 0.0:
		current_state = State.GROUND_WAVE
		_wave_timer = 0.50
		_wave_fired = false
		_show_alert("▼", Color(1.0, 0.45, 0.0))
		var wt = create_tween()
		wt.tween_property(self, "scale", Vector2(1.25, 1.25), 0.45)
		return

	# 원거리 (≥ 450): 포효 → 돌진 (450 이하에선 돌진 없음)
	if dist >= 450.0 and roar_timer <= 0.0 and not _roar_sealed:
		current_state = State.ROAR
		return

	if dist >= 450.0 and _charge_cooldown <= 0.0:
		_start_lunge_ready()
		return

	# 걷기 추격
	if _nav_agent:
		_nav_agent.target_position = target_player.global_position
		var next = _nav_agent.get_next_path_position()
		var to_next = next - global_position
		if to_next.length() > 5.0:
			var dir = to_next.normalized()
			velocity = dir * walk_speed
			rotation = dir.angle()
		else:
			var fallback = (target_player.global_position - global_position).normalized()
			velocity = fallback * walk_speed
			rotation = fallback.angle()
	else:
		var dir = (target_player.global_position - global_position).normalized()
		velocity = dir * walk_speed
		rotation = dir.angle()

# 포효. 손전등을 강제로 끄고 공포를 심은 뒤, 곧장 돌진한다.
func _roar_logic(_delta):
	velocity = Vector2.ZERO
	if _is_roaring: return
	_is_roaring = true
	if target_player and is_instance_valid(target_player):
		if target_player.has_method("force_stop_flashlight"):
			target_player.force_stop_flashlight()
		if target_player.has_method("apply_roar_effect"):
			target_player.apply_roar_effect(0.8)
	if sfx_roar:
		_sfx_roar_player.stream = sfx_roar
		_sfx_roar_player.play()
	roar_timer = roar_cooldown
	await get_tree().create_timer(1.5).timeout
	if is_queued_for_deletion(): return
	if current_state != State.ROAR: return
	_is_roaring = false
	_start_lunge_ready()

func _tail_swipe_logic(delta) -> void:
	velocity = Vector2.ZERO
	if target_player and is_instance_valid(target_player):
		rotation = (target_player.global_position - global_position).angle()
	_tail_timer -= delta

	# 선딜 0.3s 후 꼬리 휘두르기 판정
	if not _tail_hit_done and _tail_timer <= 0.10:
		_tail_hit_done = true
		_spawn_impact_ring(200.0, Color(0.9, 0.35, 0.05, 0.85))
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(1.5, 0.6), 0.06)
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22)
		if target_player and is_instance_valid(target_player) and target_player.is_alive:
			var d = global_position.distance_to(target_player.global_position)
			if d < 190.0:
				var kb_dir = (target_player.global_position - global_position).normalized()
				if target_player.has_method("apply_knockback"):
					target_player.apply_knockback(kb_dir, 640.0)
				_boss_hit_player(target_player)
				if target_player.has_method("_shake_screen"):
					target_player._shake_screen(0.0, 22.0)

	if _tail_timer <= 0.0:
		_tail_cooldown = 1.5
		current_state = State.CHASE

func _ground_wave_logic(delta):
	velocity = Vector2.ZERO
	if target_player and is_instance_valid(target_player):
		rotation = (target_player.global_position - global_position).angle()
	_wave_timer -= delta
	if not _wave_fired and _wave_timer <= 0.0:
		_wave_fired = true
		_fire_stomp_rocks()
		_wave_timer = 0.50
	elif _wave_fired and _wave_timer <= 0.0:
		_wave_cooldown = 3.5
		current_state = State.CHASE

func _fire_stomp_rocks() -> void:
	if _sfx_rock: _play_sfx(_sfx_rock)
	# 발구름 스쿼시 연출
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.45, 0.65), 0.07)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.20)

	if not target_player or not is_instance_valid(target_player): return

	var base_angle = (target_player.global_position - global_position).angle()
	var spread = deg_to_rad(40.0)
	var ColossusRock = load("res://scenes/colossus_rock.gd")

	for i in 5:
		var angle = base_angle + randf_range(-spread, spread)
		var dir = Vector2.RIGHT.rotated(angle)
		var rock = ColossusRock.new()
		rock.setup(global_position + dir * 65.0, dir)
		get_parent().add_child(rock)

# 플레이어가 상자에 숨으면 상자를 부수러 간다. 숨을 곳은 없다.
func _destroy_box_logic(_delta):
	if not target_box or not is_instance_valid(target_box):
		target_box = null
		current_state = State.CHASE
		return
	var dist = global_position.distance_to(target_box.global_position)
	if dist > 50:
		if _nav_agent:
			_nav_agent.target_position = target_box.global_position
			var next = _nav_agent.get_next_path_position()
			var to_next = next - global_position
			if to_next.length() > 5.0:
				velocity = to_next.normalized() * walk_speed
				rotation = velocity.angle()
			else:
				velocity = (target_box.global_position - global_position).normalized() * walk_speed
		else:
			var dir = (target_box.global_position - global_position).normalized()
			velocity = dir * walk_speed
			rotation = dir.angle()
	else:
		velocity = Vector2.ZERO
		if target_box.has_method("destroy"):
			target_box.destroy()
		target_box = null
		current_state = State.CHASE

# ═══════════════════════════
# 파편 드롭 (돌진 벽 충돌 시)
# ═══════════════════════════

func _spawn_fragment(spawn_pos: Vector2) -> void:
	var frag = Node2D.new()
	get_parent().add_child(frag)
	frag.global_position = spawn_pos

	# 비주얼 — 청록 다이아몬드 파편
	frag.add_child(_make_diamond_poly(24.0, 18.0, Color(0.0, 0.85, 0.95, 0.28)))
	var body_vis = _make_diamond_poly(15.0, 11.0, Color(0.05, 0.80, 0.90))
	frag.add_child(body_vis)
	frag.add_child(_make_diamond_poly(7.0, 5.0, Color(0.85, 1.0, 1.0)))

	# 픽업 영역
	var area = Area2D.new()
	var cshape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	cshape.shape = circle
	area.collision_layer = 0
	area.collision_mask  = 1   # 플레이어 레이어
	area.add_child(cshape)
	frag.add_child(area)

	# 펄스 애니메이션
	var pulse = frag.create_tween().set_loops()
	pulse.tween_property(body_vis, "scale", Vector2(1.30, 1.30), 0.55)
	pulse.tween_property(body_vis, "scale", Vector2(1.0,  1.0),  0.55)

	# 픽업 처리
	area.body_entered.connect(func(b):
		if not is_instance_valid(frag): return
		if b.is_in_group("player") and b.has_method("try_pickup_item"):
			if b.try_pickup_item(4):   # 4 = ItemType.FLARE
				pulse.kill()
				frag.queue_free()
	)

	# 10초 후 2초 페이드 소멸
	var expire = frag.create_tween()
	expire.tween_interval(10.0)
	expire.tween_callback(func():
		if not is_instance_valid(frag): return
		pulse.kill()
		var fade = frag.create_tween()
		fade.tween_property(frag, "modulate:a", 0.0, 2.0)
		fade.tween_callback(frag.queue_free)
	)

# ═══════════════════════════
# 충격파 링 비주얼
# ═══════════════════════════

func _spawn_impact_ring(radius: float, color: Color) -> void:
	var ring = Node2D.new()
	ring.z_index = 3
	get_parent().add_child(ring)
	ring.global_position = global_position

	# 반투명 채우기
	var pts = PackedVector2Array()
	for i in 32:
		var a = TAU * i / 32.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var fill = Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(color.r, color.g, color.b, 0.30)
	ring.add_child(fill)

	# 밝은 테두리 선
	var line = Line2D.new()
	line.width = 6.0
	line.default_color = Color(color.r, color.g, color.b, min(1.0, color.a + 0.3))
	var lpts = PackedVector2Array()
	for i in 33:
		var a = TAU * i / 32.0
		lpts.append(Vector2(cos(a), sin(a)) * radius)
	line.points = lpts
	ring.add_child(line)

	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(1.45, 1.45), 0.50)
	tw.parallel().tween_property(fill, "color", Color(color.r, color.g, color.b, 0.0), 0.50)
	tw.parallel().tween_property(line, "default_color", Color(color.r, color.g, color.b, 0.0), 0.50)
	tw.tween_callback(ring.queue_free)

# ═══════════════════════════
# 보조
# ═══════════════════════════

func receive_shield_block(player_pos: Vector2):
	var dir = (global_position - player_pos).normalized()
	_shield_knockback_vel = dir * 200.0
	_shield_stagger_timer = 1.2
	_is_roaring = false
	current_state = State.CHASE
	_show_alert("!", Color(1.0, 0.6, 0.0))

func stop_chasing_forced():
	target_player = null
	target_box = null
	velocity = Vector2.ZERO
	_is_roaring = false
	current_state = State.PATROL
	_pick_patrol_target()

func alert_by_herald():
	if current_state != State.PATROL: return
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive: return
	target_player = player
	_start_lunge_ready()
	_show_alert("!", Color(1.0, 0.3, 0.0))

func _play_sfx(stream: AudioStream):
	if stream == null: return
	_sfx_player.stream = stream
	_sfx_player.play()

func _on_stuck_detected() -> void:
	if current_state == State.CHARGE:
		_stagger_bounce = -_charge_dir * 450.0
		_start_stagger()
	elif current_state == State.CHASE:
		velocity = Vector2.ZERO
		_pick_patrol_target()
		current_state = State.PATROL

func _setup_alert_label():
	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 64)
	_alert_label.z_index = 20
	_alert_label.modulate.a = 0.0
	add_child(_alert_label)

func _show_alert(text: String, color: Color):
	if _alert_active or not _alert_label: return
	_alert_active = true
	_alert_label.text = text
	_alert_label.add_theme_color_override("font_color", color)
	_alert_label.scale = Vector2(2.5, 2.5)
	_alert_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(_alert_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(0.65)
	tween.tween_property(_alert_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): _alert_active = false)

# =====================
# 코드 기반 비주얼
# =====================
func _build_visual():
	add_child(_make_diamond_poly(46.0, 36.0, Color(0.10, 0.0, 0.0)))
	add_child(_make_diamond_poly(42.0, 32.0, Color(0.95, 0.10, 0.05)))
	add_child(_make_diamond_poly(26.0, 18.0, Color(1.0, 0.40, 0.10)))
	var eye = _make_diamond_poly(10.0, 7.0, Color(1.0, 0.75, 0.0))
	eye.position = Vector2(34.0, 0.0)
	add_child(eye)

func _update_visibility(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	var in_light = _is_in_flashlight(player)
	var target_a = 1.0 if in_light else 0.7
	var new_a = move_toward(modulate.a, target_a, (2.0 if in_light else 1.0) * delta)
	_flash_intensity = max(0.0, _flash_intensity - delta * 3.5)

	var r_add = _flash_intensity * 1.6
	var g_sub = _flash_intensity * 0.75
	var b_sub = _flash_intensity * 0.85

	if _enraged:
		_enrage_pulse = fmod(_enrage_pulse + delta * 5.0, TAU)
		var p = abs(sin(_enrage_pulse)) * 0.45
		r_add += p
		g_sub += p * 0.6
		b_sub += p * 0.6

	modulate = Color(
		1.0 + r_add,
		max(0.0, 1.0 - g_sub),
		max(0.0, 1.0 - b_sub),
		new_a
	)

# ═══════════════════
# 체력 시스템
# ═══════════════════

func _setup_health_display():
	current_health = max_health
	_health_root = Node2D.new()
	_health_root.z_index = 22
	add_child(_health_root)
	var bg = Polygon2D.new()
	bg.polygon = _hp_rect(-HP_BAR_W * 0.5, 0, HP_BAR_W * 0.5, HP_BAR_H)
	bg.color = Color(0.10, 0.02, 0.02)
	_health_root.add_child(bg)
	_health_fill = Polygon2D.new()
	_health_fill.z_index = 1
	_health_root.add_child(_health_fill)
	var lbl = Label.new()
	lbl.text = "COLOSSUS"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15))
	lbl.position = Vector2(-HP_BAR_W * 0.5, -18)
	lbl.size = Vector2(HP_BAR_W, 16)
	_health_root.add_child(lbl)
	_update_health_display()

func _update_health_display():
	if not _health_fill: return
	var ratio = float(current_health) / float(max_health)
	var fill_w = max(0.0, (HP_BAR_W - 4.0) * ratio)
	var x0 = -HP_BAR_W * 0.5 + 2.0
	_health_fill.polygon = _hp_rect(x0, 2, x0 + fill_w, HP_BAR_H - 2)
	_health_fill.color = Color(
		lerp(0.9,  0.05, ratio),
		lerp(0.08, 0.82, ratio),
		0.05
	)

func _hp_rect(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x1,y1), Vector2(x2,y1), Vector2(x2,y2), Vector2(x1,y2)])

## 신호탄 직접 명중 — 데미지 + 5.5초 긴 경직
func receive_flare_hit():
	take_damage_from_flare()
	if not _is_dying:
		current_state  = State.STAGGER
		_stagger_timer = 5.5
		velocity       = Vector2.ZERO
		_show_alert("▽▽", Color(0.9, 0.7, 0.2))

## 파편 명중 — 데미지 + 2.5초 경직
func receive_rock_hit():
	take_damage_from_flare()
	if not _is_dying:
		current_state  = State.STAGGER
		_stagger_timer = 2.5
		velocity       = Vector2.ZERO

## 신호탄 폭발 충격파 (0.5s 경직)
func receive_flare_bang(_origin: Vector2):
	if _is_dying or current_state == State.STAGGER: return
	current_state  = State.STAGGER
	_stagger_timer = 0.5
	velocity       = Vector2.ZERO
	_show_alert("▽", Color(0.9, 0.7, 0.2))

## 신호탄/파편 피격
func take_damage_from_flare():
	if _is_dying: return
	if _phase == 2: return  # 2페이즈: 신호탄 피해 없음 (벽 자해만 가능)
	current_health -= 1
	_flash_intensity = 1.0
	_update_health_display()
	# HP 2 이하: 광폭화 (1페이즈만)
	if current_health <= 2 and not _enraged:
		_enraged = true
		walk_speed     = _base_walk_speed  * 1.35
		charge_speed   = _base_charge_speed * 1.25
		roar_cooldown  = 5.0
		stagger_duration = 1.4
		_show_alert("!!!", Color(1.0, 0.0, 0.0))
	if current_health <= 0:
		_enter_phase2()

## 격리 패널 활성화 → 콜로서스 약화 (World.gd에서 호출)
func apply_panel_weakening(panel_num: int) -> void:
	_panels_done += 1
	match panel_num:
		1:
			_panel_speed_mult *= 0.85
			walk_speed = _base_walk_speed * _panel_speed_mult
			_show_alert("▽", Color(0.35, 0.80, 1.0))
		2:
			_panel_speed_mult *= 0.85
			walk_speed = _base_walk_speed * _panel_speed_mult
			_charge_extra_cooldown += 2.0
			_show_alert("▽▽", Color(0.35, 0.80, 1.0))
		3:
			_roar_sealed = true
			_charge_extra_cooldown += 2.0
			_show_alert("▽▽▽", Color(0.35, 0.80, 1.0))

# 첫 번째 형태가 아니었다.
func _enter_phase2() -> void:
	_phase = 2
	_enraged = false
	_p2_charge_speed_mult = 1.0
	_p2_enrage_done = false
	current_health = 10
	max_health     = 10
	_update_health_display()
	_charge_cooldown       = 0.0
	_charge_extra_cooldown = 0.0
	_roar_sealed = true
	roar_timer   = 99999.0
	walk_speed   = _base_walk_speed  * _panel_speed_mult * 1.4
	charge_speed = _base_charge_speed * 1.15
	current_state = State.CHASE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_show_alert("2페이즈!", Color(1.0, 0.05, 0.05))
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 0.1, 0.1, 1.0), 0.15)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	_phase2_entry_roar()

func _phase2_entry_roar() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive: return
	# 공포 + 이동 경직 (실드 소모는 clear_boss_shield로 별도 처리)
	player.current_fear = min(player.current_fear + 50.0, player.max_fear)
	player._roar_lock_timer = 1.5
	# 보호막 전부 삭제 — 패널 3개 모두 활성화 시 1블록 잔존
	if player.has_method("clear_boss_shield"):
		player.clear_boss_shield(_panels_done >= 3)
	# 모든 상자 파괴
	for box in get_tree().get_nodes_in_group("box"):
		if is_instance_valid(box) and box.has_method("destroy"):
			box.destroy()
	# 아레나 기둥 파괴
	for pillar in get_tree().get_nodes_in_group("arena_pillar"):
		if is_instance_valid(pillar):
			pillar.queue_free()

func _spawn_wall_burst(pos: Vector2) -> void:
	_spawn_impact_ring(180.0, Color(1.0, 0.50, 0.05, 0.75))
	var ColossusRock = load("res://scenes/colossus_rock.gd")
	var count = 10
	for i in count:
		var angle = TAU * i / float(count) + randf_range(-0.18, 0.18)
		var dir = Vector2.RIGHT.rotated(angle)
		var rock = ColossusRock.new()
		rock.setup(pos + dir * 55.0, dir)
		get_parent().add_child(rock)

func _take_wall_damage() -> void:
	if _is_dying: return
	current_health -= 1
	_flash_intensity = 1.5
	_update_health_display()
	_show_alert("※", Color(1.0, 0.25, 0.1))
	if _phase == 2:
		# 벽 충돌마다 돌진 속도 누적 (+6%, 최대 1.4배)
		_p2_charge_speed_mult = minf(_p2_charge_speed_mult + 0.06, 1.4)
		charge_speed = _base_charge_speed * 1.15 * _p2_charge_speed_mult
		# 충돌 지점에서 파편 방사형 폭발
		_spawn_wall_burst(global_position)
		# 짧은 경직 후 즉시 재돌진
		_stagger_bounce = -_charge_dir * charge_speed * 0.4
		_stagger_timer = 0.35
		_charge_cooldown = 0.0
		current_state = State.STAGGER
	else:
		current_state  = State.STAGGER
		_stagger_timer = 1.0
		velocity       = Vector2.ZERO
	if current_health <= 0:
		_die()

func _chase_logic_phase2(_delta) -> void:
	if not target_player or not target_player.is_alive:
		current_state = State.PATROL
		_pick_patrol_target()
		return

	# HP 절반 이하 → 중간 광폭화
	if not _p2_enrage_done and current_health <= 5:
		_p2_enrage_done = true
		charge_speed = _base_charge_speed * 1.15 * _p2_charge_speed_mult * 1.2
		_show_alert("!!!", Color(1.0, 0.0, 0.0))
		var ft = create_tween()
		ft.tween_property(self, "modulate", Color(3.0, 0.1, 0.1, 1.0), 0.12)
		ft.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

	# 쿨다운 없이 즉시 돌진
	_start_lunge_ready()

# 쓰러졌다. 하지만 폭발까지 3초가 남아 있다.
func _die():
	_is_dying = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	if _health_root: _health_root.visible = false
	if _alert_label: _alert_label.modulate.a = 0.0

	# Phase 1: 몸 페이드 (0.95s)
	var body_tween = create_tween()
	body_tween.tween_property(self, "modulate", Color(3.0, 2.0, 0.5, 1.0), 0.12)
	body_tween.tween_property(self, "modulate", Color(0.8, 0.1, 0.0, 0.0), 0.8)
	await get_tree().create_timer(0.95).timeout
	if is_queued_for_deletion(): return

	var death_pos = global_position

	# Phase 2: 경고 원 (3s 카운트다운)
	var warning = _spawn_warning_circle(death_pos)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(warning): warning.queue_free()
	if is_queued_for_deletion(): return

	# Phase 3: 폭발 비주얼 + 피해 + 클리어 문
	_trigger_explosion(death_pos)
	_spawn_clear_door(death_pos)
	boss_died.emit()
	queue_free()

const EXPLOSION_RADIUS = 350.0

func _spawn_warning_circle(center: Vector2) -> Node2D:
	var node = Node2D.new()
	node.global_position = center
	node.z_index = 10
	get_parent().add_child(node)

	var steps = 48
	var fill_pts = PackedVector2Array()
	for i in steps:
		var a = TAU * i / float(steps)
		fill_pts.append(Vector2(cos(a), sin(a)) * EXPLOSION_RADIUS)

	var fill = Polygon2D.new()
	fill.polygon = fill_pts
	fill.color = Color(0.9, 0.05, 0.05, 0.18)
	node.add_child(fill)

	var border = Line2D.new()
	border.width = 6.0
	border.default_color = Color(1.0, 0.1, 0.1, 0.9)
	for i in steps + 1:
		var a = TAU * i / float(steps)
		border.add_point(Vector2(cos(a), sin(a)) * EXPLOSION_RADIUS)
	node.add_child(border)

	var warn_lbl = Label.new()
	warn_lbl.text = "폭발 위험!"
	warn_lbl.add_theme_font_size_override("font_size", 22)
	warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.position = Vector2(-120, -55)
	warn_lbl.size = Vector2(240, 36)
	node.add_child(warn_lbl)

	var count_lbl = Label.new()
	count_lbl.text = "3"
	count_lbl.add_theme_font_size_override("font_size", 52)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.05, 0.05))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.position = Vector2(-50, -28)
	count_lbl.size = Vector2(100, 65)
	node.add_child(count_lbl)

	# 펄스
	var pulse = fill.create_tween().set_loops()
	pulse.tween_property(fill, "color:a", 0.35, 0.4)
	pulse.tween_property(fill, "color:a", 0.12, 0.4)

	# 카운트다운 — Tween 콜백으로 (await 사용 안 함)
	var ctw = node.create_tween()
	ctw.tween_interval(1.0)
	ctw.tween_callback(func():
		if is_instance_valid(count_lbl): count_lbl.text = "2"
	)
	ctw.tween_interval(1.0)
	ctw.tween_callback(func():
		if is_instance_valid(count_lbl): count_lbl.text = "1"
	)
	ctw.tween_interval(1.0)
	ctw.tween_callback(func():
		pulse.kill()
	)

	return node

func _trigger_explosion(center: Vector2) -> void:
	var ring = Node2D.new()
	ring.global_position = center
	ring.z_index = 15
	get_parent().add_child(ring)

	var steps = 48
	var pts = PackedVector2Array()
	for i in steps:
		var a = TAU * i / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * EXPLOSION_RADIUS)
	var fill = Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(1.0, 0.45, 0.05, 0.80)
	ring.add_child(fill)

	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.55)
	tw.parallel().tween_property(fill, "color:a", 0.0, 0.55)
	tw.tween_callback(ring.queue_free)

	# 플레이어 피해 판정
	var player = get_tree().get_first_node_in_group("player")
	if player and player.is_alive:
		if center.distance_to(player.global_position) <= EXPLOSION_RADIUS:
			player.note_attacker("콜로서스 (폭발)")
			_boss_hit_player(player)

	if player and player.has_method("_shake_screen"):
		player._shake_screen(0.0, 40.0)

func _spawn_clear_door(pos: Vector2) -> void:
	var ClearDoorScene = load("res://scenes/clear_door.tscn")
	if not ClearDoorScene: return
	var door = ClearDoorScene.instantiate()
	door.global_position = pos
	get_parent().add_child(door)

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
	if player_fwd.dot(to_self.normalized()) < cos(0.60): return false
	var my_fwd = Vector2.RIGHT.rotated(rotation)
	if my_fwd.dot(-to_self.normalized()) <= 0.0: return false
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(player.global_position, global_position)
	params.collision_mask = 4
	params.exclude = [self]
	if not space.intersect_ray(params).is_empty(): return false
	return true

func _spawn_afterimage():
	var ghost = Polygon2D.new()
	ghost.polygon = PackedVector2Array([
		Vector2(42.0, 0.0), Vector2(0.0, 32.0),
		Vector2(-42.0, 0.0), Vector2(0.0, -32.0),
	])
	ghost.color = Color(0.95, 0.30, 0.05, 0.55)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "color", Color(0.95, 0.30, 0.05, 0.0), 0.28)
	tween.tween_callback(ghost.queue_free)

func _make_diamond_poly(w: float, h: float, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2( w,  0.0), Vector2( 0.0,  h),
		Vector2(-w,  0.0), Vector2( 0.0, -h),
	])
	poly.color = color
	return poly
