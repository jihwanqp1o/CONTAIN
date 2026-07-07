extends Area2D

const GameState = preload("res://scenes/game_state.gd")

var _player_in_range: bool = false
var _used: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1
	_build_visual()
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 120)
	cs.shape = rect
	add_child(cs)

	body_entered.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = true
	)
	body_exited.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = false
	)

func _build_visual() -> void:
	var door = Polygon2D.new()
	door.polygon = PackedVector2Array([
		Vector2(-45, -60), Vector2(45, -60),
		Vector2(45,  60),  Vector2(-45, 60),
	])
	door.color = Color(0.1, 0.55, 0.35)
	door.z_index = 2
	add_child(door)

	var hint = Label.new()
	hint.text = "[ E ] 탈출"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.3, 1.2, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-60, -90)
	hint.z_index = 3
	add_child(hint)

	# 반짝임
	var pulse = door.create_tween().set_loops()
	pulse.tween_property(door, "modulate", Color(1.5, 2.0, 1.5, 1.0), 0.6)
	pulse.tween_property(door, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if _used: return
	if not _player_in_range: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			_used = true
			_enter_clear()
			get_viewport().set_input_as_handled()

func _enter_clear() -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load("res://assets/clear.mp3")
	add_child(sfx)
	sfx.play()
	var player = get_tree().get_first_node_in_group("player")
	if player and "_survival_time" in player:
		var t = player._survival_time
		GameState.is_new_record = GameState.best_time > 0 and t > GameState.best_time
		GameState.survival_time = t
		if t > GameState.best_time:
			GameState.best_time = t
	if player:
		var canvas = player.get_node_or_null("CanvasLayer")
		if canvas:
			var ctrl = canvas.get_node_or_null("Control")
			if ctrl:
				var fade = ColorRect.new()
				fade.set_anchors_preset(Control.PRESET_FULL_RECT)
				fade.color = Color(1.0, 1.0, 1.0, 0.0)
				fade.z_index = 200
				ctrl.add_child(fade)
				var tw = fade.create_tween()
				tw.tween_property(fade, "color:a", 1.0, 0.8)
				tw.tween_callback(func():
					get_tree().change_scene_to_file("res://scenes/game_clear.tscn")
				)
				return
	get_tree().change_scene_to_file("res://scenes/game_clear.tscn")
