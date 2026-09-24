extends CharacterBody2D

const WALK_SPEED := 80.0
const STOP_DISTANCE := 40.0
const COIN_SCENE := preload("res://CoinPickup.tscn")
# อ้างอิงค่าเดียวกับ Hero เพื่อให้ปรับพร้อมกัน — ยังไม่ได้ใช้ รอระบบ detect ของ Enemy (ส่วนที่ 4)
const ENEMY_DETECT_RANGE: float = preload("res://Hero.gd").HERO_DETECT_RANGE

@onready var sprite: Sprite2D = $Sprite2D

var hp: int = 30
var attack_damage: int = 5
var attack_interval: float = 1.5
var attack_timer: float = 0.0
var stopped := false
var target_hero: Node2D = null
# เริ่มต้นยืนนิ่งที่จุดเกิด จนกว่าจะถูก detect (ระบบ detect จะทำในส่วนถัดไป)
var is_active := false


func _process(delta: float) -> void:
	if hp <= 0 or not is_active:
		return

	_update_target()
	if target_hero == null:
		return

	if not stopped:
		_walk_toward_target(delta)
	else:
		_attack_target(delta)


func _update_target() -> void:
	if is_instance_valid(target_hero) and target_hero.hp > 0:
		return
	target_hero = _find_nearest_hero()
	stopped = false


func _find_nearest_hero() -> Node2D:
	var closest: Node2D = null
	var closest_dist := INF
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero.hp <= 0:
			continue
		var dist: float = global_position.distance_to(hero.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = hero
	return closest


func _walk_toward_target(delta: float) -> void:
	var distance := global_position.distance_to(target_hero.global_position)
	if distance <= STOP_DISTANCE:
		stopped = true
		return
	global_position = global_position.move_toward(target_hero.global_position, WALK_SPEED * delta)


func _attack_target(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		target_hero.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	_flash_hit()
	if hp <= 0:
		_spawn_coin()
		queue_free()


func _flash_hit() -> void:
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)


func _spawn_coin() -> void:
	var coin := COIN_SCENE.instantiate()
	get_parent().add_child(coin)
	coin.global_position = global_position
