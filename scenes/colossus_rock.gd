extends Node2D

const SPEED: float     = 280.0
const MAX_RANGE: float = 400.0

var _dir: Vector2    = Vector2.ZERO
var _traveled: float = 0.0
var _done: bool      = false

func setup(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	_dir = dir.normalized()
	rotation = _dir.angle()

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	if _done: return

	var step = _dir * SPEED * delta

	# 벽 충돌 감지 (레이어 4 = 벽)
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position, global_position + step * 4.0)
	params.collision_mask = 4
	if not space.intersect_ray(params).is_empty():
		_on_wall_hit()
		return

	position += step
	_traveled += step.length()

	if _traveled >= MAX_RANGE:
		_done = true
		_spawn_chips(global_position)
		queue_free()
		return

	# 플레이어 피격
	var player = get_tree().get_first_node_in_group("player")
	if player and player.is_alive and not ("is_hidden_state" in player and player.is_hidden_state):
		if global_position.distance_to(player.global_position) < 32.0:
			player.note_attacker("콜로서스")
			player.play_attack_sfx()
			player.take_damage()
			_done = true
			queue_free()

func _on_wall_hit() -> void:
	_done = true
	_spawn_chips(global_position)
	if randf() < 0.5:
		_spawn_rock_item()
	queue_free()

func _spawn_rock_item() -> void:
	var ItemScene = load("res://scenes/item.tscn")
	if not ItemScene: return
	var item = ItemScene.instantiate()
	item.item_type = 5  # ItemType.ROCK
	item.global_position = global_position
	get_parent().add_child(item)

func _spawn_chips(pos: Vector2) -> void:
	for i in 5:
		var chip = Polygon2D.new()
		var pts = PackedVector2Array()
		for j in 6:
			var a = TAU * j / 6.0
			pts.append(Vector2(cos(a), sin(a)) * randf_range(3.0, 7.0))
		chip.polygon = pts
		chip.color = Color(0.65, 0.50, 0.28, 0.9)
		chip.global_position = pos
		get_parent().add_child(chip)
		var d = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var tw = chip.create_tween()
		tw.parallel().tween_property(chip, "global_position",
			chip.global_position + d * randf_range(15.0, 40.0), 0.35)
		tw.parallel().tween_property(chip, "color",
			Color(0.65, 0.50, 0.28, 0.0), 0.35)
		tw.tween_callback(chip.queue_free)

func _build_visual() -> void:
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2( 12,  0),
		Vector2(  6, -9),
		Vector2( -4, -11),
		Vector2(-11, -4),
		Vector2(-11,  5),
		Vector2( -4, 11),
		Vector2(  6,  8),
	])
	body.color = Color(0.55, 0.42, 0.25)
	add_child(body)

	var glint = Polygon2D.new()
	glint.polygon = PackedVector2Array([
		Vector2(-2, -8),
		Vector2( 4, -5),
		Vector2( 0, -2),
	])
	glint.color = Color(0.85, 0.72, 0.50, 0.7)
	add_child(glint)
