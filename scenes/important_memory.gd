extends Node2D

const PICKUP_RANGE: float = 65.0

const MEMORY_TEXTS: Dictionary = {
	"zone_b": {
		"title": "[ 연구 개시 기록 — 최초 실험 일지 ]",
		"text":  "모든 것은 하나의 번호로 시작되었다.\n실험 개시 일련번호: 0.\n인류의 한계를 넘기 위한 첫 번째 시도.\n그 번호는 지금도 어딘가에 새겨져 있다.",
	},
	"zone_c": {
		"title": "[ 격리 현황 보고 — 봉쇄 단계 기록 ]",
		"text":  "실험체들은 3중 격리 장치에 의해 봉쇄되었다.\n1단계와 2단계는 이미 실패했다.\n세 번째 봉쇄가 마지막 희망이었다.\n그마저도 오래가지 못했다.",
	},
	"zone_d": {
		"title": "[ 최초 격리 실패 보고서 ]",
		"text":  "보안 오류는 1번 구역에서 처음 감지되었다.\n가장 오래된 격리실, 가장 먼저 열린 문.\n단 한 번의 실수가 모든 것을 바꾸었다.\n— 그 이후로 아무도 돌아오지 않았다.",
	},
	"zone_e": {
		"title": "[ 마지막 연구원들의 기록 ]",
		"text":  "사고 당일 시설에 남아 있던 연구원은 9명이었다.\n그들은 탈출 코드를 나누어 기억하기로 했다.\n하지만 아무도 합산에 성공하지 못했다.\n이 기억이 그 코드의 마지막 조각이다.",
	},
	"zone_f": {
		"title": "[ 탈출 지침 — 최후 기록 ]",
		"text":  "보관함 코드는 순서대로다.\n0 — 3 — 1 — 9.\nF구역 동쪽 끝 보안 실험실 안에 열쇠가 있다.\n지금 당장 가라.",
	},
}

var _memory_id: String  = ""
var _pulse_time: float  = 0.0
var _player_nearby: Node = null
var _hint_label: Label  = null
var _collected: bool    = false

func setup(memory_id: String) -> void:
	_memory_id = memory_id

func _ready() -> void:
	if _memory_id == "":
		_memory_id = "imem_%d" % get_instance_id()
	if GlobalSave.is_important_memory_collected(_memory_id):
		queue_free()
		return
	_build_visual()
	_build_pickup_area()

func _process(delta: float) -> void:
	if _collected: return
	_pulse_time += delta
	scale = Vector2.ONE * (1.0 + sin(_pulse_time * 2.0) * 0.07)
	if _player_nearby and Input.is_action_just_pressed("interact"):
		_collect()

func _collect() -> void:
	if _collected: return
	_collected = true
	var triggered_reveal: bool = GlobalSave.collect_important_memory(_memory_id)
	_show_memory_text(triggered_reveal)
	set_process(false)
	if _hint_label: _hint_label.visible = false
	var sfx = AudioStreamPlayer.new()
	var _mind_pool = ["res://assets/mind.mp3", "res://assets/mind2.mp3"]
	sfx.stream = load(_mind_pool[randi() % 2])
	sfx.volume_db = -5.0
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(3.2, 3.2), 0.65)
	tw.tween_property(self, "modulate:a", 0.0, 0.65)

func _show_memory_text(triggered_reveal: bool) -> void:
	var mem      = MEMORY_TEXTS.get(_memory_id, {"title": "[ 중요한 기억 ]", "text": "…"})
	var count    = GlobalSave.get_important_memory_count()

	var overlay = CanvasLayer.new()
	overlay.layer = 22
	overlay.add_to_group("lore_popup")
	get_tree().root.add_child(overlay)

	# 반투명 배경
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.60)
	overlay.add_child(bg)

	# 패널
	var panel = PanelContainer.new()
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -290)
	panel.set_offset(SIDE_RIGHT,   290)
	panel.set_offset(SIDE_TOP,    -115 if not triggered_reveal else -140)
	panel.set_offset(SIDE_BOTTOM,  115 if not triggered_reveal else 140)
	overlay.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)

	# 상단: 제목 + 카운터
	var top = HBoxContainer.new()
	vb.add_child(top)
	var title_lbl = Label.new()
	title_lbl.text = mem["title"]
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.28))
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_lbl)
	var cnt_lbl = Label.new()
	cnt_lbl.text = "기억  %d / 5" % count
	cnt_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	cnt_lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(cnt_lbl)

	# 본문
	var body = Label.new()
	body.text = mem["text"]
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.87, 0.83, 0.74))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(body)

	# KP 표시
	var kp_row = HBoxContainer.new()
	vb.add_child(kp_row)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kp_row.add_child(sp)
	var kp_lbl = Label.new()
	kp_lbl.text = "+8 KP"
	kp_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	kp_lbl.add_theme_font_size_override("font_size", 12)
	kp_row.add_child(kp_lbl)

	# 열쇠 해금 메시지
	if triggered_reveal:
		vb.add_child(HSeparator.new())
		var reveal_lbl = Label.new()
		reveal_lbl.text = "✦  모든 기억이 맞춰졌다.  열쇠의 위치가 머릿속에 떠오른다..."
		reveal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reveal_lbl.add_theme_color_override("font_color", Color(1.3, 1.0, 0.15))
		reveal_lbl.add_theme_font_size_override("font_size", 13)
		vb.add_child(reveal_lbl)

	var close_btn = Button.new()
	close_btn.text = "[ 닫기 ]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	close_btn.flat = true
	close_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(close_btn)

	# 페이드인 → 유지 → 페이드아웃
	panel.modulate.a = 0.0
	var hold_time: float = 5.5 if triggered_reveal else 4.5
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.45)
	tw.tween_interval(hold_time)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		overlay.queue_free()
		if triggered_reveal:
			_fire_key_reveal()
		queue_free()
	)
	var close_fn = func():
		tw.kill()
		overlay.queue_free()
		if triggered_reveal:
			_fire_key_reveal()
		queue_free()
	close_btn.pressed.connect(close_fn)
	overlay.set_meta("close_fn", close_fn)

# ─────────────────────────────────────────
func _on_player_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = body
		if _hint_label: _hint_label.visible = true

func _on_player_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = null
		if _hint_label: _hint_label.visible = false

func _build_pickup_area() -> void:
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = PICKUP_RANGE
	shape.shape   = circle
	area.add_child(shape)
	area.body_entered.connect(_on_player_enter)
	area.body_exited.connect(_on_player_exit)
	add_child(area)

	_hint_label = Label.new()
	_hint_label.text = "E — 기억 회수"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.28))
	_hint_label.position = Vector2(-38, 30)
	_hint_label.visible  = false
	add_child(_hint_label)

func _build_visual() -> void:
	# 외부 헥사곤 — 금빛
	add_child(_make_hex(20.0, Color(1.0, 0.76, 0.18, 0.85)))
	# 중간 헥사곤 — 연한 금
	add_child(_make_hex(13.0, Color(1.0, 0.92, 0.52, 0.55)))
	# 중심 다이아몬드
	var core_pts = PackedVector2Array()
	for i in 4:
		var a = TAU * i / 4.0 - PI / 4.0
		core_pts.append(Vector2(cos(a), sin(a)) * 6.5)
	var core = Polygon2D.new()
	core.polygon = core_pts
	core.color   = Color(1.0, 1.0, 0.88, 1.0)
	add_child(core)
	# 후광 원
	var gpts = PackedVector2Array()
	for i in 24:
		var a = TAU * i / 24.0
		gpts.append(Vector2(cos(a), sin(a)) * 32.0)
	var glow = Polygon2D.new()
	glow.polygon = gpts
	glow.color   = Color(1.0, 0.72, 0.08, 0.22)
	glow.z_index = -1
	add_child(glow)
	# 자체 발광
	var light = PointLight2D.new()
	light.texture       = _make_light_texture()
	light.texture_scale = 3.0
	light.energy        = 1.4
	light.color         = Color(1.0, 0.80, 0.20)
	add_child(light)
	var ltw = light.create_tween().set_loops()
	ltw.tween_property(light, "energy", 0.8, 1.4)
	ltw.tween_property(light, "energy", 1.4, 1.4)

func _fire_key_reveal() -> void:
	var kp = get_tree().get_first_node_in_group("key_pickup")
	if kp and kp.has_method("show_reveal_hud"):
		kp.show_reveal_hud()

func _make_light_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center = Vector2(64, 64)
	for y in 128:
		for x in 128:
			var d = Vector2(x, y).distance_to(center) / 64.0
			var a = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)

func _make_hex(radius: float, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts  = PackedVector2Array()
	for i in 6:
		var a = TAU * i / 6.0 - PI / 6.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color   = color
	return poly
