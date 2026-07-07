extends Node2D

const SPEED: float        = 380.0
const MAX_RANGE: float    = 450.0
const ACTIVE_DURATION: float = 20.0
const PULSE_INTERVAL: float  = 2.0
const ATTRACT_RANGE: float   = 400.0

var _dir: Vector2    = Vector2.ZERO
var _traveled: float = 0.0
var _stop_dist: float = MAX_RANGE
var _landed: bool    = false
var _active_timer: float = 0.0
var _pulse_timer: float  = 0.0

func setup(pos: Vector2, target_pos: Vector2) -> void:
	global_position = pos
	var to_target = target_pos - pos
	_dir = to_target.normalized()
	rotation = _dir.angle()
	_stop_dist = minf(to_target.length(), MAX_RANGE)

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	if _landed:
		_active_timer += delta
		_pulse_timer  += delta
		if _pulse_timer >= PULSE_INTERVAL:
			_pulse_timer = 0.0
			_attract_enemies()
			_show_pulse()
		if _active_timer >= ACTIVE_DURATION:
			queue_free()
		return

	# 비행 중
	var step = _dir * SPEED * delta
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position, global_position + step * 3.0)
	params.collision_mask = 4
	if not space.intersect_ray(params).is_empty():
		_land()
		return

	position  += step
	_traveled += step.length()
	if _traveled >= _stop_dist:
		_land()

func _land() -> void:
	_landed = true
	_attract_enemies()
	_show_pulse()

func _attract_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		if global_position.distance_to(enemy.global_position) > ATTRACT_RANGE: continue
		if enemy.has_method("attract_to_noise"):
			enemy.attract_to_noise(global_position)
		else:
			if "last_known_position" in enemy:
				enemy.last_known_position = global_position
			if "_target_pos" in enemy:
				enemy._target_pos = global_position

func _show_pulse() -> void:
	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.9, 0.85, 0.15, 0.85)
	ring.z_index = 5
	var steps = 24
	for i in range(steps + 1):
		var a = TAU * float(i) / float(steps)
		ring.add_point(Vector2(cos(a), sin(a)) * 8.0)
	add_child(ring)
	var tw = ring.create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(ring, "scale", Vector2(12.0, 12.0), 0.5)
	tw.tween_callback(ring.queue_free)

func _build_visual() -> void:
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2( 8,  0), Vector2( 4, -7),
		Vector2(-5, -7), Vector2(-8,  0),
		Vector2(-5,  7), Vector2( 4,  7),
	])
	body.color = Color(0.75, 0.72, 0.18)
	body.z_index = 2
	add_child(body)

	var glow = Polygon2D.new()
	var gpts = PackedVector2Array()
	for i in 12:
		var a = TAU * i / 12.0
		gpts.append(Vector2(cos(a), sin(a)) * 12.0)
	glow.polygon = gpts
	glow.color = Color(1.0, 0.95, 0.3, 0.18)
	glow.z_index = 1
	add_child(glow)
