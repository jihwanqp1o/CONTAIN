extends Node2D

signal panel_activated

const ACTIVATE_TIME: float = 3.0
const BAR_W: float = 44.0
const BAR_H: float = 7.0

var _active: bool = false
var _progress: float = 0.0
var _player_nearby: bool = false
var _label: Label = null
var _bar_fill: Polygon2D = null
var _glow: Polygon2D = null
var _screen_poly: Polygon2D = null

func _ready() -> void:
	_build_visual()
	_build_detect_area()

func _process(delta: float) -> void:
	if _active: return

	if _player_nearby and Input.is_action_pressed("interact"):
		_progress = min(_progress + delta / ACTIVATE_TIME, 1.0)
		_update_bar()
		if _progress >= 1.0:
			_activate()
	elif _progress > 0.0:
		_progress = max(_progress - delta * 2.0, 0.0)
		_update_bar()

func _activate() -> void:
	_active = true
	panel_activated.emit()
	if _label: _label.text = "[ 격리 완료 ]"
	if _bar_fill: _bar_fill.visible = false
	if _screen_poly: _screen_poly.color = Color(0.08, 0.60, 0.22, 0.9)
	if _glow:
		_glow.color = Color(0.15, 0.90, 0.35, 0.25)
		var tw2 = _glow.create_tween().set_loops()
		tw2.tween_property(_glow, "modulate:a", 0.7, 0.55)
		tw2.tween_property(_glow, "modulate:a", 1.0, 0.55)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(0.6, 2.0, 0.8), 0.25)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.7)

func _build_visual() -> void:
	# 환경광 (어두운 아레나에서 패널 자체 발광)
	var light = PointLight2D.new()
	light.color = Color(0.25, 0.60, 1.0)
	light.energy = 0.9
	light.texture_scale = 1.4
	light.texture = _make_light_texture()
	light.z_index = 1
	add_child(light)
	var ltw = light.create_tween().set_loops()
	ltw.tween_property(light, "energy", 0.55, 1.2)
	ltw.tween_property(light, "energy", 0.9,  1.2)

	# 패널 외벽
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-22, -32), Vector2(22, -32),
		Vector2(22, 32), Vector2(-22, 32)
	])
	body.color = Color(0.20, 0.26, 0.42)
	body.z_index = 3
	add_child(body)

	# 스크린 영역
	_screen_poly = Polygon2D.new()
	_screen_poly.polygon = PackedVector2Array([
		Vector2(-16, -24), Vector2(16, -24),
		Vector2(16, 16), Vector2(-16, 16)
	])
	_screen_poly.color = Color(0.08, 0.48, 0.82, 0.95)
	_screen_poly.z_index = 4
	add_child(_screen_poly)

	# 화면 스캔라인
	for i in 3:
		var ln = Line2D.new()
		var y = -16.0 + float(i) * 10.0
		ln.add_point(Vector2(-13, y))
		ln.add_point(Vector2(13, y))
		ln.width = 1.5
		ln.default_color = Color(0.45, 0.80, 1.0, 0.65)
		ln.z_index = 5
		add_child(ln)

	# 리벳 점
	for sy in [-20.0, 20.0]:
		for sx in [-19.0, 19.0]:
			var dot = Polygon2D.new()
			var pts = PackedVector2Array()
			for k in 6:
				var a = TAU * float(k) / 6.0
				pts.append(Vector2(sx + cos(a) * 2.0, sy + sin(a) * 2.0))
			dot.polygon = pts
			dot.color = Color(0.55, 0.65, 0.85)
			dot.z_index = 5
			add_child(dot)

	# 발광 후광 (크고 밝게)
	_glow = Polygon2D.new()
	var gpts = PackedVector2Array()
	for i in 16:
		var a = TAU * float(i) / 16.0
		gpts.append(Vector2(cos(a), sin(a)) * 50.0)
	_glow.polygon = gpts
	_glow.color = Color(0.15, 0.55, 1.0, 0.30)
	_glow.z_index = 2
	add_child(_glow)
	var tw = _glow.create_tween().set_loops()
	tw.tween_property(_glow, "modulate:a", 0.40, 1.0)
	tw.tween_property(_glow, "modulate:a", 1.0,  1.0)

	# 외곽 테두리
	var brd = Line2D.new()
	for p in [Vector2(-22, -32), Vector2(22, -32), Vector2(22, 32), Vector2(-22, 32), Vector2(-22, -32)]:
		brd.add_point(p)
	brd.width = 2.5
	brd.default_color = Color(0.40, 0.72, 1.0)
	brd.z_index = 6
	add_child(brd)

	# 진행 바 배경
	var bar_bg = Polygon2D.new()
	bar_bg.polygon = PackedVector2Array([
		Vector2(-BAR_W / 2, -BAR_H / 2), Vector2(BAR_W / 2, -BAR_H / 2),
		Vector2(BAR_W / 2, BAR_H / 2), Vector2(-BAR_W / 2, BAR_H / 2)
	])
	bar_bg.color = Color(0.10, 0.12, 0.20)
	bar_bg.position = Vector2(0, 42)
	bar_bg.z_index = 5
	add_child(bar_bg)

	# 진행 바 채움
	_bar_fill = Polygon2D.new()
	_bar_fill.polygon = PackedVector2Array([
		Vector2(-BAR_W / 2, -BAR_H / 2), Vector2(-BAR_W / 2, -BAR_H / 2),
		Vector2(-BAR_W / 2, BAR_H / 2), Vector2(-BAR_W / 2, BAR_H / 2)
	])
	_bar_fill.color = Color(0.40, 0.82, 1.0)
	_bar_fill.position = Vector2(0, 42)
	_bar_fill.z_index = 6
	add_child(_bar_fill)

	# 안내 레이블
	_label = Label.new()
	_label.text = "[ E ] 격리 활성화"
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-60, 52)
	_label.visible = false
	_label.z_index = 7
	add_child(_label)

func _make_light_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center = Vector2(64, 64)
	for y in 128:
		for x in 128:
			var d = Vector2(x, y).distance_to(center) / 64.0
			var a = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func _update_bar() -> void:
	if not _bar_fill: return
	var fill_w = BAR_W * _progress
	_bar_fill.polygon = PackedVector2Array([
		Vector2(-BAR_W / 2, -BAR_H / 2), Vector2(-BAR_W / 2 + fill_w, -BAR_H / 2),
		Vector2(-BAR_W / 2 + fill_w, BAR_H / 2), Vector2(-BAR_W / 2, BAR_H / 2)
	])

func _build_detect_area() -> void:
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var cs = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 75.0
	cs.shape = circle
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if _label and not _active:
			_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if _label:
			_label.visible = false
