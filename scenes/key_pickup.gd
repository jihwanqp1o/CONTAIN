extends StaticBody2D

signal key_taken

const CORRECT_CODE: String = "0319"

var _player_in_range: bool = false
var _used: bool = false
var _hidden: bool = false
var _area: Area2D = null

var _showing_story: bool = false
var _story_popup: Control = null
var _reveal_canvas: CanvasLayer = null
var _arrow_label: Label = null
var _bob_t: float = 0.0

var _keypad_open: bool = false
var _keypad_layer: CanvasLayer = null
var _entered: String = ""
var _digit_display: Label = null
var _error_label: Label = null

const STORY_TEXT = """[ 연구원 김민준의 수첩 ]

   2084년 3월 19일

   시설 내부 잠금이 해제된 구역에서
   "그것"들이 나타나기 시작했다.
   프로토콜 CONTAIN이 발동됐지만
   격리에 실패했다.

   보스 격리실 열쇠를 이 보관함에 남겨둔다.
   누군가 이걸 읽는다면…
   제발 살아서 나가라.

   보관함 코드 — 오늘의 날짜.
						— 김민준"""

func _ready() -> void:
	add_to_group("key_pickup")
	_build_visual()
	_build_interact_area()

	if GlobalSave.all_important_memories_collected():
		show_reveal_hud()  # 이전 런에서 이미 수집 완료
	else:
		_hide_key()
		GlobalSave.key_revealed.connect(_on_key_revealed)

func _exit_tree() -> void:
	if is_instance_valid(_reveal_canvas):
		_reveal_canvas.queue_free()
		_reveal_canvas = null

func _hide_key() -> void:
	_hidden = true
	visible = false
	if _area:
		_area.monitoring = false

func _on_key_revealed() -> void:
	_hidden = false
	if _area:
		_area.monitoring = true
	modulate.a = 0.0
	visible = true
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.2)
	_add_world_arrow()
	show_reveal_hud()

func _add_world_arrow() -> void:
	var arrow = Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", 32)
	arrow.add_theme_color_override("font_color", Color(1.3, 1.0, 0.15))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.position = Vector2(-20, -80)
	arrow.z_index  = 20
	add_child(arrow)
	var bob = arrow.create_tween().set_loops()
	bob.tween_property(arrow, "position:y", -92.0, 0.6).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(arrow, "position:y", -80.0, 0.6).set_ease(Tween.EASE_IN_OUT)

## important_memory.gd에서 패널 닫힌 후 호출 — 열쇠를 줍기 전까지 계속 표시
func show_reveal_hud() -> void:
	if is_instance_valid(_reveal_canvas): return
	_reveal_canvas = CanvasLayer.new()
	_reveal_canvas.layer = 88
	get_tree().root.add_child(_reveal_canvas)

	# 미니맵(offset_bottom=165) 아래 배치, 너비 동일
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.set_offset(SIDE_LEFT,  -215)
	panel.set_offset(SIDE_RIGHT,   -5)
	panel.set_offset(SIDE_TOP,    170)
	panel.set_offset(SIDE_BOTTOM, 267)
	_reveal_canvas.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var t1 = Label.new()
	t1.text = "✦  보안 보관실 위치 확인"
	t1.add_theme_color_override("font_color", Color(1.3, 1.0, 0.15))
	t1.add_theme_font_size_override("font_size", 12)
	vb.add_child(t1)

	var t2 = Label.new()
	t2.text = "격리 유적 동쪽 끝  (화살표 따라가기)"
	t2.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	t2.add_theme_font_size_override("font_size", 11)
	vb.add_child(t2)

	var t3 = Label.new()
	t3.text = "보관함 코드:  0 3 1 9"
	t3.add_theme_color_override("font_color", Color(0.30, 1.0, 0.45))
	t3.add_theme_font_size_override("font_size", 13)
	vb.add_child(t3)

	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.5)

	# 화면 엣지 방향 화살표
	_arrow_label = Label.new()
	_arrow_label.text = "►"
	_arrow_label.add_theme_font_size_override("font_size", 28)
	_arrow_label.add_theme_color_override("font_color", Color(1.3, 1.0, 0.15, 0.92))
	_arrow_label.pivot_offset = Vector2(14, 14)
	_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_canvas.add_child(_arrow_label)

	set_process(true)

# ─────────────────────────────
# 화살표 업데이트 (_process에서 직접 처리)
# ─────────────────────────────
func _process(delta: float) -> void:
	if not _arrow_label or not is_instance_valid(_reveal_canvas): return
	_bob_t += delta
	var vp = get_viewport()
	if not vp: return
	var vp_size = vp.get_visible_rect().size
	var edge = 42.0
	var key_screen: Vector2 = vp.get_canvas_transform() * global_position
	if key_screen.x > edge and key_screen.x < vp_size.x - edge and \
	   key_screen.y > edge and key_screen.y < vp_size.y - edge:
		_arrow_label.visible = false
		return
	_arrow_label.visible = true
	var center = vp_size * 0.5
	var dir = (key_screen - center).normalized()
	if dir.length_squared() < 0.0001: return
	var t_min: float = INF
	if abs(dir.x) > 0.0001:
		var t = ((vp_size.x - edge - center.x) if dir.x > 0.0 else (edge - center.x)) / dir.x
		if t > 0.0: t_min = min(t_min, t)
	if abs(dir.y) > 0.0001:
		var t = ((vp_size.y - edge - center.y) if dir.y > 0.0 else (edge - center.y)) / dir.y
		if t > 0.0: t_min = min(t_min, t)
	if t_min == INF: return
	var edge_pos = center + dir * t_min
	var bob = sin(_bob_t * 4.0) * 4.0
	_arrow_label.position = edge_pos - _arrow_label.pivot_offset + dir * bob
	_arrow_label.rotation = dir.angle()

# ─────────────────────────────
# 입력
# ─────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _hidden or _used: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key = event.keycode == KEY_E or event.physical_keycode == KEY_E
	if not key: return

	if _keypad_open:
		# 키패드 열려 있을 때 E는 닫기
		_close_keypad()
		get_viewport().set_input_as_handled()
	elif _showing_story and _player_in_range:
		_close_story()
		_open_keypad()
		get_viewport().set_input_as_handled()
	elif not _showing_story and _player_in_range:
		_open_story()
		get_viewport().set_input_as_handled()

# ─────────────────────────────
# 스토리 팝업
# ─────────────────────────────
func _open_story() -> void:
	_showing_story = true
	var layer = CanvasLayer.new()
	layer.layer = 80
	get_tree().root.add_child(layer)

	_story_popup = Control.new()
	_story_popup.set_anchors_preset(Control.PRESET_CENTER)
	_story_popup.custom_minimum_size = Vector2(460, 360)
	_story_popup.offset_left   = -230
	_story_popup.offset_right  =  230
	_story_popup.offset_top    = -180
	_story_popup.offset_bottom =  180
	_story_popup.z_index = 80
	layer.add_child(_story_popup)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 0.93)
	_story_popup.add_child(bg)

	# 테두리
	for side in [
		{"p": Vector2(0,0),     "s": Vector2(460, 2)},
		{"p": Vector2(0, 358),  "s": Vector2(460, 2)},
		{"p": Vector2(0,0),     "s": Vector2(2, 360)},
		{"p": Vector2(458,0),   "s": Vector2(2, 360)},
	]:
		var bd = ColorRect.new()
		bd.position = side["p"]; bd.size = side["s"]
		bd.color = Color(0.45, 0.35, 0.20, 0.70)
		_story_popup.add_child(bd)

	var text_label = Label.new()
	text_label.text = STORY_TEXT
	text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_label.offset_left   = 22
	text_label.offset_right  = -22
	text_label.offset_top    = 14
	text_label.offset_bottom = -42
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.68))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_popup.add_child(text_label)

	var hint = Label.new()
	hint.text = "[ E ] 보관함 열기"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top    = -32
	hint.offset_bottom = -6
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1.1, 0.9, 0.2))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_popup.add_child(hint)

	_story_popup.modulate.a = 0.0
	_story_popup.create_tween().tween_property(_story_popup, "modulate:a", 1.0, 0.25)

func _close_story() -> void:
	_showing_story = false
	if not _story_popup: return
	var p = _story_popup
	_story_popup = null
	var layer = p.get_parent()  # CanvasLayer
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		if is_instance_valid(layer): layer.queue_free()
	)

# ─────────────────────────────
# 키패드 UI
# ─────────────────────────────
func _open_keypad() -> void:
	_keypad_open = true
	_entered = ""
	_keypad_layer = CanvasLayer.new()
	_keypad_layer.layer = 85
	get_tree().root.add_child(_keypad_layer)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.60)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keypad_layer.add_child(dim)

	var panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(280, 380)
	panel.offset_left  = -140
	panel.offset_right =  140
	panel.offset_top   = -190
	panel.offset_bottom=  190
	_keypad_layer.add_child(panel)

	var pbg = ColorRect.new()
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbg.color = Color(0.05, 0.05, 0.08, 0.97)
	panel.add_child(pbg)

	# 테두리
	for side in [
		{"p": Vector2(0,0),    "s": Vector2(280,2)},
		{"p": Vector2(0,378),  "s": Vector2(280,2)},
		{"p": Vector2(0,0),    "s": Vector2(2,380)},
		{"p": Vector2(278,0),  "s": Vector2(2,380)},
	]:
		var bd = ColorRect.new()
		bd.position = side["p"]; bd.size = side["s"]
		bd.color = Color(0.50, 0.38, 0.15, 0.80)
		panel.add_child(bd)

	# 제목
	var title = Label.new()
	title.text = "[ 격리 보관함 ]"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.75, 0.60, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(280, 24)
	panel.add_child(title)

	# 코드 디스플레이
	var disp_bg = ColorRect.new()
	disp_bg.position = Vector2(30, 50)
	disp_bg.size     = Vector2(220, 48)
	disp_bg.color    = Color(0.02, 0.04, 0.02, 1.0)
	panel.add_child(disp_bg)

	_digit_display = Label.new()
	_digit_display.text = "_ _ _ _"
	_digit_display.add_theme_font_size_override("font_size", 28)
	_digit_display.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_digit_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digit_display.position = Vector2(30, 52)
	_digit_display.size     = Vector2(220, 44)
	panel.add_child(_digit_display)

	# 오류 라벨
	_error_label = Label.new()
	_error_label.text = ""
	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.position = Vector2(0, 100)
	_error_label.size     = Vector2(280, 20)
	panel.add_child(_error_label)

	# 숫자 키패드 (1~9, 0)
	const BTN_W = 68.0
	const BTN_H = 46.0
	const PAD_X = 26.0
	const START_Y = 128.0
	const GAP = 8.0
	var digits = [1, 2, 3, 4, 5, 6, 7, 8, 9, -1, 0, -2]  # -1=빈칸, -2=백스페이스
	for i in digits.size():
		var col = i % 3
		var row = i / 3
		var bx = PAD_X + col * (BTN_W + GAP)
		var by = START_Y + row * (BTN_H + GAP)
		var d = digits[i]
		if d == -1: continue
		var btn = Button.new()
		btn.position = Vector2(bx, by)
		btn.size     = Vector2(BTN_W, BTN_H)
		if d == -2:
			btn.text = "⌫"
		else:
			btn.text = str(d)
		btn.add_theme_font_size_override("font_size", 20)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.10, 0.12, 0.10) if d != -2 else Color(0.14, 0.06, 0.06)
		s.border_color = Color(0.35, 0.28, 0.12)
		s.border_width_top = 1; s.border_width_bottom = 1
		s.border_width_left = 1; s.border_width_right = 1
		s.corner_radius_top_left = 3; s.corner_radius_top_right = 3
		s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
		btn.add_theme_stylebox_override("normal", s)
		if d == -2:
			btn.pressed.connect(_on_backspace)
		else:
			btn.pressed.connect(_on_digit_pressed.bind(d))
		panel.add_child(btn)

	# 확인 버튼
	var confirm = Button.new()
	confirm.text = "확인"
	confirm.position = Vector2(PAD_X, START_Y + 4 * (BTN_H + GAP))
	confirm.size     = Vector2(BTN_W * 3 + GAP * 2, BTN_H)
	confirm.add_theme_font_size_override("font_size", 16)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.22, 0.10)
	cs.border_color = Color(0.40, 0.65, 0.25)
	cs.border_width_top = 1; cs.border_width_bottom = 1
	cs.border_width_left = 1; cs.border_width_right = 1
	cs.corner_radius_top_left = 3; cs.corner_radius_top_right = 3
	cs.corner_radius_bottom_left = 3; cs.corner_radius_bottom_right = 3
	confirm.add_theme_stylebox_override("normal", cs)
	confirm.add_theme_color_override("font_color", Color(0.75, 1.0, 0.60))
	confirm.pressed.connect(_on_confirm)
	panel.add_child(confirm)

	# 닫기 힌트
	var close_hint = Label.new()
	close_hint.text = "[ E ] 닫기"
	close_hint.add_theme_font_size_override("font_size", 11)
	close_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.position = Vector2(0, 358)
	close_hint.size     = Vector2(272, 18)
	panel.add_child(close_hint)

	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.2)

func _on_digit_pressed(d: int) -> void:
	if _entered.length() >= 4: return
	_entered += str(d)
	_update_display()

func _on_backspace() -> void:
	if _entered.is_empty(): return
	_entered = _entered.left(_entered.length() - 1)
	_update_display()

func _update_display() -> void:
	if not _digit_display: return
	var shown = ""
	for i in 4:
		if i < _entered.length():
			shown += _entered[i]
		else:
			shown += "_"
		if i < 3: shown += " "
	_digit_display.text = shown

func _on_confirm() -> void:
	if _entered.length() < 4:
		_show_error("코드를 완성하세요")
		return
	if _entered == CORRECT_CODE:
		_close_keypad()
		_take_key()
	else:
		_entered = ""
		_update_display()
		_show_error("코드 오류")

func _show_error(msg: String) -> void:
	if not _error_label: return
	_error_label.text = msg
	_error_label.modulate.a = 1.0
	var tw = _error_label.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_error_label, "modulate:a", 0.0, 0.4)

func _close_keypad() -> void:
	_keypad_open = false
	_digit_display = null
	_error_label   = null
	if is_instance_valid(_keypad_layer):
		_keypad_layer.queue_free()
	_keypad_layer = null

# ─────────────────────────────
# 열쇠 획득
# ─────────────────────────────
func _take_key() -> void:
	_used = true
	_arrow_label = null
	set_process(false)
	if is_instance_valid(_reveal_canvas):
		_reveal_canvas.queue_free()
		_reveal_canvas = null
	var player = get_tree().get_first_node_in_group("player")
	if player and "has_key" in player:
		player.has_key = true
	key_taken.emit()
	_show_key_obtained_hud()
	queue_free()

func _show_key_obtained_hud() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 92
	get_tree().root.add_child(layer)
	var panel = PanelContainer.new()
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -250)
	panel.set_offset(SIDE_RIGHT,   250)
	panel.set_offset(SIDE_TOP,     -58)
	panel.set_offset(SIDE_BOTTOM,   58)
	panel.z_index = 90
	layer.add_child(panel)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)

	var top = Label.new()
	top.text = "✦  보스 격리실 열쇠 획득"
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_color_override("font_color", Color(1.3, 1.0, 0.15))
	top.add_theme_font_size_override("font_size", 16)
	vb.add_child(top)

	var sub = Label.new()
	sub.text = "격리실 문이 열렸다  —  시작 지점 근처로 돌아가라"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	sub.add_theme_font_size_override("font_size", 12)
	vb.add_child(sub)

	panel.modulate.a = 0.0
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)


# ─────────────────────────────
# 비주얼 / 영역
# ─────────────────────────────
func _build_visual() -> void:
	# 시신
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-28, -8), Vector2(28, -8),
		Vector2(28, 8),   Vector2(-28, 8),
	])
	body.color = Color(0.30, 0.22, 0.18)
	body.z_index = 1
	add_child(body)

	# 보관함 본체
	var locker = Polygon2D.new()
	locker.polygon = PackedVector2Array([
		Vector2(-22, -42), Vector2(22, -42),
		Vector2(22,  -10), Vector2(-22, -10),
	])
	locker.color = Color(0.18, 0.18, 0.22)
	locker.z_index = 2
	add_child(locker)

	# 보관함 테두리
	var outline = Line2D.new()
	outline.width = 1.5
	outline.default_color = Color(0.45, 0.38, 0.18, 0.85)
	outline.z_index = 3
	for pt in [Vector2(-22,-42), Vector2(22,-42), Vector2(22,-10), Vector2(-22,-10), Vector2(-22,-42)]:
		outline.add_point(pt)
	add_child(outline)

	# 자물쇠 아이콘
	var lock_pts = PackedVector2Array()
	for i in 8:
		var a = TAU * i / 8.0
		lock_pts.append(Vector2(cos(a) * 5, sin(a) * 5))
	var lock_icon = Polygon2D.new()
	lock_icon.polygon = lock_pts
	lock_icon.color = Color(0.85, 0.68, 0.15)
	lock_icon.position = Vector2(0, -26)
	lock_icon.z_index = 4
	add_child(lock_icon)

	var pulse = lock_icon.create_tween().set_loops()
	pulse.tween_property(lock_icon, "modulate:a", 0.4, 1.0)
	pulse.tween_property(lock_icon, "modulate:a", 1.0, 1.0)

	var hint = Label.new()
	hint.text = "[ E ] 조사"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-40, -65)
	hint.z_index = 5
	add_child(hint)

func _build_interact_area() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask  = 1
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 80)
	cs.shape = rect
	_area.add_child(cs)
	_area.body_entered.connect(func(b):
		if b.is_in_group("player"): _player_in_range = true
	)
	_area.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = false
			if _showing_story: _close_story()
			if _keypad_open:   _close_keypad()
	)
	add_child(_area)
