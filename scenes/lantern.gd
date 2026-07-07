extends Node2D

const MAX_LANTERNS:   int   = 2
const DURATION:       float = 90.0
const LIGHT_RADIUS:   float = 256.0   # texture_scale = 4.0 → 64*4
const FADE_START:     float = 20.0    # 남은 시간이 이 이하면 꺼지기 시작
const PICKUP_RANGE:   float = 60.0

static var _shared_tex: ImageTexture = null

var _timer:         float       = DURATION
var _light:         PointLight2D = null
var _base_energy:   float       = 1.3
var _pulse_time:    float       = 0.0
var _player_nearby: Node        = null
var _pickup_hint:   Label       = null

func _ready() -> void:
	add_to_group("lantern")
	if GlobalSave.has_skill("lantern_memory"):
		_timer += 45.0
	_build_visual()
	_build_light()
	_build_pickup_area()
	_enforce_max()

func _process(delta: float) -> void:
	_timer -= delta
	_pulse_time += delta

	# 서서히 꺼짐 (마지막 20초)
	if _light:
		var energy_mult = 1.0
		if _timer < FADE_START:
			energy_mult = max(0.0, _timer / FADE_START)
		# 미세 흔들림 (현실감)
		var flicker = 1.0 + sin(_pulse_time * 7.3) * 0.04 + sin(_pulse_time * 13.1) * 0.02
		_light.energy = _base_energy * energy_mult * flicker

	if _timer <= 0.0:
		queue_free()
		return

	_update_time_label()

	# 적 유인 (1초마다)
	if _player_nearby and Input.is_action_just_pressed("interact"):
		_try_pickup()

func _try_pickup() -> void:
	if not _player_nearby or not is_instance_valid(_player_nearby): return
	if not _player_nearby.has_method("try_pickup_item"): return
	if _player_nearby.try_pickup_item(6):  # 6 = LANTERN
		queue_free()

func _on_player_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = body
		if _pickup_hint: _pickup_hint.visible = true

func _on_player_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = null
		if _pickup_hint: _pickup_hint.visible = false

func _build_pickup_area() -> void:
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = PICKUP_RANGE
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_player_enter)
	area.body_exited.connect(_on_player_exit)
	add_child(area)

	_pickup_hint = Label.new()
	_pickup_hint.text = "E - 회수"
	_pickup_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_hint.add_theme_font_size_override("font_size", 12)
	_pickup_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_pickup_hint.position = Vector2(-22, 26)
	_pickup_hint.visible  = false
	add_child(_pickup_hint)

func _enforce_max() -> void:
	var lanterns = get_tree().get_nodes_in_group("lantern")
	if lanterns.size() <= MAX_LANTERNS: return
	# 타이머가 가장 적게 남은 것 = 가장 먼저 배치된 것 → 제거
	var oldest: Node = null
	var min_time: float = INF
	for l in lanterns:
		if l == self: continue
		if l._timer < min_time:
			min_time = l._timer
			oldest = l
	if oldest:
		oldest.queue_free()

# ─────────────────────────────
# 빛 구성
# ─────────────────────────────

func _build_light() -> void:
	_light = PointLight2D.new()

	if _shared_tex == null:
		var size = 128
		var half = size * 0.5
		var img  = Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d = Vector2(x, y).distance_to(Vector2(half, half)) / half
				var a = clamp(1.0 - d, 0.0, 1.0)
				a = a * a * a
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_shared_tex = ImageTexture.create_from_image(img)

	_light.texture       = _shared_tex
	_light.texture_scale = LIGHT_RADIUS / half  # = 4.0
	_light.color         = Color(1.0, 0.80, 0.42)  # 따뜻한 주황빛
	_light.energy        = _base_energy
	_light.shadow_enabled = false
	add_child(_light)

# ─────────────────────────────
# 비주얼: 손잡이 있는 랜턴 모양
# ─────────────────────────────

func _build_visual() -> void:
	# 발광 후광
	var glow = Polygon2D.new()
	var gpts = PackedVector2Array()
	for i in 20:
		var a = TAU * i / 20.0
		gpts.append(Vector2(cos(a), sin(a)) * 22.0)
	glow.polygon = gpts
	glow.color   = Color(1.0, 0.75, 0.30, 0.18)
	glow.z_index = -1
	add_child(glow)

	# 랜턴 몸체 (육각형)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2( 0, -14),
		Vector2( 9,  -7),
		Vector2( 9,   7),
		Vector2( 0,  14),
		Vector2(-9,   7),
		Vector2(-9,  -7),
	])
	body.color = Color(0.82, 0.68, 0.30)
	add_child(body)

	# 내부 유리창 (반투명)
	var glass = Polygon2D.new()
	glass.polygon = PackedVector2Array([
		Vector2( 0, -9),
		Vector2( 6, -4),
		Vector2( 6,  4),
		Vector2( 0,  9),
		Vector2(-6,  4),
		Vector2(-6, -4),
	])
	glass.color = Color(1.0, 0.92, 0.55, 0.75)
	add_child(glass)

	# 손잡이
	var handle = Polygon2D.new()
	handle.polygon = PackedVector2Array([
		Vector2(-3, -14),
		Vector2( 3, -14),
		Vector2( 2, -20),
		Vector2(-2, -20),
	])
	handle.color = Color(0.55, 0.45, 0.22)
	add_child(handle)

	# 남은 시간 표시 라벨 (희미하게)
	var lbl = Label.new()
	lbl.name = "TimeLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 0.65))
	lbl.position = Vector2(-15, 16)
	lbl.z_index  = 10
	add_child(lbl)

func _update_time_label() -> void:
	var lbl = get_node_or_null("TimeLabel")
	if not lbl: return
	if _timer > FADE_START:
		lbl.text = ""
	else:
		lbl.text = "%ds" % int(ceil(_timer))
