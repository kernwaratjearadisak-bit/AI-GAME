extends CharacterBody2D

enum HeroState { SEEKING, FIGHTING, RETURNING }

const SELECT_HALF_SIZE := Vector2(120, 160)
const RETURN_LEASH_RANGE := 300.0
# เมื่อเข้า RETURNING แล้ว ให้เดินกลับจนเข้าใกล้ leader ระยะนี้ก่อนค่อยกลับไปหา Enemy
# (ถ้าหยุดที่ขอบ 300 พอดี จะสลับ RETURNING/SEEKING ไปมาทุกเฟรม)
const RETURN_STOP_RANGE := 150.0
const MOVE_SPEED := 150.0
# ต้องเร็วกว่า MOVE_SPEED ไม่งั้นจะไม่มีวันตามทัน leader ที่กำลังเดินขวาอยู่
const RETURN_SPEED := 225.0
# รัศมีของ SightArea (เดิม 200 ใน Hero.tscn) — ขยาย 2 เท่าเพราะ World แนวตั้งแคบลง
const HERO_DETECT_RANGE := 400.0
const WORLD_SCRIPT := preload("res://World.gd")
const HERO_SEPARATION_DISTANCE := 24.0
const SEPARATION_PUSH_SPEED := 80.0

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
var state: HeroState = HeroState.SEEKING

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


func _process(delta: float) -> void:
	if hp <= 0:
		return

	# is_selected มีผลกับ AI แค่จุดเดียว: ตัวที่ไม่ได้ถูกเลือกจะมี leash กลับหา leader
	# ส่วน หา/ไล่/ต่อสู้/เดินขวา ด้านล่าง ทุกตัวรันอิสระของตัวเอง
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
		else:
			_walk_forward(delta)
		return

	state = HeroState.FIGHTING
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		_attack_current_target()


# fallback เมื่อไม่มี Enemy ใน SightArea: เดินไปทางขวาเรื่อยๆ
func _walk_forward(delta: float) -> void:
	global_position = WORLD_SCRIPT.clamp_to_bounds(global_position + Vector2.RIGHT * MOVE_SPEED * delta)


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
	var next_position := global_position.move_toward(target.global_position, MOVE_SPEED * delta)
	global_position = WORLD_SCRIPT.clamp_to_bounds(next_position)


func _physics_process(_delta: float) -> void:
	var push := Vector2.ZERO
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero == self:
			continue
		var offset: Vector2 = global_position - hero.global_position
		var distance: float = offset.length()
		if distance > 0.0 and distance < HERO_SEPARATION_DISTANCE:
			push += offset.normalized()

	push.x = 0.0
	velocity = push * SEPARATION_PUSH_SPEED
	move_and_slide()


func _update_leash(delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return

	var distance := global_position.distance_to(leader.global_position)

	if distance > RETURN_LEASH_RANGE and state != HeroState.RETURNING:
		state = HeroState.RETURNING
		attack_timer = 0.0
		enemies_in_sight.clear()
		sight_area.monitoring = false

	if state != HeroState.RETURNING:
		return

	if distance > RETURN_STOP_RANGE:
		var next_position := global_position.move_toward(leader.global_position, RETURN_SPEED * delta)
		global_position = WORLD_SCRIPT.clamp_to_bounds(next_position)
	else:
		state = HeroState.SEEKING
		sight_area.monitoring = true


func _attack_current_target() -> void:
	var target: Node2D = enemies_in_attack_range[0]
	if is_instance_valid(target):
		target.take_damage(attack_damage)


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

