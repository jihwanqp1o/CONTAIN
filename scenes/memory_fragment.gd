extends Node2D

const PICKUP_RANGE: float = 55.0

const LORE_TEXTS: Array = [
	# 연구의 시작
	"연구는 인류를 위한 것이었다.\n하지만 어느 순간, 점점 통제를 벗어나기 시작했다.\n실험체들은 단순한 생명체가 아니었다.\n그들은 스스로 생각하기 시작했다.",
	# 격리
	"연구원들은 위험을 감지하고\n모든 실험체를 지하 격리 구역에 가두었다.\n하지만 긴 감금은 실험체들의 분노만 키워 갔다.\n그 분노를 가둘 수 있는 벽은 없었다.",
	# 오류
	"보안 시스템 오류가 반복해서 발생했다.\n처음엔 작은 오작동처럼 보였다.\n일부 연구원들은 누군가가 시스템을 조작하고 있다고 의심했다.\n하지만 아무도 확인하지 못했다.",
	# 정전
	"정전이 발생한 순간,\n격리 장치가 하나둘 멈추기 시작했다.\n굳게 닫혀 있던 철문이 열렸다.\n연구소는 순식간에 혼란에 빠졌다.",
	# 탈출
	"실험체들의 탈출로 연구소는 통제력을 잃었다.\n남겨진 기록들 사이에\n마지막 출구를 열 수 있는 열쇠의 존재가 적혀 있었다.\n— 그 열쇠를 찾아야 한다.",
	# 은신
	"상자 안으로 들어갔다.\n발소리가 지나쳤다.\n그것들도 한때 인간의 유전자를 품고 있었다.\n지금은 그 사실이 전혀 위안이 되지 않는다.",
	# 빛
	"빛이 저것들을 잠깐 밀어낸다.\n인간의 본능이 아직 남아 있는 탓인지.\n완전히는 아니다. 잠깐만.\n하지만 그 잠깐이 전부다.",
	# APEX
	"심층부에서 땅이 흔들렸다.\n벽에 금이 갔다.\nAPEX — 분류조차 포기한 코드명.\n저것을 위해 이 시설의 가장 깊은 곳이 만들어졌다.",
	# 반복
	"몇 번을 죽었는지 세지 않는다.\n이 시설에서 죽음은 형벌이 아니다.\n다시 일어날 때마다 조금씩 더 오래 살아남는다.\n죽음이 정보가 되는 날까지.",
	# 대가
	"수십 년간의 실험.\n인류의 한계를 넘겠다는 목표.\n그들은 성공했다.\n다만 그 결과물이 자신들을 가뒀을 뿐이다.",
	# 전령
	"혼자인 것과 마주쳤다. 별것 아닌 줄 알았다.\n그것이 신호를 보내자 — 사방이 깨어났다.\n실험체들 사이에도 통신 체계가 있었다.\n이제야 이해했다. 그래서 다들 당한 거구나.",
	# 마지막 희망
	"누군가가 먼저 여기까지 왔다.\n그는 메모를 남겼다:\n'열쇠는 심층부 보안 실험실에.'\n그 사람이 어떻게 됐는지는 모른다.",
]

var _fragment_id: String = ""
var _log_enemy_id: String = ""   # 비어 있으면 일반 기억 모드
var _log_line_idx: int = 0
var _pulse_time: float = 0.0
var _player_nearby: Node = null
var _hint_label: Label = null
var _collected: bool = false

func setup(fragment_id: String) -> void:
	_fragment_id = fragment_id

func setup_as_log(fragment_id: String, enemy_id: String, line_idx: int) -> void:
	_fragment_id = fragment_id
	_log_enemy_id = enemy_id
	_log_line_idx = line_idx

func _ready() -> void:
	if _fragment_id == "":
		_fragment_id = "frag_%d" % get_instance_id()
	if GlobalSave.is_fragment_collected(_fragment_id):
		queue_free()
		return
	_build_visual()
	_build_pickup_area()

func _process(delta: float) -> void:
	if _collected: return
	_pulse_time += delta
	scale = Vector2.ONE * (1.0 + sin(_pulse_time * 3.5) * 0.08)
	if _player_nearby and Input.is_action_just_pressed("interact"):
		_collect()

func _collect() -> void:
	if _collected: return
	_collected = true
	var kp = 8 if _log_enemy_id != "" else 5
	GlobalSave.collect_fragment(_fragment_id, kp)
	_show_lore()
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
	tw.tween_property(self, "scale", Vector2(2.5, 2.5), 0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free).set_delay(0.4)

func _show_lore() -> void:
	var text: String
	var title_text: String
	var title_color: Color
	var kp_gained: int

	if _log_enemy_id != "":
		var entry: Dictionary = SpecimenDB.get_entry(_log_enemy_id)
		var lines: Array = entry.get("damaged_lines", [])
		text = lines[_log_line_idx % lines.size()] if lines.size() > 0 else ""
		title_text = "[ 연구 기록 — %s ]" % entry.get("code", "???")
		title_color = entry.get("color", Color.WHITE)
		kp_gained = 8
	else:
		var idx = abs(_fragment_id.hash()) % LORE_TEXTS.size()
		text = LORE_TEXTS[idx]
		title_text = "[ 단편적 기억 ]"
		title_color = Color(0.55, 0.85, 1.0)
		kp_gained = 5

	var overlay = CanvasLayer.new()
	overlay.add_to_group("lore_popup")
	get_tree().root.add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 110)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var body = Label.new()
	body.text = text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 12)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var kp_lbl = Label.new()
	kp_lbl.text = "+%d KP" % kp_gained
	kp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kp_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	kp_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(kp_lbl)

	var close_btn = Button.new()
	close_btn.text = "[ 닫기 ]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	close_btn.flat = true
	close_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(close_btn)

	var tw = overlay.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(overlay.queue_free)
	var close_fn = func():
		tw.kill()
		overlay.queue_free()
	close_btn.pressed.connect(close_fn)
	overlay.set_meta("close_fn", close_fn)

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
	_hint_label.text = "E - 수집"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_hint_label.position = Vector2(-18, 22)
	_hint_label.visible  = false
	add_child(_hint_label)

func _build_visual() -> void:
	# 별 모양 (5각) 발광 오브젝트
	var outer = _make_star(14.0, 6.0, 5, Color(0.55, 0.85, 1.0, 0.9))
	add_child(outer)
	var inner = _make_star(8.0, 3.5, 5, Color(1.0, 1.0, 1.0, 0.95))
	add_child(inner)
	# 후광
	var glow = Polygon2D.new()
	var gpts = PackedVector2Array()
	for i in 16:
		var a = TAU * i / 16.0
		gpts.append(Vector2(cos(a), sin(a)) * 20.0)
	glow.polygon = gpts
	glow.color   = Color(0.4, 0.75, 1.0, 0.15)
	glow.z_index = -1
	add_child(glow)
	# 어두운 환경에서도 보이도록 자체 발광
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d = Vector2(float(x), float(y)).distance_to(Vector2(16.0, 16.0)) / 16.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clamp(pow(1.0 - d, 1.5), 0.0, 1.0)))
	var light = PointLight2D.new()
	light.texture       = ImageTexture.create_from_image(img)
	light.texture_scale = 2.2
	light.energy        = 1.6
	light.color         = Color(0.55, 0.85, 1.0)
	add_child(light)

func _make_star(r_outer: float, r_inner: float, points: int, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts  = PackedVector2Array()
	for i in points * 2:
		var a = TAU * i / (points * 2.0) - PI / 2.0
		var r = r_outer if i % 2 == 0 else r_inner
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	poly.polygon = pts
	poly.color   = color
	return poly
