extends Node2D

# ลูกธนูของ Archer — ไม่มี collision
# ปกติ (setup): ภาพอย่างเดียว ไม่ทำ damage (Hero ทำ damage ทันทีตอนยิง) บินตามเป้า
# ทะลุ (setup_pierce, Charge Arrow): บินตรงจนสุดระยะ และทำ damage ที่คำนวณไว้แล้วให้แต่ละเป้าตอนบินผ่าน
const ARROW_LENGTH := 40.0
const ARROW_WIDTH := 1.0
const ARROW_COLOR := Color(1, 0.95, 0.7)
# ระยะยิงไกลสุด ~360px ถึงเป้าใน~0.25 วิ
const ARROW_SPEED := 1400.0
# กันลูกธนูค้างถ้าไล่เป้าไม่ถึง
const MAX_LIFETIME := 1.0

@onready var line: Line2D = $Line2D

var target: Node2D = null
# ตำแหน่งเล็งล่าสุด — ถ้า target ตาย/ถูก free กลางทาง จะบินต่อมาที่จุดนี้แล้วหายไป
var last_aim_position := Vector2.ZERO
var lifetime := 0.0
# โหมดทะลุ
var is_piercing := false
var pierce_direction := 1.0
var pierce_distance_left := 0.0
var pending_hits: Array[Dictionary] = []


func _ready() -> void:
	# เส้นตามแกน X หัวลูกศรอยู่ที่ origin หางอยู่ด้านหลัง — rotation = ทิศที่พุ่ง
	line.points = PackedVector2Array([Vector2(-ARROW_LENGTH, 0), Vector2.ZERO])
	line.width = ARROW_WIDTH
	line.default_color = ARROW_COLOR


# เรียกหลัง add_child
func setup(new_target: Node2D, start_position: Vector2) -> void:
	target = new_target
	global_position = start_position
	# จำจุดเล็งตั้งแต่ตอนยิง — ลูกที่ยิงแล้วเป้าตายทันที (hp <= 0 แล้ว) ก็ยังมีที่ให้บินไป
	last_aim_position = _get_aim_position(target)
	rotation = (last_aim_position - global_position).angle()


# เรียกหลัง add_child — ยาว/หนา/สีตาม skill, hits เรียงใกล้ → ไกลแล้ว
func setup_pierce(start_position: Vector2, direction: float, distance: float, hits: Array[Dictionary], length: float, width: float, color: Color) -> void:
	is_piercing = true
	global_position = start_position
	pierce_direction = direction
	pierce_distance_left = distance
	pending_hits = hits
	rotation = 0.0 if direction > 0.0 else PI
	line.points = PackedVector2Array([Vector2(-length, 0), Vector2.ZERO])
	line.width = width
	line.default_color = color


func _process(delta: float) -> void:
	if is_piercing:
		_process_pierce(delta)
		return
	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		queue_free()
		return

	# homing: ตาม Enemy ที่เดิน / โดน knockback อยู่ จนกว่าเป้าจะตาย
	if is_instance_valid(target) and target.hp > 0:
		last_aim_position = _get_aim_position(target)

	var to_target := last_aim_position - global_position
	var step := ARROW_SPEED * delta
	if to_target.length() <= step:
		queue_free()
		return
	rotation = to_target.angle()
	global_position += to_target.normalized() * step


# เป้าที่ตาย/ถูกลบก่อนลูกธนูมาถึงข้ามไป — ถึงสุดระยะแล้วหาย (เป้าที่ยังไม่ถึงก็ไม่โดน)
func _process_pierce(delta: float) -> void:
	var step := minf(ARROW_SPEED * delta, pierce_distance_left)
	global_position.x += pierce_direction * step
	pierce_distance_left -= step
	while not pending_hits.is_empty():
		var target: Node2D = pending_hits[0]["target"]
		if is_instance_valid(target) and target.hp > 0:
			if (target.global_position.x - global_position.x) * pierce_direction > 0.0:
				break
			target.take_damage(pending_hits[0]["damage"])
		pending_hits.pop_front()
	if pierce_distance_left <= 0.0:
		queue_free()


# กลางลำตัว = กึ่งกลาง CollisionShape2D (SPRITE_OFFSET จัดลำตัวให้อยู่ตรง origin ที่ collision อยู่)
# Boss ใช้ collision ใหญ่กว่าแต่กึ่งกลางยังตรงลำตัวเหมือนกัน — ไม่มี collision ก็เล็ง origin
static func _get_aim_position(node: Node2D) -> Vector2:
	var collision_shape := node.get_node_or_null("CollisionShape2D") as Node2D
	if collision_shape:
		return collision_shape.global_position
	return node.global_position
