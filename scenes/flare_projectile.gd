extends Node2D

const SPEED     = 520.0
const MAX_RANGE = 1200.0

var _dir: Vector2 = Vector2.ZERO
var _traveled: float = 0.0
var _stop_dist: float = MAX_RANGE
var _trail_timer: float = 0.0
var _done: bool = false

func setup(start_pos: Vector2, target_pos: Vector2):
	global_position = start_pos
	var to_target = target_pos - start_pos
	if to_target.length() < 1.0:
		_dir = Vector2.RIGHT
		_stop_dist = MAX_RANGE
	else:
		_dir = to_target.normalized()
		_stop_dist = minf(to_target.length(), MAX_RANGE)

func _ready():
	_build_visual()

func _process(delta):
	if _done: return

	_trail_timer -= delta
	if _trail_timer <= 0:
		_trail_timer = 0.042
		_spawn_trail()

	var step = _dir * SPEED * delta

	# 벽 충돌 레이캐스트 (LOS 레이어=4)
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position, global_position + step * 3.5)
	params.collision_mask = 4
	if not space.intersect_ray(params).is_empty():
		_explode()
		return

	position += step
	_traveled += step.length()

	if _traveled >= _stop_dist:
		_explode()
		return

	# 일반 적 직접 명중 (50px)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_in_group("boss"):
			if global_position.distance_to(enemy.global_position) < 50.0:
				if enemy.has_method("receive_flare_hit"):
					enemy.receive_flare_hit()
				_explode()
				return

	# 보스 근접 체크
	for boss in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(boss):
			if global_position.distance_to(boss.global_position) < 50.0:
				if boss.has_method("take_damage_from_flare"):
					boss.take_damage_from_flare()
				_explode()
				return

func _explode():
	if _done: return
	_done = true
	_trigger_bang()
	# 폭발 파티클
	for i in 7:
		var spark = Polygon2D.new()
		var pts = PackedVector2Array()
		for j in 8:
			var a = TAU * j / 8.0
			pts.append(Vector2(cos(a), sin(a)) * randf_range(4.5, 10.0))
		spark.polygon = pts
		spark.color = Color(1.0, randf_range(0.35, 0.75), 0.0, 0.95)
		spark.global_position = global_position
		get_parent().add_child(spark)
		var d = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var tw = spark.create_tween()
		tw.parallel().tween_property(spark, "global_position",
			spark.global_position + d * randf_range(28.0, 65.0), 0.38)
		tw.parallel().tween_property(spark, "color",
			Color(1.0, 0.2, 0.0, 0.0), 0.38)
		tw.tween_callback(spark.queue_free)
	queue_free()

func _trigger_bang():
	const BANG_RADIUS      = 500.0
	const BROOD_AOE_RADIUS = 80.0
	var bang_pos = global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_in_group("boss"): continue
		var dist = bang_pos.distance_to(enemy.global_position)
		if dist > BANG_RADIUS: continue
		if enemy.is_in_group("brood") and dist <= BROOD_AOE_RADIUS:
			if enemy.has_method("receive_flare_hit"):
				enemy.receive_flare_hit()
		elif enemy.has_method("receive_flare_bang"):
			enemy.receive_flare_bang(bang_pos)

func _spawn_trail():
	var t = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 8:
		var a = TAU * i / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 7.5)
	t.polygon = pts
	t.color = Color(1.0, 0.52, 0.0, 0.58)
	t.global_position = global_position
	get_parent().add_child(t)
	var tw = t.create_tween()
	tw.parallel().tween_property(t, "color", Color(1.0, 0.25, 0.0, 0.0), 0.28)
	tw.parallel().tween_property(t, "scale", Vector2(2.0, 2.0), 0.28)
	tw.tween_callback(t.queue_free)

func _build_visual():
	# 후광
	add_child(_circle(22.0, 12, Color(1.0, 0.55, 0.0, 0.22)))
	# 본체
	add_child(_circle(11.0, 10, Color(1.0, 0.72, 0.08)))
	# 중심 코어
	add_child(_circle(5.5, 8, Color(1.0, 1.0, 0.85)))

func _circle(r: float, segs: int, col: Color) -> Polygon2D:
	var p = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in segs:
		var a = TAU * i / segs
		pts.append(Vector2(cos(a), sin(a)) * r)
	p.polygon = pts
	p.color = col
	return p
