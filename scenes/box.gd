extends StaticBody2D

var is_player_inside: bool = false
var player_ref: CharacterBody2D = null

@onready var interact_area = $InteractArea

@export_group("Sound Effects")
@export var sfx_enter: AudioStream    # 상자에 들어갈 때
@export var sfx_exit: AudioStream     # 상자에서 나올 때
@export var sfx_destroy: AudioStream  # 보스에게 파괴될 때

var _sfx_player: AudioStreamPlayer

func _ready():
	add_to_group("box")
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	sfx_enter = load("res://assets/box.mp3")
	_build_visual()
	interact_area.body_entered.connect(func(b):
		if b.is_in_group("player") and b.has_method("show_hint"):
			b.show_hint("box", "[ E ] 박스에 숨기 — 안에서 적이 지나갈 때까지 대기")
	)

func _build_visual() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr: spr.visible = false

	var W: float = 50.0
	var H: float = 37.0
	var vis = Node2D.new()
	vis.position = Vector2(-7.0, 2.0)
	vis.z_index  = 1
	add_child(vis)

	# 본체
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-W,-H), Vector2(W,-H), Vector2(W,H), Vector2(-W,H)])
	body.color   = Color(0.55, 0.40, 0.20)
	vis.add_child(body)

	# 윗면 하이라이트 (입체감)
	var top = Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-W+3,-H+3), Vector2(W-3,-H+3), Vector2(W-3,-H+13), Vector2(-W+3,-H+13)])
	top.color   = Color(0.70, 0.55, 0.30, 0.45)
	vis.add_child(top)

	# 가로 밴드
	var hb = Polygon2D.new()
	hb.polygon = PackedVector2Array([Vector2(-W+3,-5), Vector2(W-3,-5), Vector2(W-3,5), Vector2(-W+3,5)])
	hb.color   = Color(0.28, 0.18, 0.08, 0.85)
	vis.add_child(hb)

	# 세로 밴드
	var vb = Polygon2D.new()
	vb.polygon = PackedVector2Array([Vector2(-4,-H+3), Vector2(4,-H+3), Vector2(4,H-3), Vector2(-4,H-3)])
	vb.color   = Color(0.28, 0.18, 0.08, 0.85)
	vis.add_child(vb)

	# 코너 브라켓 4개
	var blen: float = 13.0
	var bthk: float = 3.5
	var bcol: Color = Color(0.22, 0.14, 0.06)
	for cx in [-W, W]:
		for cy in [-H, H]:
			var sx = sign(cx); var sy = sign(cy)
			for pts in [
				PackedVector2Array([Vector2(cx,cy), Vector2(cx-sx*blen,cy), Vector2(cx-sx*blen,cy-sy*bthk), Vector2(cx,cy-sy*bthk)]),
				PackedVector2Array([Vector2(cx,cy), Vector2(cx-sx*bthk,cy), Vector2(cx-sx*bthk,cy-sy*blen), Vector2(cx,cy-sy*blen)]),
			]:
				var brk = Polygon2D.new()
				brk.polygon = pts
				brk.color   = bcol
				vis.add_child(brk)

	# 외곽 테두리
	var fr = Line2D.new()
	for p in [Vector2(-W,-H), Vector2(W,-H), Vector2(W,H), Vector2(-W,H), Vector2(-W,-H)]:
		fr.add_point(p)
	fr.width         = 3.0
	fr.default_color = Color(0.18, 0.11, 0.05)
	vis.add_child(fr)

func destroy():
	print("상자가 파괴됨!")
	# 충돌을 즉시 비활성화해야 돌진 중인 적이 다음 프레임에 통과할 수 있음
	remove_from_group("box")
	$CollisionShape2D.disabled = true

	if sfx_destroy:
		var temp = AudioStreamPlayer.new()
		temp.stream = sfx_destroy
		get_parent().add_child(temp)
		temp.play()
		temp.finished.connect(temp.queue_free)

	if is_player_inside:
		_toggle_hide()
	_spawn_fragments()
	queue_free()

func _input(event):
	if event.is_action_pressed("interact"):
		if is_player_inside:
			_toggle_hide()
			return

		var bodies = interact_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player"):
				player_ref = body
				_toggle_hide()
				break

func _toggle_hide():
	is_player_inside = !is_player_inside

	if is_player_inside:
		_enter_box()
	else:
		_exit_box()

func _enter_box():
	if not player_ref: return
	_play_sfx(sfx_enter)
	GlobalSave.count_action("hide")

	player_ref.visible = false
	player_ref.set_collision_layer_value(1, false)
	player_ref.set_collision_mask_value(1, false)
	player_ref.global_position = global_position
	player_ref.is_hidden_state = true

	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("stop_chasing_forced"):
			enemy.stop_chasing_forced()

func _exit_box():
	if not player_ref: return
	_play_sfx(sfx_exit)

	player_ref.visible = true
	player_ref.set_collision_layer_value(1, true)
	player_ref.set_collision_mask_value(1, true)
	player_ref.is_hidden_state = false
	player_ref = null

func _spawn_fragments():
	var parent = get_parent()
	if not parent: return
	var origin = global_position
	var box_colors = [
		Color(0.72, 0.52, 0.22),
		Color(0.58, 0.40, 0.16),
		Color(0.80, 0.62, 0.30),
		Color(0.55, 0.38, 0.12),
	]
	for i in range(10):
		var w = randf_range(4.0, 14.0)
		var h = randf_range(4.0, 12.0)
		var frag = Polygon2D.new()
		frag.polygon = PackedVector2Array([
			Vector2(-w, -h), Vector2(w, -h),
			Vector2(w, h), Vector2(-w, h),
		])
		frag.color = box_colors[randi() % box_colors.size()]
		parent.add_child(frag)
		frag.global_position = origin + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		frag.rotation = randf_range(0.0, 2.0 * PI)
		var vel = Vector2(randf_range(-200.0, 200.0), randf_range(-220.0, 220.0))
		var duration = randf_range(0.4, 0.8)
		var end_color = Color(frag.color.r, frag.color.g, frag.color.b, 0.0)
		var tween = frag.create_tween().set_parallel(true)
		tween.tween_property(frag, "position", frag.position + vel * duration, duration)
		tween.tween_property(frag, "rotation", frag.rotation + randf_range(-PI * 2.0, PI * 2.0), duration)
		tween.tween_property(frag, "color", end_color, duration)
		tween.finished.connect(frag.queue_free)

func _play_sfx(stream: AudioStream):
	if stream == null: return
	_sfx_player.stream = stream
	_sfx_player.play()
