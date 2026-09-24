extends Node2D

const ENEMY_SCENE := preload("res://Enemy.tscn")
const WORLD_SCRIPT := preload("res://World.gd")
const RANDOM_ENEMY_COUNT_MIN := 15
const RANDOM_ENEMY_COUNT_MAX := 20
# กันไม่ให้ Enemy เกิดชิดขอบโลก หรือเกิดทับจุดเริ่มของ Hero
const WORLD_EDGE_MARGIN := 200.0
const HERO_SAFE_RADIUS := 800.0

# ตำแหน่งเกิดของ Enemy ทั้งหมด (พิกัด World) — spawn ครั้งเดียวตอนเริ่มเกม
# ถ้าอยากกำหนดตำแหน่งตายตัว ให้ใส่ค่าลงใน array นี้ได้เลย เช่น
#   Vector2(500, 300), Vector2(1200, 4800), ...
# ถ้า array ว่าง จะสุ่มตำแหน่งกระจายทั่ว World ให้แทน
var enemy_spawn_points: Array[Vector2] = []

@onready var enemy_container: Node2D = $Enemies


func _ready() -> void:
	if enemy_spawn_points.is_empty():
		enemy_spawn_points = _generate_random_spawn_points()
	_spawn_enemies()


func _spawn_enemies() -> void:
	for point in enemy_spawn_points:
		var enemy := ENEMY_SCENE.instantiate()
		enemy_container.add_child(enemy)
		enemy.global_position = point


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
		points.append(point)
	return points
