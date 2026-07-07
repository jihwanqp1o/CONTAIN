extends Node2D

const INTERACT_RANGE: float = 70.0

var _player_nearby: Node = null
var _hint_label: Label   = null
var _ui_open: bool       = false
var _ui_layer: CanvasLayer = null
var _tab: int = 0   # 0 = 능력 강화, 1 = 스킬 구매

func _ready() -> void:
	_build_visual()
	_build_interact_area()

func _process(_delta: float) -> void:
	if _player_nearby and Input.is_action_just_pressed("interact"):
		if _ui_open:
			_close_ui()
		else:
			_open_ui()
	if _ui_open and Input.is_action_just_pressed("ui_cancel"):
		_close_ui()

# ─────────────────────────────────────────────
# UI 열기/닫기
# ─────────────────────────────────────────────
func _open_ui() -> void:
	_ui_open = true
	get_tree().paused = true
	_ui_layer = CanvasLayer.new()
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_ui_layer)
	_rebuild_ui()

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _ui_layer:
		_ui_layer.queue_free()
		_ui_layer = null

func _rebuild_ui() -> void:
	for c in _ui_layer.get_children():
		c.queue_free()

	# 배경 반투명
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(bg)

	# 메인 패널
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 480)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -310)
	panel.set_offset(SIDE_RIGHT,   310)
	panel.set_offset(SIDE_TOP,    -240)
	panel.set_offset(SIDE_BOTTOM,  240)
	_ui_layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 제목 + KP 표시
	var header = HBoxContainer.new()
	vbox.add_child(header)
	var title = Label.new()
	title.text = "[ 기억 터미널 ]"
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var kp_lbl = Label.new()
	kp_lbl.name = "KPLabel"
	kp_lbl.text = "KP: %d" % GlobalSave.get_total_kp()
	kp_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	kp_lbl.add_theme_font_size_override("font_size", 15)
	header.add_child(kp_lbl)

	# 탭 버튼
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vbox.add_child(tabs)
	var tab_names = ["능력 강화", "스킬 구매"]
	for i in 2:
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(120, 30)
		if i == _tab:
			btn.modulate = Color(1.0, 0.9, 0.3)
		var idx = i
		btn.pressed.connect(func():
			_tab = idx
			_rebuild_ui()
		)
		tabs.add_child(btn)

	# 닫기 버튼
	var close_btn = Button.new()
	close_btn.text = "닫기 [ESC]"
	close_btn.custom_minimum_size = Vector2(90, 30)
	close_btn.pressed.connect(_close_ui)
	tabs.add_child(close_btn)

	# 구분선
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 탭 콘텐츠
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if _tab == 0:
		_build_ability_tab(content)
	else:
		_build_skill_tab(content)

	# 안내
	var hint = Label.new()
	hint.text = "E 또는 ESC 로 닫기"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

# ─────────────────────────────────────────────
# 탭 0: 능력 강화
# ─────────────────────────────────────────────
func _build_ability_tab(parent: VBoxContainer) -> void:
	var ability_ids = GlobalSave.ABILITY_NAMES.keys()
	for ability_id in ability_ids:
		var level = GlobalSave.get_ability_level(ability_id)
		var name  = GlobalSave.ABILITY_NAMES[ability_id]
		var descs = GlobalSave.ABILITY_DESCS.get(ability_id, [])
		var costs = GlobalSave.ABILITY_UPGRADE_COSTS.get(ability_id, [])

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)

		# 능력 이름 + 레벨 표시
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl = Label.new()
		if level == 0:
			name_lbl.text = "??? (미해금)"
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			name_lbl.text = "%s  [Lv.%d]" % [name, level]
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		name_lbl.add_theme_font_size_override("font_size", 13)
		info.add_child(name_lbl)

		# 현재 레벨 설명
		if level > 0 and descs.size() >= level:
			var desc_lbl = Label.new()
			desc_lbl.text = "현재: " + descs[level - 1]
			desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			desc_lbl.add_theme_font_size_override("font_size", 11)
			info.add_child(desc_lbl)

		# 다음 단계 설명
		if level > 0 and level < 3 and descs.size() > level:
			var next_lbl = Label.new()
			next_lbl.text = "다음: " + descs[level]
			next_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
			next_lbl.add_theme_font_size_override("font_size", 11)
			info.add_child(next_lbl)

		# 해금 조건 (level == 0)
		if level == 0:
			var unlock_hint = _get_unlock_hint(ability_id)
			var hint_lbl = Label.new()
			hint_lbl.text = unlock_hint
			hint_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			hint_lbl.add_theme_font_size_override("font_size", 10)
			info.add_child(hint_lbl)

		# 강화 버튼
		if level > 0 and level < 3:
			var cost_idx = level - 1
			var cost = costs[cost_idx] if cost_idx < costs.size() else 999
			var btn = Button.new()
			btn.text = "강화 (%d KP)" % cost
			btn.custom_minimum_size = Vector2(110, 28)
			if GlobalSave.get_total_kp() < cost:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5)
			var ab_id = ability_id
			btn.pressed.connect(func():
				if GlobalSave.upgrade_ability(ab_id):
					_rebuild_ui()
			)
			row.add_child(btn)
		elif level == 3:
			var done = Label.new()
			done.text = "MAX"
			done.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			done.add_theme_font_size_override("font_size", 13)
			row.add_child(done)

		parent.add_child(HSeparator.new())

# ─────────────────────────────────────────────
# 탭 1: 스킬 구매
# ─────────────────────────────────────────────
func _build_skill_tab(parent: VBoxContainer) -> void:
	for skill_id in GlobalSave.PURCHASABLE_SKILLS:
		var info_dict = GlobalSave.PURCHASABLE_SKILLS[skill_id]
		var owned = GlobalSave.has_skill(skill_id)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl = Label.new()
		name_lbl.text = info_dict["name"]
		name_lbl.add_theme_font_size_override("font_size", 13)
		if owned:
			name_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		info.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = info_dict["desc"]
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		info.add_child(desc_lbl)

		if owned:
			var done = Label.new()
			done.text = "보유 중"
			done.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
			done.add_theme_font_size_override("font_size", 12)
			row.add_child(done)
		else:
			var cost: int = info_dict["cost"]
			var btn = Button.new()
			btn.text = "구매 (%d KP)" % cost
			btn.custom_minimum_size = Vector2(120, 28)
			if GlobalSave.get_total_kp() < cost:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5)
			var s_id = skill_id
			btn.pressed.connect(func():
				if GlobalSave.buy_skill(s_id, GlobalSave.PURCHASABLE_SKILLS[s_id]["cost"]):
					_rebuild_ui()
			)
			row.add_child(btn)

		parent.add_child(HSeparator.new())

func _get_unlock_hint(ability_id: String) -> String:
	match ability_id:
		"shadow_instinct": return "해금 조건: 은신 10회"
		"light_control":   return "해금 조건: 눈부심 8회"
		"steady_hand":     return "해금 조건: 파편 격파 5회"
		"flame_sense":     return "해금 조건: 신호탄 사용 5회"
		"fear_resist":     return "해금 조건: 공포 100% 생존 3회"
		_: return "해금 조건 불명"

# ─────────────────────────────────────────────
# 인게임 비주얼 + 감지 영역
# ─────────────────────────────────────────────
func _build_visual() -> void:
	# 터미널 본체 (직사각형)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-20, -28), Vector2(20, -28),
		Vector2(20,  28), Vector2(-20,  28),
	])
	body.color = Color(0.15, 0.20, 0.30)
	add_child(body)

	# 화면 (발광)
	var screen = Polygon2D.new()
	screen.polygon = PackedVector2Array([
		Vector2(-14, -20), Vector2(14, -20),
		Vector2(14,   8), Vector2(-14,  8),
	])
	screen.color = Color(0.2, 0.55, 0.9, 0.85)
	add_child(screen)

	# 화면 텍스트 표시 (심볼)
	var lbl = Label.new()
	lbl.text = "KP"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 1.0))
	lbl.position = Vector2(-8, -14)
	add_child(lbl)

	# 하단 버튼부
	var btn_body = Polygon2D.new()
	btn_body.polygon = PackedVector2Array([
		Vector2(-16, 12), Vector2(16, 12),
		Vector2(16, 22), Vector2(-16, 22),
	])
	btn_body.color = Color(0.25, 0.35, 0.50)
	add_child(btn_body)

	_hint_label = Label.new()
	_hint_label.text = "E - 터미널"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_hint_label.position = Vector2(-28, 32)
	_hint_label.visible  = false
	add_child(_hint_label)

func _build_interact_area() -> void:
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = INTERACT_RANGE
	shape.shape   = circle
	area.add_child(shape)
	area.body_entered.connect(_on_player_enter)
	area.body_exited.connect(_on_player_exit)
	add_child(area)

func _on_player_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = body
		if _hint_label: _hint_label.visible = true

func _on_player_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = null
		if _hint_label: _hint_label.visible = false
		if _ui_open: _close_ui()
