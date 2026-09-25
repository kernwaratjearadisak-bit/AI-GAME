extends CharacterBody2D

const WALK_SPEED := 80.0
# ระยะ center-to-center ที่หยุดเดินแล้วเริ่มตี: ลำตัว knight กว้าง 76 → ≥ 76 ไม่ทับกัน
# ≥ จุดที่ Hero หยุด (AttackArea 80 + ครึ่งความกว้าง Enemy 38 = 118) จึงตีกันได้ทั้งคู่ที่ระยะ ~118
const STOP_DISTANCE := 120.0
const COIN_SCENE := preload("res://CoinPickup.tscn")
const HP_POTION_SCENE := preload("res://HPPotionPickup.tscn")
const HP_POTION_DROP_CHANCE := 0.25
const WORLD_SCRIPT := preload("res://World.gd")
# อ้างอิงค่าเดียวกับ Hero เพื่อให้ปรับพร้อมกัน — ใช้เป็นรัศมีของ DetectArea
const ENEMY_DETECT_RANGE: float = preload("res://Hero.gd").HERO_DETECT_RANGE
# ใช้ offset / threshold ชุดเดียวกับ Hero
const SPRITE_OFFSET: Vector2 = preload("res://Hero.gd").SPRITE_OFFSET
const ANIM_MOVE_THRESHOLD: float = preload("res://Hero.gd").ANIM_MOVE_THRESHOLD

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detect_area: Area2D = $DetectArea

var hp: int = 30
var attack_damage: int = 5
var attack_interval: float = 1.5
var attack_timer: float = 0.0
var target_hero: Node2D = null
var is_knocked_back := false
var knockback_tween: Tween = null

var heroes_in_detect: Array[Node2D] = []


func _ready() -> void:
	var detect_shape: CircleShape2D = detect_area.get_node("CollisionShape2D").shape
	detect_shape.radius = ENEMY_DETECT_RANGE
	detect_area.body_entered.connect(_on_detect_area_body_entered)
	detect_area.body_exited.connect(_on_detect_area_body_exited)


func _process(delta: float) -> void:
	if hp <= 0:
		return
	# Enemy เดินด้วยการตั้ง global_position ตรงๆ ไม่มี velocity — วัดระยะที่ขยับในเฟรมนี้แทน
	var previous_position := global_position
	_update_ai(delta)
	_update_animation((global_position - previous_position) / delta)


func _update_ai(delta: float) -> void:
	# ระหว่างโดน knock-back = stun: ไม่เดิน ไม่โจมตี
	if hp <= 0 or is_knocked_back:
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
		sprite.play("attack")
		target_hero.take_damage(attack_damage)


func apply_knockback(offset: Vector2, duration: float) -> void:
	if knockback_tween and knockback_tween.is_valid():
		knockback_tween.kill()
	is_knocked_back = true
	attack_timer = 0.0
	var destination := WORLD_SCRIPT.clamp_to_bounds(global_position + offset)
	knockback_tween = create_tween()
	knockback_tween.tween_property(self, "global_position", destination, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	knockback_tween.finished.connect(func() -> void: is_knocked_back = false)


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
		_die()
	elif not _is_playing_action("attack"):
		sprite.play("hit")


# ของ drop ออกไปแล้วตอน hp ถึง 0 — ตรงนี้ปิด collision/area แล้วรอ death เล่นจบก่อน queue_free
func _die() -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	detect_area.set_deferred("monitoring", false)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()


# attack / hit เล่นจนจบก่อน แล้วค่อยกลับเป็น idle/run ตามการเคลื่อนที่
func _update_animation(motion: Vector2) -> void:
	if absf(motion.x) > ANIM_MOVE_THRESHOLD:
		_set_facing_left(motion.x < 0)
	elif is_instance_valid(target_hero):
		_set_facing_left(target_hero.global_position.x < global_position.x)

	if _is_playing_action("attack") or _is_playing_action("hit"):
		return
	if motion.length() > ANIM_MOVE_THRESHOLD:
		sprite.play("run")
	else:
		sprite.play("idle")


func _is_playing_action(anim_name: StringName) -> bool:
	return sprite.animation == anim_name and sprite.is_playing()


func _set_facing_left(left: bool) -> void:
	sprite.flip_h = left
	sprite.offset = Vector2(-SPRITE_OFFSET.x if left else SPRITE_OFFSET.x, SPRITE_OFFSET.y)


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
