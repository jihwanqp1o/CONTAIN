extends StaticBody2D

var _player_in_range: bool = false
var _opened: bool = false
var _hint_label: Label = null
var _door_poly: Polygon2D = null

func _ready() -> void:
	add_to_group("boss_door")
	_build_visual()
	_build_collider()
	_build_interact_area()
	# 기본 숨김 — 열쇠 획득 전까지 비가시화
	modulate.a = 0.0
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)

func show_door() -> void:
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", false)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.0)
	tw.tween_callback(_add_beacon)

func _add_beacon() -> void:
	# 문 위에 펄스하는 ▼ 마커 — 플레이어가 시각적으로 위치를 찾을 수 있도록
	var label = Label.new()
	label.text = "▼ 격리실"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.3, 1.0, 0.1, 0.95))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-35, -115)
	label.z_index = 10
	add_child(label)

	var pulse = label.create_tween().set_loops()
	pulse.tween_property(label, "position:y", -125.0, 0.55).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(label, "position:y", -115.0, 0.55).set_ease(Tween.EASE_IN_OUT)

func _build_visual() -> void:
	_door_poly = Polygon2D.new()
	_door_poly.polygon = PackedVector2Array([
		Vector2(-45, -70), Vector2(45, -70),
		Vector2(45,  70),  Vector2(-45, 70),
	])
	_door_poly.color = Color(0.28, 0.12, 0.06)
	_door_poly.z_index = 1
	add_child(_door_poly)

	# 잠금 아이콘 (빨간 X)
	var lock = Label.new()
	lock.text = "🔒"
	lock.add_theme_font_size_override("font_size", 28)
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.position = Vector2(-20, -20)
	lock.z_index = 2
	add_child(lock)

	_hint_label = Label.new()
	_hint_label.text = "잠겨 있다"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3, 0.85))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(-55, -95)
	_hint_label.z_index = 3
	_hint_label.visible = false
	add_child(_hint_label)

func _build_collider() -> void:
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 140)
	shape.shape = rect
	add_child(shape)

func _build_interact_area() -> void:
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(120, 180)
	cs.shape = rect
	area.add_child(cs)
	area.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = true
			_update_hint(b)
	)
	area.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = false
			_hint_label.visible = false
	)
	add_child(area)

func _update_hint(player) -> void:
	if _opened: return
	if "has_key" in player and player.has_key:
		_hint_label.text = "[ E ] 문 열기"
		_hint_label.add_theme_color_override("font_color", Color(1.2, 1.0, 0.1))
	else:
		_hint_label.text = "잠겨 있다  (열쇠 필요)"
		_hint_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3, 0.85))
	_hint_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if _opened: return
	if not _player_in_range: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			var player = get_tree().get_first_node_in_group("player")
			if player and "has_key" in player and player.has_key:
				_open_door()
			else:
				_shake_no()
			get_viewport().set_input_as_handled()

func _open_door() -> void:
	_opened = true
	_hint_label.visible = false

	# 충돌체 비활성화 (통과 가능)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	var door_sfx = AudioStreamPlayer.new()
	door_sfx.stream = load("res://assets/door.mp3")
	get_parent().add_child(door_sfx)
	door_sfx.play()
	door_sfx.finished.connect(door_sfx.queue_free)

	# 문 열리는 연출 (위로 슬라이드)
	var tw = create_tween()
	tw.tween_property(_door_poly, "position:y", -150.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_door_poly, "modulate:a", 0.0, 0.6)

	# World에 보스전 시작 알림
	await get_tree().create_timer(0.5).timeout
	var world = get_tree().get_first_node_in_group("world_root")
	if world and world.has_method("_on_boss_door_opened"):
		world._on_boss_door_opened()

func _shake_no() -> void:
	var tw = create_tween()
	tw.tween_property(_door_poly, "position:x", 8.0, 0.05)
	tw.tween_property(_door_poly, "position:x", -8.0, 0.05)
	tw.tween_property(_door_poly, "position:x", 6.0, 0.04)
	tw.tween_property(_door_poly, "position:x", 0.0, 0.04)
