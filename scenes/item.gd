extends Area2D

# player.gd의 ItemType과 값이 일치해야 함 (NONE=0 제외)
enum ItemType {
	ADRENALINE = 1, BATTERY = 2, SHIELD = 3, FLARE = 4, ROCK = 5, LANTERN = 6, MEMORY_SHARD = 7,
	# 재료 아이템 (제작대에서 사용)
	WIRE = 8, CHEM = 9, METAL = 10, CLOTH = 11, CELL = 12, EXPLOSIVE = 13,
	# 제작 결과물
	NOISE_DEVICE = 14, EMP_GRENADE = 15, FEAR_SUPPRESSOR = 16, ENHANCED_FLASHLIGHT = 17,
}

@export var item_type: ItemType = ItemType.ADRENALINE

@export_group("Sound Effects")
@export var sfx_pickup: AudioStream

const ITEM_COLORS = {
	ItemType.ADRENALINE:          Color(1.0, 0.45, 0.0),
	ItemType.BATTERY:             Color(1.0, 0.90, 0.1),
	ItemType.SHIELD:              Color(0.3, 0.55, 1.0),
	ItemType.FLARE:               Color(1.0, 0.22, 0.05),
	ItemType.ROCK:                Color(0.72, 0.58, 0.32),
	ItemType.LANTERN:             Color(1.0,  0.80, 0.32),
	ItemType.MEMORY_SHARD:        Color(0.55, 0.85, 1.0),
	# 재료
	ItemType.WIRE:                Color(1.0, 0.88, 0.10),
	ItemType.CHEM:                Color(0.25, 0.95, 0.40),
	ItemType.METAL:               Color(0.68, 0.68, 0.75),
	ItemType.CLOTH:               Color(0.65, 0.42, 0.22),
	ItemType.CELL:                Color(0.18, 0.52, 1.0),
	ItemType.EXPLOSIVE:           Color(1.0, 0.42, 0.05),
	# 제작 결과물
	ItemType.NOISE_DEVICE:        Color(0.80, 0.80, 0.20),
	ItemType.EMP_GRENADE:         Color(0.20, 0.82, 0.92),
	ItemType.FEAR_SUPPRESSOR:     Color(0.62, 0.28, 0.85),
	ItemType.ENHANCED_FLASHLIGHT: Color(0.95, 0.88, 0.25),
}

const ITEM_NAMES = {
	ItemType.ADRENALINE:          "아드레날린",
	ItemType.BATTERY:             "배터리",
	ItemType.SHIELD:              "방패",
	ItemType.FLARE:               "신호탄",
	ItemType.ROCK:                "파편",
	ItemType.LANTERN:             "전등",
	ItemType.MEMORY_SHARD:        "기억 조각",
	# 재료
	ItemType.WIRE:                "전선 조각",
	ItemType.CHEM:                "화학 시약",
	ItemType.METAL:               "금속 파편",
	ItemType.CLOTH:               "방호복 조각",
	ItemType.CELL:                "에너지 셀",
	ItemType.EXPLOSIVE:           "불안정 화합물",
	# 제작 결과물
	ItemType.NOISE_DEVICE:        "소음 장치",
	ItemType.EMP_GRENADE:         "EMP 수류탄",
	ItemType.FEAR_SUPPRESSOR:     "공포 억제제",
	ItemType.ENHANCED_FLASHLIGHT: "강화 손전등",
}

var _sfx_player: AudioStreamPlayer
var _pulse_time: float = 0.0
var _initial_y: float = 0.0
var _player_in_range: CharacterBody2D = null
var _hint_label: Label = null

func _ready():
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_initial_y = position.y

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	sfx_pickup = load("res://assets/pickup.mp3")

	_build_visual()

	var name_label = get_node_or_null("NameLabel")
	if name_label:
		name_label.text = ITEM_NAMES.get(item_type, "아이템")

	_hint_label = get_node_or_null("PickupHint")
	if _hint_label:
		_hint_label.visible = false

func _process(delta):
	_pulse_time += delta
	position.y = _initial_y + sin(_pulse_time * 3.0) * 5.0

	if _player_in_range and Input.is_action_just_pressed("interact"):
		_try_pickup(_player_in_range)

func _on_body_entered(body):
	if body.is_in_group("player"):
		_player_in_range = body
		if _hint_label:
			_hint_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		_player_in_range = null
		if _hint_label:
			_hint_label.visible = false

func _try_pickup(player):
	if not player.has_method("try_pickup_item"): return
	if not player.try_pickup_item(item_type): return

	if sfx_pickup:
		var temp = AudioStreamPlayer.new()
		temp.stream = sfx_pickup
		get_parent().add_child(temp)
		temp.play()
		temp.finished.connect(temp.queue_free)
	queue_free()

func _build_visual():
	var color = ITEM_COLORS.get(item_type, Color.WHITE)
	var is_material = item_type >= ItemType.WIRE and item_type <= ItemType.EXPLOSIVE

	if is_material:
		# 재료: 다이아몬드 형태
		var size = 11.0
		var diamond = Polygon2D.new()
		diamond.polygon = PackedVector2Array([
			Vector2(0, -size), Vector2(size, 0),
			Vector2(0, size),  Vector2(-size, 0),
		])
		diamond.color = color
		diamond.z_index = 1
		add_child(diamond)
		var border = Polygon2D.new()
		var bs = size + 2.5
		border.polygon = PackedVector2Array([
			Vector2(0, -bs), Vector2(bs, 0),
			Vector2(0, bs),  Vector2(-bs, 0),
		])
		border.color = Color(1.0, 1.0, 1.0, 0.6)
		border.z_index = 0
		add_child(border)
	else:
		# 일반 아이템: 사각형
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(color)
		for i in range(32):
			img.set_pixel(i, 0,  Color.WHITE)
			img.set_pixel(i, 31, Color.WHITE)
			img.set_pixel(0,  i, Color.WHITE)
			img.set_pixel(31, i, Color.WHITE)
		var sprite = Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.scale = Vector2(1.5, 1.5)
		add_child(sprite)
