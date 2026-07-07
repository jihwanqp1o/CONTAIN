# TRK-11 "HOUND" — 추적 강화 실험체. 한 번 눈에 담은 것은 놓지 않는다.
# 손전등을 너무 오래 비추면 경고도 없이 달려든다.
extends CharacterBody2D

enum State { PATROL, CHASE, ALERT, LUNGE_READY, SEARCH, ENRAGE_WARN }
var current_state: State = State.PATROL
var search_count: int = 0

@export_group("Speed Settings")
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 220.0

@export_group("Detection Settings")
@export var light_detection_range: float = 380.0
@export var close_detection_range: float = 80.0
@export_group("FOV Detection")
@export var fov_range: float = 250.0   # 시야각 감지 거리 (손전등보다 짧음)
@export var fov_angle: float = 50.0    # 시야각 반각 (도 단위, 총 100°)

@export_group("Sound Effects")
@export var sfx_lunge_ready: AudioStream  # 플레이어 발견 + 0.5초 준비 경고음
@export var sfx_search: AudioStream       # 수색 상태 진입 시

@onready var status_label = $StatusLabel
@onready var detection_area = $DetectionArea
@onready var ray_cast = $RayCast2D

var patrol_direction: Vector2 = Vector2.ZERO
var patrol_timer: float = 0.0
var target_player: CharacterBody2D = null
var last_known_position: Vector2 = Vector2.ZERO
var alert_timer: float = 0.0
var current_speed: float = 0.0
var lunge_ready_timer: float = 0.0
var damage_cooldown: float = 0.0
var _attack_flash_timer:    float  = 0.0
var _attack_flash_duration: float  = 0.45
var _attack_flash_ready:    bool   = false
var _attack_icon:           Label  = null
var _attack_ring:           Node2D = null
var _sfx_player: AudioStreamPlayer
var _alert_label: Label = null
var _alert_active: bool = false
var _shield_stagger_timer: float = 0.0
var _shield_knockback_vel: Vector2 = Vector2.ZERO
var _stun_timer: float = 0.0
var _lose_timer: float = 0.0     # 시야 이탈 후 포기까지 카운트
var _fov_detect_timer: float = 0.0  # FOV 인식 누적 타이머
var _nav_agent: NavigationAgent2D = null
@export var patrol_bounds: Rect2 = Rect2(0, 0, 9999, 9999)

# ── 반전체: 손전등 지속 비춤 → 경고 → 격노 추격 ──
@export_group("Chase Settings")
@export var chase_lose_time: float = 3.0   # 시야 이탈 후 포기까지 초
@export var fov_detect_time: float = 0.5   # FOV 내 인식 시간 → 돌진 트리거

@export_group("Enrage Settings")
@export var flashlight_trigger_time: float = 0.5   # D안: 이 시간 이상 비춰야 격노 트리거
@export var enrage_warn_time: float = 0.45          # A안: 경고 단계 지속시간
@export var enraged_speed: float = 325.0            # B안: 격노 추격 속도 (플레이어 달리기 300보다 약간 빠름)
@export var enrage_duration: float = 2.5            # 격노 지속시간

var _is_enraged: bool = false
var _enrage_timer: float = 0.0
var _flashlight_hit_timer: float = 0.0   # D안: 손전등 누적 시간
var _enrage_warn_timer: float = 0.0      # A안: 경고 단계 타이머
var _warn_blink_timer: float = 0.0       # 경고 깜빡임용
var _los_check_timer: float = 0.0
var _last_in_light:   bool  = false
var _sfx_cries: Array = []

func _ready():
	add_to_group("enemy")
	modulate.a = 0.0
	_build_visual()
	_setup_alert_label()

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 20.0
	_nav_agent.target_desired_distance = 35.0
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)
	_build_attack_icon()
	call_deferred("_pick_patrol_target")
	_sfx_cries = [load("res://assets/monster_cry1.mp3"), load("res://assets/monster_cry2.mp3")]

func _physics_process(delta):
	damage_cooldown -= delta
	_update_visibility(delta)

	# 격노 타이머 처리
	if _is_enraged:
		_enrage_timer -= delta
		if _enrage_timer <= 0.0:
			_is_enraged = false

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_icons()
		return

	if _shield_stagger_timer > 0:
		_shield_stagger_timer -= delta
		velocity = _shield_knockback_vel
	else:
		match current_state:
			State.PATROL:      _patrol_logic(delta)
			State.LUNGE_READY: _lunge_ready_logic(delta)
			State.CHASE:       _chase_logic(delta)
			State.ALERT:       _alert_logic(delta)
			State.SEARCH:      _search_logic(delta)
			State.ENRAGE_WARN: _enrage_warn_logic(delta)

	move_and_slide()
	_sync_icons()

func _sync_icons():
	if _alert_label and _alert_label.modulate.a > 0.0:
		_alert_label.rotation        = -rotation
		_alert_label.global_position = global_position + Vector2(-15.0, -70.0)
	if _attack_icon and _attack_icon.visible:
		_attack_icon.rotation        = 0.0
		_attack_icon.global_position = global_position + Vector2(-18.0, -90.0)
	if _attack_ring and _attack_ring.visible:
		_attack_ring.global_position = global_position

# 손전등을 비추면 점점 빨개진다. 일정 시간 이상 비추면 경고 단계를 거쳐 격노한다.
func _update_visibility(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	if player.get("is_in_safe_zone"):
		_flashlight_hit_timer = 0.0
		return

	_los_check_timer -= delta
	if _los_check_timer <= 0.0:
		_los_check_timer = 0.12
		_last_in_light = _is_in_flashlight(player)
	var in_light = _last_in_light

	if in_light:
		$CollisionShape2D.disabled = false
		_flashlight_hit_timer += delta
		if _flashlight_hit_timer >= flashlight_trigger_time \
				and not _is_enraged \
				and current_state != State.ENRAGE_WARN:
			current_state = State.ENRAGE_WARN
			_enrage_warn_timer = enrage_warn_time
			_warn_blink_timer = 0.0
			target_player = player
			velocity = Vector2.ZERO
			_show_alert("!!!", Color(1.0, 0.05, 0.05))
	else:
		if current_state != State.ENRAGE_WARN and not _is_enraged:
			_flashlight_hit_timer = 0.0

	# 색상 처리
	if current_state == State.ENRAGE_WARN:
		_warn_blink_timer += delta
		var blink = sin(_warn_blink_timer * 18.0) * 0.5 + 0.5   # 빠른 깜빡임
		modulate = Color(0.6 + blink * 0.7, 0.05, 0.05, 1.0)
	elif _is_enraged:
		modulate = Color(1.25, 0.18, 0.18, 1.0)
	elif in_light:
		modulate.a = 1.0
		modulate.r = 1.0; modulate.g = 1.0; modulate.b = 1.0
	else:
		modulate.a = move_toward(modulate.a, 0.5, 1.0 * delta)
		modulate.r = 1.0; modulate.g = 1.0; modulate.b = 1.0
		if modulate.a < 0.1:
			$CollisionShape2D.disabled = true

# 0.45초. 경고가 끝나면 달려든다 — 빛을 꺼도 이미 늦었다.
func _enrage_warn_logic(delta):
	velocity = Vector2.ZERO
	_enrage_warn_timer -= delta
	if _enrage_warn_timer <= 0.0:
		_is_enraged = true
		_enrage_timer = enrage_duration
		_flashlight_hit_timer = 0.0
		current_state = State.CHASE
		if target_player:
			last_known_position = target_player.global_position

func _pick_patrol_target() -> void:
	if not _nav_agent: return
	var m = 60.0
	var b = patrol_bounds
	var t = Vector2(
		randf_range(b.position.x + m, b.end.x - m),
		randf_range(b.position.y + m, b.end.y - m)
	)
	_nav_agent.target_position = t
	patrol_timer = randf_range(2.0, 4.0)

func _patrol_logic(delta):
	status_label.text = ""
	current_speed = patrol_speed
	patrol_timer -= delta
	if patrol_timer <= 0 or (_nav_agent and _nav_agent.is_navigation_finished()):
		_pick_patrol_target()

	if _nav_agent and not _nav_agent.is_navigation_finished():
		var next = _nav_agent.get_next_path_position()
		var to_next = next - global_position
		if to_next.length() > 5.0:
			var dir = to_next.normalized()
			velocity = dir * current_speed
			rotation = dir.angle()
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	_check_for_player(delta)

func _lunge_ready_logic(delta):
	velocity = Vector2.ZERO
	lunge_ready_timer -= delta
	if lunge_ready_timer <= 0:
		current_state = State.CHASE

func _chase_logic(delta):
	if target_player and "is_hidden_state" in target_player:
		if target_player.is_hidden_state:
			_lost_player()
			return

	if not target_player or not target_player.is_alive:
		_lost_player()
		return

	var dist = global_position.distance_to(target_player.global_position)
	var can_see = _is_player_in_fov(target_player) or _is_in_flashlight(target_player)
	var actual_speed = enraged_speed if _is_enraged else chase_speed

	if can_see or _is_enraged:
		last_known_position = target_player.global_position
		_lose_timer = 0.0
		_nav_to(target_player.global_position, actual_speed)

		if dist < 110.0 and damage_cooldown <= 0:
			if _attack_flash_timer <= 0.0 and not _attack_flash_ready:
				_attack_flash_timer = _attack_flash_duration
				status_label.text = ""
				target_player.play_attack_sfx()
				_show_attack_icon()
				_show_attack_ring()
				_do_attack_telegraph()
			elif _attack_flash_ready:
				_attack_flash_ready = false
				_hide_attack_icon()
				_burst_attack_ring()
				modulate = Color(1.0, 1.0, 1.0)
				if dist < 110.0:
					target_player.note_attacker("스토커")
					target_player.take_damage()
				damage_cooldown = 1.0
	else:
		# C안: 시야 이탈 후 chase_lose_time 초 동안 LKP로 이동, 이후 포기
		_lose_timer += delta
		if _lose_timer >= chase_lose_time:
			_lost_player()
			return
		var dist_to_lkp = global_position.distance_to(last_known_position)
		if dist_to_lkp > 55.0:
			_nav_to(last_known_position, actual_speed)
		else:
			_lost_player()
			return

	if _attack_flash_timer > 0.0:
		_attack_flash_timer -= delta
		var progress = 1.0 - (_attack_flash_timer / _attack_flash_duration)
		_update_attack_ring(progress)
		if _attack_flash_timer <= 0.0:
			_attack_flash_ready = true

func _alert_logic(delta):
	velocity = Vector2.ZERO
	alert_timer -= delta
	if alert_timer <= 0:
		current_state = State.SEARCH
		search_count = 3
		_choose_search_direction()
		_play_random_cry()
		_show_alert("?", Color(1.0, 0.85, 0.0))
	_check_for_player(delta)

func _search_logic(delta):
	status_label.text = "??"
	current_speed = patrol_speed * 0.8

	# 마지막 목격 위치까지 먼저 이동
	var dist_to_last = global_position.distance_to(last_known_position)
	if dist_to_last > 60.0 and _nav_agent:
		_nav_agent.target_position = last_known_position
		var next = _nav_agent.get_next_path_position()
		var to_next = next - global_position
		if to_next.length() > 5.0:
			velocity = to_next.normalized() * current_speed
			rotation = velocity.angle()
		_check_for_player(delta)
		return

	# 도착 후 주변 수색 (랜덤 방향 전환)
	patrol_timer -= delta
	if patrol_timer <= 0:
		search_count -= 1
		if search_count <= 0:
			current_state = State.PATROL
			_pick_patrol_target()
		else:
			_choose_search_direction()
	velocity = patrol_direction * current_speed
	rotation = velocity.angle() if velocity != Vector2.ZERO else rotation
	_check_for_player(delta)

func _choose_new_patrol_direction():
	patrol_direction = Vector2.RIGHT.rotated(randf_range(0, 2*PI)).normalized()
	patrol_timer = randf_range(2.0, 4.0)

func _choose_search_direction():
	patrol_direction = patrol_direction.rotated(randf_range(-PI/2, PI/2)).normalized()
	patrol_timer = 1.2

# 시야각(100°) 안에 0.5초 머물면 추격을 시작한다. 시야 밖이면 감지하지 못한다.
func _check_for_player(delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive:
		_fov_detect_timer = 0.0
		return
	if "is_hidden_state" in player and player.is_hidden_state:
		_fov_detect_timer = 0.0
		return
	if player.get("is_in_safe_zone"):
		_fov_detect_timer = 0.0
		return
	if not _is_player_in_fov(player):
		_fov_detect_timer = 0.0
		return

	_fov_detect_timer += delta
	if _fov_detect_timer < fov_detect_time: return

	_fov_detect_timer = 0.0
	target_player = player
	last_known_position = player.global_position
	_trigger_lunge_ready()
	GlobalSave.mark_seen("stalker_seen")

func _is_player_in_fov(player) -> bool:
	var to_player = player.global_position - global_position
	var dist = to_player.length()
	var sneaking = "is_sneaking" in player and player.is_sneaking
	var eff_range = fov_range * 0.45 if sneaking else fov_range
	if dist > eff_range: return false
	var my_fwd = Vector2.RIGHT.rotated(rotation)
	var dot = my_fwd.dot(to_player.normalized())
	return rad_to_deg(acos(clampf(dot, -1.0, 1.0))) <= fov_angle

func _trigger_lunge_ready():
	if current_state != State.CHASE and current_state != State.LUNGE_READY:
		current_state = State.LUNGE_READY
		lunge_ready_timer = 0.5
		status_label.text = "!"
		_play_random_cry()
		_show_alert("!", Color(1.0, 0.1, 0.1))

# 시야를 잃으면 마지막 목격 위치로 이동해 수색한다. 포기까지 3초.
func _lost_player():
	target_player = null
	_lose_timer = 0.0
	_attack_flash_timer = 0.0
	_attack_flash_ready = false
	_hide_attack_icon()
	_burst_attack_ring()
	current_state = State.ALERT
	status_label.text = "?"
	alert_timer = 2.0
	if last_known_position != Vector2.ZERO and _nav_agent:
		_nav_agent.target_position = last_known_position

func _nav_to(target: Vector2, speed: float) -> void:
	if _nav_agent:
		_nav_agent.target_position = target
		var next = _nav_agent.get_next_path_position()
		var to_next = next - global_position
		if to_next.length() > 5.0:
			var dir = to_next.normalized()
			velocity = dir * speed
			rotation = dir.angle()
		else:
			var fallback = (target - global_position).normalized()
			if fallback.length() > 0.01:
				velocity = fallback * speed
				rotation = fallback.angle()
	else:
		var dir = (target - global_position).normalized()
		velocity = dir * speed
		rotation = dir.angle()

func receive_shield_block(player_pos: Vector2):
	var dir = (global_position - player_pos).normalized()
	_shield_knockback_vel = dir * 250.0
	_shield_stagger_timer = 0.7
	_show_alert("!", Color(1.0, 0.6, 0.0))

func stop_chasing_forced():
	target_player = null
	velocity = Vector2.ZERO
	last_known_position = global_position
	current_state = State.ALERT
	alert_timer = 2.0
	status_label.text = "?"
	_attack_flash_timer = 0.0
	_attack_flash_ready = false
	_hide_attack_icon()
	_burst_attack_ring()
	_show_alert("?", Color(1.0, 0.85, 0.0))
	_pick_patrol_target()

func alert_by_herald():
	if current_state != State.PATROL: return
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.is_alive: return
	target_player = player
	last_known_position = player.global_position
	_trigger_lunge_ready()
	_show_alert("!", Color(1.0, 0.4, 0.0))

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_attack_icon): _attack_icon.queue_free()
		if is_instance_valid(_attack_ring): _attack_ring.queue_free()

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

# 빛이 아니라 소리로 반응한다 — 섬광 위치로 수색을 전환한다.
func receive_flare_bang(origin: Vector2):
	if not is_in_group("enemy"): return
	last_known_position = origin
	target_player = null
	current_state = State.SEARCH
	search_count = 2
	_show_alert("!", Color(1.0, 0.85, 0.2))

func receive_rock_hit():
	receive_flare_hit()

func _do_attack_telegraph():
	velocity = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.8, 0.45, 0.35), 0.10)
	tw.tween_property(self, "modulate", Color(1.3, 0.6,  0.4 ), 0.12)
	tw.tween_property(self, "modulate", Color(1.0, 1.0,  1.0 ), 0.10)

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
	_alert_label.z_index = 20
	_alert_label.modulate.a = 0.0
	add_child(_alert_label)

func _show_alert(text: String, color: Color):
	if _alert_active or not _alert_label: return
	_alert_active = true
	_alert_label.text = text
	_alert_label.add_theme_color_override("font_color", color)
	_alert_label.scale = Vector2(2.2, 2.2)
	_alert_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(_alert_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(0.65)
	tween.tween_property(_alert_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): _alert_active = false)

# =====================
# 코드 기반 비주얼 (보라 5각 별)
# =====================
func _build_visual():
	# 외곽선 (짙은 보라)
	add_child(_make_star_poly(32.0, 14.0, 5, Color(0.20, 0.0, 0.30)))
	# 몸통 (선명한 보라-마젠타)
	add_child(_make_star_poly(28.0, 11.0, 5, Color(0.80, 0.10, 1.0)))
	# 전방 방향 삼각형 (정면 표시)
	var tip = Polygon2D.new()
	tip.polygon = PackedVector2Array([
		Vector2(36.0, 0.0),
		Vector2(25.0, -7.0),
		Vector2(25.0,  7.0),
	])
	tip.color = Color(0.95, 0.2, 1.0)
	add_child(tip)

func _has_los_to(target_pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	params.collision_mask = 4   # LOS 전용 레이어(벽만)
	params.exclude = [self]
	return space.intersect_ray(params).is_empty()

func _is_in_flashlight(player) -> bool:
	if not player.flashlight_on: return false
	var to_self = global_position - player.global_position
	var dist = to_self.length()
	if dist > light_detection_range: return false
	var player_fwd = Vector2.RIGHT.rotated(player.rotation)
	if player_fwd.dot(to_self.normalized()) < cos(0.60):
		return false
	var my_fwd = Vector2.RIGHT.rotated(rotation)
	if my_fwd.dot(-to_self.normalized()) <= 0.0:
		return false
	# 벽/기둥이 손전등 빛을 가로막는지 확인
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		player.global_position, global_position)
	params.collision_mask = 4
	params.exclude = [self]
	if not space.intersect_ray(params).is_empty():
		return false
	return true

func _make_star_poly(outer_r: float, inner_r: float, points: int, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(points * 2):
		var angle = (PI * i) / points - PI / 2.0
		var r = outer_r if i % 2 == 0 else inner_r
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	poly.polygon = pts
	poly.color = color
	return poly
