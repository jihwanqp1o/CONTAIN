extends Node2D

const SPEED: float      = 400.0
const MAX_RANGE: float  = 500.0
const STUN_RADIUS: float = 200.0
const STUN_DURATION: float = 3.0

var _dir: Vector2    = Vector2.ZERO
var _traveled: float = 0.0
var _stop_dist: float = MAX_RANGE
var _done: bool      = false

func setup(pos: Vector2, target_pos: Vector2) -> void:
	global_position = pos
	var to_target = target_pos - pos
	_dir = to_target.normalized()
	rotation = _dir.angle()
	_stop_dist = minf(to_target.length(), MAX_RANGE)

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	if _done: return

	var step = _dir * SPEED * delta
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position, global_position + step * 3.0)
	params.collision_mask = 4
	if not space.intersect_ray(params).is_empty():
		_explode()
		return

	position  += step
	_traveled += step.length()
	if _traveled >= _stop_dist:
		_explode()

func _explode() -> void:
	if _done: return
	_done = true
	_stun_enemies()
	_show_blast()
	queue_free()

func _stun_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		if global_position.distance_to(enemy.global_position) > STUN_RADIUS: continue
		# 공통 기절 메서드 우선 시도
		if enemy.has_method("receive_flare_bang"):
			enemy.receive_flare_bang(global_position)
		else:
			# fallback: 물리 일시 정지 후 재개
			enemy.set_physics_process(false)
			var stun_tw = enemy.create_tween()
			stun_tw.tween_interval(STUN_DURATION)
			stun_tw.tween_callback(func(): if is_instance_valid(enemy): enemy.set_physics_process(true))

func _show_blast() -> void:
	var parent = get_parent()
	if not parent: return

	# 섬광 충격파 링 3개
	for i in 3:
		var ring = Line2D.new()
		ring.width = 4.0 - i
		ring.default_color = Color(1.0, 0.95, 0.6, 0.9 - i * 0.25)
		ring.global_position = global_position
		ring.z_index = 10
		var steps = 32
		for j in range(steps + 1):
			var a = TAU * float(j) / float(steps)
			ring.add_point(Vector2(cos(a), sin(a)) * 5.0)
		parent.add_child(ring)
		var tw = ring.create_tween()
		var target_scale = Vector2.ONE * (STUN_RADIUS / 5.0 + i * 20.0)
		tw.tween_interval(i * 0.06)
		tw.tween_property(ring, "scale", target_scale, 0.38)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.38)
		tw.tween_callback(ring.queue_free)

	# 중심 플래시
	var flash = Polygon2D.new()
	var fpts = PackedVector2Array()
	for i in 16:
		var a = TAU * i / 16.0
		fpts.append(Vector2(cos(a), sin(a)) * 18.0)
	flash.polygon = fpts
	flash.color = Color(1.0, 1.0, 0.85, 0.95)
	flash.global_position = global_position
	flash.z_index = 11
	parent.add_child(flash)
	var tw2 = flash.create_tween()
	tw2.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw2.tween_callback(flash.queue_free)

func _build_visual() -> void:
	var body = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 8:
		var a = TAU * i / 8.0 + TAU / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0)
	body.polygon = pts
	body.color = Color(0.95, 0.88, 0.30)
	body.z_index = 2
	add_child(body)

	var glow = Polygon2D.new()
	var gpts = PackedVector2Array()
	for i in 16:
		var a = TAU * i / 16.0
		gpts.append(Vector2(cos(a), sin(a)) * 14.0)
	glow.polygon = gpts
	glow.color = Color(1.0, 0.95, 0.4, 0.28)
	glow.z_index = 1
	add_child(glow)
