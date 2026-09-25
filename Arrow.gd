extends Node2D

# ลูกธนูของ Archer — ภาพอย่างเดียว ไม่มี collision ไม่ทำ damage (Hero ทำ damage ทันทีตอนยิง)
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


func _process(delta: float) -> void:
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


# กลางลำตัว = กึ่งกลาง CollisionShape2D (SPRITE_OFFSET จัดลำตัวให้อยู่ตรง origin ที่ collision อยู่)
# Boss ใช้ collision ใหญ่กว่าแต่กึ่งกลางยังตรงลำตัวเหมือนกัน — ไม่มี collision ก็เล็ง origin
static func _get_aim_position(node: Node2D) -> Vector2:
	var collision_shape := node.get_node_or_null("CollisionShape2D") as Node2D
	if collision_shape:
		return collision_shape.global_position
	return node.global_position
