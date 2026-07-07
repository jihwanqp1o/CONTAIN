# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CONTAIN** (프로젝트명: comgegi_game) is a 2D survival horror roguelike built with Godot 4.6.

**Core Identity:**
- 제한된 자원과 환경에서 극도의 공포를 느끼는 생존 게임
- 플레이어는 반복적으로 죽으며 적 패턴을 익힌다 — 죽음이 정보다
- 무력감이 점진적 숙달로 바뀌는 로그라이크적 성취감
- 전투 없음. 지식, 은신, 자원 관리가 유일한 생존 수단

**Tech Stack:**
- **Engine:** Godot 4.6 (GDScript)
- **Rendering:** Forward Plus with D3D12 on Windows
- **Physics:** Jolt Physics
- **Platform:** Windows Desktop (export: `../컴퓨터 게임과 기술/comgegi.exe`)

---

## Project Structure

### Directory Layout

```
rr/
├── scenes/
│   ├── World.tscn / World.gd         # 메인 게임 레벨 (맵 생성, 적/아이템 스폰, 보스전)
│   ├── World.gdshader                 # 화면 글리치/왜곡 셰이더
│   ├── player.tscn / player.gd        # 플레이어 (이동, 스태미나, 공포, 손전등, 아이템, 도감, 독백)
│   ├── ui.tscn                        # 인게임 HUD (체력/스태미나/배터리/공포 바, 아이템 슬롯)
│   │                                  # Inventory: offset_top=560, offset_bottom=624 (화면 절대 좌표)
│   ├── main_menu.tscn / main_menu.gd  # 메인메뉴 (도감/도전/스킬트리 포함)
│   ├── game_over.tscn / game_over.gd  # 사망 화면
│   ├── game_clear.tscn / game_clear.gd # 클리어 화면
│   ├── GlobalSave.gd                  # 런 간 영속 저장 (autoload)
│   ├── SpecimenDB.gd                  # 실험체 데이터베이스 (autoload)
│   ├── game_state.gd                  # 씬 간 공유 상태 (killer_name, survival_time 등)
│   │
│   ├── ─ 적 ─
│   ├── lurker.tscn / lurker.gd        # ACU-07 "Echo" — 청각 감지, 빛 회피
│   ├── stalker.tscn / stalker.gd      # TRK-11 "Hound" — FOV 추적, 격노 시스템
│   ├── colossus.tscn / colossus.gd    # APEX "Colossus" — 보스, 돌진/포효/박스파괴/2페이즈
│   ├── ambusher.tscn / ambusher.gd    # 매복자 — 잠복 후 급습, 스폰 귀환
│   ├── sentinel.tscn / sentinel.gd    # 파수꾼 — 고정 감시, 충격파 발사, 무리 소환
│   ├── herald.tscn / herald.gd        # 전령 — 탐지 시 주변 전체 경보 브로드캐스트
│   ├── charger.tscn / charger.gd      # 돌격병 — FOV 감지, 고속 돌진
│   ├── brood.tscn / brood.gd          # 진동체 — 팩 군집, 알파/일반 구분, 스태미나 압박
│   │
│   ├── ─ 오브젝트 ─
│   ├── box.tscn / box.gd              # 은신 박스 (공포 감소, 보스에 의해 파괴 가능)
│   ├── item.tscn / item.gd            # 아이템 픽업 (enum 기반 다종 아이템)
│   ├── lantern.tscn / lantern.gd      # 배치형 랜턴 (최대 2개, 90초 지속)
│   ├── key_pickup.tscn / key_pickup.gd # 열쇠 (중요 기억 5개 수집 후 활성화)
│   ├── boss_door.tscn / boss_door.gd  # 보스 문 (열쇠 획득 시 출현)
│   ├── safe_zone.gd                   # 안전구역 (진입 시 모든 적 추격 중단)
│   ├── crafting_table.gd              # 제작대 (8종 레시피)
│   ├── terminal.gd                    # 터미널 (능력 강화 / 스킬 구매)
│   ├── containment_panel.gd           # 보스방 격리 패널 (E 홀드 활성화)
│   │
│   ├── ─ 투사체 ─
│   ├── flare_projectile.gd            # 신호탄 (SPEED=520, MAX_RANGE=1200, BANG_RADIUS=500)
│   ├── rock_projectile.gd             # 돌 투척
│   ├── emp_grenade.gd                 # EMP 수류탄 (200px 반경 3초 스턴)
│   ├── noise_device.gd                # 소음 장치 (400px 반경 20초 유인)
│   ├── colossus_rock.gd               # 콜로서스 투척 바위
│   │
│   ├── ─ 내러티브 ─
│   ├── memory_fragment.gd             # 기억 조각 (12개 + 연구 기록 8개, 서사 텍스트 작성 완료)
│   ├── important_memory.gd            # 중요한 기억 (5개, 핵심 서사 + 열쇠 위치 공개)
│   ├── specimen_icon.gd               # 도감 아이콘 UI 요소
│   │
│   └── clear_door.gd                  # 탈출 문 (보스 처치 후 활성화)
│
├── assets/
│   ├── bgm.mp3 / bgm2.mp3            # 배경음 (일반 / 심층부)
│   ├── bossf.mp3 / bosszab.mp3       # 보스전 BGM
│   ├── clear.mp3 / over.mp3 / main.mp3 # 클리어/사망/메뉴 BGM
│   ├── walking.mp3                    # 발소리
│   ├── sinho.mp3 / zab.mp3 / dolzin.mp3 / feer.mp3 # 적 효과음
│   ├── rock.mp3 / rock2.mp3          # 돌 투척음
│   ├── memo.mp3                       # 기억 조각 수집음
│   ├── die.mp3 / flee.mp3 / stam.mp3 # 플레이어 상태음
│   └── button.mp3 / button2.mp3 / start.mp3 # UI 효과음
│
├── project.godot                      # 프로젝트 설정 (1600×900, autoload 등록)
├── export_presets.cfg
├── [게임 기획서].md                    # 한국어 기획 문서
└── CLAUDE.md
```

---

## Key Systems

### Player (player.gd)

**이동 & 상태:**
- WASD 이동, 마우스 방향 조준
- 걷기 / 달리기 / 소진(피로) 3단계 속도
- 스태미나: 달리기 시 35/s 소모, 휴식 시 80/s 회복
- `COLLAPSE_SPEED=35`, `COLLAPSE_RECOVERY_THRESHOLD=25`, `EXHAUST_DEATH_DURATION=5.0`
- 단발 사망 (`take_damage()` → game_over 씬 전환)

**손전등:**
- F키 토글, 기본 배터리 소모 2.5/s (스킬로 감소 가능)
- 적 탐지 트리거 / 일부 적 약화 또는 격노 유발

**신호탄:**
- 좌클릭 발사, `THROW_MAX_RANGE=720px` (조준 한계), 실제 비행 `MAX_RANGE=1200px`
- 발사 가드: `_codex_open`, `_bag_open`, `crafting_table._ui_open`, `key_pickup._keypad_open`, `lore_popup` 그룹 존재 시 모두 차단

**도지:**
- `can_dodge` (스킬 해금 필요), 스태미나 25 소모
- `DODGE_DISTANCE=120px`, `DODGE_DURATION=0.13s`, `DODGE_COOLDOWN=1.5s`
- 퍼펙트 도지 윈도우 0.28s: 무적 0.20s + 스태미나 30 회복 + 속도 1.4배 1.5초

**은신/암살:**
- `can_sneak` / `can_assassinate` (스킬 해금 필요)
- `SNEAK_SPEED=90px/s`, `ASSASSINATION_RANGE=85px`
- 암살 성공 시 속도 1.3배 5초 부스트

**공포(Fear) 시스템:**
```
은신 중:
  주변 적 있음: -8/s    없음: -25/s (fear_reduction_in_box)
노출 중:
  추격 중(350px 내): +15~+45/s (거리 비례)
  근접(200px 내):    +5~+25/s
  혼자:              -5/s (fear_reduction_rate, 손전등 켜면 -12/s)

공포 효과:
  80+: UI 흔들림, 글리치 강도 상승
  90+: 이동 감속, fear_speed_mult 저하 (iron_will_2 스킬로 제거 가능)
  100: 화면 붕괴 연출 (fear_was_100 플래그)
```

**화면 효과:**
- Glitch Shader: 공포 + 보스 근접(500px 내) 시 강도 증가
- 카메라 흔들림: 보스 거리 기반 (magnitude 0–10)

**도감(Codex):**
- Tab 키 토글, GUI 클릭 시 `get_viewport().set_input_as_handled()` 필수
- `_codex_list_btns`: dict 배열 `{"root", "bg", "bar", "col"}` — Button API 사용 불가
- `_csec_obs_bar()`에서 반드시 `SpecimenDB.OBSERVE_KEY.get(enemy_id, enemy_id)` 변환 후 사용

---

### 플레이어 독백 시스템 (player.gd)

런 도중 상황에 따라 화면 하단(인벤토리 위)에 1인칭 혼잣말 텍스트 표시.

**UI 위치:** `PRESET_BOTTOM_WIDE`, `offset_left=400`, `offset_right=-400`, `offset_top=-404`, `offset_bottom=-356`
(인벤토리 top=y:560 기준 20px 위, 800px 너비 중앙 정렬)

**상수:**
```gdscript
MONO_GLOBAL_CD = 14.0   # 독백 간 최소 간격(초)
MONO_ENEMY: Dictionary  # 적 최초 목격 텍스트 (shade/stalker/ambusher/herald/sentinel/charger/brood/colossus)
```

**트리거 목록 (우선순위 순):**

| 트리거 | 조건 | 쿨다운/횟수 |
|--------|------|------------|
| 런 시작 | `_mono_spawn_delay` 2초 후 (사망 횟수 기반 텍스트) | 런당 1회 |
| 적 최초 목격 | 350px 이내, `_get_enemy_type()` 식별 | 종류별 1회 |
| 공포 50/75/90% | 임계값 돌파 | 런당 각 1회 |
| 공포 회복 | fear < 20 (fear_level > 0 이후) | 1회 |
| 박스 은신 | 진입 즉시 / 30초 체류 | 재진입 시 리셋 |
| 어둠 지속 | 손전등 꺼진 상태 45초 | 1회 (재점등 시 리셋) |
| 배터리 위기 | battery ≤ 15% + 손전등 ON | 1회 (30% 이상 회복 시 리셋) |
| 스태미나 고갈 | `is_exhausted` | 30초 쿨다운 |
| 추격 이탈 | `_was_chasing` false 전환 | 20초 쿨다운 |
| 안전구역 진입 | `is_in_safe_zone` on 전환 | 런당 2회 |

**핵심 함수:**
```gdscript
show_monologue(text: String, hold: float = 2.5)  # 페이드인 0.4s → 유지 → 페이드아웃 0.6s
_check_monologue_triggers(delta)                  # _process()에서 호출
_build_monologue_ui()                             # _ready()에서 호출, CanvasLayer/Control에 추가
```

---

### Enemies (공통 규칙)

- 모두 CharacterBody2D, `"enemy"` 그룹 등록
- 손전등 노출에 따라 alpha 변화 (0.25 ~ 1.0)
- `stop_chasing_forced()`: 박스 은신 시 외부에서 호출
- `receive_flare_hit()` / `receive_flare_bang()`: 신호탄 반응
- 거리 계산은 **몸 반경(BODY_RADIUS) 제외** 후 실제 거리 사용
- 스폰 위치(`spawn_pos`)로 귀환하는 RETURN 상태 구현

| 실험체 | 코드명 | 감지 방식 | 주요 특수 행동 |
|--------|--------|-----------|----------------|
| lurker | ACU-07 Echo | 소리(580px) | 빛 회피(RETREAT), 신호탄 소리에 반응 |
| stalker | TRK-11 Hound | FOV 시야(250px/100°) | LKP 추격, 섬광탄 이끌림, 격노 시스템 |
| colossus | APEX Colossus | 광역(500px) | 돌진/포효/박스파괴/2페이즈/보스모드 |
| ambusher | — | 근접 + 잠복 | 잠복→급습, 스폰 귀환 |
| sentinel | — | 구역 감시 | 충격파 이중 발사, 무리(Brood) 소환 |
| herald | — | FOV | 탐지 시 주변 전체 경보 브로드캐스트 |
| charger | — | FOV | 짧은 준비 후 고속 돌진, 충돌 스턴 |
| brood | — | 군집 | 알파 1 + 일반 7팩 구조, 스태미나 압박 오라 |

---

### Map (World.gd)

**맵 상수:**
```
MW=5200, MH=3800, WT=50(외벽), IWT=40(내벽)
MX0=50, MY0=50, MX1=5150, MY1=3750
```

**6개 구역 (Zone A–F):**

| 구역 | 좌표 범위 | 특성 | 주요 적 |
|------|-----------|------|---------|
| A (진입) | x:50–1395, y:50–1435 | 초반 탐색, 안전구역 있음 | Lurker ×1 |
| B (어둠) | x:1435–2700, y:50–1435 | 적색 비상등, 비상 대피소 | Lurker ×2, Ambusher ×1 |
| C (추격 평야) | x:2700–5150, y:50–1435 | 개방 공간, L형 엄폐물 2개 | Stalker ×2, Charger ×2 |
| D (메아리 방) | x:50–2300, y:1435–2810 | 격리 유적, 소형 부속실 | Herald, Ambusher, Brood팩 |
| E (파수꾼) | x:2300–5150, y:1435–2810 | 영역 감시, 동쪽 L형 장벽 | Sentinel, Charger, Brood팩 |
| F (보스 접근로) | x:50–5150, y:2810–3750 | 가운틀렛 구조, 붉은 조명 | Lurker, Stalker, Charger |

**구역 경계벽 통로 위치:**
- A↔B (x=1395–1435): 통로 y=570–820
- B↔C (x=2700–2740): 통로 y=660–910
- 상단↔하단 (y=1395–1435): 통로 x=680–930 / x=2050–2340 / x=3750–4000
- D↔E (x=2300–2340): 통로 y=2100–2350
- 하단↔F (y=2810–2850): 통로 x=550–800 / x=2000–2250 / x=3600–3850

**구역별 내부 구조물 (`_build_interior()` 추가분):**
```
Zone B 비상 대피소 (방 x:1800–2050, y:950–1200, 동쪽 입구 y:1020–1100):
  _rw(1800, 950, 2050, 990)   # 북벽
  _rw(1800, 990, 1840, 1200)  # 서벽
  _rw(1800, 1160, 2050, 1200) # 남벽
  _rw(2010, 950, 2050, 1020)  # 동벽 북
  _rw(2010, 1100, 2050, 1200) # 동벽 남

Zone C L형 엄폐물 1 (서쪽 중단):
  _rw(3050, 650, 3290, 690)   # 수평
  _rw(3050, 650, 3090, 820)   # 수직

Zone C L형 엄폐물 2 (동쪽 중단):
  _rw(4600, 640, 4840, 680)   # 수평
  _rw(4800, 640, 4840, 820)   # 수직

Zone D 소형 격리 부속실 (x:500–760, y:2450–2710, 북쪽 입구 x:590–670):
  _rw(500, 2450, 590, 2490)   # 북벽 서
  _rw(670, 2450, 760, 2490)   # 북벽 동
  _rw(720, 2450, 760, 2710)   # 동벽
  _rw(500, 2670, 760, 2710)   # 남벽

Zone E 동쪽 L형 장벽:
  _rw(3850, 1700, 4350, 1740) # 수평
  _rw(4310, 1700, 4350, 2050) # 수직
```

**보스 아레나:**
- 메인 맵 밖 별도 좌표 `ARENA_X=8000, ARENA_Y=500` (1200×1100)
- `KEY_POS=Vector2(2090, 2580)` — Zone D 보안 창고 방 (x:1960–2220)
- 보스 문 활성화 시 암전 후 플레이어 텔레포트

**내비게이션:**
- `_build_navigation()`: `add_outline()` + `make_polygons_from_outlines()` 방식
- `_nav_wall_rects()`: 외부 경계 CW, 홀 CCW (TL→BL→BR→TR) 와인딩
- 새 구조물 17개 홀 추가 (Zone B 대피소 ×5, Zone C 엄폐물 ×4, Zone D 부속실 ×4, Zone E 장벽 ×2, 보안창고 ×2)

**월드 생성 함수:**
```gdscript
_build_full_map():
  _build_floors()               # 구역별 바닥 색상/텍스처
  _build_floor_textures()       # concrete/metal/stone/grating 타일
  _build_outer_walls()          # 외벽 4면
  _build_zone_walls()           # 구역 분리벽 (통로 포함)
  _build_interior()             # 구역별 내부 구조물 (대피소/엄폐물/부속실/장벽)
  _build_secure_storage()       # Zone D 보안 창고 (KEY_POS 주변)
  _build_navigation()           # 내비게이션 메시 (홀 포함)
  _build_lighting()             # 구역별 PointLight2D (깜빡임 포함)
  _build_props()                # 기둥/잔해/배럴/파이프 등 소품
  _build_zone_differentiation() # 구역 경계선/표식/에코링/화살표
  _spawn_enemies()              # 모든 적 배치
  _spawn_boxes()                # 은신 박스 + 열쇠 + 보스문
  _spawn_items()                # 재료 아이템 + _spawn_memory_fragments() 호출
  _build_safe_zone()            # 안전구역 방 (Zone A 서쪽)
```

**아이템 스폰 함수 분리 구조:**
```gdscript
_spawn_items():
  _spawn_material_items()     # 재료 아이템 (Zone A–F, 약 26개)
  _spawn_memory_fragments()   # 기억 조각/연구 기록/중요 기억

_spawn_memory_fragments():    # respawn_memory_items()와 공유 — 재료 중복 방지
  # 단편적 기억 12개 (frag_0 ~ frag_11)
  # 연구 기록 8개 (log_shade/ambusher/stalker/herald/brood/sentinel/charger/colossus)
  # 중요한 기억 5개 (zone_b/c/d/e/f)

respawn_memory_items():       # DEV 기억 초기화 시 호출 — 재료 건드리지 않음
  # memory_fragment / important_memory 스크립트 노드만 제거 후
  # _spawn_memory_fragments() 호출
```

**월드 헬퍼 함수:**
- `_rw(x1,y1,x2,y2)`: 벽 (StaticBody2D + 시각 + LightOccluder2D, layer=5)
- `_rv(x1,y1,x2,y2,color,z)`: 시각 전용 Polygon2D
- `_rp(x,y,w,h)`: 기둥형 StaticBody2D
- `_pl(pos,tex,color,energy,scale)`: PointLight2D
- `_echo_ring(center, radius, color=Color(0.50,0.22,0.72,1.0))`: 동심원 Line2D (color 기본값=보라)
- `_nav_wall_rects()`: 내비 홀 좌표 배열 반환

---

### Item System (item.gd)

```gdscript
enum ItemType {
  ADRENALINE=1, BATTERY=2, SHIELD=3, FLARE=4,
  ROCK=5, LANTERN=6, MEMORY_SHARD=7,
  WIRE=8, CHEM=9, METAL=10, CLOTH=11, CELL=12, EXPLOSIVE=13,
  NOISE_DEVICE=14, EMP_GRENADE=15, FEAR_SUPPRESSOR=16, ENHANCED_FLASHLIGHT=17
}
```

재료(WIRE~EXPLOSIVE): 다이아몬드 형태 비주얼, `material_inventory` 딕셔너리에 별도 관리
일반 아이템(ADRENALINE~MEMORY_SHARD): slot1/slot2에 배치

---

### Crafting System (crafting_table.gd)

Zone A 안전구역 내 배치. 8종 레시피:
아드레날린, 배터리, 방패, 신호탄, 소음장치, EMP 수류탄, 공포억제제, 강화 손전등

---

### Narrative System

**memory_fragment.gd — 기억 조각 (12개) + 연구 기록 (8개):**
- 서사 텍스트 12개 완성 (각성/설계/첫 감지/박스/빛/첫 죽음/거대한 것/선행자/전령/루프/목적/마지막 전언)
- `LORE_TEXTS` 배열, `abs(_fragment_id.hash()) % size` 로 인덱스 결정
- 연구 기록: `setup_as_log(id, enemy_id, line_idx)`, SpecimenDB `damaged_lines` 참조
- 수집 보상: 일반 조각 5KP, 연구 기록 8KP

**important_memory.gd — 중요한 기억 (5개):**
- `MEMORY_TEXTS` 딕셔너리 키: `zone_b/c/d/e/f`
- 5번째 수집 시 `triggered_reveal=true` → 열쇠 위치 UI 공개 (`_fire_key_reveal()`)
- 수집 보상: 8KP, 자동 4.5초 후 닫힘 (열쇠 공개 시 5.5초)

**Lore Popup 공통 패턴:**
```gdscript
# 팝업 생성 시
overlay.add_to_group("lore_popup")
var close_fn = func(): tw.kill(); overlay.queue_free(); ...
close_btn.pressed.connect(close_fn)
overlay.set_meta("close_fn", close_fn)   # E키 닫기용

# player.gd _input()에서 E키 처리
for node in get_tree().get_nodes_in_group("lore_popup"):
    node.get_meta("close_fn").call()
```
- `close_btn`은 panel 내부 VBox 마지막에 배치 (flat=true, right-aligned)
- 좌클릭 신호탄 발사: `lore_popup` 그룹 존재 시 `_input()`에서 early return

---

### Progression Systems

**GlobalSave (autoload):**
```gdscript
data = {
  "shade_seen" ... "brood_seen": bool,   # 8종 목격 플래그
  "total_kp": int,
  "action_counts": {},                   # hide/blind/rock_kill/flare_use 횟수
  "ability_levels": {},                  # shadow_instinct/light_control/steady_hand/flame_sense/fear_resist
  "observed_times": {},                  # 관찰 시간(초) per enemy type
  "fragments_collected": [],             # 수집된 frag_id 목록
  "important_memories": [],              # 수집된 memory_id 목록
  "fear_endurance_count": int,
  "codex_rewarded": {},                  # 도감 4티어 보상 지급 여부
  "death_counts": {},                    # adapt_memory: 적별 사망 횟수
  "carried_item": int,                   # carry_over 스킬: 이월 아이템
}
purchased_skills: Dictionary            # skill_id → true
run_kp: int                             # 런 내 획득 KP
run_buffs: Dictionary                   # F 시스템 런 한정 버프
```

**SpecimenDB (autoload):**
- `ENEMY_DATA[]`: 8종 실험체 메타데이터 (code/nickname/threat/tier2~4 설명/field_note/damaged_lines)
- `OBSERVE_KEY{}`: `"shade_seen"→"shade"` 등 8개 매핑 — `_csec_obs_bar()` 변환 시 필수
- `get_tier(id)`: 0(미목격) / 1(목격) / 2(≥3s) / 3(≥15s) / 4(≥45s)

**런 간 보존:** KP, 도감 관찰 시간, 기억 조각 수집 여부, 구매 스킬
**런 내 소실:** 수집 자원/아이템, 공포 수치, 위치

---

### Boss Fight Flow

1. 열쇠 수집 (중요 기억 5개 수집 선행 → `_fire_key_reveal()` 호출)
2. 보스 문 활성화 → E 상호작용
3. 화면 암전 → 아레나 벽 생성 → 플레이어 텔레포트 (ARENA_X=8000, ARENA_Y=500)
4. 콜로서스 스폰, 보스 BGM 전환
5. 격리 패널 3개 활성화 → 콜로서스 약화
6. 2페이즈 진입 (`_enter_phase2`), 체력 0 → 폭발(3초) → 탈출 문 활성화

---

### Communication Patterns

```
Player  ←── take_damage()           ← 모든 적
Player  ←── force_stop_flashlight() ← Colossus (포효)
Player  ←── add_fear_from_brood()   ← Brood (스태미나 압박 오라)
Enemy   ←── stop_chasing_forced()   ← Box (은신 시)
Enemy   ←── receive_flare_hit/bang() ← FlareProjectile
Box     ←── destroy()               ← Colossus
World   ←── _on_panel_activated()   ← ContainmentPanel
World   ←── respawn_memory_items()  ← player.gd DEV 모드 (기억 초기화)
```

그룹 기반 탐색:
```gdscript
get_tree().get_nodes_in_group("enemy")           # 모든 적
get_tree().get_first_node_in_group("player")     # 플레이어
get_tree().get_nodes_in_group("boss")            # 보스만
get_tree().get_nodes_in_group("lore_popup")      # 활성 로어 팝업 (있으면 좌클릭 차단)
get_tree().get_first_node_in_group("world_root") # World 노드 접근
```

---

## Known Issues & Quirks

1. **내비게이션 홀 와인딩:** `make_polygons_from_outlines()` 실패 시 적이 벽 통과 가능. 홀은 반드시 CCW (TL→BL→BR→TR). 구조물 추가 시 `_nav_wall_rects()`에 대응 홀 필수.
2. **보스 포효 비동기:** `await` 1.5초 동안 상태 전환 없음 — 포효 중 연속 호출 주의
3. **카메라 흔들림:** 카메라 offset 직접 조작 — 다른 카메라 스크립트와 충돌 가능
4. **OBSERVE_KEY 누락 시 obs_bar 미표시:** `_csec_obs_bar()`에서 반드시 `SpecimenDB.OBSERVE_KEY.get(enemy_id, enemy_id)` 변환 후 사용
5. **`_input()` 가드 순서:** 신호탄 발사 전 `_codex_open`, `_bag_open`, `crafting_table._ui_open`, `key_pickup._keypad_open`, `lore_popup` 그룹 — 새 UI 추가 시 이 목록에 반드시 추가

---

## Development Priorities (기획 기준)

현재 구현 vs 기획 목표 갭:

| 항목 | 현황 | 목표 |
|------|------|------|
| 공포 90–100 효과 | 이동 감속 구현 (fear_speed_mult), 글리치+UI흔들림 | (완료) iron_will_2 스킬로 제거 가능 |
| 기억 조각 텍스트 | 12개 서사 텍스트 완성, 연구 기록 8개 포함 | ✅ 완료 |
| 사망 화면 | 재시작/메뉴만 | 사망 원인/생존시간/런 진행도 표시 |
| 초반 난이도 커브 | 시작부터 전 적 배치 | 구역 순차 활성화 (Area2D 기반 지연 스폰) |
| BGM | 상시 재생 | 위협 레벨 연동 동적 전환 |
| 플레이어 독백 | 14개 트리거, 인벤토리 위 표시 | ✅ 구현 완료 |
| 런 간 진행 체감 | KP/도감/스킬트리 | 런 결과 화면 개선 + in-run 도감 혜택 강화 |
