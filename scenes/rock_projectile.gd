extends Node2D

const SPEED: float     = 420.0
const MAX_RANGE: float = 500.0

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

	# 벽 충돌 감지
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position, global_position + step * 3.5)
	params.collision_mask = 4
	if not space.intersect_ray(params).is_empty():
		_impact()
		return

	position += step
	_traveled += step.length()

	if _traveled >= _stop_dist:
		_impact()
		return

	# 소형 적 명중 → 즉사
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_in_group("boss"): continue
		if global_position.distance_to(enemy.global_position) < 40.0:
			if enemy.has_method("receive_rock_hit"):
				enemy.receive_rock_hit()
			_impact()
			return

	# 보스 명중 → flare 1 데미지
	for boss in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(boss): continue
		if global_position.distance_to(boss.global_position) < 60.0:
			if boss.has_method("take_damage_from_flare"):
				boss.take_damage_from_flare()
			_impact()
			return

func _impact() -> void:
	if _done: return
	_done = true
	_spawn_chips()
	queue_free()

func _spawn_chips() -> void:
	for i in 4:
		var chip = Polygon2D.new()
		var pts = PackedVector2Array()
		for j in 6:
			var a = TAU * j / 6.0
			pts.append(Vector2(cos(a), sin(a)) * randf_range(3.0, 6.0))
		chip.polygon = pts
		chip.color = Color(0.55, 0.42, 0.25, 0.9)
		chip.global_position = global_position
		get_parent().add_child(chip)
		var d = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var tw = chip.create_tween()
		tw.parallel().tween_property(chip, "global_position",
			chip.global_position + d * randf_range(12.0, 30.0), 0.28)
		tw.parallel().tween_property(chip, "color",
			Color(0.55, 0.42, 0.25, 0.0), 0.28)
		tw.tween_callback(chip.queue_free)

func _build_visual() -> void:
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2( 13,  0),
		Vector2(  7, -10),
		Vector2( -4, -12),
		Vector2(-12, -4),
		Vector2(-12,  5),
		Vector2( -4, 12),
		Vector2(  7,  9),
	])
	body.color = Color(0.58, 0.44, 0.26)
	add_child(body)

	var glint = Polygon2D.new()
	glint.polygon = PackedVector2Array([
		Vector2(-3, -9),
		Vector2( 5, -6),
		Vector2( 1, -2),
	])
	glint.color = Color(0.88, 0.74, 0.52, 0.75)
	add_child(glint)

	# 발광 후광 (플레이어 투척임을 표시)
	var glow = Polygon2D.new()
	var gpts = PackedVector2Array()
	for i in 16:
		var a = TAU * i / 16.0
		gpts.append(Vector2(cos(a), sin(a)) * 18.0)
	glow.polygon = gpts
	glow.color = Color(1.0, 0.80, 0.30, 0.22)
	glow.z_index = -1
	add_child(glow)
