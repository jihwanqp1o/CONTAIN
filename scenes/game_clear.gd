extends Control

const GameState = preload("res://scenes/game_state.gd")

var _bgm: AudioStreamPlayer = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_bgm = AudioStreamPlayer.new()
	_bgm.stream    = load("res://assets/clear.mp3")
	_bgm.volume_db = -5.0
	add_child(_bgm)
	_bgm.play()
	_bgm.finished.connect(func(): _bgm.play())

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.06, 0.03)
	add_child(bg)

	# 클리어 메시지
	var title = Label.new()
	title.text = "CONTAIN  CLEAR"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.4, 1.2, 0.5))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left   = -300
	title.offset_right  =  300
	title.offset_top    = -160
	title.offset_bottom = -90
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub = Label.new()
	sub.text = "시설에서 탈출했다."
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.6, 0.85, 0.65, 0.9))
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub.offset_left   = -200
	sub.offset_right  =  200
	sub.offset_top    = -60
	sub.offset_bottom = -22
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# 생존 시간
	var time_lbl = Label.new()
	time_lbl.text = "생존 시간  " + _format_time(GameState.survival_time)
	time_lbl.add_theme_font_size_override("font_size", 17)
	time_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 0.70))
	time_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	time_lbl.offset_left   = -200
	time_lbl.offset_right  =  200
	time_lbl.offset_top    = -10
	time_lbl.offset_bottom =  24
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(time_lbl)

	# 버튼 두 개
	var quit_btn = Button.new()
	quit_btn.text = "게임 종료"
	quit_btn.custom_minimum_size = Vector2(160, 50)
	quit_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	quit_btn.offset_left   = -175
	quit_btn.offset_right  = -15
	quit_btn.offset_top    =  60
	quit_btn.offset_bottom =  110
	quit_btn.pressed.connect(func(): get_tree().quit())
	add_child(quit_btn)

	var menu_btn = Button.new()
	menu_btn.text = "메인 메뉴"
	menu_btn.custom_minimum_size = Vector2(160, 50)
	menu_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_btn.offset_left   =  15
	menu_btn.offset_right  = 175
	menu_btn.offset_top    =  60
	menu_btn.offset_bottom = 110
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(menu_btn)

	menu_btn.grab_focus()

	# 페이드 인
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.0)

func _format_time(seconds: float) -> String:
	var total = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
