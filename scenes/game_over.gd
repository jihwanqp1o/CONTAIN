extends Control

const GameState = preload("res://scenes/game_state.gd")

var _over_bgm: AudioStreamPlayer = null
var _over_bgm_timer: float = 0.0
var _sfx_hover: AudioStreamPlayer = null
var _sfx_click: AudioStreamPlayer = null

func _ready():
	$VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$VBoxContainer/RestartButton.grab_focus()

	_setup_audio()

	# 사망 원인 표시
	var killer_label = %KillerLabel if has_node("%KillerLabel") else null
	if killer_label:
		var name = GameState.killer_name
		killer_label.text = "사망 원인:  %s" % name

	# 생존 시간 표시
	var time_label = %TimeLabel
	var best_label = %BestTimeLabel
	if time_label:
		time_label.text = _format_time(GameState.survival_time)
	if best_label:
		if GameState.is_new_record:
			best_label.text = "★ 신기록!"
			best_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
		else:
			best_label.text = "최고 기록: " + _format_time(GameState.best_time)

	var kp_run_label = %KpRunLabel
	var kp_total_label = %KpTotalLabel
	if kp_run_label:
		var earned = GlobalSave.run_kp
		if earned > 0:
			kp_run_label.text = "이번 런  +%d p" % earned
		else:
			kp_run_label.text = "이번 런  +0 p"
	if kp_total_label:
		kp_total_label.text = "누적 지식 포인트:  %d p" % GlobalSave.get_total_kp()

func _process(delta: float) -> void:
	if _over_bgm == null: return
	_over_bgm_timer += delta
	if _over_bgm_timer >= 12.0:
		_over_bgm_timer = 0.0
		_over_bgm.play()

func _format_time(seconds: float) -> String:
	var total = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]

func _on_restart_pressed():
	if _sfx_click: _sfx_click.play()
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_menu_pressed():
	if _sfx_click: _sfx_click.play()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _setup_audio() -> void:
	_over_bgm = AudioStreamPlayer.new()
	_over_bgm.stream    = load("res://assets/over.mp3")
	_over_bgm.volume_db = -5.0
	add_child(_over_bgm)
	_over_bgm.play()

	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.stream = load("res://assets/button.mp3")
	add_child(_sfx_hover)

	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/button2.mp3")
	add_child(_sfx_click)

	for btn in [$VBoxContainer/RestartButton, $VBoxContainer/MenuButton]:
		btn.mouse_entered.connect(func(): _sfx_hover.play())
