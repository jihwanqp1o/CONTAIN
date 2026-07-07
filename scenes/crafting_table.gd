extends StaticBody2D

# ── 재료/결과 타입 상수 (player.gd ItemType과 일치) ──
const MAT_WIRE = 8; const MAT_CHEM = 9;  const MAT_METAL = 10
const MAT_CLOTH= 11; const MAT_CELL= 12; const MAT_EXPLOSIVE = 13

const MAT_NAMES  = {8:"전선", 9:"시약", 10:"금속", 11:"방호복", 12:"셀", 13:"폭발물"}
const MAT_COLORS = {
	8:Color(1.0,0.88,0.10), 9:Color(0.25,0.95,0.40), 10:Color(0.68,0.68,0.75),
	11:Color(0.65,0.42,0.22), 12:Color(0.18,0.52,1.0), 13:Color(1.0,0.42,0.05),
}
const RESULT_NAMES = {
	1:"아드레날린", 2:"배터리 팩", 3:"방패", 4:"신호탄",
	14:"소음 장치", 15:"섬광탄", 16:"공포 억제제", 17:"강화 손전등",
}

# { name, result, cost:{type:count}, desc }
const RECIPES = [
	{"name":"아드레날린",   "result":1,  "cost":{9:2},          "desc":"스테미나 즉시 회복"},
	{"name":"배터리 팩",    "result":2,  "cost":{12:2},         "desc":"손전등 배터리 100% 충전"},
	{"name":"방패",         "result":3,  "cost":{11:2, 9:1},    "desc":"피격 1회 무효"},
	{"name":"신호탄",       "result":4,  "cost":{8:1, 13:1},    "desc":"적 유인 + 보스 피해"},
	{"name":"소음 장치",    "result":14, "cost":{8:1, 10:1},    "desc":"20초간 적 유인"},
	{"name":"섬광탄",       "result":15, "cost":{12:1, 13:1},   "desc":"반경 200px 적 섬광 기절"},
	{"name":"공포 억제제",  "result":16, "cost":{9:1, 11:1},    "desc":"공포 즉시 초기화"},
	{"name":"강화 손전등",  "result":17, "cost":{12:1, 10:1, 8:1}, "desc":"손전등 범위 5분 확장"},
	{"name":"신호탄 케이스","result":18, "cost":{11:2, 10:1},     "desc":"신호탄 최대 보유 +1 (최대 5)"},
]

var _interact_area: Area2D = null
var _hint_label: Label     = null
var _player_in_range: bool = false
var _ui_open: bool         = false
var _ui_layer: CanvasLayer = null
var _craft_msg: Label      = null
var _craft_msg_timer: float = 0.0
var _sfx_player: AudioStreamPlayer = null
var _sfx_open: AudioStream = null

func _ready() -> void:
	add_to_group("crafting_table")
	_build_visual()
	_setup_interact_area()
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_sfx_open = load("res://assets/bag_open.mp3")

func _process(delta: float) -> void:
	if _craft_msg_timer > 0.0:
		_craft_msg_timer -= delta
		if _craft_msg_timer <= 0.0 and _craft_msg:
			_craft_msg.modulate.a = 0.0

# ─────────────────────────────
# 입력
# ─────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if not event.pressed or event.echo: return
	var key = event.keycode
	if key == KEY_E or event.physical_keycode == KEY_E:
		if _player_in_range and not _ui_open:
			_open_ui()
			get_viewport().set_input_as_handled()
		elif _ui_open:
			_close_ui()
			get_viewport().set_input_as_handled()

# ─────────────────────────────
# UI 열기 / 닫기
# ─────────────────────────────
func _open_ui() -> void:
	_ui_open = true
	if _sfx_open and _sfx_player:
		_sfx_player.stream = _sfx_open
		_sfx_player.play()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 50
	add_child(_ui_layer)
	_build_craft_ui(player)

func _close_ui() -> void:
	_ui_open = false
	if _sfx_open and _sfx_player:
		_sfx_player.stream = _sfx_open
		_sfx_player.play()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)
	if is_instance_valid(_ui_layer):
		_ui_layer.queue_free()
	_ui_layer    = null
	_craft_msg   = null

# ─────────────────────────────
# UI 빌드
# ─────────────────────────────
func _build_craft_ui(player) -> void:
	# ── 배경 어둠막 ──
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(dim)

	# ── 메인 패널 ──
	var panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 620)
	panel.offset_left  = -350
	panel.offset_right =  350
	panel.offset_top   = -310
	panel.offset_bottom=  310
	_ui_layer.add_child(panel)

	var pbg = ColorRect.new()
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbg.color = Color(0.05, 0.05, 0.08, 0.97)
	panel.add_child(pbg)

	# 테두리 선
	for side in [
		{"r":Rect2(0,0,700,2)}, {"r":Rect2(0,618,700,2)},
		{"r":Rect2(0,0,2,620)}, {"r":Rect2(698,0,2,620)},
	]:
		var bd = ColorRect.new()
		bd.position = side["r"].position
		bd.size     = side["r"].size
		bd.color    = Color(0.3, 0.55, 0.32, 0.85)
		panel.add_child(bd)

	# ── 제목 ──
	var title = Label.new()
	title.text = "[ 제작대 ]"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.55, 0.90, 0.60))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10; title.offset_bottom = 38
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var close_hint = Label.new()
	close_hint.text = "[ E ] 닫기"
	close_hint.add_theme_font_size_override("font_size", 12)
	close_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	close_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	close_hint.offset_top = 14; close_hint.offset_bottom = 34; close_hint.offset_right = -12
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(close_hint)

	# ── 재료 현황 ──
	_build_materials_row(panel, player)

	# ── 레시피 그리드 ──
	_build_recipe_grid(panel, player)

	# ── 결과 메시지 ──
	_craft_msg = Label.new()
	_craft_msg.add_theme_font_size_override("font_size", 18)
	_craft_msg.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	_craft_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_craft_msg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_craft_msg.offset_top = -44; _craft_msg.offset_bottom = -14
	_craft_msg.modulate.a = 0.0
	panel.add_child(_craft_msg)

func _build_materials_row(panel: Control, player) -> void:
	var row_bg = ColorRect.new()
	row_bg.position = Vector2(8, 42)
	row_bg.size     = Vector2(684, 44)
	row_bg.color    = Color(0.08, 0.10, 0.08, 0.85)
	panel.add_child(row_bg)

	var lbl = Label.new()
	lbl.text = "보유 재료 :"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.68, 0.60))
	lbl.position = Vector2(14, 52)
	panel.add_child(lbl)

	const MAT_ORDER = [8, 9, 10, 11, 12, 13]
	var x_off = 110.0
	for type_id in MAT_ORDER:
		var cnt = 0
		if player and "material_inventory" in player:
			cnt = player.material_inventory.get(type_id, 0)
		var chip = ColorRect.new()
		chip.position = Vector2(x_off, 47)
		chip.size     = Vector2(88, 32)
		chip.color    = Color(MAT_COLORS[type_id], 0.22) if cnt == 0 else Color(MAT_COLORS[type_id], 0.45)
		panel.add_child(chip)

		var mat_lbl = Label.new()
		mat_lbl.text = "%s×%d" % [MAT_NAMES[type_id], cnt]
		mat_lbl.add_theme_font_size_override("font_size", 12)
		mat_lbl.add_theme_color_override("font_color",
			Color(0.4, 0.4, 0.4) if cnt == 0 else Color(MAT_COLORS[type_id]) * 2.0)
		mat_lbl.position = Vector2(x_off + 4, 52)
		mat_lbl.size     = Vector2(84, 22)
		mat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(mat_lbl)
		x_off += 93.0

func _build_recipe_grid(panel: Control, player) -> void:
	# 4열 3행 = 최대 12개 레시피
	const COLS = 4
	const CARD_W = 158.0
	const CARD_H = 160.0
	const PAD_X  = 14.0
	const START_Y = 94.0
	const GAP_X  = 8.0
	const GAP_Y  = 8.0

	for i in RECIPES.size():
		var recipe = RECIPES[i]
		var col = i % COLS
		var row = i / COLS
		var cx = PAD_X + col * (CARD_W + GAP_X)
		var cy = START_Y + row * (CARD_H + GAP_Y)

		var block_reason = _craft_block_reason(recipe, player)
		_build_recipe_card(panel, recipe, cx, cy, CARD_W, CARD_H, block_reason, player)

func _build_recipe_card(panel: Control, recipe: Dictionary,
		x: float, y: float, w: float, h: float, block_reason: String, player) -> void:
	var can_craft = block_reason == ""
	var card = Control.new()
	card.position = Vector2(x, y)
	card.custom_minimum_size = Vector2(w, h)
	panel.add_child(card)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.14, 0.10, 0.9) if can_craft else Color(0.08, 0.08, 0.10, 0.9)
	card.add_child(bg)

	# 테두리
	var border_color = Color(0.30, 0.62, 0.35, 0.90) if can_craft else Color(0.22, 0.22, 0.28, 0.60)
	for side in [
		{"p":Vector2(0,0),"s":Vector2(w,1.5)},
		{"p":Vector2(0,h-1.5),"s":Vector2(w,1.5)},
		{"p":Vector2(0,0),"s":Vector2(1.5,h)},
		{"p":Vector2(w-1.5,0),"s":Vector2(1.5,h)},
	]:
		var bd = ColorRect.new()
		bd.position = side["p"]; bd.size = side["s"]; bd.color = border_color
		card.add_child(bd)

	# 이름
	var name_lbl = Label.new()
	name_lbl.text = recipe["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color",
		Color(0.70, 1.00, 0.74) if can_craft else Color(0.45, 0.45, 0.50))
	name_lbl.position = Vector2(6, 6)
	name_lbl.size     = Vector2(w - 12, 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_lbl)

	# 설명
	var desc_lbl = Label.new()
	desc_lbl.text = recipe["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.55))
	desc_lbl.position = Vector2(6, 28)
	desc_lbl.size     = Vector2(w - 12, 18)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(desc_lbl)

	# 재료 목록
	var cost_y = 50.0
	for mat_type in recipe["cost"].keys():
		var need = recipe["cost"][mat_type]
		var have = 0
		if player and "material_inventory" in player:
			have = player.material_inventory.get(mat_type, 0)
		var enough = have >= need
		var cost_lbl = Label.new()
		cost_lbl.text = "  %s×%d  (%d보유)" % [MAT_NAMES[mat_type], need, have]
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color",
			Color(0.55, 0.88, 0.58) if enough else Color(0.80, 0.30, 0.28))
		cost_lbl.position = Vector2(4, cost_y)
		cost_lbl.size     = Vector2(w - 8, 17)
		card.add_child(cost_lbl)
		cost_y += 17.0

	# 제작 버튼
	var btn = Button.new()
	btn.text = "제작" if can_craft else block_reason
	btn.disabled = not can_craft
	btn.position = Vector2(8, h - 34)
	btn.size     = Vector2(w - 16, 26)
	if can_craft:
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.15, 0.42, 0.18)
		s.border_width_top = 1; s.border_width_bottom = 1
		s.border_width_left = 1; s.border_width_right = 1
		s.border_color = Color(0.35, 0.75, 0.40)
		s.corner_radius_top_left = 3; s.corner_radius_top_right = 3
		s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.87))
		btn.pressed.connect(_on_craft_pressed.bind(recipe, player))
	card.add_child(btn)

func _craft_block_reason(recipe: Dictionary, player) -> String:
	if not player or not ("material_inventory" in player): return "재료 부족"
	for mat_type in recipe["cost"].keys():
		var need = recipe["cost"][mat_type]
		if player.material_inventory.get(mat_type, 0) < need:
			return "재료 부족"
	if recipe["result"] == 18:
		var cur_bonus = player.get("run_max_flare_bonus") if player.get("run_max_flare_bonus") != null else 0
		if cur_bonus >= 1: return "이미 업그레이드됨"
	elif recipe["result"] == 4:
		var cur_max = player.get_max_flare() if player.has_method("get_max_flare") else 3
		var cur_f = player.get("flare_count") if player.get("flare_count") != null else 0
		if cur_f >= cur_max: return "최대 보유"
	else:
		var s1 = player.get("slot1_item")
		var s2 = player.get("slot2_item")
		if s1 != null and s2 != null and s1 != 0 and s2 != 0:
			return "슬롯 가득 참"
	return ""

func _check_recipe(recipe: Dictionary, player) -> bool:
	return _craft_block_reason(recipe, player) == ""

func _on_craft_pressed(recipe: Dictionary, player) -> void:
	if not _check_recipe(recipe, player): return
	# 슬롯 공간 확인
	if not player.has_method("try_pickup_item"): return
	# 재료 차감 (dev_mode: 무소모 / waste_not: 30% 확률로 재료 1종 환급)
	var is_dev = player.get("dev_mode") == true
	if not is_dev:
		var refund_candidate: int = -1
		var refund_pool: Array = recipe["cost"].keys()
		if GlobalSave.has_skill("waste_not") and refund_pool.size() > 0:
			if randf() < 0.30:
				refund_candidate = refund_pool[randi() % refund_pool.size()]
		for mat_type in recipe["cost"].keys():
			var deduct = recipe["cost"][mat_type]
			if mat_type == refund_candidate:
				deduct = max(0, deduct - 1)
			player.material_inventory[mat_type] = player.material_inventory.get(mat_type, 0) - deduct
			if player.material_inventory[mat_type] <= 0:
				player.material_inventory.erase(mat_type)
	player._update_material_ui()
	# 결과물 슬롯에 추가
	if recipe["result"] == 18:
		player.run_max_flare_bonus += 1
		player._update_flare_ui()
	elif recipe["result"] == 4:
		player.try_pickup_item(4)
	else:
		if player.slot1_item == 0:
			player.slot1_item = recipe["result"]
		elif player.slot2_item == 0:
			player.slot2_item = recipe["result"]
		else:
			pass
		player._update_item_ui()
	# UI 갱신
	_show_craft_message("✓  %s 제작 완료!" % recipe["name"])
	if is_instance_valid(_ui_layer):
		_ui_layer.queue_free()
		_ui_layer = null
		_craft_msg = null
		await get_tree().create_timer(0.05).timeout
		var p = get_tree().get_first_node_in_group("player")
		_open_ui_delayed(p)

func _open_ui_delayed(player) -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 50
	add_child(_ui_layer)
	_build_craft_ui(player)
	if _craft_msg and _craft_msg_timer > 0.0:
		_craft_msg.modulate.a = 1.0

func _show_craft_message(msg: String) -> void:
	_craft_msg_timer = 2.5
	if _craft_msg:
		_craft_msg.text = msg
		_craft_msg.modulate.a = 1.0

# ─────────────────────────────
# 상호작용 영역
# ─────────────────────────────
func _setup_interact_area() -> void:
	_interact_area = Area2D.new()
	_interact_area.collision_layer = 0
	_interact_area.collision_mask  = 1
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 75)
	cs.shape  = rect
	_interact_area.add_child(cs)
	add_child(_interact_area)

	_hint_label = Label.new()
	_hint_label.text = "[ E ] 제작"
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.60))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(-45, -52)
	_hint_label.visible  = false
	_hint_label.z_index  = 5
	add_child(_hint_label)

	_interact_area.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = true
			if _hint_label: _hint_label.visible = true
			if b.has_method("show_hint"):
				b.show_hint("crafting", "[ E ] 제작 메뉴 — 재료 아이템으로 소모품 제작")
	)
	_interact_area.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_player_in_range = false
			if _hint_label: _hint_label.visible = false
			if _ui_open: _close_ui()
	)

# ─────────────────────────────
# 비주얼
# ─────────────────────────────
func _build_visual() -> void:
	# 작업대 상판
	var top = Polygon2D.new()
	top.polygon = PackedVector2Array([
		Vector2(-38, -18), Vector2(38, -18),
		Vector2(38,   4),  Vector2(-38,  4),
	])
	top.color   = Color(0.28, 0.22, 0.14)
	top.z_index = 2
	add_child(top)

	# 상판 하이라이트
	var highlight = Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(-38, -18), Vector2(38, -18),
		Vector2(38,  -15), Vector2(-38,-15),
	])
	highlight.color   = Color(0.48, 0.38, 0.24)
	highlight.z_index = 3
	add_child(highlight)

	# 다리 왼쪽
	var leg_l = Polygon2D.new()
	leg_l.polygon = PackedVector2Array([
		Vector2(-32, 4), Vector2(-22, 4),
		Vector2(-22,20), Vector2(-32,20),
	])
	leg_l.color   = Color(0.22, 0.17, 0.10)
	leg_l.z_index = 1
	add_child(leg_l)

	# 다리 오른쪽
	var leg_r = Polygon2D.new()
	leg_r.polygon = PackedVector2Array([
		Vector2(22, 4), Vector2(32, 4),
		Vector2(32,20), Vector2(22,20),
	])
	leg_r.color   = Color(0.22, 0.17, 0.10)
	leg_r.z_index = 1
	add_child(leg_r)

	# 발광 윤곽 (안전구역 표시)
	var glow = Line2D.new()
	glow.width         = 2.0
	glow.default_color = Color(0.30, 0.80, 0.38, 0.55)
	glow.z_index       = 4
	var pts = PackedVector2Array([
		Vector2(-38,-18), Vector2(38,-18),
		Vector2(38,  4),  Vector2(-38, 4), Vector2(-38,-18)
	])
	for p in pts: glow.add_point(p)
	add_child(glow)

	# 콜리전
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(76, 38)
	col.shape = rect
	col.position = Vector2(0, -7)
	add_child(col)

	# "제작대" 라벨
	var lbl = Label.new()
	lbl.text = "제작대"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.60, 0.80))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-30, -30)
	lbl.z_index  = 5
	add_child(lbl)
