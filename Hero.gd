extends CharacterBody2D

enum HeroState { SEEKING, FIGHTING, RETURNING }

const SELECT_HALF_SIZE := Vector2(120, 160)
const RETURN_LEASH_RANGE := 300.0
# เมื่อเข้า RETURNING แล้ว ให้เดินกลับจนเข้าใกล้ formation slot ระยะนี้ก่อนค่อยกลับไปหา Enemy
# slot ไกลสุดห่าง leader 3 * FORMATION_SPACING = 210 → หยุดที่ ≤ 260 จาก leader ยังต่ำกว่า RETURN_LEASH_RANGE (300)
# เหลือช่วงกัน 40px ไม่สลับ RETURNING/SEEKING ไปมาทุกเฟรม
const RETURN_STOP_RANGE := 50.0
const MOVE_SPEED := 150.0
# ต้องเร็วกว่า MOVE_SPEED ไม่งั้นจะไม่มีวันตามทัน leader ที่กำลังเดินขวาอยู่
const RETURN_SPEED := 225.0
# ระยะมองเห็นแกน X (abs(dx)) — SightArea เป็นสี่เหลี่ยมกว้าง 2 เท่าของค่านี้ รอบ origin
const HERO_DETECT_RANGE := 400.0
# ความสูงของ SightArea / DetectArea — ทุกตัวยืนบนพื้นเดียวกัน แค่ให้สูงพอครอบลำตัว Boss (296)
const DETECT_AREA_HEIGHT := 600.0
const WORLD_SCRIPT := preload("res://World.gd")
# สีตัวเลข damage ตอน Hero โดนตี
const DAMAGE_NUMBER_COLOR := Color(1.0, 0.25, 0.25)
const HERO_KNOCKBACK_CHANCE := 0.3
const HERO_KNOCKBACK_DISTANCE := 65.0
# ระยะเวลาที่ Enemy ถูกดันถอยหลัง = ระยะเวลาที่ Enemy ถูก stun ด้วย
const HERO_KNOCKBACK_DURATION := 0.12
# แถวเดียวข้างหลัง leader: follower ลำดับที่ i (เรียงตาม recruit_index, เริ่ม 0) อยู่ห่าง leader (i + 1) * FORMATION_SPACING
# "ข้างหลัง" = ฝั่งตรงข้ามกับ HeroParty.formation_facing (ไม่ใช่ flip_h ของ leader ที่หันไปมาตอนตี)
const FORMATION_SPACING := 70.0
# ตาม formation แบบ feed-forward: desired = ความเร็ว leader + (slot - ตำแหน่ง) * GAIN (ไม่มี dead zone หยุด/วิ่ง)
# แล้วค่อยๆ ปรับความเร็วเข้าหา desired ด้วย FORMATION_ACCEL (px/s²) ไม่ให้กระตุก
const FORMATION_CORRECTION_GAIN := 4.0
const FORMATION_ACCEL := 1200.0
# offset ของ AnimatedSprite2D ตอนหันขวา (ตัว knight อยู่เยื้องซ้ายใน frame 120x80) — ตอน flip_h ต้องกลับด้าน x เอง
# เพราะ flip_h ไม่ได้ flip offset ให้ ลำตัวจะเลื่อนออกจาก origin
const SPRITE_OFFSET := Vector2(6, -21)
# ความเร็ว x ต่ำกว่านี้ไม่เปลี่ยนทิศที่หัน
const ANIM_MOVE_THRESHOLD := 5.0
# hysteresis ของ run/idle: เร็วกว่า RUN เปลี่ยนเป็น run, ช้ากว่า IDLE กลับเป็น idle กันสลับรัวๆ
const ANIM_RUN_SPEED := 20.0
const ANIM_IDLE_SPEED := 8.0
# ราคาอัป STR / VIT / AGI +1 (หักจาก coin กองกลางใน HeroParty)
const STAT_UPGRADE_COST := 5
# จุดปล่อยลูกธนูของ Archer เทียบกับ origin (กลางลำตัว) ตอนหันขวา: ระดับอก เยื้องไปข้างหน้าเล็กน้อย — หันซ้ายกลับด้าน x
const ARROW_RELEASE_OFFSET := Vector2(24, -24)

# ประเภทการเดินในเฟรมนี้ — ใช้ตัดสินว่าจะหันหน้าตามอะไร
enum MoveMode { NONE, CHASE, FORMATION, RETURN }

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_area: Area2D = $SightArea
@onready var attack_area: Area2D = $AttackArea
@onready var selected_indicator: Polygon2D = $SelectedIndicator

var hp: float = 100.0
var max_hp: float = 100.0
var attack_damage: float = 10.0
# HeroParty ตั้งก่อน add_child — _ready() ปรับ attack range / interval / tint ตาม HeroClasses
var hero_class: HeroClasses.HeroClass = HeroClasses.HeroClass.WARRIOR
# STR / VIT / AGI — สูตรอยู่ใน CombatStats.gd
@export var strength: int = 10
@export var vitality: int = 10
@export var agility: int = 10:
	set(value):
		agility = value
		_update_attack_interval()
# interval ก่อนคิด class และ AGI — attack_interval จริงคำนวณใหม่จากค่านี้ทุกครั้ง ไม่คูณทับ
@export var base_attack_interval: float = 1.0:
	set(value):
		base_attack_interval = value
		_update_attack_interval()
var attack_interval: float = 1.0
var attack_timer: float = 0.0
var is_selected: bool = false
# ลำดับการ recruit: ตัวแรกตั้งแต่ต้นเกม = 0, ตัวที่กด Recruit เพิ่มตามลำดับ = 1, 2, 3 (HeroParty เป็นคนตั้ง)
var recruit_index: int = 0
var state: HeroState = HeroState.SEEKING

# ทุกเส้นทางการเดิน (ไล่ Enemy / formation / RETURNING / เดินขวา) ตั้งค่านี้ = velocity.x ของเฟรมนี้
# velocity.y มาจาก gravity อย่างเดียว แล้วขยับจริงผ่าน move_and_slide() ครั้งเดียวต่อเฟรม
var move_velocity_x := 0.0
# ความเร็วที่ค้างข้ามเฟรมของ formation/RETURNING (move_toward ต่อจากค่านี้) — ตอนทำอย่างอื่นจะ sync ตาม move_velocity_x
# เพื่อให้ตอนสลับเข้า formation เริ่มจากความเร็วจริงที่เดินอยู่
var formation_velocity_x := 0.0
var move_mode: MoveMode = MoveMode.NONE
var is_running := false

var enemies_in_sight: Array[Node2D] = []
var enemies_in_attack_range: Array[Node2D] = []


func _ready() -> void:
	add_to_group("heroes")
	# select() ยกเป็น Z_INDEX_SELECTED_HERO ทีหลังถ้าเป็นตัวที่เลือก
	z_index = WORLD_SCRIPT.Z_INDEX_HERO
	_apply_hero_class()
	_update_attack_interval()
	animated_sprite.play("idle")
	var sight_shape: RectangleShape2D = sight_area.get_node("CollisionShape2D").shape
	sight_shape.size = Vector2(HERO_DETECT_RANGE * 2.0, DETECT_AREA_HEIGHT)
	sight_area.body_entered.connect(_on_sight_area_body_entered)
	sight_area.body_exited.connect(_on_sight_area_body_exited)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)


func select() -> void:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero == self:
			continue
		hero.is_selected = false
		hero.remove_from_group("party_leader")
		hero.selected_indicator.visible = false
		hero.z_index = WORLD_SCRIPT.Z_INDEX_HERO
	is_selected = true
	z_index = WORLD_SCRIPT.Z_INDEX_SELECTED_HERO
	add_to_group("party_leader")
	selected_indicator.visible = true
	state = HeroState.SEEKING
	sight_area.monitoring = true


func _unhandled_input(event: InputEvent) -> void:
	var click_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
	else:
		return

	# event.position เป็นพิกัดจอ ต้องแปลงเป็นพิกัด World ก่อน เพราะกล้องขยับแล้ว
	click_pos = get_canvas_transform().affine_inverse() * click_pos
	print("Hero _unhandled_input click at ", click_pos, " checking ", name, " at ", global_position)
	if absf(click_pos.x - global_position.x) <= SELECT_HALF_SIZE.x and absf(click_pos.y - global_position.y) <= SELECT_HALF_SIZE.y:
		select()


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return

	move_velocity_x = 0.0
	move_mode = MoveMode.NONE
	_update_ai(delta)
	if move_mode != MoveMode.FORMATION and move_mode != MoveMode.RETURN:
		formation_velocity_x = move_velocity_x
	velocity.x = move_velocity_x
	velocity.y += WORLD_SCRIPT.GRAVITY * delta
	# ขอบซ้าย/ขวาของ World กันด้วยกำแพง (World.gd) ไม่ต้อง clamp ตำแหน่งเอง
	move_and_slide()
	_update_animation()


func _update_ai(delta: float) -> void:

	# is_selected มีผลกับ AI แค่ตอนไม่มีการต่อสู้: ตัวที่ไม่ได้ถูกเลือกจะมี leash และ fallback กลับ formation slot
	# ส่วน หา/ไล่/ต่อสู้ Enemy ด้านล่าง ทุกตัวรันอิสระของตัวเอง
	if not is_selected:
		_update_leash(delta)

	if state == HeroState.RETURNING:
		return

	if enemies_in_attack_range.is_empty():
		state = HeroState.SEEKING
		attack_timer = 0.0
		# หาเป้าใหม่ทุกเฟรม — ถ้าเป้าเดิมตาย/หายไป จะได้ตัวใกล้สุดตัวถัดไปทันที
		var target := _find_nearest_enemy_in_sight()
		if target:
			_chase_enemy(target, delta)
		elif is_selected:
			_walk_forward()
		else:
			_move_to_formation_slot(delta)
		return

	state = HeroState.FIGHTING
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		_attack_current_target()


# fallback ของ Hero ที่ถูกเลือก เมื่อไม่มี Enemy ใน SightArea: เดินไปทางขวาเรื่อยๆ
func _walk_forward() -> void:
	move_velocity_x = MOVE_SPEED


# ตั้ง move_velocity_x ให้เดินเข้าหา target_x ด้วย speed แต่ไม่เลยเป้าในเฟรมนี้
func _steer_toward(target_x: float, speed: float, delta: float) -> void:
	move_velocity_x = clampf(target_x - global_position.x, -speed * delta, speed * delta) / delta


# fallback ของ Hero ที่ไม่ได้ถูกเลือก เมื่อไม่มี Enemy ใน SightArea: เดินตาม formation slot ไปพร้อม leader
func _move_to_formation_slot(delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	_follow_slot(leader, _get_formation_slot(leader), delta)
	move_mode = MoveMode.FORMATION


# feed-forward ความเร็ว leader + แก้ระยะห่างจาก slot แบบสัดส่วน — ใกล้ slot ส่วนแก้จะเหลือ ~0 แต่ยังเดินไปพร้อม leader
# limit ที่ RETURN_SPEED (เร็วกว่า MOVE_SPEED ของ leader) และเปลี่ยนความเร็วไม่เกิน FORMATION_ACCEL — คิดแค่แกน X
func _follow_slot(leader: Node2D, slot: Vector2, delta: float) -> void:
	var leader_velocity_x: float = leader.velocity.x
	var desired := clampf(leader_velocity_x + (slot.x - global_position.x) * FORMATION_CORRECTION_GAIN, -RETURN_SPEED, RETURN_SPEED)
	formation_velocity_x = move_toward(formation_velocity_x, desired, FORMATION_ACCEL * delta)
	move_velocity_x = formation_velocity_x


# คำนวณใหม่ทุกครั้งที่เรียก จึงอัปเดตเองเมื่อเปลี่ยนตัวที่เลือก / มีการ recruit / มี Hero ตาย
func _get_formation_slot(leader: Node2D) -> Vector2:
	var followers: Array[Node2D] = []
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero.is_selected and hero.hp > 0:
			followers.append(hero)
	followers.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.recruit_index < b.recruit_index)

	var slot_distance := (maxi(followers.find(self), 0) + 1) * FORMATION_SPACING
	return WORLD_SCRIPT.clamp_to_bounds(leader.global_position - Vector2(_get_formation_facing() * slot_distance, 0.0))


# 1 = หันขวา, -1 = หันซ้าย — ไม่มี HeroParty ให้ถือว่าหันขวา
func _get_formation_facing() -> float:
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	return hero_party.formation_facing if hero_party else 1.0


func _find_nearest_enemy_in_sight() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies_in_sight:
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue
		var dist := absf(enemy.global_position.x - global_position.x)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


# เดินแกน X เข้าหา Enemy จนกว่าจะเข้า AttackArea — Hero ไม่ชนกันเอง ยืนทับกันได้
func _chase_enemy(target: Node2D, delta: float) -> void:
	_steer_toward(target.global_position.x, MOVE_SPEED, delta)
	move_mode = MoveMode.CHASE


func _update_leash(delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return

	# เข้า RETURNING ตามระยะห่างแกน X จาก leader แล้วเดินกลับไปที่ formation slot ของตัวเอง
	var distance := absf(leader.global_position.x - global_position.x)

	if distance > RETURN_LEASH_RANGE and state != HeroState.RETURNING:
		state = HeroState.RETURNING
		attack_timer = 0.0
		enemies_in_sight.clear()
		sight_area.monitoring = false

	if state != HeroState.RETURNING:
		return

	var slot := _get_formation_slot(leader)
	if absf(slot.x - global_position.x) > RETURN_STOP_RANGE:
		_follow_slot(leader, slot, delta)
		move_mode = MoveMode.RETURN
	else:
		state = HeroState.SEEKING
		sight_area.monitoring = true


func _attack_current_target() -> void:
	var target: Node2D = enemies_in_attack_range[0]
	if not is_instance_valid(target):
		return
	animated_sprite.play("attack", CombatStats.get_attack_anim_speed(animated_sprite, attack_interval))
	# STR → สุ่ม ±20% → (ฝั่งที่โดนตี) หัก VIT ใน take_damage
	if hero_class == HeroClasses.HeroClass.ARCHER:
		_spawn_arrow(target)
	target.take_damage(CombatStats.roll_damage(CombatStats.get_damage_output(attack_damage, strength)))
	if target.hp > 0 and randf() < HERO_KNOCKBACK_CHANCE:
		# ผลักแค่แกน X ออกจาก Hero — ยืนตรงกันเป๊ะให้ผลักไปทางขวา
		var direction := signf(target.global_position.x - global_position.x)
		if direction == 0.0:
			direction = 1.0
		target.apply_knockback(Vector2(direction * HERO_KNOCKBACK_DISTANCE, 0.0), HERO_KNOCKBACK_DURATION)


func take_damage(amount: float) -> void:
	if hp <= 0:
		return
	var received := CombatStats.get_damage_received(amount, vitality)
	hp = snappedf(hp - received, 0.01)
	_spawn_damage_number(received)
	_flash_hit()
	if hp <= 0:
		_die()
	elif not _is_playing_action("attack"):
		animated_sprite.play("hit")


# เรียกจากปุ่ม + ใน HeroStatusPanel — อัป stat ของ Hero ตัวนี้ ด้วย coin กองกลาง
# coin ไม่พอหรือชื่อ stat ไม่ถูกต้อง = ไม่เปลี่ยนอะไรเลย
func try_upgrade_stat(stat_name: StringName) -> bool:
	if stat_name not in [&"strength", &"vitality", &"agility"]:
		return false
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	if hero_party == null or not hero_party.spend_coins(STAT_UPGRADE_COST):
		return false
	match stat_name:
		&"strength":
			strength += 1
		&"vitality":
			vitality += 1
		&"agility":
			# setter ของ agility คำนวณ attack_interval ใหม่จาก base_attack_interval ให้ทันที
			agility += 1
	return true


func _update_attack_interval() -> void:
	attack_interval = CombatStats.get_attack_interval(_get_class_base_interval(), agility)


# Archer ตีช้าลง 30%: 1.0 / 0.7 ≈ 1.43 วิ ก่อนคิด AGI
func _get_class_base_interval() -> float:
	return base_attack_interval / HeroClasses.get_config(hero_class)["attack_speed_multiplier"]


func _apply_hero_class() -> void:
	var config := HeroClasses.get_config(hero_class)
	# shape ใน Hero.tscn เป็น sub_resource ที่ Hero ทุกตัวใช้ร่วมกัน — duplicate ก่อน ไม่งั้นแก้ทีเดียวเปลี่ยนทุกตัว
	# คูณจากรัศมีใน scene ของ instance นี้ (ใหม่ทุกครั้ง) จึงไม่คูณทับซ้ำ
	var attack_collision: CollisionShape2D = attack_area.get_node("CollisionShape2D")
	var attack_shape: CircleShape2D = attack_collision.shape.duplicate()
	attack_shape.radius *= config["attack_range_multiplier"]
	attack_collision.shape = attack_shape
	animated_sprite.self_modulate = config["tint"]


# เรียกจาก HeroParty ตอนเริ่ม stage ใหม่ — เก็บ recruit_index ไว้ ส่วนตำแหน่ง HeroParty เป็นคนวาง
func reset_for_new_stage() -> void:
	var was_dead := hp <= 0
	hp = max_hp
	state = HeroState.SEEKING
	move_velocity_x = 0.0
	formation_velocity_x = 0.0
	velocity = Vector2.ZERO
	is_running = false
	attack_timer = 0.0
	enemies_in_sight.clear()
	enemies_in_attack_range.clear()
	sight_area.monitoring = true
	# _die() ไม่ได้ queue_free แค่ปิด collision / AttackArea — hp เต็มแล้วต้องเปิดคืน ไม่งั้นเดินได้แต่ตีไม่ได้
	if was_dead:
		$CollisionShape2D.disabled = false
		attack_area.monitoring = true
	animated_sprite.play("idle")


# _physics_process หยุด AI/การเดินเองเมื่อ hp <= 0 — ตรงนี้ปิด collision/area แล้วรอ death เล่นจบ
func _die() -> void:
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	sight_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	print("Hero died")


# attack / hit เล่นจนจบก่อน แล้วค่อยกลับเป็น idle/run ตามความเร็ว
func _update_animation() -> void:
	# velocity.y มี gravity สะสมทุกเฟรม — ดูแค่แกน X
	var speed := absf(velocity.x)
	if is_running and speed < ANIM_IDLE_SPEED:
		is_running = false
	elif not is_running and speed > ANIM_RUN_SPEED:
		is_running = true

	if move_mode == MoveMode.FORMATION and not is_running:
		# ยืนใน slot หันตาม formation_facing — ไม่หันตาม velocity ที่ส่ายเล็กน้อยตอนแก้ตำแหน่ง
		# (วิ่งอยู่ เช่น ตอนแถวสลับข้างแล้ววิ่งผ่าน leader ไปอีกฝั่ง ค่อยหันตาม velocity ด้านล่าง)
		_set_facing_left(_get_formation_facing() < 0.0)
	elif absf(velocity.x) > ANIM_MOVE_THRESHOLD:
		_set_facing_left(velocity.x < 0)
	else:
		var target := _get_facing_target()
		if target:
			_set_facing_left(target.global_position.x < global_position.x)

	if _is_playing_action("attack") or _is_playing_action("hit"):
		return
	if is_running:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func _is_playing_action(anim_name: StringName) -> bool:
	return animated_sprite.animation == anim_name and animated_sprite.is_playing()


func _get_facing_target() -> Node2D:
	for enemy in enemies_in_attack_range:
		if is_instance_valid(enemy) and enemy.hp > 0:
			return enemy
	return _find_nearest_enemy_in_sight()


func _set_facing_left(left: bool) -> void:
	animated_sprite.flip_h = left
	animated_sprite.offset = Vector2(-SPRITE_OFFSET.x if left else SPRITE_OFFSET.x, SPRITE_OFFSET.y)


# ภาพอย่างเดียว — damage ยังทำทันทีใน _attack_current_target()
func _spawn_arrow(target: Node2D) -> void:
	var effects := get_tree().get_first_node_in_group("effects")
	if effects == null:
		return
	var release_offset := ARROW_RELEASE_OFFSET
	if animated_sprite.flip_h:
		release_offset.x = -release_offset.x
	effects.spawn_arrow(target, global_position + release_offset)


func _spawn_damage_number(amount: float) -> void:
	var effects := get_tree().get_first_node_in_group("effects")
	if effects:
		effects.spawn_damage_number(self, amount, DAMAGE_NUMBER_COLOR)


func _flash_hit() -> void:
	animated_sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.15)


func _on_sight_area_body_entered(body: Node2D) -> void:
	enemies_in_sight.append(body)


func _on_sight_area_body_exited(body: Node2D) -> void:
	enemies_in_sight.erase(body)


func _on_attack_area_body_entered(body: Node2D) -> void:
	enemies_in_attack_range.append(body)


func _on_attack_area_body_exited(body: Node2D) -> void:
	enemies_in_attack_range.erase(body)

