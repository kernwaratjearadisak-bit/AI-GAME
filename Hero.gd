extends CharacterBody2D

enum HeroState { SEEKING, FIGHTING, RETURNING }

const SELECT_HALF_SIZE := Vector2(120, 160)
const RETURN_LEASH_RANGE := 300.0
# เมื่อเข้า RETURNING แล้ว ให้เดินกลับจนเข้าใกล้ formation slot ระยะนี้ก่อนค่อยกลับไปหา Enemy
# slot ห่าง leader 150 → หยุดที่ ≤ 200 จาก leader ต่ำกว่า RETURN_LEASH_RANGE พอ ไม่สลับ RETURNING/SEEKING ไปมาทุกเฟรม
const RETURN_STOP_RANGE := 50.0
const MOVE_SPEED := 150.0
# ต้องเร็วกว่า MOVE_SPEED ไม่งั้นจะไม่มีวันตามทัน leader ที่กำลังเดินขวาอยู่
const RETURN_SPEED := 225.0
# รัศมีของ SightArea (เดิม 200 ใน Hero.tscn) — ขยาย 2 เท่าเพราะ World แนวตั้งแคบลง
const HERO_DETECT_RANGE := 400.0
const WORLD_SCRIPT := preload("res://World.gd")
# Hero ไม่ได้ชนกันด้วย collision (layer "heroes" ไม่อยู่ใน mask ของตัวเอง ตัว 240x320 จะดันกันจนเข้า formation ไม่ได้)
# จึงใช้แรงผลักแบบนุ่มแทน: ใกล้กันกว่า HERO_SEPARATION_DISTANCE จะถูกดันออกทั้งแกน X/Y แรงขึ้นตามระยะที่ซ้อนกัน
const HERO_SEPARATION_DISTANCE := 90.0
const SEPARATION_PUSH_SPEED := 400.0
const HERO_KNOCKBACK_CHANCE := 0.3
const HERO_KNOCKBACK_DISTANCE := 65.0
# ระยะเวลาที่ Enemy ถูกดันถอยหลัง = ระยะเวลาที่ Enemy ถูก stun ด้วย
const HERO_KNOCKBACK_DURATION := 0.12
# ตำแหน่งสัมพัทธ์กับ leader ของ Hero ที่ไม่ได้ถูกเลือก เรียงตาม recruit_index น้อย→มาก: บน, ล่าง, ซ้าย
const FORMATION_OFFSETS: Array[Vector2] = [Vector2(0, -150), Vector2(0, 150), Vector2(-150, 0)]
const FORMATION_ARRIVE_DISTANCE := 5.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_area: Area2D = $SightArea
@onready var attack_area: Area2D = $AttackArea
@onready var selected_indicator: Polygon2D = $SelectedIndicator

var hp: int = 100
var max_hp: int = 100
var attack_damage: int = 10
var attack_interval: float = 1.0
var attack_timer: float = 0.0
var coin_count: int = 0
var is_selected: bool = false
# ลำดับการ recruit: ตัวแรกตั้งแต่ต้นเกม = 0, ตัวที่กด Recruit เพิ่มตามลำดับ = 1, 2, 3 (HeroParty เป็นคนตั้ง)
var recruit_index: int = 0
var state: HeroState = HeroState.SEEKING

# ทุกเส้นทางการเดิน (ไล่ Enemy / formation / RETURNING / เดินขวา) ตั้งค่านี้ แล้วค่อยรวมกับแรงผลัก
# และขยับจริงผ่าน move_and_slide() ครั้งเดียวต่อเฟรม
var move_velocity := Vector2.ZERO

var enemies_in_sight: Array[Node2D] = []
var enemies_in_attack_range: Array[Node2D] = []


func _ready() -> void:
	add_to_group("heroes")
	animated_sprite.play("walk")
	var sight_shape: CircleShape2D = sight_area.get_node("CollisionShape2D").shape
	sight_shape.radius = HERO_DETECT_RANGE
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
	is_selected = true
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

	move_velocity = Vector2.ZERO
	_update_ai(delta)
	velocity = move_velocity + _get_separation_velocity()
	move_and_slide()
	global_position = WORLD_SCRIPT.clamp_to_bounds(global_position)


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
	move_velocity = Vector2.RIGHT * MOVE_SPEED


# ตั้ง move_velocity ให้เดินเข้าหา target ด้วย speed แต่ไม่เลยเป้าในเฟรมนี้ (แทน move_toward เดิม)
func _steer_toward(target: Vector2, speed: float, delta: float) -> void:
	move_velocity = (target - global_position).limit_length(speed * delta) / delta


# fallback ของ Hero ที่ไม่ได้ถูกเลือก เมื่อไม่มี Enemy ใน SightArea: เดินไป formation slot แล้วหยุดรอ
func _move_to_formation_slot(delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	var slot := _get_formation_slot(leader)
	if global_position.distance_to(slot) < FORMATION_ARRIVE_DISTANCE:
		return
	# ใช้ RETURN_SPEED เพราะต้องเร็วกว่า leader ที่เดินขวาอยู่ ไม่งั้นจะตามไม่ทัน slot
	_steer_toward(slot, RETURN_SPEED, delta)


# คำนวณใหม่ทุกครั้งที่เรียก จึงอัปเดตเองเมื่อเปลี่ยนตัวที่เลือก / มีการ recruit / มี Hero ตาย
func _get_formation_slot(leader: Node2D) -> Vector2:
	var followers: Array[Node2D] = []
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not hero.is_selected and hero.hp > 0:
			followers.append(hero)
	followers.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.recruit_index < b.recruit_index)

	var slot_index := mini(followers.find(self), FORMATION_OFFSETS.size() - 1)
	return WORLD_SCRIPT.clamp_to_bounds(leader.global_position + FORMATION_OFFSETS[slot_index])


func _find_nearest_enemy_in_sight() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies_in_sight:
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


# เดินตรงเข้าหา Enemy ตามเวกเตอร์ทิศทางจริง (ทั้งแกน X และ Y) จนกว่าจะเข้า AttackArea
func _chase_enemy(target: Node2D, delta: float) -> void:
	_steer_toward(target.global_position, MOVE_SPEED, delta)


func _get_separation_velocity() -> Vector2:
	# ตัวที่กำลังตีอยู่ยืนหยัดที่เดิม ไม่ถูกดัน (ระยะตีสั้น ~60px ถ้าโดนดันจะหลุดระยะแล้วต้องเดินกลับเข้าไปใหม่ไม่จบ)
	# ตัวที่กำลังเดินเข้ามาจะถูกดันเบี่ยงไปหาที่ว่างรอบ Enemy แทน
	if state == HeroState.FIGHTING:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero == self or hero.hp <= 0:
			continue
		var offset: Vector2 = global_position - hero.global_position
		var distance: float = offset.length()
		if distance >= HERO_SEPARATION_DISTANCE:
			continue
		if distance < 0.01:
			# ยืนทับจุดเดียวกันเป๊ะ ไม่มีทิศให้ดัน — แยกทิศตาม recruit_index ให้ทั้งคู่ดันออกคนละทาง
			offset = Vector2.UP.rotated(recruit_index * TAU / 4.0)
		# ยิ่งซ้อนมากยิ่งดันแรง (0 ที่ขอบระยะ → 1 ตอนทับกันสนิท)
		push += offset.normalized() * (1.0 - distance / HERO_SEPARATION_DISTANCE)
	return push * SEPARATION_PUSH_SPEED


func _update_leash(delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return

	# เข้า RETURNING ตามระยะห่างจาก leader เหมือนเดิม แต่เดินกลับไปที่ formation slot ของตัวเอง
	var distance := global_position.distance_to(leader.global_position)

	if distance > RETURN_LEASH_RANGE and state != HeroState.RETURNING:
		state = HeroState.RETURNING
		attack_timer = 0.0
		enemies_in_sight.clear()
		sight_area.monitoring = false

	if state != HeroState.RETURNING:
		return

	var slot := _get_formation_slot(leader)
	if global_position.distance_to(slot) > RETURN_STOP_RANGE:
		_steer_toward(slot, RETURN_SPEED, delta)
	else:
		state = HeroState.SEEKING
		sight_area.monitoring = true


func _attack_current_target() -> void:
	var target: Node2D = enemies_in_attack_range[0]
	if not is_instance_valid(target):
		return
	target.take_damage(attack_damage)
	if target.hp > 0 and randf() < HERO_KNOCKBACK_CHANCE:
		var direction := global_position.direction_to(target.global_position)
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		target.apply_knockback(direction * HERO_KNOCKBACK_DISTANCE, HERO_KNOCKBACK_DURATION)


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	_flash_hit()
	if hp <= 0:
		print("Hero died")


func add_coin(amount: int) -> void:
	coin_count += amount


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

