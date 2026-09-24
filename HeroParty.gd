extends Node2D

const HERO_SCENE := preload("res://Hero.tscn")
const HERO_COUNT := 2
const MAX_HEROES := 4
const LANE_GAP := 40.0
const RECRUIT_OFFSET := 30.0
# จุดเกิดในพิกัด World (ขนาด 14400x1280): ชิดซ้าย กึ่งกลางแนวตั้ง
const BASE_POSITION := Vector2(1000, 640)

# ตัวแรกตั้งแต่ต้นเกม = 0 ตัวที่ recruit เพิ่มได้ 1, 2, 3 ตามลำดับ
var next_recruit_index := 0


func _ready() -> void:
	add_to_group("hero_party")

	var hero: CharacterBody2D = HERO_SCENE.instantiate()
	hero.recruit_index = next_recruit_index
	next_recruit_index += 1
	add_child(hero)
	hero.global_position = BASE_POSITION
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


func recruit_hero() -> void:
	if get_tree().get_nodes_in_group("heroes").size() >= MAX_HEROES:
		return

	var leader := get_tree().get_first_node_in_group("party_leader")
	var spawn_position: Vector2 = leader.global_position if leader else BASE_POSITION

	var hero: CharacterBody2D = HERO_SCENE.instantiate()
	hero.recruit_index = next_recruit_index
	next_recruit_index += 1
	add_child(hero)
	hero.global_position = spawn_position + Vector2(0, RECRUIT_OFFSET)


func _get_hitbox_height(hero: CharacterBody2D) -> float:
	var collision_shape: CollisionShape2D = hero.get_node("CollisionShape2D")
	var rect_shape: RectangleShape2D = collision_shape.shape
	return rect_shape.size.y * collision_shape.scale.y
