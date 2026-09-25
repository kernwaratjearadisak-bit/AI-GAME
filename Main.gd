extends Node2D

const ENEMY_SCENE := preload("res://Enemy.tscn")
const BOSS_SCENE := preload("res://Boss.tscn")
const WORLD_SCRIPT := preload("res://World.gd")
const RANDOM_ENEMY_COUNT_MIN := 15
const RANDOM_ENEMY_COUNT_MAX := 20
# กันไม่ให้ Enemy เกิดชิดขอบโลก หรือเกิดทับจุดเริ่มของ Hero
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
# TODO: ปุ่ม debug ชั่วคราว — B = Boss ตายทันที, V = ย้าย Boss มาข้างหน้า leader ปิดเป็น false ก่อน release
const DEBUG_BOSS_KEYS := true
const DEBUG_BOSS_NEAR_OFFSET := Vector2(500, 0)

# ตำแหน่งเกิดของ Enemy ทั้งหมด (พิกัด World)
# ถ้าอยากกำหนดตำแหน่งตายตัว ให้ใส่ค่าลงใน array นี้ได้เลย เช่น
#   Vector2(500, 300), Vector2(1200, 4800), ...
# ถ้า array ว่าง จะสุ่มตำแหน่งกระจายทั่ว World ให้แทน และสุ่มใหม่ทุก stage
var enemy_spawn_points: Array[Vector2] = []
var stage_pass_count := 0

# จำไว้ตอนเริ่มเกมว่า enemy_spawn_points ถูกกำหนดตายตัวไหม (หลัง _ready array จะไม่ว่างแล้วทั้งสองแบบ)
var has_fixed_spawn_points := false
var boss: Node2D = null
var stage_title_tween: Tween = null

@onready var enemy_container: Node2D = $Enemies
@onready var camera: Camera2D = $Camera2D
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
	for point in enemy_spawn_points:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.setup(get_stage_multiplier())
		enemy_container.add_child(enemy)
		enemy.global_position = point


func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.setup(get_stage_multiplier())
	enemy_container.add_child(boss)
	boss.global_position = BOSS_SPAWN_POSITION
	boss.boss_defeated.connect(_on_boss_defeated)


# current_stage = stage_pass_count + 1 → Stage 1 = x1, Stage 2 = x1.5, Stage 3 = x2.25, ...
func get_stage_multiplier() -> float:
	var current_stage := stage_pass_count + 1
	return pow(STAGE_SCALING, current_stage - 1)


func _generate_random_spawn_points() -> Array[Vector2]:
	var leader := get_tree().get_first_node_in_group("party_leader")
	var hero_start: Vector2 = leader.global_position if leader else Vector2(-INF, -INF)
	var count := randi_range(RANDOM_ENEMY_COUNT_MIN, RANDOM_ENEMY_COUNT_MAX)

	var points: Array[Vector2] = []
	while points.size() < count:
		var point := Vector2(
			randf_range(WORLD_EDGE_MARGIN, WORLD_SCRIPT.SIZE.x - WORLD_EDGE_MARGIN),
			randf_range(WORLD_EDGE_MARGIN, WORLD_SCRIPT.SIZE.y - WORLD_EDGE_MARGIN)
		)
		if point.distance_to(hero_start) < HERO_SAFE_RADIUS:
			continue
		if point.distance_to(BOSS_SPAWN_POSITION) < BOSS_SAFE_RADIUS:
			continue
		points.append(point)
	return points


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
	if not is_instance_valid(boss) or boss.hp <= 0:
		return
	if event.keycode == KEY_B:
		# damage ถูกหักด้วย VIT ของ Boss — ส่งเกินไว้มากๆ ให้ตายในครั้งเดียว
		boss.take_damage(boss.max_hp * 100.0)
	elif event.keycode == KEY_V:
		var leader := get_tree().get_first_node_in_group("party_leader")
		if leader:
			boss.global_position = WORLD_SCRIPT.clamp_to_bounds(leader.global_position + DEBUG_BOSS_NEAR_OFFSET)
