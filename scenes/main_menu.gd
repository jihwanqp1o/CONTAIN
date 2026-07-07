extends Control

@onready var controls_panel = $ControlsPanel

var _bestiary_panel: Control = null
var _bestiary_list_vbox: VBoxContainer = null
var _bestiary_detail_root: VBoxContainer = null
var _bestiary_selected: int = -1
var _bestiary_list_btns: Array = []

var _skill_panel: Control = null
var _skill_kp_label: Label = null
var _skill_cards: Dictionary = {}  # skill_id -> button node
var _skill_current_col: int = 0
var _skill_col_btns: Array = []
var _skill_content_vbox: VBoxContainer = null

var _bg_lines: Array = []
var _bg_line_speeds: Array = []
var _kp_corner_label: Label = null
var _start_btn_style_normal: StyleBoxFlat = null
var _sfx_hover: AudioStreamPlayer = null
var _sfx_click: AudioStreamPlayer = null
var _sfx_start: AudioStreamPlayer = null

# ──────────────────────────────
# 기억 시스템 데이터
# ──────────────────────────────
const SKILL_COLUMNS: Array = [
	{
		"title": "신체 기억",
		"color": Color(0.35, 0.90, 0.45),
		"skills": [
			{"id":"stamina_1", "name":"근력 기억 I",  "desc":"달리기 스태미나 소모 -20%",       "cost":15, "req":""},
			{"id":"stamina_2", "name":"근력 기억 II", "desc":"달리기 스태미나 소모 추가 -20%",   "cost":20, "req":"stamina_1"},
			{"_fork":"body_b1", "req":"stamina_2", "options":[
				[
					{"id":"dodge_unlock",       "name":"회피 기억",    "desc":"[Space] 긴급 회피 해제",               "cost":20},
					{"id":"dodge_up",           "name":"회피 숙련",    "desc":"회피 스태미나 소모 -50%",              "cost":30},
					{"id":"dodge_perfect",      "name":"완벽한 반응",  "desc":"퍼펙트 회피 판정 시간 +0.05초",        "cost":40},
				],
				[
					{"id":"breath_hold",        "name":"숨 참기",      "desc":"은신 정지 시 소리 감지 무효",          "cost":20},
					{"id":"recovery_instinct",  "name":"회복 본능",    "desc":"탈진 상태 정지 시 회복 속도 2배",      "cost":30},
					{"id":"impact_memory",      "name":"충격 기억",    "desc":"보스 넉백 시 방향 제어 유지",          "cost":40},
				],
			]},
		],
	},
	{
		"title": "은신 기억",
		"color": Color(1.0, 0.42, 0.28),
		"skills": [
			{"id":"sneak_unlock", "name":"은신 기억",    "desc":"[Ctrl] 은신 상태 해제",                "cost":15, "req":""},
			{"id":"shadow_read",  "name":"그림자 읽기",  "desc":"어두운 구역에서 적 감지 범위 -15%",    "cost":20, "req":"sneak_unlock"},
			{"_fork":"stealth_b1", "req":"shadow_read", "options":[
				[
					{"id":"position_memory", "name":"자리 기억",    "desc":"상자 5초 은신 시 주변 적 실루엣 2초",    "cost":25},
					{"id":"assassin_unlock", "name":"암살 기억",    "desc":"은신 중 적 후방 [E] 암살 해제",         "cost":30},
					{"id":"assassin_range",  "name":"사냥 본능",    "desc":"암살 유효 거리 +40%",                   "cost":35},
				],
				[
					{"id":"quiet_step",      "name":"고요한 발걸음","desc":"달리기 소리 방출 강도 -35%",             "cost":20},
					{"id":"hearing_adapt",   "name":"청각 적응",    "desc":"은신 이동속도 +30%",                    "cost":25},
					{"id":"escape_instinct", "name":"도주 본능",    "desc":"추격 시작 3초간 이동속도 +20%",         "cost":35},
				],
			]},
		],
	},
	{
		"title": "감각 기억",
		"color": Color(0.28, 0.88, 0.98),
		"skills": [
			{"id":"battery_1",       "name":"전지 기억 I",  "desc":"손전등 배터리 소모 -25%",            "cost":10, "req":""},
			{"id":"battery_2",       "name":"전지 기억 II", "desc":"손전등 배터리 소모 추가 -25%",       "cost":20, "req":"battery_1"},
			{"id":"battery_warning", "name":"배터리 경고",  "desc":"손전등 꺼지기 5초 전 깜빡임 시작",  "cost":15, "req":"battery_2"},
			{"_fork":"sense_b1", "req":"battery_warning", "options":[
				[
					{"id":"visual_memory",  "name":"시각 기억",    "desc":"아이템 어둠 속 약한 발광 (범위 내)",     "cost":20},
					{"id":"flare_ready",    "name":"신호탄 기억",  "desc":"런 시작 시 신호탄 +1",                  "cost":30},
					{"id":"item_memory",    "name":"아이템 기억",  "desc":"배터리 아이템 충전량 +25",              "cost":35},
				],
				[
					{"id":"sense_alert",    "name":"낌새 기억",    "desc":"적이 추격 전환 시 짧은 청각 경고음",    "cost":20},
					{"id":"quiet_footstep", "name":"발소리 기억",  "desc":"달리기/걷기 소리 방출 추가 -25%",      "cost":25},
					{"id":"material_sense", "name":"재료 감각",    "desc":"재료 픽업 범위 +50%, 런 시작 재료 1개", "cost":35},
				],
			]},
		],
	},
	{
		"title": "정신 기억",
		"color": Color(0.75, 0.45, 1.0),
		"skills": [
			{"id":"fear_resist", "name":"공포 저항", "desc":"공포 증가율 -25%",        "cost":20, "req":""},
			{"id":"hide_master", "name":"잠복 기억", "desc":"상자 안 공포 감소 +50%",  "cost":15, "req":"fear_resist"},
			{"_fork":"mental_b1", "req":"hide_master", "options":[
				[
					{"id":"iron_will",   "name":"강철 신경",    "desc":"공포 증가율 추가 -25%",                "cost":30},
					{"id":"iron_will_2", "name":"불굴의 정신",  "desc":"공포 90+ 이동 패널티 완전 제거",       "cost":35},
					{"id":"calm_mind",   "name":"냉철함",       "desc":"손전등 OFF 시 공포 감소 +8/s",        "cost":30},
				],
				[
					{"id":"adapt_memory", "name":"적응 기억",    "desc":"같은 적 3회 사망마다 공포 증가 -10%",  "cost":25},
					{"id":"cold_focus",   "name":"냉혹한 집중",  "desc":"공포 50 이하에서 은신 이동속도 +10%", "cost":30},
					{"id":"fear_surge",   "name":"공포 각성",    "desc":"공포 90+ 시 아드레날린 자동 1회",     "cost":40},
				],
			]},
		],
	},
	{
		"title": "자원 기억",
		"color": Color(1.0, 0.75, 0.30),
		"skills": [
			{"id":"lantern_memory", "name":"랜턴 기억", "desc":"배치 랜턴 지속시간 +45초",     "cost":15, "req":""},
			{"id":"craft_memory",   "name":"제작 기억", "desc":"런 시작 시 랜덤 재료 2개 지급", "cost":20, "req":"lantern_memory"},
			{"_fork":"resource_b1", "req":"craft_memory", "options":[
				[
					{"id":"carry_over",      "name":"이월 기억", "desc":"사망 시 슬롯1 아이템 다음 런 이월",  "cost":35},
					{"id":"preserve_memory", "name":"비축 기억", "desc":"아이템 20% 확률 소모 없이 사용",     "cost":45},
				],
				[
					{"id":"waste_not",       "name":"절약 본능", "desc":"제작 시 재료 1개 30% 확률 환급",     "cost":30},
					{"id":"scavenge_memory", "name":"수색 기억", "desc":"아이템 픽업 범위 +40%",              "cost":40},
				],
			]},
		],
	},
	{
		"title": "행동 능력",
		"color": Color(0.55, 0.85, 1.0),
		"skills": [],
		"_action_col": true,
	},
]


func _ready():
	$StartButton.pressed.connect(_on_start_pressed)
	$ControlsButton.pressed.connect(_on_controls_pressed)
	$MidButtonRow/BestiaryButton.pressed.connect(_on_bestiary_pressed)
	$MidButtonRow/SkillButton.pressed.connect(_on_skill_pressed)
	$ExitButton.pressed.connect(_on_exit_pressed)
	$ControlsPanel/ContentPanel/VBox/CloseButton.pressed.connect(_on_controls_close)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$StartButton.grab_focus()

	_build_bestiary_panel()
	_build_skill_panel()
	_build_menu_visuals()
	_setup_audio()

func _input(event):
	if controls_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_controls_close()
		get_viewport().set_input_as_handled()
	if _bestiary_panel and _bestiary_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_bestiary_close()
		get_viewport().set_input_as_handled()
	if _skill_panel and _skill_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_skill_close()
		get_viewport().set_input_as_handled()

# ──────────────────────────────
# 기존 버튼 핸들러
# ──────────────────────────────
func _on_start_pressed():
	if _sfx_start:
		_sfx_start.play()
	$StartButton.disabled = true
	var tw = create_tween()
	tw.tween_property($StartButton, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.08)
	tw.tween_property($StartButton, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.10)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/World.tscn"))

func _on_controls_pressed():
	controls_panel.visible = true
	$ControlsPanel/ContentPanel/VBox/CloseButton.grab_focus()

func _on_controls_close():
	controls_panel.visible = false
	$ControlsButton.grab_focus()

func _on_exit_pressed():
	get_tree().quit()

# ──────────────────────────────
# 적 도감
# ──────────────────────────────
func _on_bestiary_pressed():
	_refresh_entries()
	_bestiary_panel.visible = true

func _on_bestiary_close():
	_bestiary_panel.visible = false
	$MidButtonRow/BestiaryButton.grab_focus()

func _build_bestiary_panel():
	_bestiary_panel = Control.new()
	_bestiary_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bestiary_panel.z_index = 10
	_bestiary_panel.visible = false
	add_child(_bestiary_panel)

	var dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_bestiary_panel.add_child(dim)

	# 패널 테두리 (2px 큰 배경)
	var panel_border = ColorRect.new()
	panel_border.color = Color(0.32, 0.18, 0.08, 1.0)
	panel_border.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_border.offset_left = -692; panel_border.offset_right  = 692
	panel_border.offset_top  = -362; panel_border.offset_bottom = 362
	_bestiary_panel.add_child(panel_border)

	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.05, 0.03, 0.02, 1.0)
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_bg.offset_left = -690; panel_bg.offset_right  = 690
	panel_bg.offset_top  = -360; panel_bg.offset_bottom = 360
	_bestiary_panel.add_child(panel_bg)

	var content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.offset_left = -688; content.offset_right  = 688
	content.offset_top  = -358; content.offset_bottom = 358
	_bestiary_panel.add_child(content)

	var outer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	outer.offset_left = 18; outer.offset_right  = -18
	outer.offset_top  = 14; outer.offset_bottom = -14
	content.add_child(outer)

	# 헤더
	var hdr = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 16)
	outer.add_child(hdr)

	var title_lbl = Label.new()
	title_lbl.text = "SPECIMEN DATABASE  —  실험체 연구 기록"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.90, 0.68, 0.38))
	hdr.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "닫기  [Esc]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(_on_bestiary_close)
	hdr.add_child(close_btn)

	var sep = HSeparator.new()
	outer.add_child(sep)

	# 2-열 레이아웃
	var cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 0)
	outer.add_child(cols)

	# 좌측 목록
	var list_side = VBoxContainer.new()
	list_side.custom_minimum_size = Vector2(310, 0)
	list_side.add_theme_constant_override("separation", 6)
	cols.add_child(list_side)

	var list_hdr = Label.new()
	list_hdr.text = "목록"
	list_hdr.add_theme_font_size_override("font_size", 11)
	list_hdr.add_theme_color_override("font_color", Color(0.48, 0.43, 0.38))
	list_side.add_child(list_hdr)

	var list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_side.add_child(list_scroll)

	_bestiary_list_vbox = VBoxContainer.new()
	_bestiary_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bestiary_list_vbox.add_theme_constant_override("separation", 3)
	list_scroll.add_child(_bestiary_list_vbox)

	# 세로 구분선
	var vsep = ColorRect.new()
	vsep.custom_minimum_size = Vector2(2, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsep.color = Color(0.28, 0.14, 0.08, 1.0)
	cols.add_child(vsep)

	# 우측 상세
	var detail_side = VBoxContainer.new()
	detail_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_side.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cols.add_child(detail_side)

	var detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_side.add_child(detail_scroll)

	_bestiary_detail_root = VBoxContainer.new()
	_bestiary_detail_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_bestiary_detail_root)


func _refresh_entries():
	for c in _bestiary_list_vbox.get_children():
		c.queue_free()
	_bestiary_list_btns.clear()

	for i in SpecimenDB.ENEMY_DATA.size():
		var entry = SpecimenDB.ENEMY_DATA[i]
		var seen  = GlobalSave.is_seen(entry["id"])
		var col   = entry["color"] if seen else Color(0.32, 0.28, 0.25)

		# 커스텀 2줄 행 (Control + ColorRect + VBox)
		var row = Control.new()
		row.custom_minimum_size = Vector2(0, 58)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_STOP

		var bg = ColorRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.09, 0.06, 0.04, 0.70)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bg)

		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 0)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hbox)

		var bar = ColorRect.new()
		bar.custom_minimum_size = Vector2(5, 0)
		bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar.color = col
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(bar)

		var pad = MarginContainer.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_theme_constant_override("margin_left",   14)
		pad.add_theme_constant_override("margin_right",   8)
		pad.add_theme_constant_override("margin_top",     9)
		pad.add_theme_constant_override("margin_bottom",  9)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(pad)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = ("%s  —  \"%s\" / %s" % [entry["code"], entry["nickname"], entry["nickname_kr"]]) \
			if seen else "???  —  미지의 존재"
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var cls_lbl = Label.new()
		cls_lbl.text = entry["classification_kr"] if seen else "직접 조우 시 기록 해제"
		cls_lbl.add_theme_font_size_override("font_size", 11)
		cls_lbl.add_theme_color_override("font_color", Color(col.r * 0.65, col.g * 0.65, col.b * 0.65, 0.8))
		cls_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cls_lbl)

		var idx  = i
		var bg_ref = bg
		row.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				_select_bestiary_entry(idx)
				get_viewport().set_input_as_handled())
		row.mouse_entered.connect(func():
			if idx != _bestiary_selected:
				bg_ref.color = Color(0.15, 0.09, 0.06, 0.85))
		row.mouse_exited.connect(func():
			if idx != _bestiary_selected:
				bg_ref.color = Color(0.09, 0.06, 0.04, 0.70))

		_bestiary_list_vbox.add_child(row)
		_bestiary_list_btns.append({"root": row, "bg": bg, "bar": bar, "col": col})

	if _bestiary_list_btns.size() > 0:
		_select_bestiary_entry(0)


func _select_bestiary_entry(idx: int) -> void:
	_bestiary_selected = idx
	for i in _bestiary_list_btns.size():
		var info = _bestiary_list_btns[i]
		if i == idx:
			info["bg"].color = Color(0.18, 0.10, 0.06, 1.0)
		else:
			info["bg"].color = Color(0.09, 0.06, 0.04, 0.70)

	for c in _bestiary_detail_root.get_children():
		c.queue_free()

	var entry = SpecimenDB.ENEMY_DATA[idx]
	var tier  = SpecimenDB.get_tier(entry["id"])
	_build_bestiary_detail(entry, tier)


func _build_bestiary_detail(entry: Dictionary, tier: int) -> void:
	var root = _bestiary_detail_root
	var col  = entry["color"]

	# 상단 컬러 바
	var top_bar = ColorRect.new()
	top_bar.custom_minimum_size = Vector2(0, 3)
	top_bar.color = col * Color(1, 1, 1, 0.7)
	root.add_child(top_bar)

	var pad = MarginContainer.new()
	pad.add_theme_constant_override("margin_left",   20)
	pad.add_theme_constant_override("margin_right",  16)
	pad.add_theme_constant_override("margin_top",    12)
	pad.add_theme_constant_override("margin_bottom", 14)
	root.add_child(pad)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	# 분류 코드 라인
	var code_lbl = Label.new()
	code_lbl.text = "SPECIMEN %s  ·  %s" % [entry["code"], entry["classification"]]
	code_lbl.add_theme_font_size_override("font_size", 12)
	code_lbl.add_theme_color_override("font_color", Color(0.52, 0.48, 0.44))
	vbox.add_child(code_lbl)

	# 이름 + 아이콘 행
	var ni_row = HBoxContainer.new()
	ni_row.add_theme_constant_override("separation", 18)
	vbox.add_child(ni_row)

	var icon = SpecimenIcon.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	icon.setup(entry["code"], col, tier >= 1)
	ni_row.add_child(icon)

	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	name_vbox.add_theme_constant_override("separation", 5)
	ni_row.add_child(name_vbox)

	if tier == 0:
		var unk = Label.new()
		unk.text = "???  /  \"???????\"  (미지의 존재)"
		unk.add_theme_font_size_override("font_size", 20)
		unk.add_theme_color_override("font_color", Color(0.32, 0.30, 0.28))
		name_vbox.add_child(unk)
		var unk2 = Label.new()
		unk2.text = "직접 조우 시 기록이 해제됩니다."
		unk2.add_theme_font_size_override("font_size", 13)
		unk2.add_theme_color_override("font_color", Color(0.28, 0.26, 0.24))
		name_vbox.add_child(unk2)
		return

	var nick_lbl = Label.new()
	nick_lbl.text = "\"%s\"  /  %s" % [entry["nickname"], entry["nickname_kr"]]
	nick_lbl.add_theme_font_size_override("font_size", 24)
	nick_lbl.add_theme_color_override("font_color", col)
	name_vbox.add_child(nick_lbl)

	var cls_lbl = Label.new()
	cls_lbl.text = "%s  /  %s" % [entry["classification"], entry["classification_kr"]]
	cls_lbl.add_theme_font_size_override("font_size", 12)
	cls_lbl.add_theme_color_override("font_color", Color(0.58, 0.53, 0.48))
	name_vbox.add_child(cls_lbl)

	var stars = "★".repeat(entry["threat"]) + "☆".repeat(5 - entry["threat"])
	var thr_lbl = Label.new()
	thr_lbl.text = "위협도  " + stars
	thr_lbl.add_theme_font_size_override("font_size", 14)
	thr_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	name_vbox.add_child(thr_lbl)

	# 관찰 진행도
	_bsec_obs_bar(vbox, entry["id"], tier, col)

	vbox.add_child(HSeparator.new())

	# Tier 2: 행동 / 감지
	if tier >= 2:
		_bsec_header(vbox, "BEHAVIORAL PROFILE  /  행동 프로필", col)
		_bsec_info(vbox, "행동 패턴", entry["tier2_behavior_kr"], entry["tier2_behavior"], col)
		_bsec_info(vbox, "감지 범위", entry["tier2_detection_kr"], entry["tier2_detection"], col)
	else:
		_bsec_locked(vbox, "BEHAVIORAL PROFILE", "관찰 시간 3초 이상 필요")

	# Tier 3: 능력 / 대응
	if tier >= 3:
		_bsec_header(vbox, "THREAT ANALYSIS  /  위협 분석", col)
		_bsec_info(vbox, "특수 능력", entry["tier3_ability_kr"], entry["tier3_ability"], col)
		_bsec_info(vbox, "대응 방법", entry["tier3_counter_kr"], entry["tier3_counter"], col)
	else:
		_bsec_locked(vbox, "THREAT ANALYSIS", "관찰 시간 15초 이상 필요")

	# Tier 4: 심층 정보
	if tier >= 4:
		_bsec_header(vbox, "ADVANCED DATA  /  고급 연구 기록", Color(0.88, 0.75, 0.32))
		_bsec_info(vbox, "심층 정보", entry["tier4_secret_kr"], entry["tier4_secret"], Color(0.88, 0.75, 0.32))
	else:
		_bsec_locked(vbox, "ADVANCED DATA", "관찰 시간 45초 이상 필요")

	vbox.add_child(HSeparator.new())

	# 손상된 연구 기록
	_bsec_corrupted(vbox, entry, col)

	# 현장 메모
	if tier >= 2 and entry.has("field_note"):
		var note = Label.new()
		note.text = entry["field_note"]
		note.add_theme_font_size_override("font_size", 14)
		note.add_theme_color_override("font_color",
			Color(col.r * 0.75, col.g * 0.75, col.b * 0.75, 0.92))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(note)


func _bsec_header(c: VBoxContainer, text: String, col: Color) -> void:
	var lbl = Label.new()
	lbl.text = "▸  " + text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.85))
	c.add_child(lbl)


func _bsec_info(c: VBoxContainer, label_kr: String, body_kr: String, body_en: String, col: Color) -> void:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	c.add_child(row)

	var lbl = Label.new()
	lbl.text = "    [ %s ]" % label_kr
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, 0.80))
	row.add_child(lbl)

	var kr = Label.new()
	kr.text = "    " + body_kr
	kr.add_theme_font_size_override("font_size", 15)
	kr.add_theme_color_override("font_color", Color(0.90, 0.87, 0.83))
	kr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(kr)

	var en = Label.new()
	en.text = "    " + body_en
	en.add_theme_font_size_override("font_size", 11)
	en.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44, 0.68))
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(en)


func _bsec_locked(c: VBoxContainer, title: String, hint: String) -> void:
	var lbl = Label.new()
	lbl.text = "▸  %s  —  ████████████████████" % title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.32, 0.29, 0.26, 0.62))
	c.add_child(lbl)

	var hlbl = Label.new()
	hlbl.text = "    [ %s ]" % hint
	hlbl.add_theme_font_size_override("font_size", 11)
	hlbl.add_theme_color_override("font_color", Color(0.38, 0.34, 0.29, 0.50))
	c.add_child(hlbl)


func _bsec_corrupted(c: VBoxContainer, entry: Dictionary, col: Color) -> void:
	var hdr = Label.new()
	hdr.text = "▸  RESEARCH LOG  —  [PARTIALLY DAMAGED]"
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(0.58, 0.46, 0.28, 0.72))
	c.add_child(hdr)

	for line in entry.get("damaged_lines", []):
		var lbl = Label.new()
		lbl.text = "    " + line
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48, 0.45))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(lbl)


func _bsec_obs_bar(c: VBoxContainer, enemy_id: String, tier: int, col: Color) -> void:
	var obs_key: String = SpecimenDB.OBSERVE_KEY.get(enemy_id, enemy_id)
	var t: float = GlobalSave.get_observe_time(obs_key)
	var tier_str: String
	var progress: float
	if tier == 0:
		progress = 0.0; tier_str = "미관찰"
	elif tier == 1:
		progress = clampf(t / 3.0, 0.0, 1.0); tier_str = "관찰 1단계  (%.0f초 / 3초)" % t
	elif tier == 2:
		progress = clampf(t / 15.0, 0.0, 1.0); tier_str = "관찰 2단계  (%.0f초 / 15초)" % t
	elif tier == 3:
		progress = clampf(t / 45.0, 0.0, 1.0); tier_str = "관찰 3단계  (%.0f초 / 45초)" % t
	else:
		progress = 1.0; tier_str = "관찰 완료  —  완전 파악"

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)

	var lbl = Label.new()
	lbl.text = tier_str
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.72))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var pbar = ProgressBar.new()
	pbar.min_value = 0.0; pbar.max_value = 1.0; pbar.value = progress
	pbar.show_percentage = false
	pbar.custom_minimum_size = Vector2(120, 9)
	pbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill_sty = StyleBoxFlat.new()
	fill_sty.bg_color = Color(col.r, col.g, col.b, 0.65)
	var bg_sty = StyleBoxFlat.new()
	bg_sty.bg_color = Color(0.14, 0.10, 0.07)
	pbar.add_theme_stylebox_override("fill",       fill_sty)
	pbar.add_theme_stylebox_override("background", bg_sty)
	row.add_child(pbar)

# ──────────────────────────────
# 스킬 트리
# ──────────────────────────────
func _on_skill_pressed():
	_refresh_skill_panel()
	_skill_panel.visible = true

func _on_skill_close():
	_skill_panel.visible = false
	$MidButtonRow/SkillButton.grab_focus()

func _build_skill_panel():
	_skill_panel = Control.new()
	_skill_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_panel.z_index = 10
	_skill_panel.visible = false
	add_child(_skill_panel)

	var dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.87)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_panel.add_child(dim)

	var content = Panel.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.offset_left   = -430.0
	content.offset_right  =  430.0
	content.offset_top    = -330.0
	content.offset_bottom =  330.0
	_skill_panel.add_child(content)

	var outer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	outer.offset_left   = 18
	outer.offset_right  = -18
	outer.offset_top    = 14
	outer.offset_bottom = -14
	content.add_child(outer)

	# 헤더 행: 제목 + KP 잔액
	var header_row = HBoxContainer.new()
	outer.add_child(header_row)

	var title_lbl = Label.new()
	title_lbl.text = "기억"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_lbl)

	_skill_kp_label = Label.new()
	_skill_kp_label.add_theme_font_size_override("font_size", 15)
	_skill_kp_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_skill_kp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(_skill_kp_label)

	var sep = HSeparator.new()
	outer.add_child(sep)

	# ─── 본문: 좌측 브랜치 목록  |  우측 스킬 내용 ───
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	outer.add_child(body)

	# 좌측 패널 (브랜치 선택 목록)
	var left_bg = ColorRect.new()
	left_bg.custom_minimum_size = Vector2(162, 0)
	left_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_bg.color = Color(0.10, 0.08, 0.12, 0.85)
	body.add_child(left_bg)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 2)
	left_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_vbox.offset_left   =  8
	left_vbox.offset_right  = -8
	left_vbox.offset_top    = 10
	left_vbox.offset_bottom = -10
	left_bg.add_child(left_vbox)

	# 좌측 브랜치 버튼들
	_skill_col_btns.clear()
	for i in SKILL_COLUMNS.size():
		var col_data = SKILL_COLUMNS[i]
		var col_btn = Button.new()
		col_btn.text = "  " + col_data["title"]
		col_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		col_btn.add_theme_font_size_override("font_size", 14)
		col_btn.add_theme_color_override("font_color", col_data["color"].darkened(0.25))
		col_btn.flat = true
		col_btn.pressed.connect(_on_skill_col_select.bind(i))
		left_vbox.add_child(col_btn)
		_skill_col_btns.append(col_btn)

	# 좌우 구분선
	var vsep = VSeparator.new()
	body.add_child(vsep)

	# 우측 스크롤 + 스킬 내용
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left",   12)
	right_margin.add_theme_constant_override("margin_right",  12)
	right_margin.add_theme_constant_override("margin_top",    8)
	right_margin.add_theme_constant_override("margin_bottom", 8)
	body.add_child(right_margin)

	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_margin.add_child(right_scroll)

	_skill_content_vbox = VBoxContainer.new()
	_skill_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_content_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(_skill_content_vbox)

	# 하단
	var sep2 = HSeparator.new()
	outer.add_child(sep2)

	var close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_skill_close)
	outer.add_child(close_btn)

	# 첫 번째 브랜치로 초기 표시
	_skill_current_col = 0
	_show_skill_column(0)

func _on_skill_col_select(col_index: int):
	_skill_current_col = col_index
	_show_skill_column(col_index)

func _show_skill_column(col_index: int):
	if not _skill_content_vbox: return

	# 기존 콘텐츠 즉시 제거
	while _skill_content_vbox.get_child_count() > 0:
		var child = _skill_content_vbox.get_child(0)
		_skill_content_vbox.remove_child(child)
		child.free()

	var col_data = SKILL_COLUMNS[col_index]

	# 행동 능력 탭은 별도 렌더링
	if col_data.get("_action_col", false):
		_show_action_col(col_data["color"])
		_update_tab_buttons(col_index)
		return

	# 현재 컬럼의 _skill_cards 항목 제거 (fork 내부 포함)
	for entry in _collect_all_skills(col_data):
		_skill_cards.erase(entry["id"])

	# 컬럼 제목 행
	var title_row = HBoxContainer.new()
	_skill_content_vbox.add_child(title_row)

	var bar = ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.color = col_data["color"]
	title_row.add_child(bar)

	var spc = Control.new()
	spc.custom_minimum_size = Vector2(8, 0)
	title_row.add_child(spc)

	var col_title_lbl = Label.new()
	col_title_lbl.text = col_data["title"]
	col_title_lbl.add_theme_font_size_override("font_size", 17)
	col_title_lbl.add_theme_color_override("font_color", col_data["color"])
	title_row.add_child(col_title_lbl)

	var sep = HSeparator.new()
	_skill_content_vbox.add_child(sep)

	# 스킬 카드 생성 (직선 + 분기 혼합)
	var prev_id = ""
	for item in col_data["skills"]:
		if item.has("_fork"):
			if item.get("req", "") != "" and item.get("req", "") == prev_id:
				_skill_content_vbox.add_child(_make_arrow())
			_render_fork(item, col_data["color"])
			prev_id = ""
		else:
			var first_req = item["req"].split(",")[0].strip_edges() if item["req"] != "" else ""
			if first_req != "" and first_req == prev_id:
				_skill_content_vbox.add_child(_make_arrow())
			_skill_content_vbox.add_child(_make_skill_card(item, col_data["color"]))
			prev_id = item["id"]

	# 상태 즉시 적용
	_refresh_current_col_states(col_data)

	# 좌측 버튼 선택 표시 갱신
	_update_tab_buttons(col_index)

func _make_arrow() -> Label:
	var arrow = Label.new()
	arrow.text = "▼"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	arrow.add_theme_font_size_override("font_size", 11)
	return arrow

func _render_fork(fork_data: Dictionary, col_color: Color) -> void:
	var fork_id  = fork_data["_fork"]
	var fork_req = fork_data.get("req", "")

	# 분기 구분선
	var divider = HBoxContainer.new()
	divider.add_theme_constant_override("separation", 4)
	var ll = ColorRect.new(); ll.custom_minimum_size = Vector2(0, 1); ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ll.color = Color(0.40, 0.40, 0.40, 0.7); divider.add_child(ll)
	var dl = Label.new(); dl.text = "  분기  "; dl.add_theme_font_size_override("font_size", 10); dl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55)); divider.add_child(dl)
	var rl = ColorRect.new(); rl.custom_minimum_size = Vector2(0, 1); rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rl.color = Color(0.40, 0.40, 0.40, 0.7); divider.add_child(rl)
	_skill_content_vbox.add_child(divider)

	# 두 옵션 나란히
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	_skill_content_vbox.add_child(hbox)

	for opt_idx in fork_data["options"].size():
		if opt_idx > 0:
			var vsep_lbl = Label.new()
			vsep_lbl.text = "또는"
			vsep_lbl.add_theme_font_size_override("font_size", 10)
			vsep_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
			vsep_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(vsep_lbl)

		var option = fork_data["options"][opt_idx]
		var opt_vbox = VBoxContainer.new()
		opt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt_vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(opt_vbox)

		for skill_idx in option.size():
			var skill = option[skill_idx].duplicate()
			skill["req"] = fork_req if skill_idx == 0 else option[skill_idx - 1]["id"]
			skill["_fork_id"] = fork_id
			skill["_opt_idx"] = opt_idx
			if skill_idx > 0:
				opt_vbox.add_child(_make_arrow())
			opt_vbox.add_child(_make_skill_card(skill, col_color))

# 컬럼의 모든 스킬 (fork 내부 포함) — req/fork 메타 포함
func _collect_all_skills(col_data: Dictionary) -> Array:
	var result: Array = []
	for item in col_data["skills"]:
		if item.has("_fork"):
			var fork_id  = item["_fork"]
			var fork_req = item.get("req", "")
			for opt_idx in item["options"].size():
				var option = item["options"][opt_idx]
				for skill_idx in option.size():
					var s = option[skill_idx].duplicate()
					s["req"]       = fork_req if skill_idx == 0 else option[skill_idx - 1]["id"]
					s["_fork_id"]  = fork_id
					s["_opt_idx"]  = opt_idx
					result.append(s)
		else:
			result.append(item)
	return result

func _update_tab_buttons(col_index: int) -> void:
	for i in _skill_col_btns.size():
		var col_btn = _skill_col_btns[i]
		var col = SKILL_COLUMNS[i]["color"]
		if i == col_index:
			col_btn.text = "▸ " + SKILL_COLUMNS[i]["title"]
			col_btn.add_theme_color_override("font_color", col)
		else:
			col_btn.text = "  " + SKILL_COLUMNS[i]["title"]
			col_btn.add_theme_color_override("font_color", col.darkened(0.30))

# ──────────────────────────────
# 행동 능력 탭
# ──────────────────────────────
func _show_action_col(accent: Color) -> void:
	var vbox = _skill_content_vbox

	# 제목
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)
	var bar = ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.color = accent
	title_row.add_child(bar)
	var spc = Control.new()
	spc.custom_minimum_size = Vector2(8, 0)
	title_row.add_child(spc)
	var ttl = Label.new()
	ttl.text = "행동 능력"
	ttl.add_theme_font_size_override("font_size", 17)
	ttl.add_theme_color_override("font_color", accent)
	title_row.add_child(ttl)
	vbox.add_child(HSeparator.new())

	# ── 섹션 1: 행동 해금 능력 ──
	var sec1 = Label.new()
	sec1.text = "행동으로 해금되는 능력"
	sec1.add_theme_font_size_override("font_size", 12)
	sec1.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(sec1)

	for ability_id in GlobalSave.ABILITY_NAMES.keys():
		vbox.add_child(_make_ability_card(ability_id, accent))

	vbox.add_child(HSeparator.new())

	# ── 섹션 2: KP 구매 스킬 ──
	var sec2 = Label.new()
	sec2.text = "KP로 구매하는 기술"
	sec2.add_theme_font_size_override("font_size", 12)
	sec2.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(sec2)

	for skill_id in GlobalSave.PURCHASABLE_SKILLS.keys():
		vbox.add_child(_make_purchasable_card(skill_id))

func _make_ability_card(ability_id: String, accent: Color) -> Control:
	var level   = GlobalSave.get_ability_level(ability_id)
	var ab_name = GlobalSave.ABILITY_NAMES.get(ability_id, ability_id)
	var descs   = GlobalSave.ABILITY_DESCS.get(ability_id, [])
	var costs   = GlobalSave.ABILITY_UPGRADE_COSTS.get(ability_id, [])

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	# 이름 + 레벨
	var name_lbl = Label.new()
	if level == 0:
		name_lbl.text = "???  (미해금)"
		name_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	else:
		name_lbl.text = "%s  [Lv.%d / 3]" % [ab_name, level]
		name_lbl.add_theme_color_override("font_color", accent.lightened(0.1))
	name_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(name_lbl)

	if level == 0:
		# 해금 조건 표시
		var hint_lbl = Label.new()
		hint_lbl.text = _get_unlock_hint(ability_id)
		hint_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		hint_lbl.add_theme_font_size_override("font_size", 10)
		vb.add_child(hint_lbl)
	else:
		# 현재 효과
		if descs.size() >= level:
			var cur_lbl = Label.new()
			cur_lbl.text = "현재: " + descs[level - 1]
			cur_lbl.add_theme_color_override("font_color", Color(0.65, 0.88, 0.65))
			cur_lbl.add_theme_font_size_override("font_size", 11)
			vb.add_child(cur_lbl)
		# 다음 효과 + 강화 버튼
		if level < 3 and descs.size() > level:
			var next_lbl = Label.new()
			next_lbl.text = "다음: " + descs[level]
			next_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
			next_lbl.add_theme_font_size_override("font_size", 11)
			vb.add_child(next_lbl)

			var cost_idx = level - 1
			var cost = costs[cost_idx] if cost_idx < costs.size() else 999
			var btn_row = HBoxContainer.new()
			vb.add_child(btn_row)
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_row.add_child(spacer)
			var btn = Button.new()
			btn.text = "강화  %d p" % cost
			btn.custom_minimum_size = Vector2(100, 0)
			if GlobalSave.get_total_kp() < cost:
				btn.disabled = true
			var ab_id = ability_id
			btn.pressed.connect(func():
				if GlobalSave.upgrade_ability(ab_id):
					_refresh_skill_panel()
					if _skill_kp_label:
						_skill_kp_label.text = "보유 KP:  %d p" % GlobalSave.get_total_kp()
					if _kp_corner_label:
						_kp_corner_label.text = "KP  %d p" % GlobalSave.get_total_kp()
			)
			btn_row.add_child(btn)
		elif level == 3:
			var max_lbl = Label.new()
			max_lbl.text = "MAX 달성"
			max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			max_lbl.add_theme_font_size_override("font_size", 11)
			vb.add_child(max_lbl)

	return panel

func _make_purchasable_card(skill_id: String) -> Control:
	var info    = GlobalSave.PURCHASABLE_SKILLS.get(skill_id, {})
	var owned   = GlobalSave.has_skill(skill_id)
	var panel   = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	var name_lbl = Label.new()
	name_lbl.text = info.get("name", skill_id)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.9, 0.5) if owned else Color(0.9, 0.9, 0.9))
	vb.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = info.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	vb.add_child(desc_lbl)

	if owned:
		var done_lbl = Label.new()
		done_lbl.text = "✓ 보유 중"
		done_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		done_lbl.add_theme_font_size_override("font_size", 11)
		vb.add_child(done_lbl)
	else:
		var cost: int = info.get("cost", 0)
		var btn_row = HBoxContainer.new()
		vb.add_child(btn_row)
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(spacer)
		var btn = Button.new()
		btn.text = "구매  %d p" % cost
		btn.custom_minimum_size = Vector2(100, 0)
		if GlobalSave.get_total_kp() < cost:
			btn.disabled = true
		var s_id = skill_id
		btn.pressed.connect(func():
			if GlobalSave.buy_skill(s_id, GlobalSave.PURCHASABLE_SKILLS[s_id]["cost"]):
				_refresh_skill_panel()
				if _skill_kp_label:
					_skill_kp_label.text = "보유 KP:  %d p" % GlobalSave.get_total_kp()
				if _kp_corner_label:
					_kp_corner_label.text = "KP  %d p" % GlobalSave.get_total_kp()
		)
		btn_row.add_child(btn)

	return panel

func _get_unlock_hint(ability_id: String) -> String:
	match ability_id:
		"shadow_instinct": return "해금 조건: 은신 10회"
		"light_control":   return "해금 조건: 눈부심 8회"
		"steady_hand":     return "해금 조건: 파편 격파 5회"
		"flame_sense":     return "해금 조건: 신호탄 사용 5회"
		"fear_resist":     return "해금 조건: 공포 100% 생존 3회"
		_: return "해금 조건 불명"

func _refresh_current_col_states(col_data: Dictionary):
	var all_skills = _collect_all_skills(col_data)
	for skill in all_skills:
		var sid = skill["id"]
		var btn = _skill_cards.get(sid)
		if not btn: continue

		var purchased  = GlobalSave.has_skill(sid)
		var req_met    = skill["req"] == "" or GlobalSave.has_skill(skill["req"])
		var can_afford = GlobalSave.get_total_kp() >= skill["cost"]

		# 분기 상호배제: 다른 옵션 스킬이 구매되면 이 옵션 잠금
		var fork_locked = false
		if skill.has("_fork_id"):
			fork_locked = _is_fork_option_locked(col_data, skill["_fork_id"], skill["_opt_idx"])

		if purchased:
			btn.text = "✓ 보유"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		elif fork_locked:
			btn.text = "—"
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		elif not req_met:
			btn.text = "잠금"
			btn.disabled = true
			btn.remove_theme_color_override("font_color")
		elif not can_afford:
			btn.text = "KP 부족"
			btn.disabled = true
			btn.remove_theme_color_override("font_color")
		else:
			btn.text = "구매"
			btn.disabled = false
			btn.remove_theme_color_override("font_color")

# 해당 fork에서 다른 옵션의 스킬이 하나라도 구매됐으면 true
func _is_fork_option_locked(col_data: Dictionary, fork_id: String, my_opt_idx: int) -> bool:
	for item in col_data["skills"]:
		if not item.has("_fork") or item["_fork"] != fork_id: continue
		for other_idx in item["options"].size():
			if other_idx == my_opt_idx: continue
			for s in item["options"][other_idx]:
				if GlobalSave.has_skill(s["id"]): return true
	return false

func _make_skill_card(skill: Dictionary, col_color: Color) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name = "card_" + skill["id"]

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = skill["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", col_color)
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = skill["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var btn_row = HBoxContainer.new()
	vbox.add_child(btn_row)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d p" % skill["cost"]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(cost_lbl)

	var buy_btn = Button.new()
	buy_btn.name = "btn_" + skill["id"]
	buy_btn.custom_minimum_size = Vector2(80, 0)
	buy_btn.pressed.connect(_on_buy_skill.bind(skill["id"], skill["cost"]))
	btn_row.add_child(buy_btn)

	_skill_cards[skill["id"]] = buy_btn
	return panel

func _refresh_skill_panel():
	if _skill_kp_label:
		_skill_kp_label.text = "보유 KP:  %d p" % GlobalSave.get_total_kp()
	_show_skill_column(_skill_current_col)

func _on_buy_skill(skill_id: String, cost: int):
	var ok = GlobalSave.buy_skill(skill_id, cost)
	if ok:
		_refresh_skill_panel()
		if _kp_corner_label:
			_kp_corner_label.text = "KP  %d p" % GlobalSave.get_total_kp()

func _process(delta: float) -> void:
	for i in _bg_lines.size():
		_bg_lines[i].position.y += _bg_line_speeds[i] * delta
		if _bg_lines[i].position.y > 740.0:
			_bg_lines[i].position.y = -2.0

# ──────────────────────────────
# 메인화면 비주얼
# ──────────────────────────────
func _build_menu_visuals() -> void:
	# 배경 스캔라인 (호러 분위기)
	for i in 8:
		var line = ColorRect.new()
		line.color = Color(0.85, 0.08, 0.08, 0.038)
		line.size = Vector2(2000, 2)
		line.position = Vector2(-100.0, randf_range(0.0, 720.0))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.z_index = 1
		add_child(line)
		_bg_lines.append(line)
		_bg_line_speeds.append(randf_range(10.0, 32.0))

	# 상단 시설 상태바
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.14, 0.03, 0.03, 0.90)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 26.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.z_index = 2
	add_child(top_bar)

	var status_lbl = Label.new()
	status_lbl.text = "CONTAIN FACILITY  ·  SECTOR 7  ·  격리 위반 경보"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.72, 0.18, 0.18))
	status_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_lbl.offset_top = 5.0
	status_lbl.offset_bottom = 22.0
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_lbl.z_index = 3
	add_child(status_lbl)

	# 서브타이틀
	var sub = Label.new()
	sub.text = "탈출한 개체들이 격리 구역을 배회하고 있다"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.52, 0.26, 0.26))
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 200.0
	sub.offset_bottom = 222.0
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.z_index = 2
	add_child(sub)

	# 장식선 (타이틀 아래)
	var deco = ColorRect.new()
	deco.color = Color(0.62, 0.14, 0.14, 0.55)
	deco.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	deco.offset_top    = 226.0
	deco.offset_bottom = 228.0
	deco.offset_left   = 248.0
	deco.offset_right  = -248.0
	deco.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	deco.z_index = 2
	add_child(deco)

	# 경고 텍스트 (좌하단, 깜빡임)
	var warn_lbl = Label.new()
	warn_lbl.text = "실험체 탈출 확인됨  ·  구역 전체 봉쇄 중"
	warn_lbl.add_theme_font_size_override("font_size", 10)
	warn_lbl.add_theme_color_override("font_color", Color(0.65, 0.12, 0.12))
	warn_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	warn_lbl.offset_left   = 20.0
	warn_lbl.offset_top    = -68.0
	warn_lbl.offset_right  = 460.0
	warn_lbl.offset_bottom = -50.0
	warn_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	warn_lbl.z_index = 2
	add_child(warn_lbl)
	var blink_tw = create_tween().set_loops()
	blink_tw.tween_property(warn_lbl, "modulate:a", 0.30, 0.9).set_trans(Tween.TRANS_SINE)
	blink_tw.tween_property(warn_lbl, "modulate:a", 1.0,  0.9).set_trans(Tween.TRANS_SINE)

	# 시설 ID (우하단)
	var fac_lbl = Label.new()
	fac_lbl.text = "연구소 ID : CF-07  ·  격리 개체 수 : [데이터 손상]"
	fac_lbl.add_theme_font_size_override("font_size", 10)
	fac_lbl.add_theme_color_override("font_color", Color(0.38, 0.22, 0.22, 0.55))
	fac_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fac_lbl.offset_left   = -420.0
	fac_lbl.offset_top    = -68.0
	fac_lbl.offset_right  = -18.0
	fac_lbl.offset_bottom = -50.0
	fac_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fac_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	fac_lbl.z_index = 2
	add_child(fac_lbl)

	# 코너 브라켓
	_add_corner_brackets()

	# KP 잔액 우상단 (상태바 내)
	_kp_corner_label = Label.new()
	_kp_corner_label.text = "KP  %d p" % GlobalSave.get_total_kp()
	_kp_corner_label.add_theme_font_size_override("font_size", 11)
	_kp_corner_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	_kp_corner_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_kp_corner_label.offset_left  = -130.0
	_kp_corner_label.offset_top   =  5.0
	_kp_corner_label.offset_right = -14.0
	_kp_corner_label.offset_bottom = 22.0
	_kp_corner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kp_corner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kp_corner_label.z_index = 4
	add_child(_kp_corner_label)

	# 타이틀 페이드인
	var title = $TitleLabel
	title.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 2.0)

	# 타이틀 색상 맥박 (더 강한 대비)
	var pulse = create_tween().set_loops()
	pulse.tween_interval(2.3)
	pulse.tween_property(title, "theme_override_colors/font_color",
		Color(0.62, 0.16, 0.16), 3.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title, "theme_override_colors/font_color",
		Color(1.00, 0.90, 0.80), 3.0).set_trans(Tween.TRANS_SINE)

	# 버튼 스타일 적용
	_style_start_button($StartButton)
	_style_mid_button($MidButtonRow/BestiaryButton, Color(0.55, 0.78, 0.95))
	_style_mid_button($MidButtonRow/SkillButton, Color(0.78, 0.58, 0.95))
	_style_corner_button($ControlsButton)
	_style_corner_button($ExitButton)

	# 게임 시작 버튼 등장 연출
	var sbtn = $StartButton
	var s_orig_top = sbtn.offset_top
	var s_orig_bot = sbtn.offset_bottom
	sbtn.modulate.a = 0.0
	sbtn.offset_top    = s_orig_top + 12.0
	sbtn.offset_bottom = s_orig_bot + 12.0
	var s_enter = create_tween()
	s_enter.tween_interval(0.45)
	s_enter.tween_callback(func():
		var t2 = create_tween().set_parallel()
		t2.tween_property(sbtn, "modulate:a", 1.0, 0.5)
		t2.tween_property(sbtn, "offset_top",    s_orig_top, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t2.tween_property(sbtn, "offset_bottom", s_orig_bot, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	# 버튼 테두리 숨쉬기
	if _start_btn_style_normal:
		var breathe = create_tween().set_loops()
		breathe.tween_property(_start_btn_style_normal, "border_color", Color(1.0, 0.50, 0.50), 1.4).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(_start_btn_style_normal, "border_color", Color(0.80, 0.20, 0.20), 1.4).set_trans(Tween.TRANS_SINE)

	# 호버 연결
	sbtn.mouse_entered.connect(_on_start_hover)
	sbtn.mouse_exited.connect(_on_start_unhover)

func _style_start_button(btn: Button) -> void:
	var s_normal = StyleBoxFlat.new()
	_start_btn_style_normal = s_normal
	s_normal.bg_color = Color(0.55, 0.07, 0.07)
	s_normal.corner_radius_top_left    = 6
	s_normal.corner_radius_top_right   = 6
	s_normal.corner_radius_bottom_left  = 6
	s_normal.corner_radius_bottom_right = 6
	s_normal.border_width_left   = 2
	s_normal.border_width_right  = 2
	s_normal.border_width_top    = 2
	s_normal.border_width_bottom = 2
	s_normal.border_color = Color(0.80, 0.20, 0.20)
	var s_hover = s_normal.duplicate()
	s_hover.bg_color = Color(0.72, 0.10, 0.10)
	s_hover.border_color = Color(1.0, 0.35, 0.35)
	var s_pressed = s_normal.duplicate()
	s_pressed.bg_color = Color(0.38, 0.04, 0.04)
	btn.add_theme_stylebox_override("normal",  s_normal)
	btn.add_theme_stylebox_override("hover",   s_hover)
	btn.add_theme_stylebox_override("pressed", s_pressed)
	btn.add_theme_stylebox_override("focus",   s_hover)
	btn.add_theme_color_override("font_color",        Color(0.98, 0.92, 0.82))
	btn.add_theme_color_override("font_hover_color",  Color(1.0,  0.96, 0.88))
	btn.add_theme_color_override("font_pressed_color",Color(0.85, 0.75, 0.65))

func _style_mid_button(btn: Button, accent: Color) -> void:
	var s_normal = StyleBoxFlat.new()
	s_normal.bg_color = Color(0.12, 0.09, 0.18, 0.9)
	s_normal.corner_radius_top_left    = 5
	s_normal.corner_radius_top_right   = 5
	s_normal.corner_radius_bottom_left  = 5
	s_normal.corner_radius_bottom_right = 5
	s_normal.border_width_left   = 2
	s_normal.border_width_right  = 2
	s_normal.border_width_top    = 2
	s_normal.border_width_bottom = 2
	s_normal.border_color = accent.darkened(0.30)
	var s_hover = s_normal.duplicate()
	s_hover.bg_color = Color(0.18, 0.12, 0.28, 0.95)
	s_hover.border_color = accent
	var s_pressed = s_normal.duplicate()
	s_pressed.bg_color = Color(0.08, 0.06, 0.12)
	btn.add_theme_stylebox_override("normal",  s_normal)
	btn.add_theme_stylebox_override("hover",   s_hover)
	btn.add_theme_stylebox_override("pressed", s_pressed)
	btn.add_theme_stylebox_override("focus",   s_hover)
	btn.add_theme_color_override("font_color",        accent.lightened(0.15))
	btn.add_theme_color_override("font_hover_color",  accent.lightened(0.35))
	btn.add_theme_color_override("font_pressed_color",accent.darkened(0.20))

func _style_corner_button(btn: Button) -> void:
	var s_normal = StyleBoxFlat.new()
	s_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	s_normal.border_width_bottom = 1
	s_normal.border_color = Color(0.40, 0.28, 0.28, 0.60)
	var s_hover = s_normal.duplicate()
	s_hover.border_color = Color(0.75, 0.45, 0.45, 0.9)
	btn.add_theme_stylebox_override("normal",  s_normal)
	btn.add_theme_stylebox_override("hover",   s_hover)
	btn.add_theme_stylebox_override("pressed", s_normal)
	btn.add_theme_stylebox_override("focus",   s_hover)
	btn.add_theme_color_override("font_color",       Color(0.55, 0.40, 0.40))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.62, 0.62))


# ──────────────────────────────
# 게임 시작 버튼 호버
# ──────────────────────────────
func _on_start_hover() -> void:
	var btn = $StartButton
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_start_unhover() -> void:
	var tw = create_tween()
	tw.tween_property($StartButton, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC)

# ──────────────────────────────
# 코너 브라켓 (연구소 HUD 느낌)
# ──────────────────────────────
func _add_corner_brackets() -> void:
	var col = Color(0.55, 0.12, 0.12, 0.42)
	var arm = 22.0
	var th  = 1.5
	var px  = 20.0
	var py  = 32.0
	_mk_br(col, Control.PRESET_TOP_LEFT,     px,        py,         px + arm,  py + th)
	_mk_br(col, Control.PRESET_TOP_LEFT,     px,        py,         px + th,   py + arm)
	_mk_br(col, Control.PRESET_TOP_RIGHT,   -(px+arm),  py,        -px,        py + th)
	_mk_br(col, Control.PRESET_TOP_RIGHT,   -(px+th),   py,        -px,        py + arm)
	_mk_br(col, Control.PRESET_BOTTOM_LEFT,  px,       -(py+th),   px + arm,  -py)
	_mk_br(col, Control.PRESET_BOTTOM_LEFT,  px,       -(py+arm),  px + th,   -py)
	_mk_br(col, Control.PRESET_BOTTOM_RIGHT,-(px+arm), -(py+th),  -px,        -py)
	_mk_br(col, Control.PRESET_BOTTOM_RIGHT,-(px+th),  -(py+arm), -px,        -py)

func _mk_br(col: Color, preset: int, ol: float, ot: float, or_: float, ob: float) -> void:
	var r = ColorRect.new()
	r.color = col
	r.set_anchors_and_offsets_preset(preset)
	r.offset_left   = ol
	r.offset_top    = ot
	r.offset_right  = or_
	r.offset_bottom = ob
	r.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	r.z_index = 2
	add_child(r)

# ──────────────────────────────
# 오디오
# ──────────────────────────────
func _setup_audio() -> void:
	# 메뉴 BGM
	var bgm = AudioStreamPlayer.new()
	bgm.stream    = load("res://assets/main.mp3")
	bgm.volume_db = -5.0
	add_child(bgm)
	bgm.play()

	# 호버 SFX
	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.stream = load("res://assets/button.mp3")
	add_child(_sfx_hover)

	# 클릭 SFX
	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/button2.mp3")
	add_child(_sfx_click)

	# 게임 시작 SFX
	_sfx_start = AudioStreamPlayer.new()
	_sfx_start.stream = load("res://assets/start.mp3")
	add_child(_sfx_start)

	# 호버 연결 (모든 버튼)
	for btn in [$StartButton, $MidButtonRow/BestiaryButton,
			$MidButtonRow/SkillButton, $ControlsButton, $ExitButton]:
		btn.mouse_entered.connect(func(): _sfx_hover.play())

	# 클릭 연결 (게임 시작 제외)
	$MidButtonRow/BestiaryButton.pressed.connect(func(): _sfx_click.play())
	$MidButtonRow/SkillButton.pressed.connect(func(): _sfx_click.play())
	$ControlsButton.pressed.connect(func(): _sfx_click.play())
	$ExitButton.pressed.connect(func(): _sfx_click.play())
