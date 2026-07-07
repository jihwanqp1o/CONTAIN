extends Node2D

# ─────────────────────────────
# 프리로드
# ─────────────────────────────
const PlayerScene   = preload("res://scenes/player.tscn")
const LurkerScene   = preload("res://scenes/lurker.tscn")
const StalkerScene  = preload("res://scenes/stalker.tscn")
const ColossusScene = preload("res://scenes/colossus.tscn")
const AmbusherScene  = preload("res://scenes/ambusher.tscn")
const SentinelScene  = preload("res://scenes/sentinel.tscn")
const HeraldScene    = preload("res://scenes/herald.tscn")
const ChargerScene   = preload("res://scenes/charger.tscn")
const BroodScene     = preload("res://scenes/brood.tscn")
const BoxScene       = preload("res://scenes/box.tscn")
const ItemScene      = preload("res://scenes/item.tscn")
const KeyPickupScene = preload("res://scenes/key_pickup.tscn")
const BossDoorScene  = preload("res://scenes/boss_door.tscn")
const ContainmentPanelScript = preload("res://scenes/containment_panel.gd")
const BGMStream      = preload("res://assets/bgm2.mp3")
const BossBGMStream  = preload("res://assets/bossf.MP3")
const GlitchShader   = preload("res://scenes/World.gdshader")

# ─────────────────────────────
# 맵 상수
# ─────────────────────────────
const WT  = 50    # 외벽 두께
const IWT = 40    # 내벽 두께
const MW  = 5200  # 맵 전체 너비
const MH  = 3800  # 맵 전체 높이
const MX0 = 50    # 내부 좌
const MY0 = 50    # 내부 상
const MX1 = 5150  # 내부 우
const MY1 = 3750  # 내부 하

# 보스방 위치 (맵 우하단)
const BOSS_ROOM_X  = 3900
const BOSS_ROOM_Y  = 2600
const BOSS_ROOM_W  = 1000
const BOSS_ROOM_H  = 1000
# 보스 문 위치 — 시작 지점(200,200) 근처에 배치
const BOSS_DOOR_X  = 550
const BOSS_DOOR_Y  = 320
# 아레나 — 메인 맵 밖 별도 공간 (X: 8000+)
const ARENA_X  = 8000
const ARENA_Y  = 500
const ARENA_W  = BOSS_ROOM_W + 200   # 1200
const ARENA_H  = BOSS_ROOM_H + 100   # 1100
const ARENA_CX = ARENA_X + ARENA_W / 2  # 8600
# 열쇠 위치 — 파수꾼 영역 서쪽, 격리실 입구 근처 (중요 기억 5개 수집 후 공개)
const KEY_POS      = Vector2(4800, 3580)  # Zone F 동쪽 끝 보안 실험실

# 구역 순찰 범위 (patrol_bounds 용)
const PB_ENTRY  = Rect2( 110,  110,  780, 730)  # x:110-890,  y:110-840
const PB_NW     = Rect2(1060,  110, 930, 730)   # x:1060-1990, y:110-840
const PB_NE     = Rect2(2160,  110, 930, 730)   # x:2160-3090, y:110-840
const PB_WEST   = Rect2( 110,  960, 780, 680)   # x:110-890,  y:960-1640
const PB_CENTER = Rect2(1060,  960, 1080, 680)  # x:1060-2140, y:960-1640
const PB_EAST   = Rect2(2310,  960, 780, 680)   # x:2310-3090, y:960-1640
const PB_BOSS   = Rect2( 110, 1810, 2930, 480)  # x:110-3040, y:1810-2290

# ─────────────────────────────
# 색상
# ─────────────────────────────
const C_BG         = Color(0.03, 0.02, 0.02)
const C_WALL       = Color(0.75, 0.64, 0.48)
const C_WALL_TOP   = Color(0.92, 0.80, 0.62)
const C_PILLAR     = Color(0.70, 0.60, 0.44)
const C_PILLAR_CAP = Color(0.88, 0.76, 0.58)
const C_LINE       = Color(0.60, 0.52, 0.40)
const C_FL_ENTRY   = Color(0.12, 0.10, 0.08)
const C_FL_NORTH   = Color(0.10, 0.10, 0.15)
const C_FL_SOUTH   = Color(0.09, 0.08, 0.12)
const C_FL_BOSS    = Color(0.16, 0.05, 0.04)

const ZONE_SUBTITLES: Dictionary = {
	"A": {"name": "[ A 구역 ]", "sub": "진입 구역",    "color": Color(0.30, 0.85, 0.45)},
	"B": {"name": "[ B 구역 ]", "sub": "어둠의 공간",  "color": Color(0.95, 0.35, 0.35)},
	"C": {"name": "[ C 구역 ]", "sub": "추격 평야",    "color": Color(0.35, 0.55, 0.95)},
	"D": {"name": "[ D 구역 ]", "sub": "메아리 방",    "color": Color(0.75, 0.35, 0.95)},
	"E": {"name": "[ E 구역 ]", "sub": "파수꾼 구역",  "color": Color(0.95, 0.80, 0.35)},
	"F": {"name": "[ F 구역 ]", "sub": "격리 심층부",  "color": Color(0.95, 0.25, 0.25)},
}

# ─────────────────────────────
# 런타임 상태
# ─────────────────────────────
var _room_root: Node2D      = null
var _player: Node2D         = null
var _colossus_ref: Node2D   = null
var _bgm_player: AudioStreamPlayer      = null
var _boss_bgm_player: AudioStreamPlayer = null
var _boss_bgm_active: bool              = false
var _boss_door_ref: Node     = null
var _boss_fight_active: bool = false
var _zone_triggered: Dictionary = {}  # 구역 최초 진입 트리거 추적
var _subtitle_queue: Array = []
var _subtitle_showing: bool = false

# 보스 HUD
var _boss_hud_layer: CanvasLayer = null
var _boss_hud_fill: ColorRect    = null
var _boss_hud_label: Label       = null
var _boss_bar_full_w: float      = 0.0
var _panels_activated: int       = 0
var _panels: Array               = []
var _panel_hud_dots: Array       = []

# 월드 HUD
var _fade_rect: ColorRect = null

# ═════════════════════════════
# 초기화
# ═════════════════════════════

func _ready():
	add_to_group("world_root")
	GlobalSave.start_new_run()
	_build_static_bg()
	_setup_postprocess()
	_setup_canvas_modulate()
	_setup_world_hud()
	_build_full_map()
	_spawn_player()
	_start_bgm()

func _process(_delta):
	_update_boss_hud()
	_check_zone_by_position()

func _check_zone_by_position() -> void:
	if not is_instance_valid(_player): return
	var px: float = _player.global_position.x
	var py: float = _player.global_position.y
	# 가장 깊은 구역부터 체크 — 한 프레임에 하나씩 순차 트리거
	if not _zone_triggered.get("F", false) and py > 2850:
		_zone_triggered["F"] = true
		_spawn_zone_f()
		_show_zone_subtitle("F")
	elif not _zone_triggered.get("E", false) and py > 1435 and py < 2850 and px > 2340:
		_zone_triggered["E"] = true
		_spawn_zone_e()
		_show_zone_subtitle("E")
	elif not _zone_triggered.get("D", false) and py > 1435 and py < 2850 and px < 2300:
		_zone_triggered["D"] = true
		_spawn_zone_d()
		_show_zone_subtitle("D")
	elif not _zone_triggered.get("C", false) and py < 1435 and px > 2740:
		_zone_triggered["C"] = true
		_spawn_zone_c()
		_show_zone_subtitle("C")
	elif not _zone_triggered.get("B", false) and py < 1435 and px > 1435:
		_zone_triggered["B"] = true
		_spawn_zone_b()
		_show_zone_subtitle("B")

# ═════════════════════════════
# 맵 생성
# ═════════════════════════════

func _build_full_map() -> void:
	_room_root = Node2D.new()
	_room_root.name = "MapRoot"
	add_child(_room_root)

	_build_floors()
	_build_floor_textures()
	_build_outer_walls()
	_build_zone_walls()
	_build_interior()
	_build_navigation()
	_build_lighting()
	_build_props()
	_build_zone_differentiation()
	_build_secure_storage()
	_build_zone_f_lab()
	_spawn_enemies()
	_spawn_boxes()
	_spawn_items()
	_build_safe_zone()

# ─────────────────────────────
# 바닥 레이어
# ─────────────────────────────
func _build_floors() -> void:
	# 기본 바닥 (전체)
	_rv(MX0, MY0, MX1, MY1, C_FL_ENTRY)

	# ── 구역 분위기 오버레이 — 경계 겹침으로 자연스럽게 블렌딩 ──

	# Zone A (진입) — 따뜻한 색조
	_rv(  50,   50, 1500, 1500, Color(0.42, 0.26, 0.10, 0.06), 1)

	# Zone B (어둠) — 차가운 청회색. A와 200px 겹침
	_rv(1300,   50, 2800, 1400, Color(0.08, 0.09, 0.20, 0.10), 1)

	# Zone C (추격 평야) — 냉랭한 녹회색. B와 250px 겹침
	_rv(2550,   50, 5150, 1600, Color(0.07, 0.16, 0.09, 0.08), 1)

	# Zone D (메아리 방) — 보라빛. A/B 아래와 200px 겹침
	_rv(  50, 1300, 2400, 2900, Color(0.16, 0.05, 0.20, 0.10), 1)

	# Zone E (파수꾼 영역) — 적황색. C 아래·D 오른쪽과 겹침
	_rv(2200, 1300, 5150, 2900, Color(0.22, 0.15, 0.03, 0.09), 1)

	# Zone F (보스 접근로) — 짙은 적색. D/E 아래와 150px 겹침
	_rv(  50, 2750, 5150, 3750, Color(0.22, 0.04, 0.04, 0.12), 1)

	# 전환 경계 혼합 띠
	_rv(1300,   50, 1500, 1400, Color(0.10, 0.10, 0.20, 0.06), 1)  # A→B
	_rv(2550,   50, 2750, 1600, Color(0.10, 0.12, 0.14, 0.06), 1)  # B→C
	_rv(  50, 1300, 5150, 1450, Color(0.14, 0.08, 0.18, 0.06), 1)  # 상단→하단
	_rv(2200, 1300, 2400, 2900, Color(0.18, 0.10, 0.12, 0.06), 1)  # D→E
	_rv(  50, 2750, 5150, 2900, Color(0.20, 0.06, 0.06, 0.07), 1)  # D/E→F

# ─────────────────────────────
# 바닥 타일 텍스처
# ─────────────────────────────
func _build_floor_textures() -> void:
	var t_conc  = _make_tile_concrete(64)
	var t_metal = _make_tile_metal(48)
	var t_stone = _make_tile_stone(64)
	var t_grate = _make_tile_grating(32)

	# Zone A — 콘크리트 타일 (베이지)
	_textured_floor(  50,   50, 1500, 1500, t_conc,  Color(0.70, 0.62, 0.52, 0.30), 64)
	# Zone B — 균열 콘크리트 (차가운 회청)
	_textured_floor(1300,   50, 2800, 1400, t_conc,  Color(0.44, 0.43, 0.55, 0.24), 64)
	# Zone C — 금속 격자 (청회색)
	_textured_floor(2550,   50, 5150, 1600, t_grate, Color(0.40, 0.47, 0.56, 0.22), 32)
	# Zone D — 거친 돌 (보라빛)
	_textured_floor(  50, 1300, 2400, 2900, t_stone, Color(0.44, 0.38, 0.60, 0.26), 64)
	# Zone E — 금속 패널 (산업용)
	_textured_floor(2200, 1300, 5150, 2900, t_metal, Color(0.55, 0.47, 0.38, 0.24), 48)
	# Zone F — 오염 콘크리트 (적갈)
	_textured_floor(  50, 2750, 5150, 3750, t_conc,  Color(0.55, 0.30, 0.27, 0.26), 64)
	# Arena — 금속 패널 (냉청)
	_textured_floor(ARENA_X + IWT, ARENA_Y + IWT,
					ARENA_X + ARENA_W - IWT, ARENA_Y + ARENA_H - IWT,
					t_metal, Color(0.38, 0.48, 0.62, 0.28), 48)

func _textured_floor(x1: float, y1: float, x2: float, y2: float,
					 tex: ImageTexture, color: Color, tile_size: float) -> void:
	var poly = Polygon2D.new()
	poly.polygon = _rect_pts(x1, y1, x2, y2)
	poly.uv = PackedVector2Array([
		Vector2(x1 / tile_size, y1 / tile_size),
		Vector2(x2 / tile_size, y1 / tile_size),
		Vector2(x2 / tile_size, y2 / tile_size),
		Vector2(x1 / tile_size, y2 / tile_size),
	])
	poly.texture = tex
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.color = color
	poly.z_index = 1
	_room_root.add_child(poly)

# ─────────────────────────────
# 외벽
# ─────────────────────────────
func _build_outer_walls() -> void:
	_rw(0,       0,      MW,      WT)       # 상
	_rw(0,       MH-WT,  MW,      MH)       # 하
	_rw(0,       WT,     WT,      MH-WT)    # 좌
	_rw(MW-WT,   WT,     MW,      MH-WT)    # 우

# ─────────────────────────────
# 구역 구분 내벽 — 분리벽 + 통로
# ─────────────────────────────
func _build_zone_walls() -> void:
	# ── A↔B 경계벽 (x=1395~1435) — 통로 y=570~820 ──
	_rw(1395, MY0,  1435, 570)
	_rw(1395, 820,  1435, 1435)

	# ── B↔C 경계벽 (x=2700~2740) — 통로 y=660~910 ──
	_rw(2700, MY0,  2740, 660)
	_rw(2700, 910,  2740, 1435)

	# ── 상단↔하단 분리벽 (y=1395~1435) — 통로 3개: x=680~930, 2050~2340, 3750~4000 ──
	_rw(MX0,  1395,  680, 1435)
	_rw( 930, 1395, 1395, 1435)
	_rw(1435, 1395, 2050, 1435)
	_rw(2340, 1395, 2700, 1435)
	_rw(2740, 1395, 3750, 1435)
	_rw(4000, 1395, MX1,  1435)

	# ── D↔E 경계벽 (x=2300~2340) — 통로 y=2100~2350 ──
	_rw(2300, 1435, 2340, 2100)
	_rw(2300, 2350, 2340, 2810)

	# ── 하단↔F 분리벽 (y=2810~2850) — 통로 3개: x=550~800, 2000~2250, 3600~3850 ──
	_rw(MX0,  2810,  550, 2850)
	_rw( 800, 2810, 2000, 2850)
	_rw(2250, 2810, 3600, 2850)
	_rw(3850, 2810, MX1,  2850)

# ─────────────────────────────
# 내부 구조물 (보스방 벽은 _build_arena_walls() 참조)
# ─────────────────────────────
func _build_interior() -> void:
	# ── Zone A: 진입 통로벽 + 소형 연구실 ──
	_rw( 400, 640,  650, 680)
	_rw( 850, 640, 1380, 680)
	# 연구실 방 — 동쪽 개방 (북·서·남벽)
	_rw( 700, 870, 1000, 910)
	_rw( 700, 870,  740, 1150)
	_rw( 700, 1110, 1000, 1150)

	# ── Zone B: 수평 장벽 2열 + 비상 대피소 ──
	_rw(1500, 480, 1950, 520)
	_rw(2150, 480, 2680, 520)
	_rw(1550, 800, 2200, 840)
	_rw(2380, 800, 2680, 840)
	# 비상 대피소 — 서·북·남벽, 동쪽 입구 (y=1020–1100)
	_rw(1800,  950, 2050,  990)
	_rw(1800,  990, 1840, 1200)
	_rw(1800, 1160, 2050, 1200)
	_rw(2010,  950, 2050, 1020)
	_rw(2010, 1100, 2050, 1200)

	# ── Zone C: 수평 장벽 2열 + L형 엄폐물 2개 ──
	_rw(2800, 180, 3500, 220)
	_rw(3750, 180, 5100, 220)
	_rw(2800, 540, 3600, 580)
	_rw(3850, 540, 5100, 580)
	# L형 엄폐물 1 (서쪽 중단)
	_rw(3050,  650, 3290,  690)
	_rw(3050,  650, 3090,  820)
	# L형 엄폐물 2 (동쪽 중단)
	_rw(4600,  640, 4840,  680)
	_rw(4800,  640, 4840,  820)

	# ── Zone D: 메아리 격리실 + 하단 격벽 + 소형 부속실 ──
	_rw( 380, 1520,  870, 1560)
	_rw(1070, 1520, 1460, 1560)
	_rw( 380, 1560,  420, 2060)
	_rw(1420, 1560, 1460, 2060)
	_rw( 380, 2060, 1460, 2100)
	_rw( 900, 2330, 1950, 2370)
	_rw(2150, 2330, 2280, 2370)
	# 소형 격리 부속실 — 북쪽 입구 (x=590–670), 동·남벽 닫힘
	_rw( 500, 2450,  590, 2490)
	_rw( 670, 2450,  760, 2490)
	_rw( 720, 2450,  760, 2710)
	_rw( 500, 2670,  760, 2710)

	# ── Zone E: L형 장벽 + 동쪽 감시 구조 ──
	_rw(2500, 1680, 3000, 1720)
	_rw(2500, 1720, 2540, 2150)
	_rw(3900, 2260, 4700, 2300)
	# 동쪽 L형 장벽 (파수꾼 감시 영역 확장)
	_rw(3850, 1700, 4350, 1740)
	_rw(4310, 1700, 4350, 2050)

	# ── Zone F: 격리실 복도 — 동쪽 끝 보안 실험실 유도 ──
	# Row 0: 중앙 갭(x:3000–3800)으로 채널링
	_rw(  50, 2970, 3000, 3010)
	_rw(3800, 2970, 5150, 3010)
	# Row 1: 서쪽 갭(x:50–1800)으로 역전환
	_rw(1800, 3130, 5150, 3170)
	# Row 2: 동쪽 갭(x:4100–5150)으로 유도
	_rw(  50, 3300, 4100, 3340)
	# Row 3: 최종 동쪽 끝 진입(x:4600–5150 갭 → 열쇠 방)
	_rw(  50, 3450, 4600, 3490)
	# 보안 실험실 (x:4600–5100, y:3500–3700, 북쪽 입구 x:4750–4950)
	_rw(4600, 3500, 4750, 3540)   # 상단 서쪽
	_rw(4950, 3500, 5100, 3540)   # 상단 동쪽
	_rw(4600, 3500, 4640, 3700)   # 서쪽 벽
	_rw(4600, 3660, 5100, 3700)   # 하단 벽
	# 미끼 방 (서쪽 하단, 북쪽 입구 x:280–420)
	_rw( 150, 3500,  280, 3540)   # 상단 서
	_rw( 420, 3500,  560, 3540)   # 상단 동
	_rw( 150, 3500,  190, 3700)   # 서쪽 벽
	_rw( 520, 3500,  560, 3700)   # 동쪽 벽
	_rw( 150, 3660,  560, 3700)   # 하단 벽

# ─────────────────────────────
# 내비게이션 메시
# ─────────────────────────────
func _build_navigation() -> void:
	var region = NavigationRegion2D.new()
	region.name = "NavRegion"
	var nav_poly = NavigationPolygon.new()
	# 외부 경계 — CW (Godot y-down 기준)
	nav_poly.add_outline(PackedVector2Array([
		Vector2(MX0, MY0), Vector2(MX1, MY0),
		Vector2(MX1, MY1), Vector2(MX0, MY1),
	]))
	# 벽 구멍 — CCW (반대 감기: TL→BL→BR→TR)
	for r in _nav_wall_rects():
		nav_poly.add_outline(PackedVector2Array([
			Vector2(r[0], r[1]), Vector2(r[0], r[3]),
			Vector2(r[2], r[3]), Vector2(r[2], r[1]),
		]))
	nav_poly.make_polygons_from_outlines()
	region.navigation_polygon = nav_poly
	_room_root.add_child(region)

func _nav_wall_rects() -> Array:
	return [
		# 구역 경계벽
		[1395,   50, 1435,  570],
		[1395,  820, 1435, 1435],
		[2700,   50, 2740,  660],
		[2700,  910, 2740, 1435],
		[  50, 1395,  680, 1435],
		[ 930, 1395, 1395, 1435],
		[1435, 1395, 2050, 1435],
		[2340, 1395, 2700, 1435],
		[2740, 1395, 3750, 1435],
		[4000, 1395, 5150, 1435],
		[2300, 1435, 2340, 2100],
		[2300, 2350, 2340, 2810],
		[  50, 2810,  550, 2850],
		[ 800, 2810, 2000, 2850],
		[2250, 2810, 3600, 2850],
		[3850, 2810, 5150, 2850],
		# Zone A 내부
		[ 400,  640,  650,  680],
		[ 850,  640, 1380,  680],
		[ 700,  870, 1000,  910],
		[ 700,  870,  740, 1150],
		[ 700, 1110, 1000, 1150],
		# Zone B 내부
		[1500,  480, 1950,  520],
		[2150,  480, 2680,  520],
		[1550,  800, 2200,  840],
		[2380,  800, 2680,  840],
		# Zone B 비상 대피소
		[1800,  950, 2050,  990],
		[1800,  990, 1840, 1200],
		[1800, 1160, 2050, 1200],
		[2010,  950, 2050, 1020],
		[2010, 1100, 2050, 1200],
		# Zone C 내부
		[2800,  180, 3500,  220],
		[3750,  180, 5100,  220],
		[2800,  540, 3600,  580],
		[3850,  540, 5100,  580],
		# Zone C 엄폐물
		[3050,  650, 3290,  690],
		[3050,  650, 3090,  820],
		[4600,  640, 4840,  680],
		[4800,  640, 4840,  820],
		# Zone D 내부 (격리실)
		[ 380, 1520,  870, 1560],
		[1070, 1520, 1460, 1560],
		[ 380, 1560,  420, 2060],
		[1420, 1560, 1460, 2060],
		[ 380, 2060, 1460, 2100],
		[ 900, 2330, 1950, 2370],
		[2150, 2330, 2280, 2370],
		# Zone D 보안 보관실
		[1960, 2450, 2220, 2490],
		[2180, 2450, 2220, 2710],
		[1960, 2670, 2220, 2710],
		[1960, 2450, 2000, 2550],
		[1960, 2630, 2000, 2710],
		# Zone D 소형 부속실
		[ 500, 2450,  590, 2490],
		[ 670, 2450,  760, 2490],
		[ 720, 2450,  760, 2710],
		[ 500, 2670,  760, 2710],
		# Zone E 내부
		[2500, 1680, 3000, 1720],
		[2500, 1720, 2540, 2150],
		[3900, 2260, 4700, 2300],
		# Zone E 동쪽 L형
		[3850, 1700, 4350, 1740],
		[4310, 1700, 4350, 2050],
		# Zone F 격리 복도
		[  50, 2970, 3000, 3010],
		[3800, 2970, 5150, 3010],
		[1800, 3130, 5150, 3170],
		[  50, 3300, 4100, 3340],
		[  50, 3450, 4600, 3490],
		# Zone F 보안 실험실 (동쪽 끝, 북쪽 입구)
		[4600, 3500, 4750, 3540],
		[4950, 3500, 5100, 3540],
		[4600, 3500, 4640, 3700],
		[4600, 3660, 5100, 3700],
		# Zone F 미끼 방 (서쪽 하단)
		[ 150, 3500,  280, 3540],
		[ 420, 3500,  560, 3540],
		[ 150, 3500,  190, 3700],
		[ 520, 3500,  560, 3700],
		[ 150, 3660,  560, 3700],
	]

func _build_arena_walls() -> void:
	# 메인 맵 밖 별도 좌표(ARENA_X/Y)에 아레나 생성
	var bx  = ARENA_X
	var by  = ARENA_Y
	var bw  = ARENA_W
	var bh  = ARENA_H
	var wt  = IWT
	# 상단 벽 — 갭 없이 완전히 막음
	_rw(bx, by, bx + bw, by + wt)
	_rw(bx,           by + wt, bx + wt,      by + bh)
	_rw(bx + bw - wt, by + wt, bx + bw,      by + bh)
	_rw(bx,           by + bh - wt, bx + bw, by + bh)
	_rv(bx + wt, by + wt, bx + bw - wt, by + bh - wt, C_FL_BOSS)

	# 입구 느낌 — 상단 중앙에 어두운 문 마킹
	var door_mark = Polygon2D.new()
	var dw = 80.0
	var dh = float(wt) * 0.7
	door_mark.polygon = PackedVector2Array([
		Vector2(-dw, -dh), Vector2(dw, -dh),
		Vector2(dw,  dh),  Vector2(-dw, dh),
	])
	door_mark.color = Color(0.10, 0.04, 0.04, 0.9)
	door_mark.position = Vector2(float(ARENA_CX), float(by) + float(wt) * 0.5)
	door_mark.z_index = 2
	_room_root.add_child(door_mark)

# ─────────────────────────────
# 조명
# ─────────────────────────────
func _build_lighting() -> void:
	var tex = _make_round_light_tex(128)

	# ── Zone A — 진입 구역 (따뜻한 천장등) ──
	for d in [
		{"pos": Vector2( 300,  200), "c": Color(1.00, 0.92, 0.70), "e": 1.1, "s": 5.5},
		{"pos": Vector2( 720,  680), "c": Color(1.00, 0.90, 0.65), "e": 1.0, "s": 5.0},
		{"pos": Vector2(1150,  310), "c": Color(1.00, 0.92, 0.72), "e": 1.0, "s": 5.0},
		{"pos": Vector2(1200, 1100), "c": Color(0.95, 0.88, 0.68), "e": 0.9, "s": 4.5},
	]:
		_pl(d["pos"], tex, d["c"], d["e"], d["s"])

	# ── Zone B — 어둠 구역 (적색 비상등, 깜빡임) ──
	for d in [
		{"pos": Vector2(1620, 420), "c": Color(0.90, 0.15, 0.08), "e": 0.75, "s": 3.5},
		{"pos": Vector2(2200, 850), "c": Color(0.85, 0.12, 0.06), "e": 0.65, "s": 3.0},
		{"pos": Vector2(1925, 1075), "c": Color(0.95, 0.18, 0.08), "e": 0.40, "s": 0.7},
	]:
		var l = _pl(d["pos"], tex, d["c"], d["e"], d["s"])
		_flicker(l, d["e"])

	# ── Zone C — 추격 평야 (듬성듬성 형광등) ──
	for d in [
		{"pos": Vector2(3050,  320), "c": Color(0.88, 0.93, 1.00), "e": 0.9, "s": 5.0},
		{"pos": Vector2(3850,  720), "c": Color(0.85, 0.90, 1.00), "e": 0.8, "s": 4.5},
		{"pos": Vector2(4600,  400), "c": Color(0.90, 0.94, 1.00), "e": 0.9, "s": 5.0},
	]:
		_pl(d["pos"], tex, d["c"], d["e"], d["s"])

	# ── Zone D — 메아리방 (보라빛 희미한 등) ──
	for d in [
		{"pos": Vector2( 400, 1600), "c": Color(0.55, 0.25, 0.85), "e": 0.70, "s": 4.0},
		{"pos": Vector2( 900, 2200), "c": Color(0.50, 0.22, 0.80), "e": 0.65, "s": 3.5},
		{"pos": Vector2(1800, 2600), "c": Color(0.60, 0.28, 0.90), "e": 0.60, "s": 4.0},
		{"pos": Vector2( 630, 2580), "c": Color(0.55, 0.22, 0.88), "e": 0.38, "s": 0.6},
	]:
		_pl(d["pos"], tex, d["c"], d["e"], d["s"])

	# ── Zone E — 파수꾼 영역 (주황 경고등) ──
	for d in [
		{"pos": Vector2(2700, 1600), "c": Color(1.00, 0.48, 0.10), "e": 0.85, "s": 4.5},
		{"pos": Vector2(3500, 2100), "c": Color(1.00, 0.45, 0.08), "e": 0.80, "s": 4.0},
		{"pos": Vector2(4500, 1750), "c": Color(1.00, 0.50, 0.12), "e": 0.85, "s": 4.5},
		{"pos": Vector2(4800, 2500), "c": Color(1.00, 0.42, 0.08), "e": 0.75, "s": 4.0},
	]:
		_pl(d["pos"], tex, d["c"], d["e"], d["s"])

	# ── Zone F — 격리 심층부 (짙은 적등, 깜빡임) ──
	for d in [
		{"pos": Vector2( 420, 3000), "c": Color(0.80, 0.08, 0.05), "e": 0.60, "s": 3.5},
		{"pos": Vector2(1650, 3210), "c": Color(0.75, 0.06, 0.04), "e": 0.55, "s": 3.0},
		{"pos": Vector2(2780, 3060), "c": Color(0.80, 0.08, 0.05), "e": 0.60, "s": 3.5},
		{"pos": Vector2(3750, 3200), "c": Color(0.75, 0.06, 0.04), "e": 0.55, "s": 3.0},
	]:
		var l = _pl(d["pos"], tex, d["c"], d["e"], d["s"])
		_flicker(l, d["e"])
	# 보안 실험실 황금 조명
	_pl(Vector2(3290, 3590), tex, Color(0.90, 0.72, 0.22), 1.0, 2.5)

	# ── 아레나 (냉청백 조명) ──
	for d in [
		{"pos": Vector2(ARENA_X +  200, ARENA_Y + 250), "c": Color(0.70, 0.85, 1.00), "e": 1.1, "s": 5.5},
		{"pos": Vector2(ARENA_X +  600, ARENA_Y + 550), "c": Color(0.68, 0.82, 1.00), "e": 1.0, "s": 5.0},
		{"pos": Vector2(ARENA_X + 1000, ARENA_Y + 250), "c": Color(0.70, 0.85, 1.00), "e": 1.1, "s": 5.5},
	]:
		_pl(d["pos"], tex, d["c"], d["e"], d["s"])

# ─────────────────────────────
# 적 배치
# ─────────────────────────────
func _spawn_enemies() -> void:
	# Zone A만 즉시 스폰, 나머지는 진입 트리거로 지연
	_spawn_zone_a()
	_setup_zone_triggers()
	# Zone A 자막: 게임 시작 2초 후
	get_tree().create_timer(2.0).timeout.connect(func(): _show_zone_subtitle("A"))

func _spawn_zone_a() -> void:
	var lk_a = LurkerScene.instantiate()
	lk_a.position = Vector2(900, 800)
	lk_a.patrol_bounds = PB_ENTRY
	_room_root.add_child(lk_a)

func _spawn_zone_b() -> void:
	for sp in [Vector2(1600, 380), Vector2(2100, 680)]:
		var e = LurkerScene.instantiate(); e.position = sp
		e.patrol_bounds = PB_NW
		_room_root.add_child(e)
	var amb = AmbusherScene.instantiate()
	amb.position = Vector2(1850, 1050)
	_room_root.add_child(amb)

func _spawn_zone_c() -> void:
	for sp in [Vector2(2900, 450), Vector2(3900, 320)]:
		var e = StalkerScene.instantiate(); e.position = sp
		_room_root.add_child(e)
	for sp in [Vector2(3300, 900), Vector2(4400, 650)]:
		var e = ChargerScene.instantiate(); e.position = sp
		_room_root.add_child(e)
	var amb = AmbusherScene.instantiate()
	amb.position = Vector2(3500, 750)
	_room_root.add_child(amb)

func _spawn_zone_d() -> void:
	var herald = HeraldScene.instantiate()
	herald.position = Vector2(700, 1700)
	_room_root.add_child(herald)
	var amb = AmbusherScene.instantiate()
	amb.position = Vector2(1750, 2550)
	_room_root.add_child(amb)
	var offs_a = [Vector2(90,60), Vector2(-85,80), Vector2(70,-95), Vector2(-110,-50),
				  Vector2(30,130), Vector2(-60,-120), Vector2(120,-30)]
	_spawn_brood_pack(0, Vector2(1300, 1900), Rect2(50, 50, 2550, 3700), offs_a)

func _spawn_zone_e() -> void:
	_spawn_sentinel(Vector2(3200, 1750), 0.0)
	var charger_e = ChargerScene.instantiate()
	charger_e.position = Vector2(3200, 2350)
	_room_root.add_child(charger_e)
	var amb = AmbusherScene.instantiate()
	amb.position = Vector2(4000, 2100)
	_room_root.add_child(amb)
	var offs_b = [Vector2(90,60), Vector2(-85,80), Vector2(70,-95), Vector2(-110,-50),
				  Vector2(30,130), Vector2(-60,-120), Vector2(120,-30)]
	_spawn_brood_pack(1, Vector2(3900, 1900), Rect2(2600, 50, 2550, 3700), offs_b)

func _spawn_zone_f() -> void:
	var lurker_f = LurkerScene.instantiate()
	lurker_f.position = Vector2(600, 3200)
	lurker_f.patrol_bounds = Rect2(110, 2860, 1400, 540)
	_room_root.add_child(lurker_f)
	var stalker_f = StalkerScene.instantiate()
	stalker_f.position = Vector2(3700, 3050)
	_room_root.add_child(stalker_f)
	var charger_f = ChargerScene.instantiate()
	charger_f.position = Vector2(2100, 2900)
	_room_root.add_child(charger_f)
	# 매복자 A — Row1/2 사이 코너에 잠복
	var amb_a = AmbusherScene.instantiate()
	amb_a.position = Vector2(1650, 3250)
	_room_root.add_child(amb_a)
	# 매복자 B — 보안 실험실 서쪽 입구 앞 잠복
	var amb_b = AmbusherScene.instantiate()
	amb_b.position = Vector2(2980, 3590)
	_room_root.add_child(amb_b)

func _setup_zone_triggers() -> void:
	# Zone B: A↔B 통로 (x=1395~1435, y=570~820) — 가로 100px으로 확장
	_make_zone_trigger("B", [Rect2(1365, 570, 100, 250)], _spawn_zone_b)
	# Zone C: B↔C 통로 (x=2700~2740, y=660~910) — 가로 100px으로 확장
	_make_zone_trigger("C", [Rect2(2670, 660, 100, 250)], _spawn_zone_c)
	# Zone D: 상단↔하단 통로 3곳 (y=1395~1435) — 세로 100px으로 확장
	_make_zone_trigger("D", [
		Rect2(680,  1365, 250, 100),
		Rect2(2050, 1365, 290, 100),
		Rect2(3750, 1365, 250, 100),
	], _spawn_zone_d)
	# Zone E: D↔E 통로 (x=2300~2340, y=2100~2350) — 가로 100px으로 확장
	_make_zone_trigger("E", [Rect2(2270, 2100, 100, 250)], _spawn_zone_e)
	# Zone F: 하단↔F 통로 3곳 (y=2810~2850) — 세로 100px으로 확장
	_make_zone_trigger("F", [
		Rect2(550,  2780, 250, 100),
		Rect2(2000, 2780, 250, 100),
		Rect2(3600, 2780, 250, 100),
	], _spawn_zone_f)

func _make_zone_trigger(zone_id: String, rects: Array, spawn_fn: Callable) -> void:
	for rect in rects:
		var area = Area2D.new()
		area.collision_layer = 0
		area.collision_mask  = 1
		var shape = CollisionShape2D.new()
		var box   = RectangleShape2D.new()
		box.size  = rect.size
		shape.shape    = box
		area.position  = rect.position + rect.size * 0.5
		area.add_child(shape)
		_room_root.add_child(area)
		area.body_entered.connect(func(body: Node):
			if body.is_in_group("player") and not _zone_triggered.get(zone_id, false):
				_zone_triggered[zone_id] = true
				spawn_fn.call()
				_show_zone_subtitle(zone_id)
		)

func _show_zone_subtitle(zone_id: String) -> void:
	if _subtitle_showing:
		if zone_id not in _subtitle_queue:
			_subtitle_queue.append(zone_id)
		return
	var info: Dictionary = ZONE_SUBTITLES.get(zone_id, {})
	if info.is_empty(): return
	_subtitle_showing = true
	var col: Color = info["color"]

	var layer = CanvasLayer.new()
	layer.layer = 30
	get_tree().root.add_child(layer)

	var name_lbl = Label.new()
	name_lbl.text = info["name"]
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", col)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	name_lbl.add_theme_constant_override("outline_size", 5)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	name_lbl.offset_top = 38; name_lbl.offset_bottom = 66
	name_lbl.modulate.a = 0.0
	layer.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = info["sub"]
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.85))
	sub_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	sub_lbl.add_theme_constant_override("outline_size", 4)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub_lbl.offset_top = 66; sub_lbl.offset_bottom = 88
	sub_lbl.modulate.a = 0.0
	layer.add_child(sub_lbl)

	var tw = layer.create_tween()
	tw.tween_property(name_lbl, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(sub_lbl, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.8)
	tw.tween_property(name_lbl, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(sub_lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		layer.queue_free()
		_subtitle_showing = false
		if not _subtitle_queue.is_empty():
			_show_zone_subtitle(_subtitle_queue.pop_front())
	)

func _spawn_brood_pack(pid: int, alpha_pos: Vector2, bounds: Rect2, regular_offs: Array) -> void:
	var a = BroodScene.instantiate()
	a.position      = alpha_pos
	a.is_alpha      = true
	a.pack_id       = pid
	a.patrol_bounds = bounds
	_room_root.add_child(a)
	for off in regular_offs:
		var b = BroodScene.instantiate()
		b.position = alpha_pos + off
		b.is_alpha  = false
		b.pack_id   = pid
		_room_root.add_child(b)

func _spawn_sentinel(pos: Vector2, facing: float) -> void:
	# detection_range(340) + BODY_RADIUS(28) = 368 → 실제 공격 반경
	_draw_sentinel_territory(pos, 368.0)
	var s = SentinelScene.instantiate()
	s.position = pos
	s.rotation = facing
	_room_root.add_child(s)

	# 부하 무리 3마리 — 파수꾼 중심에서 삼각 배치 (반경 180px)
	var sub_offsets: Array = [
		Vector2(180,   0),
		Vector2(-90,  156),
		Vector2(-90, -156),
	]
	for off in sub_offsets:
		var home: Vector2 = pos + off
		var b = BroodScene.instantiate()
		b.position       = home
		b.is_alpha       = false
		b.is_subordinate = true
		b.swarm_speed    = 270.0
		_room_root.add_child(b)
		s.add_subordinate(b, home)

func _draw_sentinel_territory(center: Vector2, attack_radius: float) -> void:
	# attack_radius   = 실제 공격 트리거 반경 (안쪽 원)
	# territory_radius = 영역 표시 반경 (바깥 원, 시각 전용 — 공격 없음)
	var territory_radius = attack_radius * 2.1   # ≈ 773
	var steps = 48

	# ── [1] 바깥 영역 원 — 시각 전용, 공격 없음 ──
	var terr_pts = PackedVector2Array()
	for i in range(steps):
		var a = (float(i) / float(steps)) * TAU
		terr_pts.append(center + Vector2(cos(a), sin(a)) * territory_radius)
	var terr_fill = Polygon2D.new()
	terr_fill.polygon = terr_pts
	terr_fill.color   = Color(3.5, 3.2, 0.35, 0.08)   # 매우 연한 황금색
	terr_fill.z_index = 1
	_room_root.add_child(terr_fill)

	var terr_border = Line2D.new()
	terr_border.width         = 2.0
	terr_border.default_color = Color(4.8, 4.4, 0.55, 0.50)
	terr_border.z_index       = 1
	for i in range(steps + 1):
		var a = (float(i) / float(steps)) * TAU
		terr_border.add_point(center + Vector2(cos(a), sin(a)) * territory_radius)
	_room_root.add_child(terr_border)

	# ── [2] 안쪽 공격 원 — 이 선 안으로 들어오면 공격 ──
	var atk_pts = PackedVector2Array()
	for i in range(steps):
		var a = (float(i) / float(steps)) * TAU
		atk_pts.append(center + Vector2(cos(a), sin(a)) * attack_radius)
	var atk_fill = Polygon2D.new()
	atk_fill.polygon = atk_pts
	atk_fill.color   = Color(5.0, 2.5, 0.10, 0.18)    # 주황-적색
	atk_fill.z_index = 2
	_room_root.add_child(atk_fill)

	var atk_border = Line2D.new()
	atk_border.width         = 3.5
	atk_border.default_color = Color(6.0, 2.0, 0.05, 0.90)
	atk_border.z_index       = 3
	for i in range(steps + 1):
		var a = (float(i) / float(steps)) * TAU
		atk_border.add_point(center + Vector2(cos(a), sin(a)) * attack_radius)
	_room_root.add_child(atk_border)

	# ── [3] 중심 십자 표식 ──
	for ang in [0.0, PI * 0.5]:
		var mark = Line2D.new()
		mark.width         = 2.0
		mark.default_color = Color(5.5, 4.0, 0.2, 0.60)
		mark.z_index       = 3
		var dir = Vector2(cos(ang), sin(ang)) * 20.0
		mark.add_point(center - dir)
		mark.add_point(center + dir)
		_room_root.add_child(mark)

# ─────────────────────────────
# 소품 / 환경 장식
# ─────────────────────────────
func _build_props() -> void:
	# ── Zone A — 진입 구역 (활성 시설, 정돈된 소품) ──
	for p in [Vector2(280,950), Vector2(700,250), Vector2(1100,250), Vector2(700,1250), Vector2(1100,1250)]:
		_pillar(p)
	for c in [Vector2(500,650), Vector2(900,430), Vector2(1200,900), Vector2(350,1100)]:
		_debris_cluster(c, 7, 55.0)
	for p in [Vector2(420,180), Vector2(620,1080), Vector2(1060,740)]:
		_barrel(p, Color(0.22, 0.38, 0.22))
	for p in [Vector2(160,760), Vector2(880,1080), Vector2(1320,500)]:
		_crate(p, 18.0, 15.0, Color(0.42, 0.32, 0.18))
	_pipe(Vector2(100,170), Vector2(560,170), 5.0, Color(0.30, 0.32, 0.35))
	_pipe(Vector2(100,170), Vector2(100,920), 5.0, Color(0.30, 0.32, 0.35))

	# ── Zone B — 어둠 구역 (사고 흔적, 경고 표지) ──
	for p in [Vector2(1500,320), Vector2(1700,620), Vector2(1900,320), Vector2(2100,920), Vector2(2300,620), Vector2(2450,250)]:
		_pillar(p, 22.0)
	for c in [Vector2(1450,820), Vector2(1800,420), Vector2(2150,1100), Vector2(2400,800)]:
		_debris_cluster(c, 9, 65.0)
	for p in [Vector2(1560,210), Vector2(2010,580), Vector2(2380,310)]:
		_warning_sign(p)
	for p in [Vector2(1710,510), Vector2(2110,860), Vector2(2480,640)]:
		_blood_stain(p, 28.0)
	for p in [Vector2(1640,740), Vector2(2130,440)]:
		_barrel(p, Color(0.35, 0.18, 0.16))
	_pipe(Vector2(1350,100), Vector2(2750,100), 5.0, Color(0.28, 0.28, 0.32))

	# ── Zone C — 추격 평야 (산업 시설 잔해) ──
	for p in [Vector2(3000,600), Vector2(3600,350), Vector2(4200,750), Vector2(4700,400)]:
		_pillar(p, 22.0)
	for c in [Vector2(3300,800), Vector2(4500,550)]:
		_debris_cluster(c, 6, 50.0)
	for p in [Vector2(3180,510), Vector2(4020,820), Vector2(4820,560)]:
		_barrel(p, Color(0.26, 0.30, 0.36))
	for p in [Vector2(3020,200), Vector2(4230,210), Vector2(5020,620)]:
		_warning_sign(p)
	_pipe(Vector2(2620,100), Vector2(5100,100), 5.0, Color(0.28, 0.30, 0.34))
	_pipe(Vector2(5100,100), Vector2(5100,1560), 5.0, Color(0.28, 0.30, 0.34))

	# ── Zone D — 메아리방 (격리 실패 현장, 혈흔+잔해) ──
	for p in [Vector2(400,1850), Vector2(800,2250), Vector2(1300,1650), Vector2(1750,2500), Vector2(2200,1850)]:
		_pillar(p)
	for c in [Vector2(300,1700), Vector2(600,2050), Vector2(950,1750), Vector2(1200,2450), Vector2(1650,1900), Vector2(2050,2300)]:
		_debris_cluster(c, 10, 70.0)
	for p in [Vector2(260,1720), Vector2(720,2120), Vector2(1110,1930), Vector2(1620,2360), Vector2(2140,2720)]:
		_blood_stain(p, 36.0)
	for p in [Vector2(360,2080), Vector2(820,1800), Vector2(1420,2480), Vector2(1920,1980)]:
		_crate(p, 16.0, 14.0, Color(0.26, 0.20, 0.30))
	_pipe(Vector2(100,1560), Vector2(100,2850), 6.0, Color(0.28, 0.26, 0.32))
	_pipe(Vector2(100,2850), Vector2(2360,2850), 6.0, Color(0.28, 0.26, 0.32))

	# ── Zone E — 파수꾼 영역 (가동 중 산업시설) ──
	for p in [Vector2(2750,1550), Vector2(3750,1550), Vector2(2750,2100), Vector2(3750,2100)]:
		_pillar(p, 16.0)
	for c in [Vector2(2900,1650), Vector2(3600,1800), Vector2(3100,2200)]:
		_debris_cluster(c, 6, 45.0)
	for p in [Vector2(2620,1720), Vector2(3250,2350), Vector2(4150,1930), Vector2(4740,2730)]:
		_barrel(p, Color(0.28, 0.38, 0.26))
	for p in [Vector2(2920,1510), Vector2(3820,2560)]:
		_warning_sign(p)
	_pipe(Vector2(2260,1420), Vector2(5100,1420), 5.0, Color(0.30, 0.28, 0.24))
	_pipe(Vector2(4900,1420), Vector2(4900,2860), 5.0, Color(0.30, 0.28, 0.24))

	# ── Zone F — 격리 심층부 (폐허, 무거운 혈흔) ──
	for p in [Vector2(500,3200), Vector2(1650,3220), Vector2(3800,3200)]:
		_pillar(p, 22.0)
	for c in [Vector2(350,2920), Vector2(750,3230), Vector2(1150,2920), Vector2(420,3550), Vector2(850,3650), Vector2(3100,3550), Vector2(1800,3200)]:
		_debris_cluster(c, 9, 60.0)
	for p in [Vector2(310,3200), Vector2(820,2930), Vector2(1430,3250), Vector2(2250,3090), Vector2(3050,3530)]:
		_blood_stain(p, 44.0)
	for p in [Vector2(560,2910), Vector2(1370,3550), Vector2(2640,3010)]:
		_warning_sign(p)
	for p in [Vector2(210,3200), Vector2(1600,3210)]:
		_barrel(p, Color(0.34, 0.13, 0.11))
	_pipe(Vector2(100,2910), Vector2(5100,2910), 6.0, Color(0.32, 0.22, 0.20))

func _pillar(pos: Vector2, r: float = 18.0) -> StaticBody2D:
	var sb = StaticBody2D.new()
	sb.position = pos
	var steps = 8
	var pts = PackedVector2Array()
	for i in steps:
		var a = (float(i) / float(steps)) * TAU + TAU / 16.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	var outer = Polygon2D.new()
	outer.polygon = pts
	outer.color   = Color(0.20, 0.20, 0.22)
	outer.z_index = 2
	sb.add_child(outer)
	var ipts = PackedVector2Array()
	for i in steps:
		var a = (float(i) / float(steps)) * TAU + TAU / 16.0
		ipts.append(Vector2(cos(a), sin(a)) * r * 0.50)
	var inner = Polygon2D.new()
	inner.polygon = ipts
	inner.color   = Color(0.30, 0.30, 0.34)
	inner.z_index = 3
	sb.add_child(inner)
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new()
	shp.radius = r
	col.shape  = shp
	sb.add_child(col)
	_room_root.add_child(sb)
	return sb

func _debris_cluster(center: Vector2, count: int = 8, spread: float = 60.0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(abs(center.x) * 73.0 + abs(center.y) * 31.0)
	var colors: Array = [
		Color(0.28, 0.26, 0.24, 0.9), Color(0.36, 0.32, 0.26, 0.9),
		Color(0.20, 0.19, 0.17, 0.9), Color(0.42, 0.37, 0.28, 0.9),
	]
	for _i in count:
		var ang = rng.randf() * TAU
		var pos = center + Vector2(cos(ang), sin(ang)) * (rng.randf() * spread)
		var w   = rng.randf_range(4.0, 16.0)
		var h   = rng.randf_range(3.0, 11.0)
		var d   = Polygon2D.new()
		d.polygon  = PackedVector2Array([Vector2(-w,-h), Vector2(w,-h), Vector2(w,h), Vector2(-w,h)])
		d.color    = colors[rng.randi() % colors.size()]
		d.position = pos
		d.rotation = rng.randf() * TAU
		d.z_index  = -1
		_room_root.add_child(d)

# ─────────────────────────────
# 구역 차별화
# ─────────────────────────────
func _build_zone_differentiation() -> void:
	# ── 구역 경계 바닥 줄 ──
	_rv(1380,   80, 1420, 1380, Color(0.65, 0.50, 0.10, 0.18), 2)   # A↔B
	_rv(2660,   80, 2700, 1500, Color(0.20, 0.35, 0.55, 0.18), 2)   # B↔C
	_rv(  80, 1370, 5120, 1410, Color(0.40, 0.20, 0.45, 0.14), 2)   # 상단↔하단
	_rv(2280, 1370, 2320, 2820, Color(0.55, 0.30, 0.12, 0.18), 2)   # D↔E
	_rv(  80, 2820, 5120, 2860, Color(0.60, 0.10, 0.08, 0.18), 2)   # 하단↔F

	# ── 구역 코드 플레이크 (벽 근처 소형 표식) ──
	_zone_plaque(Vector2( 130,  150), "A-1", Color(0.75, 0.65, 0.25))
	_zone_plaque(Vector2(1460,  150), "B-2", Color(0.35, 0.30, 0.70))
	_zone_plaque(Vector2(2720,  150), "C-3", Color(0.25, 0.45, 0.65))
	_zone_plaque(Vector2( 130, 1470), "D-4", Color(0.55, 0.25, 0.72))
	_zone_plaque(Vector2(2320, 1470), "E-5", Color(0.72, 0.42, 0.12))
	_zone_plaque(Vector2( 130, 2870), "F-6", Color(0.72, 0.12, 0.10))

	# ── Zone D — 에코 링 (잔향 느낌의 동심원) ──
	_echo_ring(Vector2( 620, 2060), 100.0)
	_echo_ring(Vector2(1320, 1760),  80.0)
	_echo_ring(Vector2( 630, 2580),  65.0)
	_echo_ring(Vector2(1600, 2200),  70.0)

	# ── Zone E — 파수꾼 감시 원형 ──
	_echo_ring(Vector2(3200, 1750), 55.0, Color(0.72, 0.42, 0.12, 1.0))
	_echo_ring(Vector2(4200, 1950), 55.0, Color(0.72, 0.42, 0.12, 1.0))

	# ── Zone B — 비상 대피소 내부 ──
	_rv(1840,  990, 2010, 1160, Color(0.50, 0.05, 0.05, 0.14), 1)

	# ── Zone D — 소형 부속실 내부 ──
	_rv( 540, 2490,  720, 2670, Color(0.28, 0.08, 0.42, 0.14), 1)

	# ── Zone F — 미로 레인 내 방향 표식 ──
	for pos in [Vector2(700.0, 3220.0), Vector2(1650.0, 3210.0), Vector2(2780.0, 3060.0), Vector2(3700.0, 3420.0)]:
		_floor_arrow(pos)

func _zone_plaque(pos: Vector2, code: String, color: Color) -> void:
	var bg = Polygon2D.new()
	bg.polygon = _rect_pts(-22, -11, 22, 11)
	bg.color = Color(color.r * 0.20, color.g * 0.20, color.b * 0.20, 0.80)
	bg.position = pos; bg.z_index = 2
	_room_root.add_child(bg)
	var border = Line2D.new()
	for pt in [Vector2(-22,-11), Vector2(22,-11), Vector2(22,11), Vector2(-22,11), Vector2(-22,-11)]:
		border.add_point(pos + pt)
	border.width = 1.5; border.default_color = color; border.z_index = 3
	_room_root.add_child(border)
	var lbl = Label.new()
	lbl.text = code; lbl.position = pos + Vector2(-16, -10)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 4
	_room_root.add_child(lbl)

func _echo_ring(center: Vector2, radius: float, color: Color = Color(0.50, 0.22, 0.72, 1.0)) -> void:
	for mult in [0.40, 0.70, 1.00]:
		var r = radius * mult
		var ring = Line2D.new()
		var steps = 28
		for i in range(steps + 1):
			var a = (float(i) / float(steps)) * TAU
			ring.add_point(center + Vector2(cos(a), sin(a)) * r)
		ring.width = 1.0
		ring.default_color = Color(color.r, color.g, color.b, 0.16 / mult)
		ring.z_index = 1
		_room_root.add_child(ring)

func _floor_arrow(pos: Vector2) -> void:
	var s = 22.0
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2( s,  0), Vector2(-s * 0.4,  s * 0.55),
		Vector2(-s * 0.4, -s * 0.55),
	])
	arrow.color = Color(0.62, 0.10, 0.08, 0.32)
	arrow.position = pos; arrow.z_index = 1
	_room_root.add_child(arrow)

func _barrel(pos: Vector2, color: Color = Color(0.22, 0.38, 0.22)) -> void:
	var sb = StaticBody2D.new()
	sb.position = pos
	sb.collision_layer = 5; sb.collision_mask = 0
	var r = 14.0
	var steps = 8
	var pts = PackedVector2Array()
	for i in steps:
		var a = (float(i) / float(steps)) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
	var body = Polygon2D.new()
	body.polygon = pts; body.color = color; body.z_index = 2
	sb.add_child(body)
	var top = Polygon2D.new()  # 상단 테두리 강조
	top.polygon = PackedVector2Array([Vector2(-r,  -r*0.35), Vector2(r, -r*0.35),
									   Vector2(r,  -r*0.15), Vector2(-r, -r*0.15)])
	top.color = color.darkened(0.35); top.z_index = 3
	sb.add_child(top)
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new(); shp.radius = r
	col.shape = shp; sb.add_child(col)
	sb.add_child(_make_occluder(pts))
	_room_root.add_child(sb)

func _crate(pos: Vector2, w: float = 18.0, h: float = 15.0,
			color: Color = Color(0.42, 0.32, 0.18)) -> void:
	var sb = StaticBody2D.new()
	sb.position = pos
	sb.collision_layer = 5; sb.collision_mask = 0
	var pts = _rect_pts(-w, -h, w, h)
	var body = Polygon2D.new()
	body.polygon = pts; body.color = color; body.z_index = 2
	sb.add_child(body)
	# X 마킹
	for sign_x in [-1.0, 1.0]:
		var xl = Line2D.new()
		xl.add_point(Vector2(sign_x * w * 0.65, -h * 0.65))
		xl.add_point(Vector2(-sign_x * w * 0.65, h * 0.65))
		xl.width = 1.5; xl.default_color = color.darkened(0.45); xl.z_index = 3
		sb.add_child(xl)
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new(); shp.size = Vector2(w * 2, h * 2)
	col.shape = shp; sb.add_child(col)
	sb.add_child(_make_occluder(pts))
	_room_root.add_child(sb)

func _pipe(p1: Vector2, p2: Vector2, width: float = 5.0,
		   color: Color = Color(0.30, 0.30, 0.34)) -> void:
	var line = Line2D.new()
	line.add_point(p1); line.add_point(p2)
	line.width = width; line.default_color = color; line.z_index = 1
	_room_root.add_child(line)

func _warning_sign(pos: Vector2) -> void:
	var diamond = Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0,-18), Vector2(14,0), Vector2(0,18), Vector2(-14,0)])
	diamond.color = Color(0.88, 0.62, 0.04, 0.88)
	diamond.position = pos; diamond.z_index = 2
	_room_root.add_child(diamond)
	var inner = Polygon2D.new()  # ! 기호
	inner.polygon = PackedVector2Array([Vector2(0,-9), Vector2(3.5,3), Vector2(-3.5,3)])
	inner.color = Color(0.06, 0.05, 0.02, 0.9)
	inner.position = pos; inner.z_index = 3
	_room_root.add_child(inner)

func _blood_stain(pos: Vector2, radius: float = 30.0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(abs(pos.x * 17.0 + pos.y * 23.0))
	var steps = 12
	var pts = PackedVector2Array()
	for i in steps:
		var a = (float(i) / float(steps)) * TAU
		var r = radius * rng.randf_range(0.45, 1.0)
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	var stain = Polygon2D.new()
	stain.polygon = pts
	stain.color = Color(0.20, 0.03, 0.03, 0.60)
	stain.z_index = 1
	_room_root.add_child(stain)

# ─────────────────────────────
# 상자 / 오브젝트 배치
# ─────────────────────────────
func _spawn_boxes() -> void:
	# 은신 박스 — 구역별 전략적 배치
	# Zone A (안전, 여유): 2개
	# Zone B (어둠, 스트레스 해소 포인트): 1개
	# Zone D (메아리, 숨어야 하지만 소음 딜레마): 2개
	# Zone E (파수꾼, 영토 사이 틈새): 1개
	# Zone F (접근로, 생존 거점): 2개
	var box_positions = [
		Vector2(620,  700),   # Zone A — 진입 직후
		Vector2(900,  380),   # Zone A — 러커 옆 안전지대
		Vector2(1350, 700),   # Zone A/B 경계
		Vector2(2250, 500),   # Zone B 깊숙이
		Vector2(500,  1700),  # Zone D — 전령 피신처
		Vector2(1500, 2200),  # Zone D — 진동체 우회로
		Vector2(2400, 2000),  # Zone D/E 경계
		Vector2(2450, 2550),  # Zone E — 파수꾼 영토 서쪽
		Vector2(600,  3000),  # Zone F — 접근로 초입
		Vector2(1900, 3300),  # Zone F — 접근로 깊은 곳
	]
	for pos in box_positions:
		var box = BoxScene.instantiate()
		box.position = pos
		_room_root.add_child(box)

	# 연구원 시신 + 열쇠 (처음엔 숨겨짐, 중요 기억 5개 수집 후 공개)
	var key = KeyPickupScene.instantiate()
	key.position = KEY_POS
	_room_root.add_child(key)

	# 보스 문 (시작 지점 근처 — 기본 숨김, 열쇠 획득 시 공개)
	var door = BossDoorScene.instantiate()
	door.position = Vector2(BOSS_DOOR_X, BOSS_DOOR_Y)
	_room_root.add_child(door)
	_boss_door_ref = door
	key.key_taken.connect(func():
		if is_instance_valid(_boss_door_ref):
			_boss_door_ref.show_door()
	)

# ─────────────────────────────
# 아이템 배치
# ─────────────────────────────
func _spawn_items() -> void:
	# ── 기억 조각 3개 ──
	for pos in [Vector2(1100, 600), Vector2(2800, 1400), Vector2(3100, 650)]:
		var item = ItemScene.instantiate()
		item.item_type = 7   # ItemType.MEMORY_SHARD
		item.position  = pos
		_room_root.add_child(item)

	# ── 재료 아이템 ──
	_spawn_material_items()

	_spawn_memory_fragments()

	# ── 스킬 시작 재료 지급 ──
	# craft_memory: 런 시작 시 재료 아이템 2개 지급 (안전구역 근처)
	# material_sense: 런 시작 시 재료 아이템 1개 지급
	var bonus_mat_count = 0
	if GlobalSave.has_skill("craft_memory"): bonus_mat_count += 2
	if GlobalSave.has_skill("material_sense"): bonus_mat_count += 1
	if bonus_mat_count > 0:
		const MAT_TYPES = [8, 9, 10, 11, 12]  # WIRE CHEM METAL CLOTH CELL
		const START_POS = Vector2(280, 550)     # 안전구역 내부 중심
		for i in bonus_mat_count:
			var mat_item = ItemScene.instantiate()
			mat_item.item_type = MAT_TYPES[randi() % MAT_TYPES.size()]
			mat_item.position  = START_POS + Vector2(randf_range(-40, 40), randf_range(-30, 30))
			_room_root.add_child(mat_item)


func _build_secure_storage() -> void:
	# Zone D 동쪽 보안 보관실
	# 방: x=1960~2220, y=2450~2710 (260×260)  /  입구: 서쪽 벽 y=2550~2630 (80px)
	# 접근: x=1950 이동 통로 동쪽에서 남하 후 서쪽 입구 진입
	const RX  = 1960; const RY  = 2450
	const RW  = 260;  const RH  = 260
	const EY1 = 2550; const EY2 = 2630  # 서쪽 벽 입구 y 범위 (80px)

	# 바닥 (어두운 금속)
	_rv(RX, RY, RX + RW, RY + RH, Color(0.10, 0.08, 0.12), -1)

	# 경고 줄무늬 (입구 왼쪽 접근로)
	for i in 3:
		var sx = RX - 10 - i * 18
		_rv(sx, EY1, sx + 10, EY2, Color(0.55, 0.42, 0.05, 0.45), 0)

	# 벽 (입구 = 서쪽 벽에 80px 갭)
	_rw(RX,            RY,          RX + RW,   RY + IWT)        # 상단
	_rw(RX + RW - IWT, RY,          RX + RW,   RY + RH)         # 우
	_rw(RX,            RY + RH - IWT, RX + RW, RY + RH)         # 하단
	_rw(RX,            RY,          RX + IWT,  EY1)              # 좌 위
	_rw(RX,            EY2,         RX + IWT,  RY + RH)          # 좌 아래

	# 입구 양쪽 기둥
	_rp(RX - 12, EY1 - 12, 14, 14)
	_rp(RX - 12, EY2 - 2,  14, 14)

	# 내부 조명 (황금빛)
	_pl(Vector2(RX + RW * 0.5, RY + RH * 0.4),
		null, Color(0.90, 0.70, 0.20), 1.1, 3.5)

	# 벽면 표지판
	var sign = Label.new()
	sign.text = "[ STORAGE — CLEARED ]"
	sign.add_theme_font_size_override("font_size", 11)
	sign.add_theme_color_override("font_color", Color(0.60, 0.45, 0.12, 0.80))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.position = Vector2(RX + IWT + 5, RY + IWT + 8)
	sign.size     = Vector2(RW - IWT - 15, 18)
	sign.z_index  = 3
	_room_root.add_child(sign)

	# 내부 선반 장식
	_rv(RX + IWT + 10, RY + IWT + 40, RX + RW - IWT - 10, RY + IWT + 52,
		Color(0.22, 0.18, 0.14), 1)
	_rv(RX + IWT + 10, RY + IWT + 80, RX + RW - IWT - 10, RY + IWT + 92,
		Color(0.22, 0.18, 0.14), 1)


func _build_zone_f_lab() -> void:
	# Zone F 동쪽 끝 보안 실험실 (열쇠 방)
	# 방: x:4600–5100, y:3500–3700  /  북쪽 입구: x:4750–4950 (200px)
	const LX = 4600; const LY = 3500
	const LW = 500;  const LH = 200
	const EX1 = 4750; const EX2 = 4950  # 북쪽 입구 x 범위

	# 바닥 (어두운 금속)
	_rv(LX + IWT, LY + IWT, LX + LW - IWT, LY + LH - IWT, Color(0.07, 0.05, 0.09), -1)

	# 입구 위쪽 경고 줄무늬 (북쪽 외부)
	for i in 3:
		var sy = LY - 10 - i * 18
		_rv(EX1, sy, EX2, sy + 10, Color(0.55, 0.42, 0.05, 0.45), 0)

	# 내부 조명 (황금빛)
	_pl(Vector2(LX + LW * 0.5, LY + LH * 0.5),
		null, Color(0.90, 0.70, 0.20), 1.2, 4.0)

	# 벽면 표지판
	var sign = Label.new()
	sign.text = "[ SECURE LAB — F ]"
	sign.add_theme_font_size_override("font_size", 10)
	sign.add_theme_color_override("font_color", Color(0.60, 0.45, 0.12, 0.80))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.position = Vector2(LX + 60, LY + IWT + 8)
	sign.size = Vector2(LW - 120, 18)
	sign.z_index = 3
	_room_root.add_child(sign)

	# 내부 선반 장식
	_rv(LX + IWT + 10, LY + IWT + 40, LX + LW - IWT - 10, LY + IWT + 52,
		Color(0.22, 0.18, 0.14), 1)
	_rv(LX + IWT + 10, LY + IWT + 85, LX + LW - IWT - 10, LY + IWT + 97,
		Color(0.22, 0.18, 0.14), 1)

	# 입구 양쪽 기둥 (북쪽 벽 외부)
	_rp(EX1 - 14, LY - 14, 14, 14)
	_rp(EX2,      LY - 14, 14, 14)

func _build_safe_zone() -> void:
	# ── 안전구역 방 (Zone A 서쪽 구석) ──
	# 내부: x=90~470, y=370~730  /  벽 두께 30
	# 북쪽에 140px 출입구 (x=155~295) — 플레이어가 남쪽으로 직진하면 진입
	const SX0 = 60.0;  const SX1 = 500.0
	const SY0 = 340.0; const SY1 = 760.0
	const DOOR_X0 = 155.0; const DOOR_X1 = 295.0  # 북쪽 출입구 x 범위 (140px)
	var cx = (SX0 + SX1) * 0.5   # 280
	var cy = (SY0 + SY1) * 0.5   # 550

	# 바닥 컬러 (안전구역은 약간 밝은 초록빛 바닥)
	_rv(SX0 + 30, SY0 + 30, SX1 - 30, SY1 - 30, Color(0.13, 0.19, 0.13, 1.0), 0)

	# 벽 4면 (북쪽 출입구 제외)
	_rw(SX0,      SY0, DOOR_X0, SY0 + 30)        # 북쪽 벽 (왼)
	_rw(DOOR_X1,  SY0, SX1,     SY0 + 30)        # 북쪽 벽 (오른)
	_rw(SX0, SY1 - 30, SX1,     SY1)             # 남쪽 벽
	_rw(SX0,      SY0, SX0 + 30, SY1)            # 서쪽 벽
	_rw(SX1 - 30, SY0, SX1,     SY1)             # 동쪽 벽 (완전)

	# 출입구 마커 (바닥에 초록 테두리선)
	_rv(DOOR_X0, SY0 + 28, DOOR_X1, SY0 + 32, Color(0.30, 0.80, 0.40, 0.55), 3)

	# 안전구역 조명 — 밝고 따뜻한 흰빛 천장등 3개
	var ltex = _make_round_light_tex(128)
	_pl(Vector2(cx, cy),          ltex, Color(0.85, 1.0, 0.88), 2.8, 4.5)
	_pl(Vector2(cx - 110, cy - 80), ltex, Color(0.80, 0.95, 0.82), 1.8, 3.0)
	_pl(Vector2(cx + 110, cy + 80), ltex, Color(0.80, 0.95, 0.82), 1.8, 3.0)

	# 안전구역 라벨 (내부 상단)
	var sign_lbl = Label.new()
	sign_lbl.text = "[ 안전구역 ]"
	sign_lbl.add_theme_font_size_override("font_size", 13)
	sign_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65, 0.90))
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.position = Vector2(cx - 55, SY0 + 38)
	sign_lbl.z_index  = 5
	_room_root.add_child(sign_lbl)

	# SafeZone Area2D — 내부 + 출입구 통로 커버
	var sz_script = load("res://scenes/safe_zone.gd")
	var sz = Area2D.new()
	sz.set_script(sz_script)
	sz.position = Vector2(cx, cy - 10)
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(SX1 - SX0 - 20, SY1 - SY0 + 30)
	cs.shape  = rect
	sz.add_child(cs)
	_room_root.add_child(sz)

	# 제작대 — 방 중앙
	var ct_script = load("res://scenes/crafting_table.gd")
	var ct = StaticBody2D.new()
	ct.set_script(ct_script)
	ct.position = Vector2(cx, cy)
	_room_root.add_child(ct)

# ─────────────────────────────
# 재료 아이템 스폰
# ─────────────────────────────
func _spawn_material_items() -> void:
	# ItemType 값 직접 사용 (enum 불필요)
	const WIRE=8; const CHEM=9; const METAL=10; const CLOTH=11; const CELL=12; const EXP=13; const FLARE=4

	var mats = [
		# 신호탄 — 구역별 1개 (탐색 보상)
		[FLARE, Vector2( 900,  600)],   # Zone A 안전구역 동쪽
		[FLARE, Vector2(1850, 1050)],   # Zone B 비상 대피소 내부
		[FLARE, Vector2(3200,  680)],   # Zone C L형 엄폐물 1 옆
		[FLARE, Vector2( 580, 2560)],   # Zone D 격리 부속실
		[FLARE, Vector2(4200, 1900)],   # Zone E L형 장벽 후방
		# Zone A
		[METAL, Vector2( 820, 300)], [METAL, Vector2( 350, 820)],
		[WIRE,  Vector2( 680, 450)], [WIRE,  Vector2(1250, 780)],
		# Zone B
		[WIRE,  Vector2(1550, 250)], [WIRE,  Vector2(2300, 750)],
		[CHEM,  Vector2(1700, 680)], [METAL, Vector2(2100, 380)],
		# Zone C
		[CELL,  Vector2(3100, 500)], [CELL,  Vector2(4100, 350)],
		[WIRE,  Vector2(3700, 800)], [METAL, Vector2(4600, 700)],
		# Zone D
		[CHEM,  Vector2( 450, 1750)],[CHEM,  Vector2(1000, 2300)],
		[CLOTH, Vector2( 700, 2050)],[CLOTH, Vector2(1600, 1700)],
		[CHEM,  Vector2(2100, 2700)],
		[CELL,  Vector2(2090, 2580)],  # Zone D 보관실 대체 보상
		# Zone E
		[CELL,  Vector2(2900, 1700)],[CELL,  Vector2(3800, 2200)],
		[METAL, Vector2(4200, 1600)],[WIRE,  Vector2(3300, 2400)],
		# Zone F (희귀 포함)
		[CLOTH, Vector2( 700, 3100)],[CLOTH, Vector2(1800, 3400)],
		[EXP,   Vector2(1100, 3200)],[EXP,   Vector2(2500, 3050)],
		[CHEM,  Vector2( 400, 3500)],[METAL, Vector2(2000, 3600)],
	]
	for entry in mats:
		var item = ItemScene.instantiate()
		item.item_type = entry[0]
		item.position  = entry[1]
		_room_root.add_child(item)

func respawn_memory_items() -> void:
	for child in _room_root.get_children():
		if child.get_script() != null:
			var path = child.get_script().resource_path
			if "memory_fragment" in path or "important_memory" in path:
				child.queue_free()
	await get_tree().process_frame
	_spawn_memory_fragments()

func _spawn_memory_fragments() -> void:
	var Fragment = load("res://scenes/memory_fragment.gd")
	var frag_positions = [
		Vector2(380,  420), Vector2(780,  950),   # Zone A
		Vector2(1450, 250), Vector2(2200, 820),   # Zone B
		Vector2(3000, 400), Vector2(4200, 780),   # Zone C
		Vector2(350,  1550), Vector2(1200, 2300), # Zone D
		Vector2(2600, 1900), Vector2(3500, 2100), # Zone E
		Vector2(1100, 3050), Vector2(2500, 3400), # Zone F
	]
	for i in frag_positions.size():
		var frag = Fragment.new()
		frag.setup("frag_%d" % i)
		frag.position = frag_positions[i]
		_room_root.add_child(frag)

	var log_data = [
		{ "id": "shade_seen",    "line": 1, "pos": Vector2(650,  350)  },
		{ "id": "ambusher_seen", "line": 0, "pos": Vector2(1800, 700)  },
		{ "id": "stalker_seen",  "line": 1, "pos": Vector2(3600, 500)  },
		{ "id": "herald_seen",   "line": 0, "pos": Vector2(700,  1700) },
		{ "id": "brood_seen",    "line": 1, "pos": Vector2(1400, 2550) },
		{ "id": "sentinel_seen", "line": 0, "pos": Vector2(2900, 2400) },
		{ "id": "charger_seen",  "line": 1, "pos": Vector2(4300, 2200) },
		{ "id": "colossus_seen", "line": 1, "pos": Vector2(2700, 3300) },
	]
	for entry in log_data:
		var log_frag = Fragment.new()
		log_frag.setup_as_log("log_%s_%d" % [entry["id"], entry["line"]], entry["id"], entry["line"])
		log_frag.position = entry["pos"]
		_room_root.add_child(log_frag)

	var IMem = load("res://scenes/important_memory.gd")
	var imem_data = [
		{ "id": "zone_b", "pos": Vector2(2680, 280)  },
		{ "id": "zone_c", "pos": Vector2(4900, 750)  },
		{ "id": "zone_d", "pos": Vector2(250,  2750) },
		{ "id": "zone_e", "pos": Vector2(4650, 1450) },
		{ "id": "zone_f", "pos": Vector2(4800, 3420) },
	]
	for entry in imem_data:
		var imem = IMem.new()
		imem.setup(entry["id"])
		imem.position = entry["pos"]
		_room_root.add_child(imem)

# ═════════════════════════════
# 보스전
# ═════════════════════════════

## 보스 문이 열리면 boss_door.gd에서 호출
func _on_boss_door_opened() -> void:
	if _boss_fight_active: return
	_panels_activated = 0
	_panels.clear()
	_panel_hud_dots.clear()
	_boss_intro()

func _boss_intro() -> void:
	var player = get_tree().get_first_node_in_group("player")

	# 보스방 밖 모든 적 즉시 동결
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_in_group("boss"):
			enemy.set_physics_process(false)

	# 플레이어 동결 (연출 중 이동 불가)
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

	# 화면 암전 (0.6초)
	if _fade_rect:
		var tw = create_tween()
		tw.tween_property(_fade_rect, "color", Color(0, 0, 0, 1.0), 0.6)
		await tw.finished

	# ── 암전 중 ──
	# 아레나 벽 생성
	_build_arena_walls()

	# 플레이어를 아레나 입구(별도 좌표)로 텔레포트
	if player:
		player.global_position = Vector2(ARENA_CX, ARENA_Y + IWT + 80.0)
		player.velocity = Vector2.ZERO

	# 카메라 한계를 아레나 범위로 교체 — 암전 중이므로 즉시 스냅해도 안 보임
	var _cam = get_viewport().get_camera_2d()
	if _cam:
		_cam.limit_left   = ARENA_X - 100
		_cam.limit_top    = ARENA_Y - 100
		_cam.limit_right  = ARENA_X + ARENA_W + 100
		_cam.limit_bottom = ARENA_Y + ARENA_H + 100
		_cam.reset_smoothing()

	# 콜로서스 스폰 (AI 꺼둠 — 화면 복귀 전 공격 차단)
	_colossus_ref = ColossusScene.instantiate()
	_colossus_ref.position = Vector2(
		ARENA_CX,
		ARENA_Y + ARENA_H * 0.80
	)
	_colossus_ref.patrol_bounds = Rect2(
		ARENA_X + IWT, ARENA_Y + IWT,
		ARENA_W - IWT * 2, ARENA_H - IWT * 2
	)
	_colossus_ref.set_physics_process(false)
	_room_root.add_child(_colossus_ref)
	_colossus_ref.boss_died.connect(_on_boss_died)

	await get_tree().create_timer(1.0).timeout

	# 화면 복귀 (0.8초)
	if _fade_rect:
		var tw2 = create_tween()
		tw2.tween_property(_fade_rect, "color", Color(0, 0, 0, 0.0), 0.8)
		await tw2.finished

	# 플레이어 동결 해제
	if player:
		player.set_physics_process(true)

	# 0.5초 유예 후 콜로서스 AI 활성화
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(_colossus_ref):
		_colossus_ref.set_physics_process(true)

	_spawn_boss_room_contents()
	_spawn_boss_panels()

	if player:
		_start_boss_fight(player)


func _spawn_boss_room_contents() -> void:
	var cx = ARENA_CX
	var cy = ARENA_Y + ARENA_H / 2

	# 상자 3개
	for pos in [Vector2(cx - 280, cy - 150), Vector2(cx + 210, cy - 190), Vector2(cx - 80, cy + 240)]:
		var box = BoxScene.instantiate()
		box.position = pos
		_room_root.add_child(box)

	# 기둥 4개 (코너) — 2페이즈 진입 시 파괴 대상
	for pos in [Vector2(cx - 330, cy - 290), Vector2(cx + 330, cy - 290),
				Vector2(cx - 330, cy + 290), Vector2(cx + 330, cy + 290)]:
		_pillar(pos, 20).add_to_group("arena_pillar")

	# 비상 물자: 아드레날린 ×2, 신호탄 ×1
	for ipos in [Vector2(cx - 190, cy - 255), Vector2(cx + 215, cy + 265)]:
		var adr = ItemScene.instantiate()
		adr.item_type = 1  # ItemType.ADRENALINE
		adr.position  = ipos
		_room_root.add_child(adr)
	var flr = ItemScene.instantiate()
	flr.item_type = 4  # ItemType.FLARE
	flr.position  = Vector2(cx, cy - 305)
	_room_root.add_child(flr)

func _spawn_boss_panels() -> void:
	var cx = float(ARENA_CX)
	var cy = float(ARENA_Y + ARENA_H / 2)

	var positions = [
		Vector2(ARENA_X + IWT + 22.0, cy),
		Vector2(ARENA_X + ARENA_W - IWT - 22.0, cy),
		Vector2(cx, ARENA_Y + ARENA_H - IWT - 22.0),
	]

	for pos in positions:
		var panel = Node2D.new()
		panel.set_script(ContainmentPanelScript)
		panel.position = pos
		_room_root.add_child(panel)
		panel.panel_activated.connect(_on_panel_activated)
		_panels.append(panel)

func _start_boss_fight(player) -> void:
	if _boss_fight_active: return
	_boss_fight_active = true
	if is_instance_valid(_colossus_ref):
		if "_health_root" in _colossus_ref:
			_colossus_ref._health_root.visible = false
		_colossus_ref.boss_mode = true
	if is_instance_valid(player) and player.has_method("activate_boss_shield"):
		player.activate_boss_shield()
	_create_boss_hud()
	# 보스 BGM 시작
	if not _boss_bgm_active and _bgm_player and _boss_bgm_player:
		_boss_bgm_active = true
		var stream = load("res://assets/bossf.MP3")
		if stream is AudioStreamMP3:
			stream.loop = true
		_boss_bgm_player.stream = stream
		_boss_bgm_player.volume_db = 0.0
		_boss_bgm_player.play()
		var tw = create_tween()
		tw.tween_property(_bgm_player, "volume_db", -80.0, 1.5)

func _create_boss_hud() -> void:
	_boss_hud_layer = CanvasLayer.new()
	_boss_hud_layer.layer = 9
	add_child(_boss_hud_layer)

	var vp_w   = get_viewport().get_visible_rect().size.x
	var margin = 180
	_boss_bar_full_w = vp_w - margin * 2

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_hud_layer.add_child(root)

	# 상단 배치 — title + bar, 총 높이 52px
	var bg = ColorRect.new()
	bg.color    = Color(0.06, 0.02, 0.02, 0.88)
	bg.position = Vector2(margin - 10, 6)
	bg.size     = Vector2(_boss_bar_full_w + 20, 52)
	root.add_child(bg)

	var title = Label.new()
	title.text = "COLOSSUS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	title.position = Vector2(margin - 10, 8)
	title.size     = Vector2(_boss_bar_full_w + 20, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var bar_bg = ColorRect.new()
	bar_bg.color    = Color(0.18, 0.04, 0.04)
	bar_bg.position = Vector2(margin, 28)
	bar_bg.size     = Vector2(_boss_bar_full_w, 22)
	root.add_child(bar_bg)

	_boss_hud_fill = ColorRect.new()
	_boss_hud_fill.color    = Color(0.85, 0.10, 0.10)
	_boss_hud_fill.position = Vector2(margin, 28)
	_boss_hud_fill.size     = Vector2(_boss_bar_full_w, 22)
	root.add_child(_boss_hud_fill)

	_boss_hud_label = Label.new()
	_boss_hud_label.add_theme_font_size_override("font_size", 13)
	_boss_hud_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	_boss_hud_label.position = Vector2(margin, 28)
	_boss_hud_label.size     = Vector2(_boss_bar_full_w, 22)
	_boss_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hud_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_boss_hud_label)

func _update_boss_hud() -> void:
	if not _boss_fight_active or not _boss_hud_fill: return
	if not is_instance_valid(_colossus_ref) or not _colossus_ref.is_inside_tree():
		_end_boss_fight()
		_on_boss_defeated()
		return
	var hp     = float(_colossus_ref.current_health)
	var max_hp = float(_colossus_ref.max_health)
	var ratio  = clamp(hp / max_hp, 0.0, 1.0)
	var phase2 = "_phase" in _colossus_ref and _colossus_ref._phase == 2
	_boss_hud_fill.size.x = _boss_bar_full_w * ratio
	if phase2:
		_boss_hud_fill.color = Color(lerp(0.6, 1.0, 1.0 - ratio), lerp(0.55, 0.15, 1.0 - ratio), 0.05)
	else:
		_boss_hud_fill.color = Color(lerp(0.15, 0.85, 1.0 - ratio), lerp(0.85, 0.08, 1.0 - ratio), 0.05)
	if _boss_hud_label:
		var phase_str = "  [ 2페이즈 — 벽으로 유도! ]" if phase2 else ""
		_boss_hud_label.text = "%d / %d%s" % [int(hp), int(max_hp), phase_str]
	if hp <= 0 and phase2:
		var kp = GlobalSave.award_kp("boss")
		if kp > 0: _show_kp_popup("콜로서스 처치  +%dp" % kp, Color(1.0, 0.85, 0.2))
		_end_boss_fight()
		_on_boss_defeated()

func _end_boss_fight() -> void:
	if not _boss_fight_active: return
	_boss_fight_active = false
	_panel_hud_dots.clear()
	if is_instance_valid(_boss_hud_layer):
		var tw = create_tween()
		tw.tween_property(_boss_hud_layer, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_boss_hud_layer.queue_free)
		_boss_hud_layer = null
		_boss_hud_fill  = null
		_boss_hud_label = null

func _on_panel_activated() -> void:
	_panels_activated += 1

	_show_kp_popup("격리 패널 활성화 (%d/3)" % _panels_activated, Color(0.4, 1.2, 0.7))

	# 콜로서스 약화
	if is_instance_valid(_colossus_ref) and _colossus_ref.has_method("apply_panel_weakening"):
		_colossus_ref.apply_panel_weakening(_panels_activated)

	if _panels_activated >= 3:
		_on_all_panels_activated()

func _on_all_panels_activated() -> void:
	# 패널 3개 활성화 = KP 보너스만. 보스전은 계속 (격파가 목표).
	var kp = GlobalSave.award_kp("panel_clear")
	if kp > 0: _show_kp_popup("패널 전체 활성화  +%dp" % kp, Color(0.4, 1.2, 0.7))
	_show_kp_popup("콜로서스를 격파하라!", Color(1.0, 0.5, 0.2))

func _on_boss_defeated() -> void:
	_show_kp_popup("콜로서스 격리 성공!", Color(0.4, 1.4, 0.55))

# ═════════════════════════════
# 플레이어 스폰
# ═════════════════════════════

func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	_player.position = Vector2(200, 200)
	add_child(_player)
	call_deferred("_setup_camera_limits")

func _setup_camera_limits() -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = MW + 200
	cam.limit_bottom = MH + 200

# ═════════════════════════════
# HUD
# ═════════════════════════════

func _setup_world_hud() -> void:
	var cl = CanvasLayer.new()
	cl.layer = 15
	cl.name  = "WorldHUD"
	add_child(cl)

	var ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(ctrl)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(_fade_rect)

	var tw = create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.6)

# ═════════════════════════════
# 배경 / 후처리
# ═════════════════════════════

func _build_static_bg() -> void:
	var bg = Polygon2D.new()
	bg.polygon = _rect_pts(-500, -500, MW + 500, MH + 500)
	bg.color   = C_BG
	bg.z_index = -10
	add_child(bg)

func _setup_postprocess() -> void:
	var mat = ShaderMaterial.new()
	mat.shader = GlitchShader
	mat.set_shader_parameter("intensity", 0.0)
	var glitch = ColorRect.new()
	glitch.name = "GlitchRect"
	glitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch.material   = mat
	glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch.color      = Color(1.0, 1.0, 1.0, 0.06)
	var post = CanvasLayer.new()
	post.name  = "PostProcess"
	post.layer = 10
	post.add_child(glitch)
	add_child(post)

func _setup_canvas_modulate() -> void:
	var cm = CanvasModulate.new()
	cm.color = Color(0.09, 0.08, 0.12, 1.0)   # 공포 분위기 암도
	add_child(cm)

func _start_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream    = BGMStream
	_bgm_player.volume_db = -5.0
	add_child(_bgm_player)
	_bgm_player.play()

	_boss_bgm_player = AudioStreamPlayer.new()
	_boss_bgm_player.volume_db = -80.0
	add_child(_boss_bgm_player)
	# 보스 BGM은 보스전 시작 시 play() — 미리 재생하면 루프 없이 끝남

func _on_boss_died() -> void:
	if not _boss_bgm_active: return
	_boss_bgm_active = false
	if not _bgm_player or not _boss_bgm_player: return
	var tw = create_tween().set_parallel()
	tw.tween_property(_bgm_player,      "volume_db", -5.0, 2.0)
	tw.tween_property(_boss_bgm_player, "volume_db", -80.0, 2.0)
	await tw.finished
	_boss_bgm_player.stop()

# ═════════════════════════════
# 헬퍼: 기하 / 시각
# ═════════════════════════════

func _rw(x1: float, y1: float, x2: float, y2: float) -> void:
	if x2 <= x1 or y2 <= y1: return
	var body = StaticBody2D.new()
	body.collision_layer = 5
	body.collision_mask  = 0
	var pts = _rect_pts(x1, y1, x2, y2)
	var sh  = CollisionPolygon2D.new(); sh.polygon = pts
	body.add_child(sh)
	var vis = Polygon2D.new(); vis.polygon = pts; vis.color = C_WALL
	body.add_child(vis)
	var cap = Polygon2D.new()
	cap.polygon = _rect_pts(x1, y1, x2, y1 + 5); cap.color = C_WALL_TOP
	body.add_child(cap)
	body.add_child(_make_occluder(pts))
	_room_root.add_child(body)

func _rp(x: float, y: float, w: float, h: float) -> void:
	var body = StaticBody2D.new()
	body.collision_layer = 5
	body.collision_mask  = 0
	var pts = _rect_pts(x, y, x + w, y + h)
	var sh  = CollisionPolygon2D.new(); sh.polygon = pts
	body.add_child(sh)
	var base = Polygon2D.new(); base.polygon = pts; base.color = C_PILLAR
	body.add_child(base)
	var cap = Polygon2D.new()
	cap.polygon = _rect_pts(x, y, x + w, y + 7); cap.color = C_PILLAR_CAP
	body.add_child(cap)
	body.add_child(_make_occluder(pts))
	_room_root.add_child(body)

func _rv(x1: float, y1: float, x2: float, y2: float, color: Color, z: int = 0) -> void:
	var poly = Polygon2D.new()
	poly.polygon = _rect_pts(x1, y1, x2, y2)
	poly.color   = color
	poly.z_index = z
	_room_root.add_child(poly)

func _make_occluder(pts: PackedVector2Array) -> LightOccluder2D:
	var op = OccluderPolygon2D.new(); op.polygon = pts
	var oc = LightOccluder2D.new()
	oc.occluder = op; oc.occluder_light_mask = 1
	return oc

func _rect_pts(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x1, y1), Vector2(x2, y1),
		Vector2(x2, y2), Vector2(x1, y2),
	])

# ─────────────────────────────
# 조명 헬퍼
# ─────────────────────────────
func _pl(pos: Vector2, tex: ImageTexture, color: Color, energy: float, scale: float) -> PointLight2D:
	var light = PointLight2D.new()
	light.position     = pos
	light.texture      = tex
	light.color        = color
	light.energy       = energy
	light.texture_scale = scale
	light.shadow_enabled = false
	_room_root.add_child(light)
	return light

func _flicker(light: PointLight2D, base_energy: float) -> void:
	var tw = light.create_tween().set_loops()
	tw.tween_property(light, "energy", base_energy * 0.30, 0.07)
	tw.tween_property(light, "energy", base_energy,        0.11)
	tw.tween_interval(randf_range(1.2, 3.2))
	tw.tween_property(light, "energy", base_energy * 0.15, 0.04)
	tw.tween_property(light, "energy", base_energy * 0.75, 0.06)
	tw.tween_property(light, "energy", base_energy,        0.09)
	tw.tween_interval(randf_range(2.0, 5.5))

func _make_round_light_tex(size: int) -> ImageTexture:
	var half = float(size) / 2.0
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in range(size):
		for y in range(size):
			var dx = float(x) - half
			var dy = float(y) - half
			var dist = sqrt(dx * dx + dy * dy)
			if dist >= half: continue
			var alpha = pow(1.0 - dist / half, 1.5)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

# ─────────────────────────────
# 타일 텍스처 생성
# ─────────────────────────────
func _make_tile_concrete(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = 1337
	var half = size / 2
	for y in range(size):
		for x in range(size):
			var v = 0.50 + (rng.randf() - 0.5) * 0.08
			if x == 0 or y == 0 or x == half or y == half:
				v -= 0.20
			elif x == 1 or y == 1 or x == half + 1 or y == half + 1:
				v -= 0.08
			img.set_pixel(x, y, Color(v, v, v, clamp(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _make_tile_metal(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = 2468
	var sm1 = size - 1
	for y in range(size):
		for x in range(size):
			var v = 0.55 + (rng.randf() - 0.5) * 0.04
			if x == 0 or y == 0 or x == sm1 or y == sm1:
				v -= 0.25
			elif x == 1 or y == 1 or x == sm1 - 1 or y == sm1 - 1:
				v -= 0.10
			v += float(x + y) / float(size * 2) * 0.06  # 대각 광택
			img.set_pixel(x, y, Color(v, v, v, clamp(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _make_tile_stone(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new(); rng.seed = 5050
	for y in range(size):
		for x in range(size):
			var v = 0.42 + (rng.randf() - 0.5) * 0.14
			var cr1 = fmod(abs(float(x) - float(y) * 0.65), 18.0) < 1.5
			var cr2 = fmod(abs(float(x) * 0.55 + float(y)), 22.0) < 1.5
			if cr1 or cr2: v -= 0.20
			img.set_pixel(x, y, Color(v, v, v, clamp(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _make_tile_grating(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var step = max(4, size / 4)
	var bar  = max(1, step / 4)
	for y in range(size):
		for x in range(size):
			var bx = (x % step) < bar
			var by = (y % step) < bar
			var v: float
			if bx and by:   v = 0.70  # 교차 리벳
			elif bx or by:  v = 0.45  # 격자 봉
			else:           v = 0.05  # 구멍
			img.set_pixel(x, y, Color(v, v, v, 0.92))
	return ImageTexture.create_from_image(img)

func _make_ambient_tex(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx  = float(size) * 0.5
	for y in size:
		for x in size:
			var d = Vector2(float(x), float(y)).distance_to(Vector2(cx, cx)) / cx
			var a = clamp(pow(1.0 - d, 1.6), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

# ═════════════════════════════
# KP 팝업
# ═════════════════════════════

func _show_kp_popup(text: String, color: Color) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	var cl   = player.get_node_or_null("CanvasLayer")
	if not cl: return
	var ctrl = cl.get_node_or_null("Control")
	if not ctrl: return
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left   = -320
	lbl.offset_right  = -16
	lbl.offset_top    = -110
	lbl.offset_bottom = -76
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ctrl.add_child(lbl)
	var tw = lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 36, 1.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.8)
	tw.tween_callback(lbl.queue_free)
