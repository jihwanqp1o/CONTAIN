extends Area2D

var _shape_half: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("safe_zone")
	collision_layer = 0
	collision_mask  = 3   # layer 1 (player) + layer 2 (enemies)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	var cs = get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		_shape_half = cs.shape.size * 0.5

func _process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("enemy"):
			_push_enemy_out(body)

func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.is_in_safe_zone = true
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and enemy.has_method("stop_chasing_forced"):
				enemy.stop_chasing_forced()
	elif body.is_in_group("enemy"):
		_push_enemy_out(body)

func _push_enemy_out(enemy: Node2D) -> void:
	if enemy.has_method("stop_chasing_forced"):
		enemy.stop_chasing_forced()
	# 출입구가 항상 북쪽이므로 Area2D 상단 경계 바깥으로 밀어낸다
	var exit_y: float
	if _shape_half != Vector2.ZERO:
		exit_y = global_position.y - _shape_half.y - 40.0
	else:
		exit_y = global_position.y - 270.0
	enemy.global_position = Vector2(enemy.global_position.x, exit_y)

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.is_in_safe_zone = false
