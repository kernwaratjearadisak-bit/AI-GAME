extends CharacterBody2D

const WALK_SPEED := 80.0
# ระยะ center-to-center ที่หยุดเดินแล้วเริ่มตี: ลำตัว knight กว้าง 76 → ≥ 76 ไม่ทับกัน
# ≥ จุดที่ Hero หยุด (AttackArea 80 + ครึ่งความกว้าง Enemy 38 = 118) จึงตีกันได้ทั้งคู่ที่ระยะ ~118
const STOP_DISTANCE := 120.0
const COIN_SCENE := preload("res://CoinPickup.tscn")
const HP_POTION_SCENE := preload("res://HPPotionPickup.tscn")
const HP_POTION_DROP_CHANCE := 0.25
const WORLD_SCRIPT := preload("res://World.gd")
# สีตัวเลข damage ตอน Enemy/Boss โดน Hero ตี
const DAMAGE_NUMBER_COLOR := Color(0.3, 0.6, 1.0)
# อ้างอิงค่าเดียวกับ Hero เพื่อให้ปรับพร้อมกัน — DetectArea กว้าง 2 เท่าของระยะแกน X นี้
const ENEMY_DETECT_RANGE: float = preload("res://Hero.gd").HERO_DETECT_RANGE
const DETECT_AREA_HEIGHT: float = preload("res://Hero.gd").DETECT_AREA_HEIGHT
# ใช้ offset / threshold ชุดเดียวกับ Hero
const SPRITE_OFFSET: Vector2 = preload("res://Hero.gd").SPRITE_OFFSET
const ANIM_MOVE_THRESHOLD: float = preload("res://Hero.gd").ANIM_MOVE_THRESHOLD
# ค่าพื้นฐานของ Stage 1 — setup() คูณ stage_multiplier จากค่านี้ทุกครั้ง ไม่คูณทับค่าเดิม
const BASE_HP := 30.0
const BASE_ATTACK := 5.0
# knockback แบบลอย: ตั้ง velocity.y = -hop ครั้งเดียวตอนเริ่ม แล้ว gravity ดึงลงเอง
# 220 → สูงสุด ~25px (220² / 2g), ลอยอยู่ ~0.45 วิ (2 * 220 / g)
const KNOCKBACK_HOP_SPEED := 220.0
# ลำดับ animation ที่ลองเล่นตอนลอยกลางอากาศระหว่าง knockback — ไม่มีสักตัวก็ค้าง animation "hit" เดิมไว้
const AIRBORNE_ANIMATIONS: Array[StringName] = [&"hurt", &"fall"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detect_area: Area2D = $DetectArea

var hp: float = BASE_HP
var max_hp: float = BASE_HP
# Boss ตั้งค่าใหม่ใน _ready (const override ใน subclass ไม่ได้) — Enemy ปกติใช้ STOP_DISTANCE เหมือนเดิม
var stop_distance: float = STOP_DISTANCE
var attack_damage: float = BASE_ATTACK
# STR / VIT / AGI — สูตรอยู่ใน CombatStats.gd
@export var strength: int = 5
@export var vitality: int = 5
@export var agility: int = 5:
	set(value):
		agility = value
		_update_attack_interval()
# interval ก่อนคิด AGI — attack_interval จริงคำนวณใหม่จากค่านี้ทุกครั้ง ไม่คูณทับ
@export var base_attack_interval: float = 1.5:
	set(value):
		base_attack_interval = value
		_update_attack_interval()
var attack_interval: float = 1.5
var attack_timer: float = 0.0
var target_hero: Node2D = null
var is_knocked_back := false
# knockback ผ่าน velocity.x: เริ่มที่ knockback_start_speed แล้วลดลงเป็นเส้นตรงถึง 0 ตอนหมดเวลา (ease out)
var knockback_start_speed := 0.0
var knockback_duration := 0.0
var knockback_time_left := 0.0
# Boss ตั้งค่าใหม่ใน _ready (ลอยต่ำกว่า)
var knockback_hop_speed: float = KNOCKBACK_HOP_SPEED

var heroes_in_detect: Array[Node2D] = []


# Main เรียกก่อน add_child — Stage 1 = x1, Stage 2 = x1.5, ...
func setup(stage_multiplier: float) -> void:
	max_hp = snappedf(_get_base_hp() * stage_multiplier, 0.01)
	hp = max_hp
	attack_damage = snappedf(BASE_ATTACK * stage_multiplier, 0.01)


# Boss override เพื่อคูณ HP ก่อนคูณ stage_multiplier
func _get_base_hp() -> float:
	return BASE_HP


func _ready() -> void:
	z_index = WORLD_SCRIPT.Z_INDEX_ENEMY
	# HeroSkills (Bash) หาเป้าจาก group นี้ — รวม Boss
	add_to_group("enemies")
	_update_attack_interval()
	var detect_shape: RectangleShape2D = detect_area.get_node("CollisionShape2D").shape
	detect_shape.size = Vector2(ENEMY_DETECT_RANGE * 2.0, DETECT_AREA_HEIGHT)
	detect_area.body_entered.connect(_on_detect_area_body_entered)
	detect_area.body_exited.connect(_on_detect_area_body_exited)


func _physics_process(delta: float) -> void:
	# AI / knockback คุมแค่ velocity.x — velocity.y มาจาก gravity (+ hop ครั้งเดียวตอนเริ่ม knockback)
	velocity.x = 0.0
	# ตายกลางอากาศก็ยังตกลงพื้นระหว่างเล่น death
	if hp <= 0:
		velocity.y += WORLD_SCRIPT.GRAVITY * delta
		move_and_slide()
		return
	# ระหว่างโดน knock-back = stun: ไม่เดิน ไม่โจมตี
	if is_knocked_back:
		_update_knockback(delta)
	else:
		_update_ai(delta)
	velocity.y += WORLD_SCRIPT.GRAVITY * delta
	move_and_slide()
	_update_animation()


func _update_ai(delta: float) -> void:

	# ไม่มี Hero ใน DetectArea (ยังไม่เคยเจอ หรือ Hero ออกนอกระยะไปแล้ว) = ยืนนิ่งที่ตำแหน่งปัจจุบัน
	target_hero = _find_nearest_hero_in_detect()
	if target_hero == null:
		attack_timer = 0.0
		return

	if absf(target_hero.global_position.x - global_position.x) > stop_distance:
		attack_timer = 0.0
		_walk_toward_target()
	else:
		_attack_target(delta)


func _find_nearest_hero_in_detect() -> Node2D:
	var closest: Node2D = null
	var closest_dist := INF
	for hero in heroes_in_detect:
		if not is_instance_valid(hero) or hero.hp <= 0:
			continue
		var dist: float = absf(hero.global_position.x - global_position.x)
		if dist < closest_dist:
			closest_dist = dist
			closest = hero
	return closest


# เดินแกน X เข้าหา Hero จนกว่าจะเข้าระยะโจมตี (stop_distance > 0 จึงไม่มีทางเลยเป้า)
func _walk_toward_target() -> void:
	velocity.x = signf(target_hero.global_position.x - global_position.x) * WALK_SPEED


func _attack_target(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		sprite.play("attack", CombatStats.get_attack_anim_speed(sprite, attack_interval))
		# STR → สุ่ม ±20% → (ฝั่งที่โดนตี) หัก VIT ใน take_damage
		target_hero.take_damage(CombatStats.roll_damage(CombatStats.get_damage_output(attack_damage, strength)))


func _update_attack_interval() -> void:
	attack_interval = CombatStats.get_attack_interval(base_attack_interval, agility)


# แกน X (offset.y ไม่ใช้): ความเร็วลดเป็นเส้นตรงถึง 0 ใน duration วิ ระยะรวม = offset.x
# (พื้นที่สามเหลี่ยม: start_speed * duration / 2) ชนกำแพงก็หยุดเองผ่าน move_and_slide()
# แกน Y: เด้งขึ้นด้วย knockback_hop_speed ครั้งเดียว — ลอยนานกว่า duration แต่แกน X หยุดแล้ว ระยะรวมจึงยัง = offset.x
func apply_knockback(offset: Vector2, duration: float) -> void:
	is_knocked_back = true
	attack_timer = 0.0
	knockback_duration = duration
	knockback_time_left = duration
	knockback_start_speed = 2.0 * offset.x / duration
	velocity.y = -knockback_hop_speed


# stun จบเมื่อหมดเวลาแกน X และลงถึงพื้นแล้วเท่านั้น — ไม่เดิน/ตีกลางอากาศ
# is_on_floor() เป็นผลของ move_and_slide() เฟรมก่อน: เฟรมที่เริ่ม hop ยังเป็น true แต่ time_left ยังไม่หมดจึงไม่จบ
func _update_knockback(delta: float) -> void:
	if knockback_time_left > 0.0:
		velocity.x = knockback_start_speed * (knockback_time_left / knockback_duration)
		knockback_time_left -= delta
	elif is_on_floor():
		is_knocked_back = false


func take_damage(amount: float) -> void:
	if hp <= 0:
		return
	var received := CombatStats.get_damage_received(amount, vitality)
	hp = snappedf(hp - received, 0.01)
	_spawn_damage_number(received)
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
# เอา layer ออกแทนการปิด shape: Hero ไม่เห็นแล้ว แต่ยังชนพื้น (mask) ได้ ศพที่ตายกลางอากาศจึงไม่ตกทะลุพื้น
func _die() -> void:
	set_deferred("collision_layer", 0)
	detect_area.set_deferred("monitoring", false)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()


# attack / hit เล่นจนจบก่อน แล้วค่อยกลับเป็น idle/run ตามการเคลื่อนที่
# velocity.y มี gravity สะสมทุกเฟรม — ดูแค่แกน X
func _update_animation() -> void:
	if absf(velocity.x) > ANIM_MOVE_THRESHOLD:
		_set_facing_left(velocity.x < 0)
	elif is_instance_valid(target_hero):
		_set_facing_left(target_hero.global_position.x < global_position.x)

	if is_knocked_back and not is_on_floor():
		_play_airborne_animation()
		return
	if _is_playing_action("attack") or _is_playing_action("hit"):
		return
	if absf(velocity.x) > ANIM_MOVE_THRESHOLD:
		sprite.play("run")
	else:
		sprite.play("idle")


# มี hurt/fall ก็เล่นตัวแรกที่เจอ ไม่มีก็ไม่เปลี่ยน — ค้าง "hit" ที่ take_damage เล่นไว้ (ไม่สลับเป็น idle/run กลางอากาศ)
func _play_airborne_animation() -> void:
	for anim_name in AIRBORNE_ANIMATIONS:
		if sprite.sprite_frames.has_animation(anim_name):
			if sprite.animation != anim_name:
				sprite.play(anim_name)
			return


func _is_playing_action(anim_name: StringName) -> bool:
	return sprite.animation == anim_name and sprite.is_playing()


func _set_facing_left(left: bool) -> void:
	sprite.flip_h = left
	sprite.offset = Vector2(-SPRITE_OFFSET.x if left else SPRITE_OFFSET.x, SPRITE_OFFSET.y)


func _spawn_damage_number(amount: float) -> void:
	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_damage_number(self, amount, DAMAGE_NUMBER_COLOR)


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
