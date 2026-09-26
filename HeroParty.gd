extends Node2D

# coin กองกลางของทั้ง party เปลี่ยน — ResourceBar / UI ฟังได้
signal coins_changed(new_amount: int)

const HERO_SCENE := preload("res://Hero.tscn")
const HERO_COUNT := 2
const MAX_HEROES := 4
const LANE_GAP := 40.0
const WORLD_SCRIPT := preload("res://World.gd")
# จุดเกิดในพิกัด World (ขนาด 14400x1280): ชิดซ้าย — ใช้แค่ x, y วางบนพื้นด้วย World.place_on_ground()
const BASE_POSITION := Vector2(1000, 640)
# formation_facing เปลี่ยนเมื่อ leader เดินไปทิศใหม่ต่อเนื่องเกินเวลานี้ หรือเกินระยะนี้ (อย่างใดอย่างหนึ่งก่อน)
const FORMATION_TURN_TIME := 0.5
const FORMATION_TURN_DISTANCE := 100.0
# leader เร็วต่ำกว่านี้ = ไม่ได้เดิน (ยืนตี / หยุด) → ล้างตัวนับ ไม่สลับแถว
const FORMATION_TURN_MIN_SPEED: float = preload("res://Hero.gd").ANIM_MOVE_THRESHOLD

# ตัวแรกตั้งแต่ต้นเกม = 0 ตัวที่ recruit เพิ่มได้ 1, 2, 3 ตามลำดับ
var next_recruit_index := 0
# coin กองกลาง — อ่าน/แก้ผ่าน add_coins / can_afford / spend_coins เท่านั้น
# HeroParty ไม่ถูกสร้างใหม่ตอน reset_stage จึงคงอยู่ข้าม stage
var party_coins: int = 0
# ทิศที่แถวหัน (1 = ขวา, -1 = ซ้าย) — follower ยืนฝั่งตรงข้าม; แยกจาก flip_h ของ leader ที่หันไปมาตอนตี
var formation_facing := 1.0
# ตัวนับ hysteresis ตอน leader เดินสวนทิศ formation_facing อยู่
var turn_time := 0.0
var turn_distance := 0.0


func _ready() -> void:
	add_to_group("hero_party")

	var hero: CharacterBody2D = HERO_SCENE.instantiate()
	hero.hero_class = HeroClasses.HeroClass.WARRIOR
	hero.recruit_index = next_recruit_index
	next_recruit_index += 1
	add_child(hero)
	WORLD_SCRIPT.place_on_ground(hero, BASE_POSITION.x)
	hero.select()

	# TODO: เปิดกลับมาใช้หลังตรรกะการโจมตีนิ่งแล้ว — spawn Hero ตัวที่ 2-4 เรียงเป็นเลน
	#var heroes: Array[CharacterBody2D] = []
	#for i in range(HERO_COUNT):
	#	var hero: CharacterBody2D = HERO_SCENE.instantiate()
	#	add_child(hero)
	#	heroes.append(hero)
	#
	#var spacing := _get_hitbox_height(heroes[0]) + LANE_GAP
	#for i in range(HERO_COUNT):
	#	var offset_y: float = (i - (HERO_COUNT - 1) / 2.0) * spacing
	#	heroes[i].position = BASE_POSITION + Vector2(0, offset_y)
	#
	#heroes[0].select()


func _physics_process(delta: float) -> void:
	_update_formation_facing(delta)


# ดูแค่ velocity.x ของ leader (ไม่ใช่ทิศที่หัน) — ยืนตีหันซ้ายขวาไม่ทำให้แถวสลับ
# ต้องเดินสวนทิศเดิมต่อเนื่อง: หยุดหรือกลับไปเดินทิศเดิมเมื่อไหร่ ล้างตัวนับ
func _update_formation_facing(delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		_reset_formation_turn()
		return
	var leader_velocity_x: float = leader.velocity.x
	if absf(leader_velocity_x) < FORMATION_TURN_MIN_SPEED or signf(leader_velocity_x) == formation_facing:
		_reset_formation_turn()
		return
	turn_time += delta
	turn_distance += absf(leader_velocity_x) * delta
	if turn_time > FORMATION_TURN_TIME or turn_distance > FORMATION_TURN_DISTANCE:
		formation_facing = signf(leader_velocity_x)
		_reset_formation_turn()


func _reset_formation_turn() -> void:
	turn_time = 0.0
	turn_distance = 0.0


# MAX_HEROES นับรวมทุก class — recruit_index / formation ไม่ขึ้นกับ class
func recruit_hero(hero_class: HeroClasses.HeroClass) -> void:
	if get_tree().get_nodes_in_group("heroes").size() >= MAX_HEROES:
		return

	var leader := get_tree().get_first_node_in_group("party_leader")
	var spawn_position: Vector2 = leader.global_position if leader else BASE_POSITION

	var hero: CharacterBody2D = HERO_SCENE.instantiate()
	hero.hero_class = hero_class
	hero.recruit_index = next_recruit_index
	next_recruit_index += 1
	add_child(hero)
	WORLD_SCRIPT.place_on_ground(hero, spawn_position.x)


# Hero ที่ recruit_index == index (Hero ไม่ถูก queue_free ตอนตาย จึงยังเจอตัวที่ตายอยู่) — ไม่มีคืน null
func get_hero_by_index(index: int) -> Node2D:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero.recruit_index == index:
			return hero
	return null


# Hero._die() เรียก — ถ้าตัวที่ตายเป็นตัวที่เลือกอยู่ ให้เลือกตัวที่ยังมีชีวิตซึ่ง recruit_index น้อยสุดแทน
# ตายหมดแล้วไม่ทำอะไร (leader ที่ตายยังอยู่ใน group party_leader ตาม logic เดิม)
func on_hero_died(hero: Node2D) -> void:
	if not hero.is_selected:
		return
	for index in next_recruit_index:
		var candidate := get_hero_by_index(index)
		if candidate and candidate.hp > 0:
			candidate.select()
			return


# Hero ที่ยังมีชีวิตซึ่ง HP% (hp / max_hp) ต่ำสุด — HP% เท่ากันเลือกตัวที่ recruit ก่อน, ไม่เหลือใครคืน null
# ทุกตัวเลือดเต็มก็ยังคืนตัวตามกฎนี้ (ผู้เรียกตัดสินเองว่าจะทำอะไร)
func get_lowest_hp_hero() -> Node2D:
	var best: Node2D = null
	var best_ratio := INF
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero.hp <= 0 or hero.is_queued_for_deletion():
			continue
		var ratio: float = hero.hp / hero.max_hp
		if ratio < best_ratio or (ratio == best_ratio and hero.recruit_index < best.recruit_index):
			best_ratio = ratio
			best = hero
	return best


func add_coins(amount: int) -> void:
	party_coins += amount
	coins_changed.emit(party_coins)


func can_afford(amount: int) -> bool:
	return party_coins >= amount


# ไม่พอ = ไม่หักและคืน false
func spend_coins(amount: int) -> bool:
	if not can_afford(amount):
		return false
	party_coins -= amount
	coins_changed.emit(party_coins)
	return true


# เรียกจาก Main.reset_stage(): ไม่สร้าง Hero ใหม่ — reset ตัวเดิม แล้ววาง leader ที่ BASE_POSITION, follower ที่ formation slot
func reset_for_new_stage() -> void:
	var heroes := get_tree().get_nodes_in_group("heroes")
	# reset hp ก่อน เพราะ _get_formation_slot นับเฉพาะ Hero ที่ hp > 0
	for hero in heroes:
		hero.reset_for_new_stage()

	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	WORLD_SCRIPT.place_on_ground(leader, BASE_POSITION.x)
	# เริ่ม stage หันขวา → follower เรียงอยู่ทางซ้ายของ leader
	formation_facing = 1.0
	_reset_formation_turn()
	for hero in heroes:
		if hero != leader:
			WORLD_SCRIPT.place_on_ground(hero, hero._get_formation_slot(leader).x)


func _get_hitbox_height(hero: CharacterBody2D) -> float:
	var collision_shape: CollisionShape2D = hero.get_node("CollisionShape2D")
	var rect_shape: RectangleShape2D = collision_shape.shape
	return rect_shape.size.y * collision_shape.scale.y
