extends CharacterBody2D

const GameState        = preload("res://scenes/game_state.gd")
const FlareProjectile  = preload("res://scenes/flare_projectile.gd")

@export_group("Movement")
@export var walk_speed: float = 150.0
@export var run_speed: float = 300.0
@export var tired_speed: float = 80.0

@export_group("Status Limits")
@export var max_hp: float = 1.0
@export var max_stamina: float = 100.0
@export var max_battery: float = 100.0
@export var max_fear: float = 100.0

@export_group("Fear Settings")
@export var fear_reduction_rate: float = 5.0
@export var fear_reduction_in_box: float = 25.0

@export_group("Sound Effects")
@export var sfx_flashlight_on: AudioStream
@export var sfx_flashlight_off: AudioStream
@export var sfx_battery_low: AudioStream
@export var sfx_heartbeat: AudioStream
@export var sfx_death: AudioStream

@export_group("Item Sound Effects")
@export var sfx_adrenaline_use: AudioStream  # 주사기 치직 같은 소리
@export var sfx_battery_use: AudioStream     # 전자 충전음
@export var sfx_shield_equip: AudioStream    # 금속 장착음
@export var sfx_shield_block: AudioStream    # 방어 충격음 (방패 깨짐)

# =====================
# 상태 변수
# =====================
var current_hp: float = 1.0
var current_stamina: float = 100.0
var current_battery: float = 100.0
var current_fear: float = 0.0

var is_exhausted: bool = false
var _is_collapsing: bool = false
var _exhaust_death_timer: float = 0.0
var _collapse_label: Label = null
var _is_dodging: bool = false
var _dodge_vel: Vector2 = Vector2.ZERO
var _dodge_timer: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_invincible_timer: float = 0.0
var _dodge_just_activated_timer: float = 0.0
var _dodge_speed_buff_timer: float = 0.0
var _dodge_pressed: bool = false
var _perfect_label: Label = null
var _dodge_cooldown_label: Label = null
var _stamina_shield_active: bool = false
var _stamina_shield_initialized: bool = false
var _boss_shield_hit_cooldown: float = 0.0
var _shield_regen_timer: float = 0.0
const SHIELD_REGEN_TIME: float = 2.0
const SHIELD_MAX_STAMINA: float = 105.0
var _boss_knockback_vel: Vector2 = Vector2.ZERO
var _boss_knockback_timer: float = 0.0
var _roar_lock_timer: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0
var _boss_shield_label: Label = null
var _ambient_light: PointLight2D = null
var _danger_overlay: ColorRect = null
var dev_mode: bool = false

# ── DEV 초기화 홀드 시스템
var _dev_reset_mode:   String = ""
var _dev_reset_timer:  float  = 0.0
const _DEV_RESET_HOLD: float  = 5.0
var _dev_reset_bar:    Control = null
var _dev_reset_fill:   ColorRect = null
var _dev_reset_label:  Label = null
var _dev_key_hints:    Label = null
var _dev_toast_label:  Label = null
var _dev_toast_timer:  float = 0.0
var _dev_mode_label: Label = null
var _battery_drain_rate: float = 1.8
var _stamina_drain_rate: float = 28.0
var _fear_increase_mult: float = 1.0
var _cached_enemies: Array = []
var _enemy_cache_timer: float = 0.0
var _fear_endurance_timer: float = 0.0
var _fear_endured: bool = false
var _fear_speed_mult: float = 1.0
var _fear_flashlight_delay: float = 0.0
var _fear_flashlight_pending: bool = false
var _fear_was_100: bool = false

# ── 스킬 트리 신규 상태 ──
var _run_sound_mult: float = 1.0          # quiet_step / quiet_footstep
var _pickup_range_mult: float = 1.0       # scavenge_memory
var _box_hide_timer: float = 0.0          # position_memory 용 은신 시간 추적
var _was_chasing: bool = false            # escape_instinct / sense_alert 트리거
var _escape_boost_timer: float = 0.0      # 도주 본능 지속 타이머
var _fear_surge_used: bool = false        # fear_surge 런당 1회
var _fear_stamina_burst_used: bool = false # 공포 100 긴급 스태미나 런당 1회
var _is_knocked_down: bool = false        # 기절 연출 진행 중 (첫 사망 유예)
var _is_paused: bool = false
var _pause_panel: Control = null
var _battery_warn_flicker: float = 0.0   # battery_warning 깜빡임 타이머
var _silhouette_timer: float = 0.0        # position_memory 실루엣 표시 타이머
var _dodge_stamina_mult: float = 1.0
var _alpha_stamina_pressure: float = 1.0  # 알파 아우라: 1.0=정상, 낮을수록 회복 감소
var is_alive: bool = true
var flashlight_on: bool = false
var is_hidden_state: bool = false
var has_key: bool = false
var killer_name: String = ""
var _battery_low_warned: bool = false
var _survival_time: float = 0.0
var _fear_nearby_enemies: Array = []
var _minimap_panel: Control = null
var _minimap_player_dot: ColorRect = null
var _minimap_zone_fills: Dictionary = {}
var _minimap_zone_labels: Dictionary = {}
var _minimap_visited: Dictionary = {}

# ── 독백 시스템 ──
var _mono_label: Label = null
var _mono_bg: ColorRect = null
var _mono_active: bool = false
var _mono_cooldown: float = 0.0
var _mono_spawn_delay: float = 2.0
# ── 힌트 시스템 ──
var _hint_label: Label = null
var _hint_tween: Tween = null
var _shown_hints: Dictionary = {}
var _mono_seen: Dictionary = {}
var _mono_fear_level: int = 0
var _mono_fear_recovered: bool = false
var _mono_battery_low: bool = false
var _mono_dark_timer: float = 0.0
var _mono_dark_shown: bool = false
var _mono_box_short: bool = false
var _mono_box_long_timer: float = 0.0
var _mono_box_long: bool = false
var _mono_safe_prev: bool = false
var _mono_safe_count: int = 0
var _mono_was_chasing: bool = false
var _mono_chase_escape_cd: float = 0.0
var _mono_stamina_cd: float = 0.0
var is_sneaking: bool = false
var _assassination_boost_timer: float = 0.0

# 기억 스킬로 조정되는 값들
var _effective_sneak_speed: float = 90.0
var _effective_assassination_range: float = 85.0
var _effective_dodge_perfect_window: float = 0.28
var _effective_adrenaline_duration: float = 5.0

# 기억 시스템 — 잠금 해제 플래그 (기억 구매 전에는 해당 능력 사용 불가)
var can_dodge: bool = false
var can_sneak: bool = false
var can_assassinate: bool = false

# =====================
# 소리 시스템 (Echo/Tremor 등 청각 기반 적을 위한 이벤트 시그널)
# =====================
# pos: 발생 위치, intensity: 0.0~1.0 (강도)
signal sound_emitted(pos: Vector2, intensity: float)
var _sound_footstep_timer: float = 0.0

# =====================
# 아이템 시스템
# =====================
# item.gd의 ItemType enum과 값이 일치해야 함
enum ItemType {
	NONE = 0, ADRENALINE = 1, BATTERY = 2, SHIELD = 3, FLARE = 4, ROCK = 5, LANTERN = 6, MEMORY_SHARD = 7,
	WIRE = 8, CHEM = 9, METAL = 10, CLOTH = 11, CELL = 12, EXPLOSIVE = 13,
	NOISE_DEVICE = 14, EMP_GRENADE = 15, FEAR_SUPPRESSOR = 16, ENHANCED_FLASHLIGHT = 17,
}

var slot1_item: int = ItemType.NONE
var slot2_item: int = ItemType.NONE

# 재료 인벤토리 (type_id → 개수)
var material_inventory: Dictionary = {}
var is_in_safe_zone: bool = false
var _enhanced_flashlight_timer: float = 0.0
var _mat_hud_label: Label = null
var _bag_open: bool = false
var _bag_container: Control = null
var _bag_mat_labels: Array = []

var _codex_open: bool = false
var _codex_panel: Control = null
var _codex_list_vbox: VBoxContainer = null
var _codex_detail_root: VBoxContainer = null
var _codex_selected: int = -1
var _codex_list_btns: Array = []

const MAX_FLARE: int = 3
var flare_count: int = 3
var run_max_flare_bonus: int = 0  # 제작대 "신호탄 케이스" 업그레이드로 증가
var _flare_icons: Array = []

func get_max_flare() -> int:
	var m = MAX_FLARE
	if GlobalSave.get_ability_level("flame_sense") >= 1: m += 1  # 기억노드 lv1: 3→4
	m += run_max_flare_bonus                                      # 제작대 케이스: 4→5
	return mini(m, 5)

var shield_active: bool = false
var adrenaline_active: bool = false
var _adrenaline_timer: float = 0.0

const ADRENALINE_DURATION: float = 5.0      # 지속 시간 (초)
const SHIELD_SPEED_MULT: float = 0.65       # 방패 장착 시 이동속도 65%

# =====================
# 노드 참조
# =====================
var light_node: PointLight2D = null
var _flashlight_cone: Polygon2D = null
@onready var footstep_sound = $working
@onready var stamina_bar = %StaminaBar
@onready var fear_bar = %FearBar
@onready var battery_bar = %BatteryBar
@onready var hp_bar = %HPBar
@onready var left_bars = %LeftBars
@onready var slot1_icon = $CanvasLayer/Control/Inventory/Slot1/Slot1Icon
@onready var slot2_icon = $CanvasLayer/Control/Inventory/Slot2/Slot2Icon
@onready var timer_label = %TimerLabel
@onready var fade_overlay = $CanvasLayer/Control/FadeOverlay
@onready var sneak_label = %SneakLabel

var _left_bars_orig_pos: Vector2
var _sfx_player: AudioStreamPlayer
var _heartbeat_player: AudioStreamPlayer
var _breathing_player: AudioStreamPlayer
var _sfx_memo: AudioStream = null
var _sfx_rock_throw: AudioStream = null
var _sfx_zab: AudioStream = null
var _sfx_sinho: AudioStream = null

# 바 색상 스타일 (한 번 생성 후 bg_color만 변경)
var _fear_style: StyleBoxFlat
var _stamina_style: StyleBoxFlat
var _battery_style: StyleBoxFlat

const COLOR_FEAR_NORMAL    = Color(0.45, 0.05, 0.60)  # 보라
const COLOR_STAMINA_NORMAL = Color(0.10, 0.65, 0.20)  # 초록
const COLOR_BATTERY_NORMAL = Color(0.75, 0.65, 0.00)  # 노랑
const COLOR_DANGER         = Color(0.90, 0.10, 0.10)  # 빨강

const SNEAK_SPEED: float = 90.0
const ASSASSINATION_RANGE: float = 85.0
const ASSASSINATION_BOOST_DURATION: float = 5.0
const ASSASSINATION_SPEED_MULT: float = 1.30

const DODGE_DISTANCE: float = 120.0
const DODGE_DURATION: float = 0.13
const DODGE_STAMINA_COST: float = 25.0
const DODGE_INVINCIBLE_TIME: float = 0.20
const DODGE_COOLDOWN: float = 1.5
const DODGE_PERFECT_WINDOW: float = 0.28
const DODGE_PERFECT_STAMINA: float = 30.0
const DODGE_PERFECT_SPEED_MULT: float = 1.4
const DODGE_PERFECT_SPEED_DURATION: float = 1.5

const COLLAPSE_SPEED: float = 35.0
const COLLAPSE_REGEN_STILL: float = 30.0   # 정지 시 회복속도
const COLLAPSE_REGEN_MOVING: float = 2.0   # 이동 중 회복속도
const COLLAPSE_RECOVERY_THRESHOLD: float = 25.0
const EXHAUST_DEATH_DURATION: float = 5.0

# ── 미니맵 ──
const MINI_W: float = 200.0
const MINI_H: float = 145.0
const MINI_ZONE_RECTS: Dictionary = {
	"A": Rect2(  50,   50, 1345, 1385),
	"B": Rect2(1435,   50, 1265, 1385),
	"C": Rect2(2700,   50, 2450, 1385),
	"D": Rect2(  50, 1435, 2250, 1375),
	"E": Rect2(2300, 1435, 2850, 1375),
	"F": Rect2(  50, 2810, 5100,  940),
}
const MINI_ZONE_COLORS: Dictionary = {
	"A": Color(0.25, 0.70, 0.35, 0.80),
	"B": Color(0.75, 0.20, 0.20, 0.80),
	"C": Color(0.20, 0.40, 0.85, 0.80),
	"D": Color(0.60, 0.20, 0.80, 0.80),
	"E": Color(0.80, 0.65, 0.20, 0.80),
	"F": Color(0.80, 0.15, 0.15, 0.80),
}
const MINI_PASSAGES: Array = [
	Vector2(1395,  695),  # A↔B
	Vector2(2700,  785),  # B↔C
	Vector2( 805, 1415),  # 상단↔D 서
	Vector2(2195, 1415),  # 상단↔D 중
	Vector2(3875, 1415),  # C↔E 동
	Vector2(2300, 2225),  # D↔E
	Vector2( 675, 2830),  # D→F 서
	Vector2(2125, 2830),  # DE→F 중
	Vector2(3725, 2830),  # E→F 동
]

const MONO_GLOBAL_CD: float = 14.0
const MONO_ENEMY: Dictionary = {
	"shade":    "저건... 빛을 피하고 있어.",
	"stalker":  "나를 보고 있다. 시선이 느껴진다.",
	"ambusher": "— 뭔가 숨어있어.",
	"herald":   "울지 마. 제발 울지 마.",
	"sentinel": "움직이지 않는다. 기다리고 있어.",
	"charger":  "저건 빠르다. 막을 수 없어.",
	"brood":    "여럿이다... 여럿이야.",
	"colossus": "...살아있는 건가. 저게.",
}

func _ready():
	add_to_group("player")
	_build_visual()
	light_node = PointLight2D.new()
	add_child(light_node)
	_setup_flashlight()
	_setup_ambient_light()
	_setup_bar_styles()
	if left_bars:
		_left_bars_orig_pos = left_bars.position
	_update_ui()
	_update_item_ui()

	sfx_flashlight_on  = load("res://assets/flee.mp3")
	sfx_flashlight_off = load("res://assets/flee.mp3")
	sfx_heartbeat      = load("res://assets/feer.mp3")
	sfx_death          = load("res://assets/die.mp3")
	sfx_shield_equip   = load("res://assets/shield_equip.mp3")
	sfx_shield_block   = load("res://assets/shield_equip.mp3")
	_sfx_memo          = load("res://assets/memo.mp3")
	_sfx_rock_throw    = load("res://assets/rock.mp3")
	_sfx_zab           = load("res://assets/zab.mp3")
	_sfx_sinho         = load("res://assets/sinho.mp3")

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.stream = sfx_heartbeat
	_heartbeat_player.finished.connect(_on_heartbeat_finished)
	add_child(_heartbeat_player)

	_breathing_player = AudioStreamPlayer.new()
	_breathing_player.stream = load("res://assets/stam.mp3")
	_breathing_player.finished.connect(_on_breathing_finished)
	add_child(_breathing_player)

	_danger_overlay = ColorRect.new()
	_danger_overlay.color = Color(0.85, 0.0, 0.0, 0.0)
	_danger_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_overlay.z_index = 90
	$CanvasLayer/Control.add_child(_danger_overlay)

	_collapse_label = Label.new()
	_collapse_label.add_theme_font_size_override("font_size", 24)
	_collapse_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	_collapse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_label.visible = false
	_collapse_label.z_index = 100
	_collapse_label.custom_minimum_size = Vector2(300, 40)
	$CanvasLayer/Control.add_child(_collapse_label)
	_collapse_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_collapse_label.offset_top = -90
	_collapse_label.offset_bottom = -50

	_perfect_label = Label.new()
	_perfect_label.add_theme_font_size_override("font_size", 30)
	_perfect_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perfect_label.visible = false
	_perfect_label.z_index = 100
	_perfect_label.custom_minimum_size = Vector2(300, 50)
	$CanvasLayer/Control.add_child(_perfect_label)
	_perfect_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_perfect_label.offset_top = -140
	_perfect_label.offset_bottom = -90

	_dodge_cooldown_label = Label.new()
	_dodge_cooldown_label.add_theme_font_size_override("font_size", 13)
	_dodge_cooldown_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_dodge_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dodge_cooldown_label.custom_minimum_size = Vector2(220, 20)
	_dodge_cooldown_label.z_index = 100
	$CanvasLayer/Control.add_child(_dodge_cooldown_label)
	_dodge_cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_dodge_cooldown_label.offset_top  = -94
	_dodge_cooldown_label.offset_left = 14

	_boss_shield_label = Label.new()
	_boss_shield_label.add_theme_font_size_override("font_size", 26)
	_boss_shield_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_boss_shield_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_boss_shield_label.add_theme_constant_override("outline_size", 4)
	_boss_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_shield_label.visible = false
	_boss_shield_label.z_index = 100
	_boss_shield_label.custom_minimum_size = Vector2(400, 40)
	$CanvasLayer/Control.add_child(_boss_shield_label)
	_boss_shield_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_shield_label.offset_top  = -118
	_boss_shield_label.offset_bottom = -80

	_dev_mode_label = Label.new()
	_dev_mode_label.add_theme_font_size_override("font_size", 18)
	_dev_mode_label.add_theme_color_override("font_color", Color(0.15, 1.0, 0.35))
	_dev_mode_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_dev_mode_label.add_theme_constant_override("outline_size", 3)
	_dev_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dev_mode_label.text = "[ 제작자 모드 ]   F2: 해제"
	_dev_mode_label.visible = false
	_dev_mode_label.z_index = 200
	_dev_mode_label.custom_minimum_size = Vector2(400, 28)
	$CanvasLayer/Control.add_child(_dev_mode_label)
	_dev_mode_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_dev_mode_label.offset_top = 4
	_dev_mode_label.offset_bottom = 32

	_apply_skill_bonuses()
	_build_flare_hud()
	_build_material_hud()
	_build_bag_panel()
	_build_codex_panel()
	_build_monologue_ui()
	_build_hint_ui()
	_build_minimap_ui()
	_build_pause_ui()
	process_mode = Node.PROCESS_MODE_ALWAYS
	GlobalSave.ability_unlocked.connect(_on_ability_unlocked)
	get_tree().create_timer(2.0).timeout.connect(func():
		show_hint("start", "[ WASD ] 이동     [ Shift ] 달리기 — 소리 발생"))

# =====================
# 스킬 적용
# =====================
func _apply_skill_bonuses() -> void:
	fear_reduction_rate = 7.0
	# ── 신체 기억 ──
	if GlobalSave.has_skill("stamina_1"): _stamina_drain_rate *= 0.80
	if GlobalSave.has_skill("stamina_2"): _stamina_drain_rate *= 0.80
	current_stamina = max_stamina

	can_dodge = GlobalSave.has_skill("dodge_unlock")
	if GlobalSave.has_skill("dodge_up"):      _dodge_stamina_mult = 0.5
	if GlobalSave.has_skill("dodge_perfect"): _effective_dodge_perfect_window += 0.05
	# breath_hold / recovery_instinct / impact_memory: _process에서 체크

	# ── 은신 기억 ──
	can_sneak       = GlobalSave.has_skill("sneak_unlock")
	can_assassinate = GlobalSave.has_skill("assassin_unlock")
	if GlobalSave.has_skill("hearing_adapt"):  _effective_sneak_speed += 27.0
	if GlobalSave.has_skill("assassin_range"): _effective_assassination_range += 34.0
	# quiet_step: _run_sound_mult에 반영
	if GlobalSave.has_skill("quiet_step"): _run_sound_mult *= 0.65
	# escape_instinct / shadow_read / position_memory: _process에서 체크

	# ── 감각 기억 ──
	if GlobalSave.has_skill("battery_1"): _battery_drain_rate *= 0.75
	if GlobalSave.has_skill("battery_2"): _battery_drain_rate *= 0.75
	# battery_warning: _handle_flashlight에서 체크
	if GlobalSave.has_skill("flare_ready"):  flare_count = mini(flare_count + 1, get_max_flare())
	if GlobalSave.has_skill("quiet_footstep"): _run_sound_mult *= 0.75
	# material_sense: 픽업 범위 + 시작 재료
	if GlobalSave.has_skill("material_sense"):
		_pickup_range_mult *= 1.5
		# 런 시작 시 랜덤 재료 1개 (GlobalSave 통해 World.gd에서 처리)
	# scavenge_memory: 픽업 범위
	if GlobalSave.has_skill("scavenge_memory"): _pickup_range_mult *= 1.4
	# sense_alert / visual_memory: _process에서 체크

	# ── 정신 기억 ──
	if GlobalSave.has_skill("fear_resist"): _fear_increase_mult -= 0.25
	if GlobalSave.has_skill("hide_master"): fear_reduction_in_box *= 1.5
	if GlobalSave.has_skill("iron_will"):   _fear_increase_mult -= 0.25
	# iron_will_2: fear 90+ 속도 패널티 제거 — _handle_fear_logic에서 체크
	if GlobalSave.has_skill("calm_mind"):   fear_reduction_rate += 8.0
	# adapt_memory / cold_focus / fear_surge: _handle_fear_logic에서 체크
	_fear_increase_mult = maxf(_fear_increase_mult, 0.1)

	# ── 자원 기억 ──
	# lantern_memory: lantern.gd에서 체크
	# craft_memory: GlobalSave.start_new_run 이후 World.gd에서 처리
	# carry_over: GlobalSave에서 처리
	# preserve_memory / waste_not: 각 사용 핸들러에서 체크

	# ── 행동 해금 능력 효과 ──
	if GlobalSave.get_ability_level("light_control") >= 1:
		_battery_drain_rate *= 0.80
	if GlobalSave.get_ability_level("shadow_instinct") >= 1:
		fear_reduction_in_box *= 1.50
	if GlobalSave.get_ability_level("fear_resist") >= 1:
		fear_reduction_rate += fear_reduction_rate * 0.20

	# ── 구매형 스킬 효과 ──
	if GlobalSave.has_skill("battery_save"):    _battery_drain_rate *= 0.75
	if GlobalSave.has_skill("mental_tough"):     fear_reduction_rate += fear_reduction_rate * 0.20
	if GlobalSave.has_skill("stealth_expert"):   fear_reduction_in_box *= 1.50

	# ── 런 버프 (F 시스템) ──
	if GlobalSave.has_run_buff("stamina_cost"):  _dodge_stamina_mult *= 0.80
	if GlobalSave.has_run_buff("battery_drain"): _battery_drain_rate *= 0.70
	if GlobalSave.has_run_buff("fear_gain"):     _fear_increase_mult *= 0.75

	# 신호탄 최대치: flame_sense lv1/lv2 각 +1, 제작 업그레이드 반영
	flare_count = mini(flare_count, get_max_flare())

	# 이월 아이템 수령 (carry_over 스킬 보유 시)
	if GlobalSave.has_skill("carry_over"):
		var carried = GlobalSave.get_carried_item()
		if carried != 0 and slot1_item == 0:
			slot1_item = carried
			GlobalSave.clear_carried_item()

# =====================
# 메인 루프
# =====================
func _physics_process(delta):
	if _is_paused: return
	if not is_alive: return
	_survival_time += delta
	_assassination_boost_timer = max(0.0, _assassination_boost_timer - delta)
	_enemy_cache_timer -= delta
	if _enemy_cache_timer <= 0.0:
		_cached_enemies = get_tree().get_nodes_in_group("enemy")
		_enemy_cache_timer = 0.25
	if _dodge_pressed:
		_dodge_pressed = false
		_try_dodge()
	_update_boss_stamina_shield()
	_handle_movement(delta)
	_handle_dodge(delta)
	_handle_collapse(delta)
	_handle_fear_logic(delta)
	_update_adrenaline(delta)
	_update_enhanced_flashlight(delta)
	_update_ui()
	_update_heartbeat()
	_update_breathing()
	move_and_slide()

func _process(delta):
	if _is_paused: return
	if not is_alive: return
	_handle_flashlight(delta)
	_handle_assassination()
	_handle_item_use()
	_update_glitch_effect()
	_track_observations(delta)
	_update_danger_overlay(delta)
	_update_dev_reset(delta)
	_check_monologue_triggers(delta)
	_update_minimap()

func _update_danger_overlay(_delta):
	pass  # _trigger_fear_pulse() 의 tween이 직접 관리

func _trigger_fear_pulse() -> void:
	if not _danger_overlay: return
	_danger_overlay.color = Color(0.85, 0.0, 0.0, 0.0)
	var tw = create_tween()
	tw.tween_property(_danger_overlay, "color:a", 0.55, 0.08)
	tw.tween_property(_danger_overlay, "color:a", 0.0,  0.60)

func _update_dev_reset(delta):
	# 키 힌트 토글
	if _dev_key_hints:
		_dev_key_hints.visible = dev_mode

	# 토스트 타이머
	if _dev_toast_timer > 0.0:
		_dev_toast_timer -= delta
		if _dev_toast_timer <= 0.0 and _dev_toast_label:
			_dev_toast_label.visible = false

	if not dev_mode or _dev_reset_mode == "":
		if _dev_reset_bar: _dev_reset_bar.visible = false
		return

	# 홀드 진행
	_dev_reset_timer += delta
	var progress = min(_dev_reset_timer / _DEV_RESET_HOLD, 1.0)

	if _dev_reset_fill:
		_dev_reset_fill.set_anchor_and_offset(SIDE_RIGHT, progress, 0.0)

	if _dev_reset_label:
		var mode_text = {"memory": "기억 초기화", "all": "전체 초기화", "run": "런 초기화"}
		_dev_reset_label.text = "[DEV] %s 중...  %.1fs" % [mode_text.get(_dev_reset_mode, ""), _dev_reset_timer]

	if _dev_reset_bar: _dev_reset_bar.visible = true

	if _dev_reset_timer >= _DEV_RESET_HOLD:
		_execute_dev_reset(_dev_reset_mode)
		_dev_reset_mode  = ""
		_dev_reset_timer = 0.0

func _execute_dev_reset(mode: String) -> void:
	# 발동 플래시
	modulate = Color(2.0, 2.0, 2.0)
	await get_tree().create_timer(0.08).timeout
	modulate = Color(1.0, 1.0, 1.0)

	var toast_text := ""
	match mode:
		"memory":
			GlobalSave.reset_memories()
			toast_text = "[DEV] 기억 초기화 완료  (조각 0/12 · 핵심 0/5)"
			var world = get_tree().get_first_node_in_group("world_root")
			if world and world.has_method("respawn_memory_items"):
				world.respawn_memory_items()
		"all":
			GlobalSave.reset_all()
			toast_text = "[DEV] 전체 저장 초기화 완료 — 씬 재로드"
			await get_tree().create_timer(0.5).timeout
			get_tree().change_scene_to_file("res://scenes/World.tscn")
			return
		"run":
			GlobalSave.reset_run()
			toast_text = "[DEV] 런 초기화 완료"

	if _dev_toast_label:
		_dev_toast_label.text    = toast_text
		_dev_toast_label.visible = true
	_dev_toast_timer = 2.5

func _close_lore_popup() -> void:
	for node in get_tree().get_nodes_in_group("lore_popup"):
		if is_instance_valid(node):
			if node.has_meta("close_fn"):
				node.get_meta("close_fn").call()
			else:
				node.queue_free()

func _input(event):
	if not is_alive: return

	# M키: 미니맵 토글
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M or event.keycode == KEY_M:
			if _minimap_panel:
				_minimap_panel.visible = not _minimap_panel.visible
			get_viewport().set_input_as_handled()
			return

	# lore 팝업 E키 닫기 (최우선)
	var lore_open = get_tree().get_nodes_in_group("lore_popup").size() > 0
	if lore_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_E or event.keycode == KEY_E:
				_close_lore_popup()
				get_viewport().set_input_as_handled()
				return
		# 마우스 클릭은 버튼에게 전달 (set_input_as_handled 생략)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_paused or _codex_open or _bag_open:
			return
		var ct = get_tree().get_first_node_in_group("crafting_table")
		if ct and ct.get("_ui_open") == true:
			return
		var kp = get_tree().get_first_node_in_group("key_pickup")
		if kp and kp.get("_keypad_open") == true:
			return
		if not is_hidden_state:
			_use_flare()
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2 or event.physical_keycode == KEY_F2:
			dev_mode = not dev_mode
			if _dev_mode_label: _dev_mode_label.visible = dev_mode
			if dev_mode:
				GlobalSave.data["total_kp"] = 9999
				for mt in [8, 9, 10, 11, 12, 13]:
					material_inventory[mt] = 99
				_update_material_ui()
			get_viewport().set_input_as_handled()
			return
		# DEV 초기화 홀드: R / Ctrl+R / Shift+R
		if dev_mode and (event.keycode == KEY_R or event.physical_keycode == KEY_R):
			if event.shift_pressed:
				_dev_reset_mode = "all"
			elif event.ctrl_pressed:
				_dev_reset_mode = "run"
			else:
				_dev_reset_mode = "memory"
			_dev_reset_timer = 0.0
			get_viewport().set_input_as_handled()
			return
	# R 키를 놓으면 홀드 취소
	if event is InputEventKey and not event.pressed:
		if (event.keycode == KEY_R or event.physical_keycode == KEY_R) and _dev_reset_mode != "":
			_dev_reset_mode  = ""
			_dev_reset_timer = 0.0
			get_viewport().set_input_as_handled()
			return
	if not is_alive: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_CTRL or event.physical_keycode == KEY_CTRL:
			if can_sneak:
				is_sneaking = not is_sneaking
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			if can_dodge:
				_dodge_pressed = true
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B or event.physical_keycode == KEY_B:
			_toggle_bag()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			_toggle_codex()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			if _is_paused:
				_resume_game()
				get_viewport().set_input_as_handled()
			elif _codex_open:
				_toggle_codex()
				get_viewport().set_input_as_handled()
			elif _bag_open:
				_toggle_bag()
				get_viewport().set_input_as_handled()
			elif is_alive and not _is_knocked_down \
					and get_tree().get_nodes_in_group("lore_popup").is_empty():
				_pause_game()
				get_viewport().set_input_as_handled()

# =====================
# 화면 효과
# =====================
func _update_glitch_effect():
	var boss_dist = 9999.0
	var boss_attacking = false

	for boss in get_tree().get_nodes_in_group("boss"):
		var d = global_position.distance_to(boss.global_position)
		if d < boss_dist:
			boss_dist = d
		if "is_attacking" in boss and boss.is_attacking:
			boss_attacking = true

	var intensity: float
	if boss_attacking:
		intensity = remap(current_fear, 0, max_fear, 0.6, 1.0)
		_shake_screen(boss_dist, 7.0)
	elif boss_dist < 500:
		intensity = remap(current_fear, 0, max_fear, 0.0, 0.15) \
				  + remap(clamp(boss_dist, 0, 500), 0, 500, 0.08, 0.0)
		_shake_screen(boss_dist, 4.0)
	else:
		intensity = remap(current_fear, 0, max_fear, 0.0, 0.1)

	# 탈진 시 글리치 추가
	if _is_collapsing:
		var collapse_ratio = 1.0 - clamp(_exhaust_death_timer / EXHAUST_DEATH_DURATION, 0.0, 1.0)
		intensity += remap(collapse_ratio, 0.0, 1.0, 0.05, 0.30)

	var glitch_rect = get_tree().root.find_child("GlitchRect", true, false)
	if glitch_rect and glitch_rect.material:
		glitch_rect.material.set_shader_parameter("intensity", intensity)

func _shake_screen(dist: float, max_force: float = 10.0):
	var shake_force = remap(clamp(dist, 0, 500), 0, 500, max_force, 0.0)
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.offset = Vector2(randf_range(-shake_force, shake_force), randf_range(-shake_force, shake_force))

func _show_kp_gain(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70, 1.0))
	lbl.z_index = 120
	$CanvasLayer/Control.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.offset_top    = -160
	lbl.offset_bottom = -130
	lbl.offset_left   = -120
	lbl.offset_right  =  120
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 30, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.finished.connect(lbl.queue_free)

func _on_ability_unlocked(ability_id: String) -> void:
	_show_ability_unlock_popup(ability_id)

func _show_ability_unlock_popup(ability_id: String) -> void:
	var ability_name = GlobalSave.ABILITY_NAMES.get(ability_id, ability_id)
	var ctrl = $CanvasLayer/Control
	if not ctrl: return

	var panel = PanelContainer.new()
	panel.z_index = 150
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -160)
	panel.set_offset(SIDE_RIGHT,   160)
	panel.set_offset(SIDE_TOP,    -52)
	panel.set_offset(SIDE_BOTTOM,  52)
	ctrl.add_child(panel)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var header = Label.new()
	header.text = "★  능력 해금!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	vb.add_child(header)

	var name_lbl = Label.new()
	name_lbl.text = ability_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vb.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "메인 메뉴에서 강화 가능"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vb.add_child(sub_lbl)

	panel.modulate.a = 0.0
	var tw = panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.8)
	tw.tween_property(panel, "modulate:a", 0.0, 0.55)
	tw.tween_callback(panel.queue_free)

# =====================
# 이동
# =====================
func _handle_movement(delta):
	if _roar_lock_timer > 0.0:
		_roar_lock_timer -= delta
		velocity = Vector2.ZERO
		return
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity = _knockback_vel
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 1800.0 * delta)
		return
	if is_hidden_state:
		velocity = Vector2.ZERO
		return

	# 회피 중: 방향 고정, 조작 불가
	if _is_dodging:
		if is_alive: look_at(get_global_mouse_position())
		velocity = _dodge_vel
		return

	# 보스 피격 넉백
	if _boss_knockback_timer > 0:
		if is_alive: look_at(get_global_mouse_position())
		velocity = _boss_knockback_vel
		return

	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if is_alive:
		look_at(get_global_mouse_position())

	# 달리기 시 은신 자동 해제
	var running = Input.is_action_pressed("shift") and dir != Vector2.ZERO and not is_exhausted
	if running and is_sneaking:
		is_sneaking = false

	var dodge_boost = DODGE_PERFECT_SPEED_MULT if _dodge_speed_buff_timer > 0 else 1.0
	var boost = max(ASSASSINATION_SPEED_MULT if _assassination_boost_timer > 0 else 1.0, dodge_boost)
	var boss_spd = 0.82 if _stamina_shield_active else 1.0
	var dev_spd  = 1.8  if dev_mode               else 1.0
	var escape_boost = 1.20 if _escape_boost_timer > 0.0 else 1.0
	var cold_focus_boost = 1.0
	if GlobalSave.has_skill("cold_focus") and is_sneaking and current_fear <= 50.0:
		cold_focus_boost = 1.10
	var spd_mult = (SHIELD_SPEED_MULT if shield_active else 1.0) * boss_spd * boost * dev_spd * _fear_speed_mult * escape_boost * cold_focus_boost
	var speed: float

	# 알파 아우라 — 매 프레임 리셋 (알파가 범위 안에 있으면 brood.gd가 덮어씀)
	_alpha_stamina_pressure = 1.0

	if is_sneaking:
		speed = _effective_sneak_speed * spd_mult
		current_stamina += 20.0 * _alpha_stamina_pressure * delta
	elif running:
		speed = run_speed * spd_mult
		if not dev_mode:
			current_stamina -= _stamina_drain_rate * delta
			if current_stamina < max_stamina * 0.3:
				show_hint("exhaust", "스태미나 부족 — 계속 달리면 탈진, 잠시 걸어서 회복")
			if current_stamina <= 0:
				current_stamina = 0.0
				is_exhausted = true
				if not _is_collapsing and not adrenaline_active:
					_is_collapsing = true
					_exhaust_death_timer = EXHAUST_DEATH_DURATION
	elif is_exhausted:
		speed = tired_speed * spd_mult
		if not _is_collapsing:
			current_stamina += 20.0 * _alpha_stamina_pressure * delta
	else:
		speed = walk_speed * spd_mult
		if not _is_collapsing:
			current_stamina += 30.0 * _alpha_stamina_pressure * delta

	if dev_mode:
		current_stamina = max_stamina
		is_exhausted    = false
		_is_collapsing  = false
	current_stamina = clamp(current_stamina, 0, max_stamina)
	if is_exhausted and not _is_collapsing and current_stamina >= max_stamina * 0.2:
		is_exhausted = false

	# 탈진 상태면 속도 강제 제한
	if _is_collapsing:
		speed = COLLAPSE_SPEED

	velocity = dir * speed

	# 발소리 이벤트 (달리기 0.4s / 걷기 0.75s 간격, 은신 중 억제)
	if dir != Vector2.ZERO and not is_sneaking and not is_hidden_state:
		_sound_footstep_timer -= delta
		if _sound_footstep_timer <= 0.0:
			# breath_hold: 은신 정지 시 소리 무효
			var stationary = velocity.length() < 8.0
			if GlobalSave.has_skill("breath_hold") and is_sneaking and stationary:
				_sound_footstep_timer = 0.4
			elif running:
				_sound_footstep_timer = 0.4
				sound_emitted.emit(global_position, 0.45 * _run_sound_mult)
			else:
				_sound_footstep_timer = 0.75
				sound_emitted.emit(global_position, 0.20 * _run_sound_mult)
	else:
		_sound_footstep_timer = 0.0

	# 은신 중에는 발소리 없음
	if dir != Vector2.ZERO and not is_sneaking:
		if not footstep_sound.playing:
			footstep_sound.play()
		footstep_sound.pitch_scale = 1.3 if running else 1.0
	else:
		footstep_sound.stop()

# =====================
# 손전등
# =====================
func _handle_flashlight(delta):
	# 공포 95+: 지연된 손전등 입력 소화
	if _fear_flashlight_delay > 0.0:
		_fear_flashlight_delay -= delta
		if _fear_flashlight_delay <= 0.0 and _fear_flashlight_pending:
			_fear_flashlight_pending = false
			flashlight_on = !flashlight_on
			_play_sfx(sfx_flashlight_on if flashlight_on else sfx_flashlight_off)
			sound_emitted.emit(global_position, 0.65)

	if Input.is_action_just_pressed("flashlight_toggle") and _fear_flashlight_delay <= 0.0:
		if current_fear >= 95.0 and not dev_mode:
			# 손이 떨린다 — 0.35초 후 실행
			_fear_flashlight_delay   = 0.35
			_fear_flashlight_pending = true
		else:
			flashlight_on = !flashlight_on
			_play_sfx(sfx_flashlight_on if flashlight_on else sfx_flashlight_off)
			sound_emitted.emit(global_position, 0.65)  # 토글 클릭음 → 청각 탐지

	if flashlight_on and (current_battery > 0 or dev_mode):
		light_node.enabled = true
		if _flashlight_cone: _flashlight_cone.visible = true
		if not dev_mode:
			current_battery -= _battery_drain_rate * delta
	else:
		light_node.enabled = false
		if _flashlight_cone: _flashlight_cone.visible = false
		if current_battery <= 0 and not dev_mode: flashlight_on = false
	current_battery = clamp(current_battery, 0, max_battery)

	if current_battery < 20.0 and not _battery_low_warned:
		_battery_low_warned = true
		_play_sfx(sfx_battery_low)
	elif current_battery >= 20.0:
		_battery_low_warned = false

	# battery_warning: 5초 전(배터리 12.5 기준)부터 깜빡임
	if GlobalSave.has_skill("battery_warning") and flashlight_on and current_battery < 12.5 and current_battery > 0.0:
		_battery_warn_flicker += get_physics_process_delta_time()
		if _battery_warn_flicker >= 0.35:
			_battery_warn_flicker = 0.0
			light_node.enabled = !light_node.enabled
	else:
		_battery_warn_flicker = 0.0

# 가까울수록 공포가 쌓인다. 상자 안에 숨으면 빠르게 가라앉는다. 100이 되면 몸이 말을 듣지 않는다.
func _handle_fear_logic(delta):
	if dev_mode:
		current_fear = 0.0
		return
	if is_in_safe_zone:
		current_fear = max(0.0, current_fear - 20.0 * delta)
		return
	var enemy_nearby = false
	var chase_active = false
	var distance_to_enemy = 9999.0
	var nearest_enemy: Node = null

	for enemy in _cached_enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < distance_to_enemy:
				distance_to_enemy = dist
				nearest_enemy = enemy
			if dist < 200.0:
				enemy_nearby = true
			if "current_state" in enemy:
				if str(enemy.current_state) == "1" or enemy.current_state == 1:
					if dist < 350.0:
						chase_active = true

	# 처치 감지: 지난 프레임에 350px 내 있던 적이 무효화 → 처치로 판정, 공포 즉시 감소
	for old_enemy in _fear_nearby_enemies:
		if not is_instance_valid(old_enemy):
			reduce_fear_burst(15.0)
	_fear_nearby_enemies.clear()
	for enemy in _cached_enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < 350.0:
			_fear_nearby_enemies.append(enemy)

	# 적 첫 접근 힌트
	if enemy_nearby and not is_hidden_state:
		show_hint("enemy_near", "[ F ] 손전등 끄기   박스에 숨거나 멀리 도망쳐라")
	if chase_active and not is_hidden_state:
		show_hint("flashlight", "[ F ] 손전등 ON/OFF — 배터리 소모, 일부 적 반응")

	var fear_change = 0.0
	if is_hidden_state:
		fear_change = (-8.0 if enemy_nearby else -fear_reduction_in_box) * delta
	else:
		if chase_active:
			fear_change = remap(clamp(distance_to_enemy, 0, 350), 0, 350, 38.0, 15.0) * delta * _fear_increase_mult
		elif enemy_nearby:
			fear_change = remap(clamp(distance_to_enemy, 0, 200), 0, 200, 20.0, 5.0) * delta * _fear_increase_mult
		else:
			fear_change = (-12.0 if flashlight_on else -fear_reduction_rate) * delta

	# 손전등 ON + 적 근처/추격 중: 볼 수 있다는 안도감으로 공포 증가 부분 상쇄
	if flashlight_on and not is_hidden_state and (chase_active or enemy_nearby):
		fear_change -= 5.0 * delta

	# 도감 Tier4: 해당 적을 완전 분석한 경우 공포 증가 15% 감소
	if fear_change > 0.0 and nearest_enemy != null:
		var etype = _get_enemy_type(nearest_enemy)
		if etype != "" and SpecimenDB.get_tier(etype + "_seen") >= 4:
			fear_change *= 0.85

	# 광원 조절 lv2: 손전등 ON + 혼자일 때 공포 감소 추가
	if flashlight_on and not is_hidden_state and not chase_active and not enemy_nearby:
		if GlobalSave.get_ability_level("light_control") >= 2:
			fear_change -= fear_reduction_rate * delta

	current_fear = clamp(current_fear + fear_change, 0, max_fear)

	# 공포 90+: 이동속도 패널티 (iron_will_2 / fear_endurance lv2 / dev_mode 시 면제)
	var endurance_lv: int = GlobalSave.get_ability_level("fear_endurance")
	if endurance_lv >= 2 or GlobalSave.has_skill("iron_will_2") or dev_mode:
		_fear_speed_mult = 1.0
	elif current_fear >= 90.0:
		_fear_speed_mult = remap(current_fear, 90.0, 100.0, 1.0, 0.75)
	else:
		_fear_speed_mult = 1.0

	# adapt_memory: GlobalSave 사망 횟수 기반 공포 감소
	if GlobalSave.has_skill("adapt_memory") and nearest_enemy != null:
		var etype = _get_enemy_type(nearest_enemy)
		if etype != "":
			var death_n = GlobalSave.get_death_count(etype + "_seen")
			if death_n >= 3:
				var adapt_mult = max(0.7, 1.0 - (death_n / 3) * 0.10)
				fear_change = minf(fear_change, fear_change * adapt_mult)

	# cold_focus: 공포 50 이하에서 은신 속도 보너스 (이동 처리에서 참조)
	# fear_surge: 공포 90+ 시 자동 아드레날린 (런당 1회)
	if GlobalSave.has_skill("fear_surge") and current_fear >= 90.0 and not _fear_surge_used and not dev_mode:
		_fear_surge_used = true
		_use_adrenaline_instant()

	# escape_instinct / sense_alert: 추격 시작 감지
	if chase_active and not _was_chasing:
		if GlobalSave.has_skill("escape_instinct"):
			_escape_boost_timer = 3.0
		if GlobalSave.has_skill("sense_alert"):
			_play_sfx_oneshot(load("res://assets/feer.mp3"), -12.0)
	_was_chasing = chase_active

	# escape_instinct 부스트 타이머 차감
	if _escape_boost_timer > 0.0:
		_escape_boost_timer -= delta

	# 공포 100 도달 순간: 화면 붉은 펄스 + 긴급 스태미나 (런당 1회)
	if current_fear >= max_fear and not _fear_was_100:
		_fear_was_100 = true
		_trigger_fear_pulse()
		if not _fear_stamina_burst_used:
			_fear_stamina_burst_used = true
			current_stamina = minf(current_stamina + 20.0, max_stamina)
			if _is_collapsing and current_stamina >= COLLAPSE_RECOVERY_THRESHOLD:
				_is_collapsing = false
				is_exhausted = false
				_exhaust_death_timer = 0.0
	elif current_fear < max_fear:
		_fear_was_100 = false
	if current_fear < 70.0:
		_fear_stamina_burst_used = false

	# 전등 반경 안 → 추가 공포 감소 (-8/s)
	if not is_hidden_state:
		for lantern in get_tree().get_nodes_in_group("lantern"):
			if is_instance_valid(lantern) and global_position.distance_to(lantern.global_position) < 256.0:
				current_fear = max(0.0, current_fear - 8.0 * delta)
				break

	# ── 공포 내성 추적 (E 시스템) ─────────────────
	if current_fear >= max_fear:
		_fear_endurance_timer += delta
		if _fear_endurance_timer >= 5.0 and not _fear_endured:
			_fear_endured = true
			var kp_gained = GlobalSave.record_fear_endurance()
			_show_kp_gain("+%d KP  공포 내성" % kp_gained)
	else:
		if _fear_endurance_timer > 0.0 and _fear_endurance_timer < 5.0:
			_fear_endured = false  # 5초 못 채우면 리셋
		_fear_endurance_timer = 0.0

	# 공포 내성 lv2: 공포 100%에서 이동속도 패널티 없음 (이동 처리에서 참조)
	# 공포 내성 lv3: 공포 100%에서 스태미나 정상화 (스태미나 처리에서 참조)

# =====================
# 탈진 → 사망 타이머
# =====================
func _handle_collapse(delta):
	if not _is_collapsing: return
	_exhaust_death_timer -= delta
	var still = velocity.length() < 5.0
	var regen = COLLAPSE_REGEN_STILL if still else COLLAPSE_REGEN_MOVING
	if GlobalSave.has_skill("recovery_instinct") and still:
		regen *= 2.0
	current_stamina = min(current_stamina + regen * delta, max_stamina)
	if current_stamina >= COLLAPSE_RECOVERY_THRESHOLD:
		_is_collapsing = false
		is_exhausted = false
		_exhaust_death_timer = 0.0
		return
	if _exhaust_death_timer <= 0.0:
		killer_name = "탈진"
		take_damage()

# =====================
# 회피
# =====================
func _try_dodge():
	if _is_dodging or _dodge_cooldown > 0: return
	if is_hidden_state or _is_collapsing: return
	if current_stamina < DODGE_STAMINA_COST * _dodge_stamina_mult: return

	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = -Vector2.RIGHT.rotated(rotation)  # 입력 없으면 후방 회피

	_is_dodging = true
	_dodge_timer = DODGE_DURATION
	_dodge_vel = dir.normalized() * (DODGE_DISTANCE / DODGE_DURATION)
	_dodge_invincible_timer = DODGE_INVINCIBLE_TIME
	_dodge_just_activated_timer = _effective_dodge_perfect_window
	_dodge_cooldown = DODGE_COOLDOWN
	current_stamina -= DODGE_STAMINA_COST * _dodge_stamina_mult
	is_sneaking = false
	sound_emitted.emit(global_position, 0.55)

func _handle_dodge(delta):
	_dodge_cooldown = max(0.0, _dodge_cooldown - delta)
	_dodge_invincible_timer = max(0.0, _dodge_invincible_timer - delta)
	_dodge_just_activated_timer = max(0.0, _dodge_just_activated_timer - delta)
	_dodge_speed_buff_timer = max(0.0, _dodge_speed_buff_timer - delta)
	_boss_knockback_timer = max(0.0, _boss_knockback_timer - delta)

	if not _is_dodging: return
	_dodge_timer -= delta
	_spawn_dodge_trail()
	if _dodge_timer <= 0.0:
		_is_dodging = false
		_dodge_vel = Vector2.ZERO

func _apply_perfect_dodge_reward():
	current_stamina = min(current_stamina + DODGE_PERFECT_STAMINA, max_stamina)
	_dodge_speed_buff_timer = DODGE_PERFECT_SPEED_DURATION
	_show_perfect()
	# 가장 가까운 적 경직
	var nearest: Node = null
	var nearest_dist = 120.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		var d = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest and nearest.has_method("receive_shield_block"):
		nearest.receive_shield_block(global_position)

func _show_perfect():
	if not _perfect_label: return
	_perfect_label.text = "PERFECT!"
	_perfect_label.modulate.a = 1.0
	_perfect_label.scale = Vector2(1.4, 1.4)
	_perfect_label.visible = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_perfect_label, "scale", Vector2(1.0, 1.0), 0.18)
	tween.tween_property(_perfect_label, "modulate:a", 0.0, 0.45).set_delay(0.25)
	tween.tween_callback(func(): _perfect_label.visible = false).set_delay(0.7)
	_shake_screen(0.0, 8.0)

func _spawn_dodge_trail():
	var trail = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(12):
		var a = (2.0 * PI * i) / 12.0
		pts.append(Vector2(cos(a) * 22.0, sin(a) * 22.0))
	trail.polygon = pts
	trail.color = Color(0.85, 0.90, 1.0, 0.45)
	trail.global_position = global_position
	trail.rotation = rotation
	trail.z_index = z_index - 1
	get_parent().add_child(trail)
	var tween = trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.22)
	tween.tween_callback(trail.queue_free)

# =====================
# 보스 스테미나 실드
# =====================
func activate_boss_shield():
	if _stamina_shield_initialized: return
	_stamina_shield_initialized = true
	_stamina_shield_active = true
	max_stamina = 105.0   # 35 × 3 = 칸 3개
	current_stamina = min(current_stamina, max_stamina)
	_boss_shield_hit_cooldown = 0.0

func clear_boss_shield(keep_one: bool) -> void:
	if not _stamina_shield_active: return
	if keep_one:
		max_stamina     = 35.0
		current_stamina = 35.0
	else:
		_stamina_shield_active = false
		max_stamina     = 100.0
		current_stamina = min(current_stamina, 100.0)

func apply_knockback(dir: Vector2, force: float) -> void:
	_knockback_vel = dir * force
	_knockback_timer = 0.35

func apply_roar_effect(duration: float) -> void:
	current_fear = min(current_fear + 35.0, max_fear)
	_roar_lock_timer = duration
	if _stamina_shield_active:
		_apply_boss_stamina_hit()

func _update_boss_stamina_shield():
	var dt = get_physics_process_delta_time()
	if _boss_shield_hit_cooldown > 0.0:
		_boss_shield_hit_cooldown -= dt

	# 보스가 죽으면 실드 자동 해제
	if _stamina_shield_initialized and get_tree().get_nodes_in_group("boss").size() == 0:
		_stamina_shield_initialized = false
		_stamina_shield_active = false
		max_stamina = 100.0
		_shield_regen_timer = 0.0
		return

	# 실드 회복: 스태미나 풀 + 정지 2초 → 1칸 회복
	if _stamina_shield_active and max_stamina < SHIELD_MAX_STAMINA:
		var stamina_full = current_stamina >= max_stamina - 0.5
		var standing_still = velocity.length() < 5.0
		if stamina_full and standing_still:
			_shield_regen_timer += dt
			if _shield_regen_timer >= SHIELD_REGEN_TIME:
				_shield_regen_timer = 0.0
				max_stamina = minf(max_stamina + 35.0, SHIELD_MAX_STAMINA)
				modulate = Color(0.55, 0.85, 1.0, 1.0)
				var tw = create_tween()
				tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)
		else:
			_shield_regen_timer = 0.0

func _apply_boss_stamina_hit():
	if dev_mode: return
	max_stamina = max(max_stamina - 35.0, 0.0)
	current_stamina = min(current_stamina, max_stamina)
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		var dir = (global_position - boss.global_position).normalized()
		var kb_speed = 520.0
		if GlobalSave.has_skill("impact_memory"):
			# 방향 제어 유지: 넉백 거리 절반, 회전 없음
			kb_speed = 260.0
		_boss_knockback_vel = dir * kb_speed
		_boss_knockback_timer = 0.35
	modulate = Color(2.5, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)
	_shake_screen(0.0, 22.0)
	if max_stamina <= 0.0:
		is_alive = false
		_die()

# =====================
# 심장박동
# =====================
func _update_heartbeat():
	if sfx_heartbeat == null: return
	if current_fear >= 50.0:
		if not _heartbeat_player.playing:
			_heartbeat_player.stream = sfx_heartbeat
			_heartbeat_player.play()
		_heartbeat_player.pitch_scale = remap(current_fear, 50.0, max_fear, 0.8, 1.6)
		_heartbeat_player.volume_db   = remap(current_fear, 50.0, max_fear, -10.0, 0.0)
	else:
		if _heartbeat_player.playing:
			_heartbeat_player.stop()

func _on_heartbeat_finished():
	if current_fear >= 50.0 and sfx_heartbeat:
		_heartbeat_player.play()

func _update_breathing() -> void:
	var threshold = max_stamina * 0.5
	if current_stamina < threshold:
		if not _breathing_player.playing:
			_breathing_player.play()
		_breathing_player.pitch_scale = remap(current_stamina, threshold, 0.0, 1.0, 1.9)
		_breathing_player.volume_db   = remap(current_stamina, threshold, 0.0, -8.0, 0.0)
	else:
		if _breathing_player.playing:
			_breathing_player.stop()

func _on_breathing_finished() -> void:
	if current_stamina < max_stamina * 0.5:
		_breathing_player.play()

# =====================
# UI
# =====================
func _setup_bar_styles():
	_fear_style = StyleBoxFlat.new()
	_fear_style.bg_color = COLOR_FEAR_NORMAL
	if fear_bar: fear_bar.add_theme_stylebox_override("fill", _fear_style)

	_stamina_style = StyleBoxFlat.new()
	_stamina_style.bg_color = COLOR_STAMINA_NORMAL
	if stamina_bar: stamina_bar.add_theme_stylebox_override("fill", _stamina_style)

	_battery_style = StyleBoxFlat.new()
	_battery_style.bg_color = COLOR_BATTERY_NORMAL
	if battery_bar: battery_bar.add_theme_stylebox_override("fill", _battery_style)

func _update_ui():
	if stamina_bar:
		stamina_bar.max_value = 100.0   # 항상 원본 최대치 기준으로 표시
		stamina_bar.value = current_stamina
	if battery_bar:
		battery_bar.value = current_battery
	if fear_bar:
		fear_bar.value = current_fear
		if left_bars:
			var shake = remap(current_fear, 80.0, 100.0, 2.0, 6.0) if current_fear > 80 else 0.0
			left_bars.position = _left_bars_orig_pos + Vector2(
				randf_range(-shake, shake), randf_range(-shake, shake))

	# 위험 색상 갱신
	if _fear_style:
		_fear_style.bg_color = COLOR_DANGER if current_fear > max_fear * 0.70 else COLOR_FEAR_NORMAL
	if _stamina_style:
		if _is_collapsing:
			var blink_on = (Time.get_ticks_msec() % 300) < 150
			_stamina_style.bg_color = COLOR_DANGER if blink_on else Color(0.15, 0.0, 0.0)
		else:
			_stamina_style.bg_color = COLOR_DANGER if current_stamina < max_stamina * 0.25 else COLOR_STAMINA_NORMAL
	if _battery_style:
		_battery_style.bg_color = COLOR_DANGER if current_battery < max_battery * 0.20 else COLOR_BATTERY_NORMAL

	# 탈진 카운트다운 표시
	if _collapse_label:
		if _is_collapsing:
			_collapse_label.visible = true
			var blink_on = (Time.get_ticks_msec() % 400) < 200
			var hint = "멈춰!" if velocity.length() > 5.0 else "회복 중..."
			_collapse_label.text = "탈진!  %.1f   %s" % [max(_exhaust_death_timer, 0.0), hint]
			_collapse_label.modulate.a = 1.0 if blink_on else 0.5
		else:
			_collapse_label.visible = false

	if hp_bar:
		if current_hp > 0:
			hp_bar.text = "♥" + ("\n[방패]" if shield_active else "")
		else:
			hp_bar.text = ""

	if timer_label:
		var total = int(_survival_time)
		timer_label.text = "%02d:%02d" % [total / 60, total % 60]

	if _dodge_cooldown_label:
		if not can_dodge:
			_dodge_cooldown_label.text = ""
		elif _dodge_cooldown > 0:
			_dodge_cooldown_label.text = "회피 재충전  %.1fs" % _dodge_cooldown
			_dodge_cooldown_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
		elif current_stamina < DODGE_STAMINA_COST * _dodge_stamina_mult:
			_dodge_cooldown_label.text = "회피 [SPACE]  스테미나 부족"
			_dodge_cooldown_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
		else:
			_dodge_cooldown_label.text = "회피 [SPACE]  준비됨"
			_dodge_cooldown_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))

	if _boss_shield_label:
		if _stamina_shield_active:
			_boss_shield_label.visible = true
			var hits_left = int(max_stamina / 35.0)
			var dots = "●".repeat(hits_left) + "○".repeat(max(0, 3 - hits_left))
			if max_stamina < SHIELD_MAX_STAMINA and _shield_regen_timer > 0.0:
				var pct = int(_shield_regen_timer / SHIELD_REGEN_TIME * 100.0)
				_boss_shield_label.text = "보스전  실드 %s  회복 %d%%" % [dots, pct]
				_boss_shield_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
			else:
				_boss_shield_label.text = "보스전  실드 " + dots
				_boss_shield_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			_boss_shield_label.visible = false

	if sneak_label:
		if can_sneak and is_sneaking:
			if can_assassinate and _has_assassination_target():
				sneak_label.text = "[ E ] 암살"
				sneak_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				sneak_label.text = "[ 은신 중 ]"
				sneak_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
			sneak_label.visible = true
		else:
			sneak_label.visible = false

# =====================
# 은신 / 암살
# =====================
func _has_assassination_target() -> bool:
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist >= _effective_assassination_range: continue
		var enemy_fwd = Vector2.RIGHT.rotated(enemy.rotation)
		var to_player = (global_position - enemy.global_position).normalized()
		if enemy_fwd.dot(to_player) < -0.30:
			return true
	return false

func _handle_assassination():
	if not can_assassinate: return
	if not Input.is_action_just_pressed("interact"): return
	if not is_sneaking: return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist >= _effective_assassination_range: continue
		var enemy_fwd = Vector2.RIGHT.rotated(enemy.rotation)
		var to_player = (global_position - enemy.global_position).normalized()
		if enemy_fwd.dot(to_player) >= -0.30: continue
		_execute_assassination(enemy)
		return

func _execute_assassination(enemy):
	enemy.remove_from_group("enemy")
	if enemy.is_in_group("boss"): enemy.remove_from_group("boss")
	enemy.set_physics_process(false)
	var shape = enemy.get_node_or_null("CollisionShape2D")
	if shape: shape.set_deferred("disabled", true)

	var tween = enemy.create_tween().set_parallel(true)
	tween.tween_property(enemy, "modulate", Color(2.5, 0.0, 0.0, 0.0), 0.40)
	tween.tween_property(enemy, "scale", Vector2.ZERO, 0.40).set_ease(Tween.EASE_IN)
	tween.finished.connect(enemy.queue_free)

	var stamina_return = 0.20 + (0.10 if GlobalSave.has_skill("assassin_stamina") else 0.0)
	current_stamina = min(current_stamina + max_stamina * stamina_return, max_stamina)
	reduce_fear_burst(30.0)
	_assassination_boost_timer = ASSASSINATION_BOOST_DURATION
	is_exhausted = false
	is_sneaking = false
	_shake_screen(0.0, 12.0)
	var kp_gain = 5 + (5 if GlobalSave.has_skill("assassin_kp") else 0)
	GlobalSave.add_kp(kp_gain)
	_show_kp_gain("+%d p  암살" % kp_gain)

func reduce_fear_burst(amount: float) -> void:
	var reduction = amount if current_fear >= 20.0 else amount * 0.5
	current_fear = maxf(0.0, current_fear - reduction)

# 한 번 잡히면 끝이다.
func take_damage():
	if not is_alive: return
	if _is_knocked_down: return
	if dev_mode: return
	# 회피 무적 프레임
	if _dodge_invincible_timer > 0:
		if _dodge_just_activated_timer > 0:
			_apply_perfect_dodge_reward()
		return
	# 보스 스테미나 실드 — 쿨타임 중이면 피해 차단만, 쿨타임 끝나면 1칸 소모
	if _stamina_shield_active:
		if _boss_shield_hit_cooldown <= 0.0:
			_apply_boss_stamina_hit()
			_boss_shield_hit_cooldown = 2.5
		return
	# 방패가 있으면 1회 방어
	if shield_active:
		_break_shield()
		return
	# 첫 번째 사망: 기절 후 기상
	if not GlobalSave.run_first_death_used:
		GlobalSave.run_first_death_used = true
		_knockdown()
		return
	is_alive = false
	_die()

func _die():
	velocity = Vector2.ZERO
	footstep_sound.stop()
	if _heartbeat_player.playing:  _heartbeat_player.stop()
	if _breathing_player.playing:  _breathing_player.stop()
	_play_sfx(sfx_death)

	# 생존 시간 / 사망 원인 저장
	GameState.is_new_record = GameState.best_time > 0 and _survival_time > GameState.best_time
	GameState.survival_time = _survival_time
	GameState.killer_name   = killer_name if killer_name != "" else "알 수 없음"
	if _survival_time > GameState.best_time:
		GameState.best_time = _survival_time
	# 도감 연결 ID 저장 — game_over.gd 힌트 표시에 사용
	const _KILLER_DB_MAP: Dictionary = {
		"Shade":           "shade_seen",
		"스토커":          "stalker_seen",
		"매복자":          "ambusher_seen",
		"파수꾼":          "sentinel_seen",
		"돌격병":          "charger_seen",
		"무리":            "brood_seen",
		"콜로서스":        "colossus_seen",
		"콜로서스 (폭발)": "colossus_seen",
		"전령":            "herald_seen",
	}
	GameState.killer_db_id = _KILLER_DB_MAP.get(killer_name, "")

	# carry_over: 사망 시 슬롯1 아이템 다음 런 이월
	if GlobalSave.has_skill("carry_over") and slot1_item != 0:
		GlobalSave.set_carried_item(slot1_item)

	# adapt_memory: 사망한 적 사망 횟수 누적
	var db_id = GameState.killer_db_id
	if db_id != "":
		GlobalSave.increment_death_count(db_id)

	# 카메라 흔들림 정지
	var camera = get_viewport().get_camera_2d()
	if camera: camera.offset = Vector2.ZERO

	# Phase 1: 빨간 섬광 (0.08초)
	modulate = Color(3.0, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.08).timeout

	# Phase 2: 회전하며 축소 + 페이드 (0.55초)
	var start_rot = rotation
	var death_tween = create_tween().set_parallel(true)
	death_tween.tween_property(self, "scale", Vector2.ZERO, 0.55).set_ease(Tween.EASE_IN)
	death_tween.tween_property(self, "rotation", start_rot + PI * 3.0, 0.55)
	death_tween.tween_property(self, "modulate", Color(1.0, 0.0, 0.0, 0.0), 0.45)
	await get_tree().create_timer(0.60).timeout

	# Phase 3: 검정 화면 페이드 인 (0.7초)
	if fade_overlay:
		var fade = create_tween()
		fade.tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.7)
	await get_tree().create_timer(3.35).timeout

	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _knockdown() -> void:
	_is_knocked_down = true
	is_hidden_state = true  # 기절 중 적 감지 차단
	velocity = Vector2.ZERO
	footstep_sound.stop()
	if _heartbeat_player.playing: _heartbeat_player.stop()
	if _breathing_player.playing: _breathing_player.stop()
	_play_sfx(sfx_death)

	# 즉시 모든 적 추격 중단
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("stop_chasing_forced"):
			enemy.stop_chasing_forced()

	# 빨간 섬광
	modulate = Color(3.0, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.08).timeout

	# 쓰러짐 — 회전 후 기울어짐 (즉사의 회전+소멸과 구분)
	var kd_tween = create_tween().set_parallel(true)
	kd_tween.tween_property(self, "rotation", deg_to_rad(85.0), 0.45).set_ease(Tween.EASE_OUT)
	kd_tween.tween_property(self, "modulate", Color(0.7, 0.15, 0.15, 1.0), 0.45)
	await get_tree().create_timer(0.55).timeout

	# 암전
	if fade_overlay:
		var fi = create_tween()
		fi.tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.7)
	await get_tree().create_timer(0.85).timeout

	# "...일어나야 한다" 텍스트
	var msg = Label.new()
	msg.text = "…일어나야 한다"
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	msg.modulate.a = 0.0
	msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer/Control.add_child(msg)
	var mt = msg.create_tween()
	mt.tween_property(msg, "modulate:a", 1.0, 0.7)
	mt.tween_interval(1.8)
	mt.tween_property(msg, "modulate:a", 0.0, 0.7)
	await get_tree().create_timer(3.4).timeout
	msg.queue_free()

	# 회복
	rotation = 0.0
	scale = Vector2(1.0, 1.0)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	current_fear = 60.0
	current_stamina = max_stamina
	killer_name = ""
	is_hidden_state = false
	_is_knocked_down = false

	# 페이드 복귀
	if fade_overlay:
		var fo = create_tween()
		fo.tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 1.0)

func _build_pause_ui() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.visible = false
	$CanvasLayer/Control.add_child(_pause_panel)

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.add_child(bg)

	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left  = -130
	box.offset_right =  130
	box.offset_top   = -105
	box.offset_bottom=  105
	box.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(box)

	var title = Label.new()
	title.text = "[ 일시정지 ]"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.55, 0.90, 0.60))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var btn_resume = Button.new()
	btn_resume.text = "게임 재개"
	btn_resume.add_theme_font_size_override("font_size", 16)
	btn_resume.pressed.connect(_resume_game)
	box.add_child(btn_resume)

	var btn_menu = Button.new()
	btn_menu.text = "메인 메뉴로"
	btn_menu.add_theme_font_size_override("font_size", 16)
	btn_menu.pressed.connect(func():
		_is_paused = false
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	box.add_child(btn_menu)

	var btn_quit = Button.new()
	btn_quit.text = "게임 종료"
	btn_quit.add_theme_font_size_override("font_size", 16)
	btn_quit.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	btn_quit.pressed.connect(func(): get_tree().quit())
	box.add_child(btn_quit)

	var hint = Label.new()
	hint.text = "[ ESC ] 재개"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func _pause_game() -> void:
	_is_paused = true
	get_tree().paused = true
	footstep_sound.stop()
	if is_instance_valid(_pause_panel):
		_pause_panel.visible = true

func _resume_game() -> void:
	_is_paused = false
	get_tree().paused = false
	if is_instance_valid(_pause_panel):
		_pause_panel.visible = false

## 적 공격 시작 시 호출 — 각 적의 어택 개시 시점에서 사용
func play_attack_sfx() -> void:
	if _sfx_zab: _play_sfx(_sfx_zab)

## 사망 원인 기록 — 적이 take_damage() 호출 직전에 사용
func note_attacker(attacker_name: String) -> void:
	killer_name = attacker_name

## 적 관찰 추적 (C 시스템) — 손전등으로 적 조준 시 누적
func _track_observations(delta: float) -> void:
	if not flashlight_on: return
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy): continue
		if not _is_enemy_in_flashlight(enemy): continue
		var etype = _get_enemy_type(enemy)
		if etype == "": continue
		var result = GlobalSave.add_observe_time(etype, delta)
		if result == "tier1":
			_show_kp_gain("[%s] 관찰 1단계" % etype)
		elif result == "tier2":
			_show_kp_gain("[%s] 관찰 2단계" % etype)
		elif result == "tier3":
			_show_kp_gain("[%s] 완전 파악! 능력 해금" % etype)

func _get_enemy_type(enemy: Node) -> String:
	var path = enemy.get_script().resource_path if enemy.get_script() else ""
	if "lurker" in path:   return "shade"
	if "stalker" in path:  return "stalker"
	if "colossus" in path: return "colossus"
	if "ambusher" in path: return "ambusher"
	if "charger" in path:  return "charger"
	if "sentinel" in path: return "sentinel"
	if "herald" in path:   return "herald"
	if "brood" in path:    return "brood"
	return ""

func _is_enemy_in_flashlight(enemy: Node) -> bool:
	var to_enemy = enemy.global_position - global_position
	var dist = to_enemy.length()
	if dist > 380.0: return false
	var fwd = Vector2.RIGHT.rotated(rotation)
	return fwd.dot(to_enemy.normalized()) >= cos(0.60)

# 콜로서스의 포효에 손전등이 꺼진다. 배터리도 10 소모된다.
func force_stop_flashlight():
	flashlight_on = false
	current_battery -= 10.0

# 무리가 후방에서 접근할 때 공포 직접 주입
func add_fear_from_brood(amount: float) -> void:
	if is_hidden_state: return
	current_fear = clamp(current_fear + amount * _fear_increase_mult, 0.0, max_fear)

# =====================
# 아이템 시스템
# =====================

## 아이템 픽업 (item.gd에서 호출)
func try_pickup_item(type: int) -> bool:
	# 재료 아이템은 별도 인벤토리로
	if type >= ItemType.WIRE and type <= ItemType.EXPLOSIVE:
		material_inventory[type] = material_inventory.get(type, 0) + 1
		_update_material_ui()
		return true
	if type == ItemType.FLARE:
		if flare_count >= get_max_flare(): return false
		flare_count += 1
		_update_flare_ui()
		GlobalSave.add_kp(2)
		_show_kp_gain("+2 p  신호탄")
		return true
	if slot1_item == ItemType.NONE:
		slot1_item = type
		_update_item_ui()
		GlobalSave.add_kp(2)
		_show_kp_gain("+2 p  아이템")
		if type == ItemType.MEMORY_SHARD and _sfx_memo:
			_play_sfx(_sfx_memo)
		show_hint("item_slot", "슬롯 아이템:  [ E ] 사용")
		if type == ItemType.FLARE:
			show_hint("flare", "[ 좌클릭 ] 신호탄 발사 — 소리와 빛으로 적 유인 가능")
		return true
	if slot2_item == ItemType.NONE:
		slot2_item = type
		_update_item_ui()
		GlobalSave.add_kp(2)
		_show_kp_gain("+2 p  아이템")
		show_hint("item_slot", "슬롯 아이템:  [ E ] 사용")
		if type == ItemType.FLARE:
			show_hint("flare", "[ 좌클릭 ] 신호탄 발사 — 소리와 빛으로 적 유인 가능")
		if type == ItemType.MEMORY_SHARD and _sfx_memo:
			_play_sfx(_sfx_memo)
		return true
	return false  # 슬롯이 꽉 차면 픽업 실패

## 아이템 사용 입력 (1번 슬롯: 숫자1 / 2번 슬롯: 숫자2)
func _handle_item_use():
	if Input.is_action_just_pressed("slot_1") and slot1_item != ItemType.NONE:
		_use_item(slot1_item)
		slot1_item = ItemType.NONE
		_update_item_ui()
	if Input.is_action_just_pressed("slot_2") and slot2_item != ItemType.NONE:
		_use_item(slot2_item)
		slot2_item = ItemType.NONE
		_update_item_ui()

func _use_item(type: int):
	match type:
		ItemType.ADRENALINE:          _use_adrenaline()
		ItemType.BATTERY:             _use_battery()
		ItemType.SHIELD:              _use_shield()
		ItemType.FLARE:               _use_flare()
		ItemType.ROCK:                _use_rock()
		ItemType.LANTERN:             _use_lantern()
		ItemType.MEMORY_SHARD:        _use_memory_shard()
		ItemType.NOISE_DEVICE:        _use_noise_device()
		ItemType.EMP_GRENADE:         _use_emp_grenade()
		ItemType.FEAR_SUPPRESSOR:     _use_fear_suppressor()
		ItemType.ENHANCED_FLASHLIGHT: _use_enhanced_flashlight()

# fear_surge용: 인벤 소모 없이 아드레날린 효과 1회 발동
func _use_adrenaline_instant() -> void:
	if adrenaline_active: return
	_use_adrenaline()
	_show_kp_gain("공포 각성!")

## 아드레날린: 스태미나 최대치를 120%로 30초간 확장, 탈진 즉시 해제
func _use_adrenaline():
	adrenaline_active = true
	_adrenaline_timer = _effective_adrenaline_duration
	current_stamina = max_stamina
	is_exhausted = false
	_is_collapsing = false
	_exhaust_death_timer = 0.0
	_play_sfx(sfx_adrenaline_use)

func _update_adrenaline(delta):
	if not adrenaline_active: return
	current_stamina = max_stamina   # 스테미나 풀 유지
	_adrenaline_timer -= delta
	if _adrenaline_timer <= 0:
		adrenaline_active = false

## 배터리: 손전등 배터리 50% 즉시 충전
func _use_battery():
	var restore = 50.0 + (25.0 if GlobalSave.has_skill("item_memory") else 0.0)
	current_battery = min(current_battery + restore, max_battery)
	_battery_low_warned = false  # 경고음 재설정
	_play_sfx(sfx_battery_use)

## 방패: 적 공격 1회 방어, 장착 중 이동속도 65%
func _use_shield():
	if shield_active: return
	shield_active = true
	modulate = Color(0.6, 0.8, 1.0)  # 파란 틴트로 방패 활성 표시
	_play_sfx(sfx_shield_equip)

const THROW_MAX_RANGE: float = 720.0

## 신호탄: 마우스 방향으로 투사체 발사 — 콜로서스에 피해
func _use_flare():
	if flare_count <= 0: return
	var mouse_pos = get_global_mouse_position()
	if global_position.distance_to(mouse_pos) > THROW_MAX_RANGE:
		_show_kp_gain("사정거리 초과")
		return
	flare_count -= 1
	_play_sfx(_sfx_sinho)
	var flare = FlareProjectile.new()
	get_parent().add_child(flare)
	flare.setup(global_position, mouse_pos)
	_update_flare_ui()
	GlobalSave.count_action("flare_use")
	sound_emitted.emit(global_position, 0.80)

## 전등: 현재 위치에 배치 — 90초 조명, 공포 감소, 적 유인
func _use_lantern():
	var Lantern = load("res://scenes/lantern.gd")
	var lantern = Lantern.new()
	lantern.global_position = global_position
	get_parent().add_child(lantern)

## 기억 조각: 사용 시 런 한정 랜덤 버프 1개 적용
func _use_memory_shard():
	var all_buffs = ["stamina_cost", "battery_drain", "fear_gain", "move_speed", "lantern_duration"]
	var available = []
	for b in all_buffs:
		if not GlobalSave.has_run_buff(b):
			available.append(b)
	if available.is_empty():
		_show_kp_gain("모든 기억 버프 적용됨")
		return
	var chosen = available[randi() % available.size()]
	GlobalSave.apply_run_buff(chosen)
	var buff_names = {
		"stamina_cost":     "스태미나 소모 -20%",
		"battery_drain":    "배터리 소모 -30%",
		"fear_gain":        "공포 증가 -25%",
		"move_speed":       "이동속도 +10%",
		"lantern_duration": "전등 지속 +30초",
	}
	_show_kp_gain("기억 조각: %s" % buff_names.get(chosen, chosen))
	# 즉시 수치 반영
	_apply_run_buff_immediate(chosen)

func _apply_run_buff_immediate(buff_id: String) -> void:
	match buff_id:
		"battery_drain":    _battery_drain_rate *= 0.70
		"fear_gain":        _fear_increase_mult *= 0.75

## 파편: 마우스 방향으로 돌멩이 투척 — 소형 적 즉사, 보스 1 데미지
func _use_rock():
	var mouse_pos = get_global_mouse_position()
	if global_position.distance_to(mouse_pos) > THROW_MAX_RANGE:
		_show_kp_gain("사정거리 초과")
		return
	_play_sfx(_sfx_rock_throw)
	var RockProjectile = load("res://scenes/rock_projectile.gd")
	var rock = RockProjectile.new()
	var dir = (mouse_pos - global_position).normalized()
	rock.setup(global_position + dir * 50.0, mouse_pos)
	get_parent().add_child(rock)

## 소음 장치: 던진 지점에서 20초간 적 유인
func _use_noise_device():
	var mouse_pos = get_global_mouse_position()
	if global_position.distance_to(mouse_pos) > THROW_MAX_RANGE:
		_show_kp_gain("사정거리 초과")
		return
	var NoiseDevice = load("res://scenes/noise_device.gd")
	var device = NoiseDevice.new()
	var dir = (mouse_pos - global_position).normalized()
	device.setup(global_position + dir * 50.0, mouse_pos)
	get_parent().add_child(device)
	sound_emitted.emit(global_position, 0.5)

## 섬광탄: 던진 지점 반경 200px 내 적 3초 기절
func _use_emp_grenade():
	var mouse_pos = get_global_mouse_position()
	if global_position.distance_to(mouse_pos) > THROW_MAX_RANGE:
		_show_kp_gain("사정거리 초과")
		return
	var EmpGrenade = load("res://scenes/emp_grenade.gd")
	var grenade = EmpGrenade.new()
	var dir = (mouse_pos - global_position).normalized()
	grenade.setup(global_position + dir * 50.0, mouse_pos)
	get_parent().add_child(grenade)

## 공포 억제제: 공포 즉시 0으로 초기화
func _use_fear_suppressor():
	current_fear = 0.0

## 강화 손전등: 5분간 손전등 범위 1.5배
func _use_enhanced_flashlight():
	_enhanced_flashlight_timer = 300.0
	_apply_enhanced_flashlight(true)

func _update_enhanced_flashlight(delta: float):
	if _enhanced_flashlight_timer <= 0.0: return
	_enhanced_flashlight_timer -= delta
	if _enhanced_flashlight_timer <= 0.0:
		_enhanced_flashlight_timer = 0.0
		_apply_enhanced_flashlight(false)

func _apply_enhanced_flashlight(enhanced: bool):
	if not is_instance_valid(light_node): return
	light_node.texture_scale = 6.5 if enhanced else 4.2

func _break_shield():
	shield_active = false
	modulate = Color(1.0, 1.0, 1.0)
	_play_sfx(sfx_shield_block)
	# 가장 가까운 적 튕겨내기
	var nearest: Node = null
	var nearest_dist: float = 150.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		var d = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest and nearest.has_method("receive_shield_block"):
		nearest.receive_shield_block(global_position)

## 신호탄 HUD
func _build_flare_hud() -> void:
	# 배경 패널
	var bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bg.offset_left   = 10
	bg.offset_right  = 186
	bg.offset_top    = -72
	bg.offset_bottom = -6
	bg.color = Color(0.0, 0.0, 0.0, 0.42)
	bg.z_index = 98
	$CanvasLayer/Control.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vbox.offset_left   = 14
	vbox.offset_right  = 182
	vbox.offset_top    = -70
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 4)
	vbox.z_index = 99
	$CanvasLayer/Control.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "신호탄  [LMB]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.70, 0.60, 0.45, 0.90))
	lbl.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(lbl)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 5)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(hbox)

	for _i in 5:  # 최대 슬롯 5칸 고정
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)
		_flare_icons.append(icon)

	_update_flare_ui()

	# ── DEV 키 힌트 (신호탄 UI 바로 위)
	_dev_key_hints = Label.new()
	_dev_key_hints.add_theme_font_size_override("font_size", 10)
	_dev_key_hints.add_theme_color_override("font_color", Color(0.15, 0.95, 0.35, 0.90))
	_dev_key_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev_key_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_dev_key_hints.offset_left   = 10
	_dev_key_hints.offset_right  = 260
	_dev_key_hints.offset_top    = -112
	_dev_key_hints.offset_bottom = -74
	_dev_key_hints.text = "[DEV]  R: 기억초기화  Ctrl+R: 런초기화  Shift+R: 전체초기화"
	_dev_key_hints.visible = false
	_dev_key_hints.z_index = 99
	$CanvasLayer/Control.add_child(_dev_key_hints)

	# ── DEV 초기화 진행 바 (화면 우상단)
	_dev_reset_bar = Control.new()
	_dev_reset_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_dev_reset_bar.offset_left   = -270
	_dev_reset_bar.offset_top    = 10
	_dev_reset_bar.offset_right  = -10
	_dev_reset_bar.offset_bottom = 52
	_dev_reset_bar.visible = false
	_dev_reset_bar.z_index = 110
	$CanvasLayer/Control.add_child(_dev_reset_bar)

	var bar_bg = ColorRect.new()
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_bg.color = Color(0.05, 0.05, 0.05, 0.80)
	_dev_reset_bar.add_child(bar_bg)

	_dev_reset_fill = ColorRect.new()
	_dev_reset_fill.color = Color(0.15, 0.95, 0.35, 0.90)
	_dev_reset_fill.set_anchor_and_offset(SIDE_LEFT,   0.0, 0.0)
	_dev_reset_fill.set_anchor_and_offset(SIDE_TOP,    0.0, 0.0)
	_dev_reset_fill.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0.0)
	_dev_reset_fill.set_anchor_and_offset(SIDE_RIGHT,  0.0, 0.0)
	_dev_reset_bar.add_child(_dev_reset_fill)

	_dev_reset_label = Label.new()
	_dev_reset_label.add_theme_font_size_override("font_size", 11)
	_dev_reset_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	_dev_reset_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dev_reset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dev_reset_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dev_reset_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev_reset_bar.add_child(_dev_reset_label)

	# ── DEV 완료 토스트
	_dev_toast_label = Label.new()
	_dev_toast_label.add_theme_font_size_override("font_size", 12)
	_dev_toast_label.add_theme_color_override("font_color", Color(0.15, 0.95, 0.35))
	_dev_toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_dev_toast_label.offset_left   = -270
	_dev_toast_label.offset_top    = 58
	_dev_toast_label.offset_right  = -10
	_dev_toast_label.offset_bottom = 80
	_dev_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dev_toast_label.visible = false
	_dev_toast_label.z_index = 110
	$CanvasLayer/Control.add_child(_dev_toast_label)

## 재료 HUD: 화면 우하단, 보유 재료 간략 표시 (세로 나열로 화면 이탈 방지)
func _build_material_hud() -> void:
	var bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bg.offset_left   = -130
	bg.offset_right  = -8
	bg.offset_top    = -130
	bg.offset_bottom = -6
	bg.color = Color(0.0, 0.0, 0.0, 0.42)
	bg.z_index = 98
	bg.visible = false
	bg.name = "MatHudBg"
	$CanvasLayer/Control.add_child(bg)

	_mat_hud_label = Label.new()
	_mat_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat_hud_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mat_hud_label.offset_left   = -126
	_mat_hud_label.offset_right  = -10
	_mat_hud_label.offset_top    = -128
	_mat_hud_label.offset_bottom = -8
	_mat_hud_label.add_theme_font_size_override("font_size", 11)
	_mat_hud_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.72, 0.95))
	_mat_hud_label.z_index = 99
	$CanvasLayer/Control.add_child(_mat_hud_label)

func _update_material_ui() -> void:
	var bg = $CanvasLayer/Control.get_node_or_null("MatHudBg")
	const MAT_ABBR = {8: "전선", 9: "시약", 10: "금속", 11: "방호복", 12: "셀", 13: "폭발물"}
	var parts: Array = []
	for type_id in [8, 9, 10, 11, 12, 13]:
		var cnt = material_inventory.get(type_id, 0)
		if cnt > 0:
			parts.append("%s×%d" % [MAT_ABBR[type_id], cnt])
	var has_any = parts.size() > 0
	if bg: bg.visible = has_any
	if _mat_hud_label:
		_mat_hud_label.visible = has_any
		if has_any:
			_mat_hud_label.text = "재료\n" + "\n".join(parts)
	if _bag_open:
		_update_bag_panel()

## 가방 패널: 재료 인벤토리 전체 표시 (B키 토글)
func _build_bag_panel() -> void:
	const MAT_FULL = {8: "전선 조각", 9: "화학 시약", 10: "금속 파편", 11: "방호복 조각", 12: "에너지 셀", 13: "불안정 화합물"}
	const MAT_COLORS = {
		8:  Color(0.40, 0.80, 1.00),
		9:  Color(0.55, 1.00, 0.30),
		10: Color(0.85, 0.75, 0.50),
		11: Color(0.90, 0.85, 0.72),
		12: Color(0.25, 0.90, 0.90),
		13: Color(1.00, 0.55, 0.20),
	}
	var ctrl = $CanvasLayer/Control

	var bg = ColorRect.new()
	bg.name = "BagPanel"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bg.offset_left   = -210
	bg.offset_right  = -10
	bg.offset_top    = 60
	bg.offset_bottom = 248
	bg.color = Color(0.04, 0.07, 0.04, 0.93)
	bg.z_index = 105
	bg.visible = false
	ctrl.add_child(bg)
	_bag_container = bg

	# 테두리
	var border = ColorRect.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.color = Color(0.28, 0.58, 0.32, 0.60)
	border.size = Vector2(198, 186)
	border.position = Vector2(1, 1)
	border.z_index = 104
	bg.add_child(border)
	var inner = ColorRect.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.color = Color(0.04, 0.07, 0.04, 0.93)
	inner.size = Vector2(196, 184)
	inner.position = Vector2(2, 2)
	inner.z_index = 105
	bg.add_child(inner)

	# 제목
	var title = Label.new()
	title.text = "가방   [B: 닫기]"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.45, 0.88, 0.50, 1.0))
	title.position = Vector2(8, 6)
	title.z_index = 106
	inner.add_child(title)

	# 구분선
	var div = ColorRect.new()
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.color = Color(0.28, 0.55, 0.32, 0.45)
	div.size = Vector2(188, 1)
	div.position = Vector2(4, 26)
	div.z_index = 106
	inner.add_child(div)

	# 재료 행 (6개)
	_bag_mat_labels.clear()
	var row_y = 32
	for type_id in [8, 9, 10, 11, 12, 13]:
		var diamond = Label.new()
		diamond.text = "◆"
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		diamond.add_theme_font_size_override("font_size", 9)
		diamond.add_theme_color_override("font_color", MAT_COLORS[type_id])
		diamond.position = Vector2(8, row_y + 1)
		diamond.z_index = 107
		inner.add_child(diamond)

		var lbl = Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.position = Vector2(22, row_y)
		lbl.z_index = 107
		inner.add_child(lbl)
		_bag_mat_labels.append({"label": lbl, "type_id": type_id, "name": MAT_FULL[type_id]})
		row_y += 22

	# 하단 힌트
	var div2 = ColorRect.new()
	div2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div2.color = Color(0.28, 0.55, 0.32, 0.30)
	div2.size = Vector2(188, 1)
	div2.position = Vector2(4, row_y + 2)
	div2.z_index = 106
	inner.add_child(div2)

	var hint = Label.new()
	hint.text = "안전구역 제작대에서 제작 가능"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.40, 0.65))
	hint.position = Vector2(8, row_y + 6)
	hint.z_index = 107
	inner.add_child(hint)

func _toggle_bag() -> void:
	_bag_open = not _bag_open
	if _bag_container:
		_bag_container.visible = _bag_open
	if _bag_open:
		_update_bag_panel()

func _update_bag_panel() -> void:
	for entry in _bag_mat_labels:
		var lbl: Label = entry["label"]
		var cnt: int = material_inventory.get(entry["type_id"], 0)
		lbl.text = "%s  ×%d" % [entry["name"], cnt]
		if cnt > 0:
			lbl.add_theme_color_override("font_color", Color(0.88, 0.95, 0.76, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.38, 0.40, 0.34, 0.55))

func _update_flare_ui() -> void:
	var cur_max = get_max_flare()
	for i in _flare_icons.size():
		if i >= cur_max:
			_flare_icons[i].visible = false
		elif i < flare_count:
			_flare_icons[i].visible = true
			_flare_icons[i].color = Color(1.0, 0.38, 0.06)
		else:
			_flare_icons[i].visible = true
			_flare_icons[i].color = Color(0.18, 0.06, 0.02)

## 슬롯 UI 갱신
func _update_item_ui():
	_set_slot_icon(slot1_icon, slot1_item)
	_set_slot_icon(slot2_icon, slot2_item)

func _set_slot_icon(icon_node, item_type: int):
	if not icon_node: return
	if item_type == ItemType.NONE:
		icon_node.texture = null
		return
	icon_node.texture = _make_item_icon(item_type)

func _make_item_icon(item_type: int) -> ImageTexture:
	const COLORS = {
		0:  Color(0, 0, 0, 0),
		1:  Color(1.0, 0.45, 0.0),   # ADRENALINE
		2:  Color(1.0, 0.90, 0.1),   # BATTERY
		3:  Color(0.3, 0.55, 1.0),   # SHIELD
		4:  Color(1.0, 0.22, 0.05),  # FLARE
		5:  Color(0.72, 0.58, 0.32), # ROCK
		6:  Color(1.0, 0.80, 0.32),  # LANTERN
		7:  Color(0.55, 0.85, 1.0),  # MEMORY_SHARD
		14: Color(0.80, 0.80, 0.20), # NOISE_DEVICE
		15: Color(1.00, 0.92, 0.22), # FLASH_GRENADE
		16: Color(0.62, 0.28, 0.85), # FEAR_SUPPRESSOR
		17: Color(0.95, 0.88, 0.25), # ENHANCED_FLASHLIGHT
	}
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(COLORS.get(item_type, Color(0.5, 0.5, 0.5)))
	# 흰색 테두리
	for i in range(32):
		img.set_pixel(i, 0,  Color.WHITE)
		img.set_pixel(i, 31, Color.WHITE)
		img.set_pixel(0,  i, Color.WHITE)
		img.set_pixel(31, i, Color.WHITE)
	return ImageTexture.create_from_image(img)

# =====================
# 공통 효과음 
# =====================
func _play_sfx(stream: AudioStream):
	if stream == null: return
	_sfx_player.stream = stream
	_sfx_player.play()

func _play_sfx_oneshot(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null: return
	var p = AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

# =====================
# 손전등 텍스처 (GradientTexture2D — 이미지 파일 불필요)
# =====================
func _setup_flashlight():
	if not is_instance_valid(light_node): return

	# PointLight2D 텍스처 — 256×256, 좁고 긴 빔
	var size = 256
	var half = 128.0
	var cone_rad = 0.38   # 반각 22° → 총 44° 집중 부채꼴

	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in range(size):
		for y in range(size):
			var dx = float(x) - half
			var dy = float(y) - half
			if dx <= 0.0: continue
			var dist = sqrt(dx * dx + dy * dy)
			if dist >= half: continue
			var angle = abs(atan2(dy, dx))
			if angle >= cone_rad: continue
			var d_fade = pow(1.0 - dist / half, 0.65)
			var a_fade = pow(1.0 - angle / cone_rad, 0.30)
			img.set_pixel(x, y, Color(1.0, 1.0, 0.92, d_fade * a_fade))

	light_node.texture = ImageTexture.create_from_image(img)
	light_node.offset = Vector2(0.0, 0.0)
	light_node.texture_scale = 4.2    # 도달 거리 ≈ 540px
	light_node.energy = 2.0
	light_node.shadow_enabled = true
	light_node.shadow_item_cull_mask = 1

	# 시각적 부채꼴 오버레이 — 밝은 곳에서도 빔 방향이 명확히 보이도록
	if _flashlight_cone:
		_flashlight_cone.queue_free()
	_flashlight_cone = Polygon2D.new()
	var pts = PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps = 24
	var reach = 280.0
	for i in range(steps + 1):
		var a = -cone_rad + (2.0 * cone_rad * float(i) / float(steps))
		pts.append(Vector2(cos(a) * reach, sin(a) * reach))
	_flashlight_cone.polygon = pts
	_flashlight_cone.color = Color(1.0, 1.0, 0.80, 0.13)
	_flashlight_cone.z_index = -1
	_flashlight_cone.visible = false
	add_child(_flashlight_cone)

func _setup_ambient_light():
	# 손전등 꺼도 발밑이 보이는 소형 항상-켜진 라이트
	var size = 64
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx = float(size) * 0.5
	for y in size:
		for x in size:
			var d = Vector2(float(x), float(y)).distance_to(Vector2(cx, cx)) / cx
			var a = clamp(pow(1.0 - d, 2.2), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_ambient_light = PointLight2D.new()
	_ambient_light.texture = ImageTexture.create_from_image(img)
	_ambient_light.texture_scale = 2.2   # 반경 약 70px
	_ambient_light.energy = 0.65
	_ambient_light.color = Color(0.82, 0.88, 1.0)
	_ambient_light.shadow_enabled = false
	add_child(_ambient_light)

# =====================
# 코드 기반 비주얼 (파란 12각형 + 전방 화살표)
# =====================
func _build_visual():
	# 외곽선 (짙은 파랑)
	add_child(_make_circle_poly(26.0, 12, Color(0.25, 0.40, 0.85)))
	# 몸통 (연한 파랑-흰색)
	add_child(_make_circle_poly(22.0, 12, Color(0.85, 0.90, 1.0)))
	# 전방 방향 화살표 (+x 방향 = 바라보는 방향)
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(27.0,  0.0),
		Vector2(13.0, -9.0),
		Vector2(13.0,  9.0),
	])
	arrow.color = Color(0.35, 0.55, 1.0)
	add_child(arrow)

func _make_circle_poly(radius: float, segments: int, color: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(segments):
		var angle = (2.0 * PI * i) / segments
		pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	poly.polygon = pts
	poly.color = color
	return poly


# ─────────────────────────────────────────────────────────
# 인게임 도감 (Tab)
# ─────────────────────────────────────────────────────────

# Tab 키로 연구 기록을 확인한다. 오래 관찰할수록 더 많은 정보가 해제된다.
func _build_codex_panel() -> void:
	var ctrl = $CanvasLayer/Control

	_codex_panel = Control.new()
	_codex_panel.name = "CodexPanel"
	_codex_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_codex_panel.visible = false
	ctrl.add_child(_codex_panel)

	var dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_codex_panel.add_child(dim)

	var panel_border = ColorRect.new()
	panel_border.color = Color(0.32, 0.18, 0.08, 1.0)
	panel_border.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_border.offset_left = -672; panel_border.offset_right  = 672
	panel_border.offset_top  = -352; panel_border.offset_bottom = 352
	_codex_panel.add_child(panel_border)

	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.05, 0.03, 0.02, 1.0)
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel_bg.offset_left = -670; panel_bg.offset_right  = 670
	panel_bg.offset_top  = -350; panel_bg.offset_bottom = 350
	_codex_panel.add_child(panel_bg)

	var content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.offset_left = -668; content.offset_right  = 668
	content.offset_top  = -348; content.offset_bottom = 348
	_codex_panel.add_child(content)

	var outer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	outer.offset_left = 18; outer.offset_right  = -18
	outer.offset_top  = 14; outer.offset_bottom = -14
	content.add_child(outer)

	var hdr = HBoxContainer.new()
	outer.add_child(hdr)

	var title_lbl = Label.new()
	title_lbl.text = "SPECIMEN DATABASE  —  실험체 연구 기록"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.90, 0.68, 0.38))
	hdr.add_child(title_lbl)

	var hint_lbl = Label.new()
	hint_lbl.text = "[Tab / Esc: 닫기]"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.42, 0.37, 0.32))
	hdr.add_child(hint_lbl)

	outer.add_child(HSeparator.new())

	var cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 0)
	outer.add_child(cols)

	# 좌측 목록
	var list_side = VBoxContainer.new()
	list_side.custom_minimum_size = Vector2(300, 0)
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

	_codex_list_vbox = VBoxContainer.new()
	_codex_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_list_vbox.add_theme_constant_override("separation", 2)
	list_scroll.add_child(_codex_list_vbox)

	var vsep = ColorRect.new()
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsep.color = Color(0.28, 0.14, 0.08, 0.8)
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

	_codex_detail_root = VBoxContainer.new()
	_codex_detail_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_detail_root.add_theme_constant_override("separation", 0)
	detail_scroll.add_child(_codex_detail_root)

	# 목록 생성 (2줄 커스텀 행)
	_codex_list_btns.clear()
	for i in SpecimenDB.ENEMY_DATA.size():
		var entry = SpecimenDB.ENEMY_DATA[i]
		var seen  = GlobalSave.is_seen(entry["id"])
		var col   = entry["color"] if seen else Color(0.32, 0.28, 0.25)

		var row = Control.new()
		row.custom_minimum_size = Vector2(0, 56)
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
		pad.add_theme_constant_override("margin_left",   12)
		pad.add_theme_constant_override("margin_right",   6)
		pad.add_theme_constant_override("margin_top",     8)
		pad.add_theme_constant_override("margin_bottom",  8)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(pad)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(vbox)

		var name_lbl = Label.new()
		name_lbl.text = ("%s  —  \"%s\" / %s" % [entry["code"], entry["nickname"], entry["nickname_kr"]]) \
			if seen else "???  —  미지의 존재"
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var cls_lbl = Label.new()
		cls_lbl.text = entry["classification_kr"] if seen else "직접 조우 시 기록 해제"
		cls_lbl.add_theme_font_size_override("font_size", 10)
		cls_lbl.add_theme_color_override("font_color", Color(col.r * 0.65, col.g * 0.65, col.b * 0.65, 0.78))
		cls_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cls_lbl)

		var idx    = i
		var bg_ref = bg
		row.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				_codex_select(idx)
				get_viewport().set_input_as_handled())
		row.mouse_entered.connect(func():
			if idx != _codex_selected: bg_ref.color = Color(0.15, 0.09, 0.06, 0.85))
		row.mouse_exited.connect(func():
			if idx != _codex_selected: bg_ref.color = Color(0.09, 0.06, 0.04, 0.70))

		_codex_list_vbox.add_child(row)
		_codex_list_btns.append({"root": row, "bg": bg, "bar": bar, "col": col})


func _toggle_codex() -> void:
	_codex_open = not _codex_open
	if _codex_panel:
		_codex_panel.visible = _codex_open
	if _codex_open:
		var sel = _codex_selected if _codex_selected >= 0 else 0
		_codex_select(sel)


func _codex_select(idx: int) -> void:
	_codex_selected = idx
	for i in _codex_list_btns.size():
		var info = _codex_list_btns[i]
		info["bg"].color = Color(0.18, 0.10, 0.06, 1.0) if i == idx else Color(0.09, 0.06, 0.04, 0.70)

	for c in _codex_detail_root.get_children():
		c.queue_free()

	var entry = SpecimenDB.ENEMY_DATA[idx]
	var tier  = SpecimenDB.get_tier(entry["id"])
	_codex_build_detail(entry, tier)

	if tier == 4:
		GlobalSave.award_codex_tier4(entry["id"])


func _codex_build_detail(entry: Dictionary, tier: int) -> void:
	var root = _codex_detail_root
	var col  = entry["color"]

	var top_bar = ColorRect.new()
	top_bar.custom_minimum_size = Vector2(0, 3)
	top_bar.color = col * Color(1, 1, 1, 0.7)
	root.add_child(top_bar)

	var pad = MarginContainer.new()
	pad.add_theme_constant_override("margin_left",   12)
	pad.add_theme_constant_override("margin_right",  10)
	pad.add_theme_constant_override("margin_top",     7)
	pad.add_theme_constant_override("margin_bottom",  9)
	root.add_child(pad)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pad.add_child(vbox)

	var code_lbl = Label.new()
	code_lbl.text = "SPECIMEN %s  ·  %s" % [entry["code"], entry["classification"]]
	code_lbl.add_theme_font_size_override("font_size", 10)
	code_lbl.add_theme_color_override("font_color", Color(0.50, 0.46, 0.42))
	vbox.add_child(code_lbl)

	var ni_row = HBoxContainer.new()
	ni_row.add_theme_constant_override("separation", 12)
	vbox.add_child(ni_row)

	var icon = SpecimenIcon.new()
	icon.custom_minimum_size = Vector2(68, 68)
	icon.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	icon.setup(entry["code"], col, tier >= 1)
	ni_row.add_child(icon)

	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	name_vbox.add_theme_constant_override("separation", 3)
	ni_row.add_child(name_vbox)

	if tier == 0:
		var unk = Label.new()
		unk.text = "???  /  \"???????\"  (미지의 존재)"
		unk.add_theme_font_size_override("font_size", 15)
		unk.add_theme_color_override("font_color", Color(0.32, 0.30, 0.28))
		name_vbox.add_child(unk)
		var unk2 = Label.new()
		unk2.text = "직접 조우 시 기록이 해제됩니다."
		unk2.add_theme_font_size_override("font_size", 11)
		unk2.add_theme_color_override("font_color", Color(0.28, 0.26, 0.24))
		name_vbox.add_child(unk2)
		return

	var nick_lbl = Label.new()
	nick_lbl.text = "\"%s\"  /  %s" % [entry["nickname"], entry["nickname_kr"]]
	nick_lbl.add_theme_font_size_override("font_size", 16)
	nick_lbl.add_theme_color_override("font_color", col)
	name_vbox.add_child(nick_lbl)

	var cls_lbl = Label.new()
	cls_lbl.text = entry["classification_kr"]
	cls_lbl.add_theme_font_size_override("font_size", 10)
	cls_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.45))
	name_vbox.add_child(cls_lbl)

	var stars = "★".repeat(entry["threat"]) + "☆".repeat(5 - entry["threat"])
	var thr = Label.new()
	thr.text = "THREAT  " + stars
	thr.add_theme_font_size_override("font_size", 11)
	thr.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	name_vbox.add_child(thr)

	_csec_obs_bar(vbox, entry["id"], tier, col)

	vbox.add_child(HSeparator.new())

	if tier >= 2:
		_csec_header(vbox, "BEHAVIORAL PROFILE  /  행동 프로필", col)
		_csec_info(vbox, "행동 패턴", entry["tier2_behavior_kr"], col)
		_csec_info(vbox, "감지 범위", entry["tier2_detection_kr"], col)
	else:
		_csec_locked(vbox, "BEHAVIORAL PROFILE", "관찰 3초 이상 필요")

	if tier >= 3:
		_csec_header(vbox, "THREAT ANALYSIS  /  위협 분석", col)
		_csec_info(vbox, "특수 능력", entry["tier3_ability_kr"], col)
		_csec_info(vbox, "대응 방법", entry["tier3_counter_kr"], col)
	else:
		_csec_locked(vbox, "THREAT ANALYSIS", "관찰 15초 이상 필요")

	if tier >= 4:
		_csec_header(vbox, "ADVANCED DATA  /  고급 연구 기록", Color(0.88, 0.75, 0.32))
		_csec_info(vbox, "심층 정보", entry["tier4_secret_kr"], Color(0.88, 0.75, 0.32))
	else:
		_csec_locked(vbox, "ADVANCED DATA", "관찰 45초 이상 필요")

	vbox.add_child(HSeparator.new())

	var dmg_hdr = Label.new()
	dmg_hdr.text = "▸ RESEARCH LOG  —  [PARTIALLY DAMAGED]"
	dmg_hdr.add_theme_font_size_override("font_size", 10)
	dmg_hdr.add_theme_color_override("font_color", Color(0.55, 0.45, 0.28, 0.68))
	vbox.add_child(dmg_hdr)

	for line in entry.get("damaged_lines", []):
		var lbl = Label.new()
		lbl.text = "  " + line
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.52, 0.50, 0.46, 0.44))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	if tier >= 2 and entry.has("field_note"):
		var note = Label.new()
		note.text = entry["field_note"]
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color",
			Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, 0.88))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(note)


func _csec_header(c: VBoxContainer, text: String, col: Color) -> void:
	var lbl = Label.new()
	lbl.text = "▸ " + text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.80))
	c.add_child(lbl)


func _csec_info(c: VBoxContainer, label_kr: String, body_kr: String, col: Color) -> void:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	c.add_child(row)

	var lbl = Label.new()
	lbl.text = "  [ %s ]" % label_kr
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, 0.76))
	row.add_child(lbl)

	var body = Label.new()
	body.text = "  " + body_kr
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.86, 0.83, 0.79))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(body)


func _csec_locked(c: VBoxContainer, title: String, hint: String) -> void:
	var lbl = Label.new()
	lbl.text = "▸ %s  —  ████████████████████" % title
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.32, 0.29, 0.26, 0.62))
	c.add_child(lbl)

	var hlbl = Label.new()
	hlbl.text = "  [%s]" % hint
	hlbl.add_theme_font_size_override("font_size", 9)
	hlbl.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28, 0.48))
	c.add_child(hlbl)


func _csec_obs_bar(c: VBoxContainer, enemy_id: String, tier: int, col: Color) -> void:
	var obs_key: String = SpecimenDB.OBSERVE_KEY.get(enemy_id, enemy_id)
	var t: float = GlobalSave.get_observe_time(obs_key)
	var tier_str: String
	var progress: float
	if tier == 0:
		progress = 0.0; tier_str = "미관찰"
	elif tier == 1:
		progress = clampf(t / 3.0, 0.0, 1.0); tier_str = "T1  (%.0fs / 3s)" % t
	elif tier == 2:
		progress = clampf(t / 15.0, 0.0, 1.0); tier_str = "T2  (%.0fs / 15s)" % t
	elif tier == 3:
		progress = clampf(t / 45.0, 0.0, 1.0); tier_str = "T3  (%.0fs / 45s)" % t
	else:
		progress = 1.0; tier_str = "T4  MASTERY"

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)

	var lbl = Label.new()
	lbl.text = "관찰  " + tier_str
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.68))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var pbar = ProgressBar.new()
	pbar.min_value = 0.0; pbar.max_value = 1.0; pbar.value = progress
	pbar.show_percentage = false
	pbar.custom_minimum_size = Vector2(80, 7)
	pbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill_sty = StyleBoxFlat.new()
	fill_sty.bg_color = Color(col.r, col.g, col.b, 0.62)
	var bg_sty = StyleBoxFlat.new()
	bg_sty.bg_color = Color(0.12, 0.09, 0.07)
	pbar.add_theme_stylebox_override("fill",       fill_sty)
	pbar.add_theme_stylebox_override("background", bg_sty)
	row.add_child(pbar)

# ─────────────────────────────────────────────────────────
# 플레이어 독백 시스템
# ─────────────────────────────────────────────────────────

func _map_to_mini_v(pos: Vector2) -> Vector2:
	return Vector2(
		(pos.x - 50.0) / 5100.0 * MINI_W,
		(pos.y - 50.0) / 3700.0 * MINI_H
	)

func _get_minimap_zone() -> String:
	var x = global_position.x
	var y = global_position.y
	if y < 1435:
		if x < 1395: return "A"
		elif x < 2700: return "B"
		else: return "C"
	elif y < 2810:
		if x < 2300: return "D"
		else: return "E"
	else: return "F"

func _build_minimap_ui() -> void:
	var ctrl = $CanvasLayer/Control

	# 외부 패널 (우상단)
	_minimap_panel = Control.new()
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_panel.z_index = 90
	_minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_minimap_panel.offset_left   = -215
	_minimap_panel.offset_right  =  -5
	_minimap_panel.offset_top    =  10
	_minimap_panel.offset_bottom =  165
	ctrl.add_child(_minimap_panel)

	# 배경
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.03, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_panel.add_child(bg)

	# 구역 사각형 + 레이블
	const PAD_X: float = 5.0
	const PAD_Y: float = 5.0
	for zone_id in ["A", "B", "C", "D", "E", "F"]:
		var map_rect: Rect2 = MINI_ZONE_RECTS[zone_id]
		var mini_tl: Vector2 = _map_to_mini_v(map_rect.position)
		var mini_br: Vector2 = _map_to_mini_v(map_rect.end)
		var mini_size: Vector2 = (mini_br - mini_tl).snappedf(1.0)

		var zr = ColorRect.new()
		zr.position = Vector2(PAD_X, PAD_Y) + mini_tl.snappedf(1.0)
		zr.size = mini_size
		zr.color = Color(0.07, 0.07, 0.09, 0.95)
		zr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap_panel.add_child(zr)
		_minimap_zone_fills[zone_id] = zr

		var lbl = Label.new()
		lbl.text = zone_id
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25, 0.9))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.position = zr.position + mini_size * 0.5 - Vector2(4.0, 6.0)
		_minimap_panel.add_child(lbl)
		_minimap_zone_labels[zone_id] = lbl

	# 플레이어 점
	_minimap_player_dot = ColorRect.new()
	_minimap_player_dot.size = Vector2(5.0, 5.0)
	_minimap_player_dot.color = Color(1.0, 1.0, 1.0, 1.0)
	_minimap_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_player_dot.z_index = 5
	_minimap_panel.add_child(_minimap_player_dot)

	# 통로 마커 (구역 경계 통로 위치 표시)
	const PAD_PASS: float = 5.0
	for pass_pos in MINI_PASSAGES:
		var pm = ColorRect.new()
		pm.size = Vector2(3.0, 3.0)
		pm.color = Color(1.0, 1.0, 0.45, 0.90)
		pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pm.z_index = 4
		var mp = _map_to_mini_v(pass_pos)
		pm.position = Vector2(PAD_PASS, PAD_PASS) + mp - Vector2(1.5, 1.5)
		_minimap_panel.add_child(pm)

	# M키 힌트
	var m_hint = Label.new()
	m_hint.text = "[M]"
	m_hint.add_theme_font_size_override("font_size", 8)
	m_hint.add_theme_color_override("font_color", Color(0.28, 0.28, 0.28, 0.8))
	m_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	m_hint.offset_left = -22; m_hint.offset_bottom = -2
	_minimap_panel.add_child(m_hint)

func _update_minimap() -> void:
	if not _minimap_panel or not _minimap_panel.visible: return
	var current_zone: String = _get_minimap_zone()
	if current_zone != "" and not _minimap_visited.get(current_zone, false):
		_minimap_visited[current_zone] = true

	for z in _minimap_zone_fills:
		var fill: ColorRect = _minimap_zone_fills[z]
		var lbl: Label = _minimap_zone_labels[z]
		if _minimap_visited.get(z, false):
			var col: Color = MINI_ZONE_COLORS[z]
			fill.color = col.lightened(0.18) if z == current_zone else col
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		else:
			fill.color = Color(0.07, 0.07, 0.09, 0.95)
			lbl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25, 0.9))

	# 플레이어 점 위치 갱신
	const PAD: float = 5.0
	var clamped = global_position.clamp(Vector2(50.0, 50.0), Vector2(5150.0, 3750.0))
	var dot_pos = Vector2(PAD, PAD) + _map_to_mini_v(clamped) - Vector2(2.5, 2.5)
	_minimap_player_dot.position = dot_pos

func _build_monologue_ui() -> void:
	var ctrl = $CanvasLayer/Control
	# 배경 — 인벤토리(y=560) 20px 위, 가로 800px 중앙 정렬
	_mono_bg = ColorRect.new()
	_mono_bg.color = Color(0.04, 0.03, 0.06, 0.80)
	_mono_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mono_bg.visible = false
	_mono_bg.z_index = 94
	ctrl.add_child(_mono_bg)
	_mono_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_mono_bg.offset_left   =  400
	_mono_bg.offset_right  = -400
	_mono_bg.offset_top    = -404
	_mono_bg.offset_bottom = -356

	# 텍스트 레이블
	_mono_label = Label.new()
	_mono_label.add_theme_font_size_override("font_size", 15)
	_mono_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82, 1.0))
	_mono_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_mono_label.add_theme_constant_override("outline_size", 4)
	_mono_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mono_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_mono_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mono_label.visible  = false
	_mono_label.z_index  = 95
	ctrl.add_child(_mono_label)
	_mono_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_mono_label.offset_left   =  404
	_mono_label.offset_right  = -404
	_mono_label.offset_top    = -402
	_mono_label.offset_bottom = -358

func _build_hint_ui() -> void:
	var ctrl = $CanvasLayer/Control
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_hint_label.add_theme_constant_override("outline_size", 3)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.modulate.a   = 0.0
	_hint_label.z_index      = 93
	ctrl.add_child(_hint_label)
	# 인벤토리(y=560) 약간 위, 화면 좌측
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.offset_left   = 16
	_hint_label.offset_right  = 570
	_hint_label.offset_top    = -375
	_hint_label.offset_bottom = -345

func show_hint(key: String, text: String, duration: float = 3.5) -> void:
	if _shown_hints.get(key, false) or not _hint_label: return
	_shown_hints[key] = true
	if is_instance_valid(_hint_tween): _hint_tween.kill()
	_hint_label.text = text
	_hint_tween = _hint_label.create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.3)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.4)

func show_monologue(text: String, hold: float = 2.5) -> void:
	if _mono_active or text == "": return
	_mono_active = true
	_mono_cooldown = MONO_GLOBAL_CD
	_mono_label.text = text
	_mono_label.modulate.a = 0.0
	_mono_bg.modulate.a    = 0.0
	_mono_label.visible = true
	_mono_bg.visible    = true
	var tw = create_tween()
	tw.tween_property(_mono_label, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(_mono_bg, "modulate:a", 1.0, 0.4)
	tw.tween_interval(hold)
	tw.tween_property(_mono_label, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_mono_bg, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		_mono_label.visible = false
		_mono_bg.visible    = false
		_mono_active = false
	)

func _check_monologue_triggers(delta: float) -> void:
	if not is_alive: return
	if _codex_open or _bag_open: return

	_mono_cooldown        -= delta
	_mono_chase_escape_cd -= delta
	_mono_stamina_cd      -= delta

	# 런 시작 독백 (딜레이)
	if _mono_spawn_delay > 0.0:
		_mono_spawn_delay -= delta
		if _mono_spawn_delay <= 0.0:
			var total_deaths: int = 0
			for cnt in GlobalSave.data.get("death_counts", {}).values():
				total_deaths += cnt
			var msg: String
			if total_deaths == 0:
				msg = "어떻게 여 들어온 거지..."
			elif total_deaths == 1:
				msg = "왜... 다시 여기에 있는 거야."
			elif total_deaths < 5:
				msg = "또다시 처음부터."
			else:
				msg = "이 공간을 이미 알고 있다."
			show_monologue(msg, 3.2)
		return

	# 추격 상태 변화 추적 (항상 업데이트)
	var chase_just_ended: bool = _mono_was_chasing and not _was_chasing
	_mono_was_chasing = _was_chasing

	# 박스 타이머 (항상 업데이트)길
	if is_hidden_state:
		_mono_box_long_timer += delta
	else:
		_mono_box_short      = false
		_mono_box_long_timer = 0.0

	# 어둠 타이머 (항상 업데이트)
	if not flashlight_on and not is_hidden_state:
		_mono_dark_timer += delta
	else:
		_mono_dark_timer = 0.0
		if flashlight_on: _mono_dark_shown = false

	# 공포 회복 플래그 리셋
	if current_fear >= 50.0: _mono_fear_recovered = false

	if _mono_active or _mono_cooldown > 0.0: return

	# ── 적 최초 목격 ──
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy): continue
		if global_position.distance_to(enemy.global_position) > 350.0: continue
		var etype: String = _get_enemy_type(enemy)
		if etype == "" or _mono_seen.has(etype): continue
		_mono_seen[etype] = true
		show_monologue(MONO_ENEMY.get(etype, ""), 2.8)
		return

	# ── 공포 임계값 ──
	if current_fear >= 90.0 and _mono_fear_level < 3:
		_mono_fear_level = 3
		show_monologue("...숨어야 해.", 2.5)
		return
	if current_fear >= 75.0 and _mono_fear_level < 2:
		_mono_fear_level = 2
		show_monologue("생각이 안 돌아가.", 2.5)
		return
	if current_fear >= 50.0 and _mono_fear_level < 1:
		_mono_fear_level = 1
		show_monologue("심장이 너무 빠르다.", 2.5)
		return
	if current_fear < 20.0 and _mono_fear_level > 0 and not _mono_fear_recovered:
		_mono_fear_recovered = true
		_mono_fear_level = 0
		show_monologue("...진정하자.", 2.2)
		return

	# ── 박스 은신 ──
	if is_hidden_state:
		if not _mono_box_short:
			_mono_box_short = true
			show_monologue("여기 있으면 못 찾겠지.", 2.5)
			return
		if _mono_box_long_timer > 30.0 and not _mono_box_long:
			_mono_box_long = true
			show_monologue("아직 밖에 있어..", 3.0)
			return

	# ── 어둠 ──
	if _mono_dark_timer > 45.0 and not _mono_dark_shown:
		_mono_dark_shown = true
		show_monologue("어둡다. 너무 어두워.", 2.5)
		return

	# ── 배터리 위기 ──
	if current_battery <= 15.0 and flashlight_on and not _mono_battery_low:
		_mono_battery_low = true
		show_monologue("배터리가... 곧 꺼진다.", 2.5)
		return
	if current_battery > 30.0: _mono_battery_low = false

	# ── 스태미나 고갈 ──
	if is_exhausted and _mono_stamina_cd <= 0.0:
		_mono_stamina_cd = 30.0
		show_monologue("다리가 안 움직여.", 2.0)
		return

	# ── 추격 이탈 ──
	if chase_just_ended and _mono_chase_escape_cd <= 0.0:
		_mono_chase_escape_cd = 20.0
		var texts: Array = ["못 봤나.", "제발 못 봤기를."]
		show_monologue(texts[randi() % texts.size()], 2.5)
		return

	# ── 안전구역 진입 ──
	if is_in_safe_zone and not _mono_safe_prev:
		_mono_safe_count += 1
		if _mono_safe_count <= 2:
			show_monologue("여기선... 괜찮아.", 2.8)
	_mono_safe_prev = is_in_safe_zone
