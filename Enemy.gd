extends CharacterBody2D

const WALK_SPEED := 80.0
const STOP_DISTANCE := 40.0
const COIN_SCENE := preload("res://CoinPickup.tscn")
const HP_POTION_SCENE := preload("res://HPPotionPickup.tscn")
const HP_POTION_DROP_CHANCE := 0.5
# อ้างอิงค่าเดียวกับ Hero เพื่อให้ปรับพร้อมกัน — ใช้เป็นรัศมีของ DetectArea
const ENEMY_DETECT_RANGE: float = preload("res://Hero.gd").HERO_DETECT_RANGE

@onready var sprite: Sprite2D = $Sprite2D
@onready var detect_area: Area2D = $DetectArea

var hp: int = 30
var attack_damage: int = 5
var attack_interval: float = 1.5
var attack_timer: float = 0.0
var target_hero: Node2D = null

var heroes_in_detect: Array[Node2D] = []


func _ready() -> void:
	var detect_shape: CircleShape2D = detect_area.get_node("CollisionShape2D").shape
	detect_shape.radius = ENEMY_DETECT_RANGE
	detect_area.body_entered.connect(_on_detect_area_body_entered)
	detect_area.body_exited.connect(_on_detect_area_body_exited)


func _process(delta: float) -> void:
	if hp <= 0:
		return

	# ไม่มี Hero ใน DetectArea (ยังไม่เคยเจอ หรือ Hero ออกนอกระยะไปแล้ว) = ยืนนิ่งที่ตำแหน่งปัจจุบัน
	target_hero = _find_nearest_hero_in_detect()
	if target_hero == null:
		attack_timer = 0.0
		return

	if global_position.distance_to(target_hero.global_position) > STOP_DISTANCE:
		attack_timer = 0.0
		_walk_toward_target(delta)
	else:
		_attack_target(delta)


func _find_nearest_hero_in_detect() -> Node2D:
	var closest: Node2D = null
	var closest_dist := INF
	for hero in heroes_in_detect:
		if not is_instance_valid(hero) or hero.hp <= 0:
			continue
		var dist: float = global_position.distance_to(hero.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = hero
	return closest


# เดินตรงเข้าหา Hero ตามเวกเตอร์ทิศทางจริง (ทั้งแกน X และ Y) จนกว่าจะเข้าระยะโจมตี
func _walk_toward_target(delta: float) -> void:
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
		# สุ่มแยกจาก coin — ไม่ผูกกัน
		if randf() < HP_POTION_DROP_CHANCE:
			_spawn_hp_potion()
		queue_free()


func _flash_hit() -> void:
	sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)


func _spawn_coin() -> void:
	var coin := COIN_SCENE.instantiate()
	get_parent().add_child(coin)
	coin.global_position = global_position


func _spawn_hp_potion() -> void:
	var potion := HP_POTION_SCENE.instantiate()
	get_parent().add_child(potion)
	potion.global_position = global_position


func _on_detect_area_body_entered(body: Node2D) -> void:
	heroes_in_detect.append(body)


func _on_detect_area_body_exited(body: Node2D) -> void:
	heroes_in_detect.erase(body)
