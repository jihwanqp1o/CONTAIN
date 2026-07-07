extends Node

signal ability_unlocked(ability_id: String)
signal key_revealed

const SAVE_PATH = "user://progress.cfg"

var data: Dictionary = {
	"shade_seen":     false,
	"stalker_seen":   false,
	"colossus_seen":  false,
	"ambusher_seen":  false,
	"sentinel_seen":  false,
	"herald_seen":    false,
	"charger_seen":   false,
	"brood_seen":     false,
	"total_kp":           0,
	"action_counts":      {},
	"ability_levels":     {},
	"observed_times":     {},
	"fragments_collected": [],
	"important_memories": [],
	"fear_endurance_count": 0,
	"codex_rewarded":       {},
	"death_counts":         {},   # adapt_memory: 적별 사망 횟수
	"carried_item":         0,    # carry_over: 이월 아이템 타입
}

var purchased_skills: Dictionary = {}

var run_kp: int = 0
var run_milestones: Dictionary = {}
var current_floor: int = 1
var run_buffs: Dictionary = {}   # F 시스템 — 런 한정
var run_first_death_used: bool = false  # 런당 1회 기절 생존 사용 여부

# ── 행동 마일스톤 ─────────────────────────────
# 값: [1단계 횟수, 2단계 횟수, 3단계 횟수]
const ACTION_MILESTONES: Dictionary = {
	"hide":      [3,  6, 10],
	"blind":     [3,  5,  8],
	"rock_kill": [2,  3,  5],
	"flare_use": [2,  4,  5],
}
# 값: [1단계 KP, 2단계 KP, 3단계 해금 능력 id]
const ACTION_REWARDS: Dictionary = {
	"hide":      [5,  8, "shadow_instinct"],
	"blind":     [5,  8, "light_control"],
	"rock_kill": [8, 12, "steady_hand"],
	"flare_use": [5,  8, "flame_sense"],
}

# ── 능력 메타데이터 ───────────────────────────
const ABILITY_UPGRADE_COSTS: Dictionary = {
	"shadow_instinct": [15, 30],
	"light_control":   [10, 25],
	"steady_hand":     [15, 25],
	"flame_sense":     [10, 20],
	"fear_resist":     [15, 30],
}
const ABILITY_NAMES: Dictionary = {
	"shadow_instinct": "그림자 본능",
	"light_control":   "광원 조절",
	"steady_hand":     "정확한 손",
	"flame_sense":     "화염 감각",
	"fear_resist":     "공포 내성",
}
# 각 능력의 레벨 1/2/3 설명
const ABILITY_DESCS: Dictionary = {
	"shadow_instinct": ["은신 중 공포 감소 +50%", "은신 진입 시 공포 -10", "은신 중 배터리 소모 없음"],
	"light_control":   ["배터리 소모 -20%", "손전등 ON 시 공포 감소 2배", "탐지 범위 +20%"],
	"steady_hand":     ["파편 투척 속도 +30%", "파편 최대 보유 +1", "보스 파편 피해 2배"],
	"flame_sense":     ["신호탄 최대 보유 +1", "신호탄 폭발 반경 +25%", "신호탄 스턴 +50%"],
	"fear_resist":     ["공포 자연 감소 +20%", "공포 100% 이속 패널티 제거", "공포 100% 스태미나 정상화"],
}

# ── 구매형 스킬 ───────────────────────────────
const PURCHASABLE_SKILLS: Dictionary = {
	"battery_save":   {"name": "배터리 절약",  "cost": 20, "desc": "손전등 소모 -25%"},
	"mental_tough":   {"name": "강인한 정신",  "cost": 15, "desc": "공포 자연 감소 +20%"},
	"quick_recovery": {"name": "빠른 회복",    "cost": 25, "desc": "스태미나 회복 +20%"},
	"stealth_expert": {"name": "은신 숙련",    "cost": 20, "desc": "박스 공포 감소 +50%"},
	"cold_judgment":  {"name": "냉철한 판단",  "cost": 30, "desc": "전등 지속시간 +30초"},
}

const MILESTONE_KP: Dictionary = {
	"r2":    10,
	"r3":    25,
	"r4":    50,
	"boss":  80,
}

func _ready() -> void:
	_load()

# ── 런 관리 ───────────────────────────────────
func start_new_run() -> void:
	run_kp = 0
	run_milestones = {}
	current_floor = 1
	run_buffs = {}
	run_first_death_used = false

func award_kp(milestone_id: String) -> int:
	if run_milestones.get(milestone_id, false): return 0
	run_milestones[milestone_id] = true
	var amount: int = MILESTONE_KP.get(milestone_id, 0)
	run_kp += amount
	data["total_kp"] = data.get("total_kp", 0) + amount
	_save()
	return amount

func get_total_kp() -> int:
	return data.get("total_kp", 0)

func add_kp(amount: int) -> void:
	run_kp += amount
	data["total_kp"] = data.get("total_kp", 0) + amount
	_save()

# ── 행동 카운트 ───────────────────────────────
# 반환: Array of {"type": "kp"/"ability", "amount": int / "id": String}
func count_action(action_id: String) -> Array:
	var counts: Dictionary = data.get("action_counts", {})
	counts[action_id] = counts.get(action_id, 0) + 1
	data["action_counts"] = counts
	var n: int = counts[action_id]
	var milestones: Array = ACTION_MILESTONES.get(action_id, [])
	var rewards: Array   = ACTION_REWARDS.get(action_id, [])
	var events: Array    = []
	for i in milestones.size():
		if n == milestones[i]:
			if i < 2:
				var kp: int = rewards[i] if rewards.size() > i else 3
				add_kp(kp)
				events.append({"type": "kp", "amount": kp})
			else:
				var ability_id: String = rewards[2] if rewards.size() > 2 else ""
				if ability_id != "" and get_ability_level(ability_id) == 0:
					unlock_ability(ability_id)
					events.append({"type": "ability", "id": ability_id})
	_save()
	return events

# ── 능력 시스템 ───────────────────────────────
func get_ability_level(ability_id: String) -> int:
	return data.get("ability_levels", {}).get(ability_id, 0)

func unlock_ability(ability_id: String) -> void:
	var levels: Dictionary = data.get("ability_levels", {})
	levels[ability_id] = 1
	data["ability_levels"] = levels
	_save()
	ability_unlocked.emit(ability_id)

# 레벨 1→2 또는 2→3 업그레이드. 성공 시 true 반환.
func upgrade_ability(ability_id: String) -> bool:
	var current: int = get_ability_level(ability_id)
	if current == 0 or current >= 3: return false
	var costs: Array = ABILITY_UPGRADE_COSTS.get(ability_id, [])
	var cost_idx: int = current - 1
	if cost_idx >= costs.size(): return false
	var cost: int = costs[cost_idx]
	if data.get("total_kp", 0) < cost: return false
	data["total_kp"] -= cost
	var levels: Dictionary = data.get("ability_levels", {})
	levels[ability_id] = current + 1
	data["ability_levels"] = levels
	_save()
	return true

# ── 구매형 스킬 ───────────────────────────────
func buy_skill(skill_id: String, cost: int) -> bool:
	if data.get("total_kp", 0) < cost: return false
	if purchased_skills.get(skill_id, false): return false
	purchased_skills[skill_id] = true
	data["total_kp"] -= cost
	_save()
	return true

func has_skill(skill_id: String) -> bool:
	return purchased_skills.get(skill_id, false)

# ── 적 관찰 ───────────────────────────────────
# 반환: "" / "tier1" / "tier2" / "tier3"
func add_observe_time(enemy_type: String, delta: float) -> String:
	var times: Dictionary = data.get("observed_times", {})
	var prev: float = times.get(enemy_type, 0.0)
	times[enemy_type] = prev + delta
	data["observed_times"] = times
	var t: float = times[enemy_type]
	var result: String = ""
	if prev < 3.0  and t >= 3.0:
		result = "tier1"
		add_kp(3)
	elif prev < 15.0 and t >= 15.0:
		result = "tier2"
		add_kp(5)
	elif prev < 45.0 and t >= 45.0:
		result = "tier3"
		add_kp(8)
		var ab: String = _observe_ability(enemy_type)
		if ab != "" and get_ability_level(ab) == 0:
			unlock_ability(ab)
	if result != "": _save()
	return result

func _observe_ability(enemy_type: String) -> String:
	match enemy_type:
		"lurker":   return "lurker_mastered"
		"stalker":  return "stalker_mastered"
		"colossus": return "colossus_mastered"
		_:          return ""

func get_observe_time(enemy_type: String) -> float:
	return data.get("observed_times", {}).get(enemy_type, 0.0)

# ── 기억 단편 ─────────────────────────────────
func collect_fragment(fragment_id: String, kp: int = 5) -> bool:
	var collected: Array = data.get("fragments_collected", [])
	if fragment_id in collected: return false
	collected.append(fragment_id)
	data["fragments_collected"] = collected
	add_kp(kp)
	_save()
	return true

func is_fragment_collected(fragment_id: String) -> bool:
	return fragment_id in data.get("fragments_collected", [])

func get_fragment_count() -> int:
	return data.get("fragments_collected", []).size()

# ── 공포 내성 ─────────────────────────────────
func record_fear_endurance() -> int:
	var count: int = data.get("fear_endurance_count", 0) + 1
	data["fear_endurance_count"] = count
	var kp: int = 5 if count <= 1 else (10 if count <= 2 else 20)
	add_kp(kp)
	if count >= 3 and get_ability_level("fear_resist") == 0:
		unlock_ability("fear_resist")
	_save()
	return kp

func get_fear_endurance_count() -> int:
	return data.get("fear_endurance_count", 0)

# ── 중요한 기억 ───────────────────────────────
const IMPORTANT_MEMORY_COUNT: int = 5

# 반환: true = 이 수집이 마지막(열쇠 해금 트리거), false = 아직 미완
func collect_important_memory(memory_id: String) -> bool:
	var collected: Array = data.get("important_memories", [])
	if memory_id in collected: return false
	collected.append(memory_id)
	data["important_memories"] = collected
	add_kp(12)
	_save()
	if collected.size() >= IMPORTANT_MEMORY_COUNT:
		key_revealed.emit()
		return true
	return false

func is_important_memory_collected(memory_id: String) -> bool:
	return memory_id in data.get("important_memories", [])

func get_important_memory_count() -> int:
	return data.get("important_memories", []).size()

func all_important_memories_collected() -> bool:
	return get_important_memory_count() >= IMPORTANT_MEMORY_COUNT

# ── 런 버프 (F 시스템) ────────────────────────
func apply_run_buff(buff_id: String) -> void:
	run_buffs[buff_id] = true

func has_run_buff(buff_id: String) -> bool:
	return run_buffs.get(buff_id, false)

# ── 적 조우 기록 ──────────────────────────────
func mark_seen(enemy_id: String) -> void:
	if data.get(enemy_id, false): return
	data[enemy_id] = true
	add_kp(5)
	_save()

func is_seen(enemy_id: String) -> bool:
	return data.get(enemy_id, false)

# ── 도감 Tier4 보상 (최초 1회 +5 KP) ───────────
func award_codex_tier4(enemy_id: String) -> bool:
	var rewarded: Dictionary = data.get("codex_rewarded", {})
	if rewarded.get(enemy_id, false): return false
	rewarded[enemy_id] = true
	data["codex_rewarded"] = rewarded
	add_kp(10)
	_save()
	return true

# ── 사망 횟수 (adapt_memory) ──────────────────
func increment_death_count(enemy_id: String) -> void:
	var counts: Dictionary = data.get("death_counts", {})
	counts[enemy_id] = counts.get(enemy_id, 0) + 1
	data["death_counts"] = counts
	_save()

func get_death_count(enemy_id: String) -> int:
	return data.get("death_counts", {}).get(enemy_id, 0)

# ── 이월 아이템 (carry_over) ──────────────────
func set_carried_item(item_type: int) -> void:
	data["carried_item"] = item_type
	_save()

func get_carried_item() -> int:
	return data.get("carried_item", 0)

func clear_carried_item() -> void:
	data["carried_item"] = 0
	_save()

# ── DEV 초기화 ────────────────────────────────
func reset_memories() -> void:
	data["fragments_collected"] = []
	data["important_memories"]  = []
	_save()

func reset_all() -> void:
	data["fragments_collected"]  = []
	data["important_memories"]   = []
	data["total_kp"]             = 0
	data["action_counts"]        = {}
	data["ability_levels"]       = {}
	data["observed_times"]       = {}
	data["fear_endurance_count"] = 0
	data["death_counts"]         = {}
	data["carried_item"]         = 0
	for key in data.keys():
		if key.ends_with("_seen"): data[key] = false
	purchased_skills = {}
	_save()

func reset_run() -> void:
	run_kp         = 0
	run_milestones = {}
	run_buffs      = {}

# ── 저장 / 불러오기 ───────────────────────────
func _save() -> void:
	var cfg = ConfigFile.new()
	for key in data:
		cfg.set_value("progress", key, data[key])
	for skill_id in purchased_skills:
		cfg.set_value("skills", skill_id, true)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return
	for key in data:
		data[key] = cfg.get_value("progress", key, data[key])
	if cfg.has_section("skills"):
		for skill_id in cfg.get_section_keys("skills"):
			purchased_skills[skill_id] = true
