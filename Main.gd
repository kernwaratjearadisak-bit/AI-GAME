extends Node2D

const ENEMY_SCENE := preload("res://Enemy.tscn")
const BOSS_SCENE := preload("res://Boss.tscn")
const WORLD_SCRIPT := preload("res://World.gd")
# Enemy เกิดเป็นกลุ่ม: สุ่มจำนวน "จุดศูนย์กลางกลุ่ม" แล้ววาง ENEMIES_PER_GROUP ตัวรอบแต่ละจุด → 45-60 ตัวต่อ stage
const RANDOM_GROUP_COUNT_MIN := 15
const RANDOM_GROUP_COUNT_MAX := 20
const ENEMIES_PER_GROUP := 3
# สมาชิกวางเป็นสามเหลี่ยมรอบศูนย์กลาง: รัศมีสุ่ม 70-100% ของ GROUP_SPREAD_RADIUS (84-120px) มุมสุ่มเลื่อน ±15°
# กรณีใกล้กันสุด = มุมห่าง 90° รัศมี 84 ทั้งคู่ → 2 * 84 * sin(45°) ≈ 119px ≥ 90 (ลำตัวกว้าง 76) ไม่ยืนทับกัน
const GROUP_SPREAD_RADIUS := 120.0
const GROUP_SPREAD_MIN_RATIO := 0.7
const GROUP_ANGLE_JITTER := PI / 12.0  # 15°
# ศูนย์กลางกลุ่มห่างกันอย่างน้อยเท่านี้ — สุ่มครบ GROUP_PLACEMENT_ATTEMPTS ครั้งแล้วยังไม่ได้ ใช้จุดที่ห่างที่สุดที่เจอแทน
const GROUP_MIN_SPACING := 400.0
const GROUP_PLACEMENT_ATTEMPTS := 30
# กันไม่ให้กลุ่ม Enemy เกิดชิดขอบโลก หรือเกิดทับจุดเริ่มของ Hero
const WORLD_EDGE_MARGIN := 200.0
const HERO_SAFE_RADIUS := 800.0
# Boss อยู่สุด World ทางขวา กึ่งกลางแนวตั้ง — Enemy ปกติไม่เกิดในรัศมี BOSS_SAFE_RADIUS รอบ Boss
const BOSS_SPAWN_POSITION := Vector2(WORLD_SCRIPT.SIZE.x - 300.0, WORLD_SCRIPT.SIZE.y / 2.0)
const BOSS_SAFE_RADIUS := 800.0
# หน่วงหลัง Boss ตายก่อนเริ่ม stage ใหม่
const STAGE_RESET_DELAY := 1.0
# ความยากต่อ stage: HP / attack ของ Enemy และ Boss = ค่าพื้นฐาน * STAGE_SCALING ^ (current_stage - 1)
const STAGE_SCALING := 1.5
# ข้อความ "Stage N" กลางจอตอนเริ่ม stage (วินาที)
const STAGE_TITLE_FADE_IN := 0.3
const STAGE_TITLE_HOLD := 1.2
const STAGE_TITLE_FADE_OUT := 0.5
# TODO: ปุ่ม debug ชั่วคราว — B = Boss ตายทันที, V = ย้าย Boss มาข้างหน้า leader
# K = cooldown ทุก skill ของ Hero ที่เลือกเป็น 0, H = HP ของ Hero ที่เลือกเหลือ DEBUG_LOW_HP_RATIO — ปิดเป็น false ก่อน release
const DEBUG_BOSS_KEYS := true
const DEBUG_LOW_HP_RATIO := 0.4
const DEBUG_BOSS_NEAR_OFFSET := Vector2(500, 0)

# จุดศูนย์กลางกลุ่ม Enemy (พิกัด World) — แต่ละจุด spawn ENEMIES_PER_GROUP ตัวรอบๆ
# ถ้าอยากกำหนดตำแหน่งตายตัว ให้ใส่ค่าลงใน array นี้ได้เลย เช่น
#   Vector2(500, 300), Vector2(1200, 800), ...
# ถ้า array ว่าง จะสุ่มจุดศูนย์กลางกระจายทั่ว World ให้แทน และสุ่มใหม่ทุก stage
var enemy_spawn_points: Array[Vector2] = []
var stage_pass_count := 0

# จำไว้ตอนเริ่มเกมว่า enemy_spawn_points ถูกกำหนดตายตัวไหม (หลัง _ready array จะไม่ว่างแล้วทั้งสองแบบ)
var has_fixed_spawn_points := false
var boss: Node2D = null
var stage_title_tween: Tween = null

@onready var enemy_container: Node2D = $Enemies
@onready var camera: Camera2D = $Camera2D
@onready var effects: Node2D = $Effects
@onready var stage_title_label: Label = $UI/StageTitleLabel


func _ready() -> void:
	add_to_group("main")
	has_fixed_spawn_points = not enemy_spawn_points.is_empty()
	if not has_fixed_spawn_points:
		enemy_spawn_points = _generate_random_spawn_points()
	_spawn_enemies()
	_spawn_boss()
	show_stage_title(stage_pass_count + 1)


func _spawn_enemies() -> void:
	var enemy_count := 0
	for center in enemy_spawn_points:
		for point in _get_group_member_positions(center):
			var enemy := ENEMY_SCENE.instantiate()
			enemy.setup(get_stage_multiplier())
			enemy_container.add_child(enemy)
			# ใช้แค่ x ของจุดที่สุ่มได้ — y วางบนพื้นเสมอ
			WORLD_SCRIPT.place_on_ground(enemy, point.x)
			enemy_count += 1
	print("Stage %d: spawned %d groups, %d enemies" % [stage_pass_count + 1, enemy_spawn_points.size(), enemy_count])


# สามเหลี่ยมรอบศูนย์กลาง หมุนสุ่มทั้งกลุ่ม + สุ่มเลื่อนแต่ละตัวเล็กน้อย (ดูระยะขั้นต่ำที่ GROUP_SPREAD_RADIUS)
func _get_group_member_positions(center: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var base_angle := randf() * TAU
	for i in ENEMIES_PER_GROUP:
		var angle := base_angle + i * TAU / ENEMIES_PER_GROUP + randf_range(-GROUP_ANGLE_JITTER, GROUP_ANGLE_JITTER)
		var radius := GROUP_SPREAD_RADIUS * randf_range(GROUP_SPREAD_MIN_RATIO, 1.0)
		positions.append(WORLD_SCRIPT.clamp_to_bounds(center + Vector2.from_angle(angle) * radius))
	return positions


func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.setup(get_stage_multiplier())
	enemy_container.add_child(boss)
	WORLD_SCRIPT.place_on_ground(boss, BOSS_SPAWN_POSITION.x)
	boss.boss_defeated.connect(_on_boss_defeated)


# current_stage = stage_pass_count + 1 → Stage 1 = x1, Stage 2 = x1.5, Stage 3 = x2.25, ...
func get_stage_multiplier() -> float:
	var current_stage := stage_pass_count + 1
	return pow(STAGE_SCALING, current_stage - 1)


# คืนจุดศูนย์กลางกลุ่ม — ระยะห่างระหว่างกลุ่มเป็นเงื่อนไขแบบ "พยายาม" (ไม่วนไม่จบ) ส่วนขอบโลก / Hero / Boss เป็นเงื่อนไขบังคับ
func _generate_random_spawn_points() -> Array[Vector2]:
	var leader := get_tree().get_first_node_in_group("party_leader")
	var hero_start: Vector2 = leader.global_position if leader else Vector2(-INF, -INF)
	var count := randi_range(RANDOM_GROUP_COUNT_MIN, RANDOM_GROUP_COUNT_MAX)

	var centers: Array[Vector2] = []
	for _i in count:
		var best_point := Vector2.ZERO
		var best_gap := -1.0
		for _attempt in GROUP_PLACEMENT_ATTEMPTS:
			var point := _random_group_center(hero_start)
			var gap := _distance_to_nearest(point, centers)
			if gap > best_gap:
				best_gap = gap
				best_point = point
			if gap >= GROUP_MIN_SPACING:
				break
		centers.append(best_point)
	return centers


# สุ่มจนได้จุดที่ผ่านเงื่อนไขบังคับ — พื้นที่ที่ผ่านกว้างมาก (World 14400x1280 ตัดแค่วงกลม 2 วง) จึงเจอเร็ว
func _random_group_center(hero_start: Vector2) -> Vector2:
	while true:
		var point := Vector2(
			randf_range(WORLD_EDGE_MARGIN, WORLD_SCRIPT.SIZE.x - WORLD_EDGE_MARGIN),
			randf_range(WORLD_EDGE_MARGIN, WORLD_SCRIPT.SIZE.y - WORLD_EDGE_MARGIN)
		)
		if point.distance_to(hero_start) >= HERO_SAFE_RADIUS and point.distance_to(BOSS_SPAWN_POSITION) >= BOSS_SAFE_RADIUS:
			return point
	return Vector2.ZERO


func _distance_to_nearest(point: Vector2, others: Array[Vector2]) -> float:
	var nearest := INF
	for other in others:
		nearest = minf(nearest, point.distance_to(other))
	return nearest


func _on_boss_defeated() -> void:
	stage_pass_count += 1
	await get_tree().create_timer(STAGE_RESET_DELAY).timeout
	# ไม่ reset ระหว่าง physics callback — รอให้เฟรมนี้ประมวลผลจบก่อน
	reset_stage.call_deferred()


func reset_stage() -> void:
	# ลูกทั้งหมดใน Enemies: Enemy ที่เหลือ, Boss, coin และ HP potion ที่ตกอยู่
	for child in enemy_container.get_children():
		child.queue_free()
	boss = null
	# ตัวเลข damage ที่ยังลอยค้างอยู่
	for child in effects.get_children():
		child.queue_free()

	# ย้าย Hero กลับจุดเริ่มก่อน เพราะการสุ่ม spawn point ใช้ตำแหน่ง leader กัน HERO_SAFE_RADIUS
	var party := get_tree().get_first_node_in_group("hero_party")
	if party:
		party.reset_for_new_stage()
	camera.snap_to_leader()

	if not has_fixed_spawn_points:
		enemy_spawn_points = _generate_random_spawn_points()
	_spawn_enemies()
	_spawn_boss()
	show_stage_title(stage_pass_count + 1)


# "Stage N" กลางจอ: fade in → ค้าง → fade out แล้วซ่อน — เกมเล่นต่อระหว่างนี้ ไม่ pause
func show_stage_title(stage_number: int) -> void:
	if stage_title_tween and stage_title_tween.is_valid():
		stage_title_tween.kill()
	stage_title_label.text = "Stage %d" % stage_number
	stage_title_label.modulate.a = 0.0
	stage_title_label.visible = true
	stage_title_tween = create_tween()
	stage_title_tween.tween_property(stage_title_label, "modulate:a", 1.0, STAGE_TITLE_FADE_IN)
	stage_title_tween.tween_interval(STAGE_TITLE_HOLD)
	stage_title_tween.tween_property(stage_title_label, "modulate:a", 0.0, STAGE_TITLE_FADE_OUT)
	stage_title_tween.tween_callback(stage_title_label.hide)


func _unhandled_input(event: InputEvent) -> void:
	if not DEBUG_BOSS_KEYS or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var selected_hero := get_tree().get_first_node_in_group("party_leader")
	if selected_hero and selected_hero.hp > 0:
		if event.keycode == KEY_K:
			selected_hero.skills.debug_clear_cooldowns()
			return
		if event.keycode == KEY_H:
			selected_hero.hp = snappedf(selected_hero.max_hp * DEBUG_LOW_HP_RATIO, 0.01)
			return
	if not is_instance_valid(boss) or boss.hp <= 0:
		return
	if event.keycode == KEY_B:
		# damage ถูกหักด้วย VIT ของ Boss — ส่งเกินไว้มากๆ ให้ตายในครั้งเดียว
		boss.take_damage(boss.max_hp * 100.0)
	elif event.keycode == KEY_V:
		var leader := get_tree().get_first_node_in_group("party_leader")
		if leader:
			WORLD_SCRIPT.place_on_ground(boss, leader.global_position.x + DEBUG_BOSS_NEAR_OFFSET.x)
