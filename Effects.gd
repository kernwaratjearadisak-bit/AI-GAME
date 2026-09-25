extends Node2D

# node กลางของ effect ใน World (ตัวเลข damage ฯลฯ) — ไม่ add เข้าตัวที่โดนตี เพราะถ้าตัวนั้นตาย/ถูก free effect จะหายตาม
# Main.reset_stage() เคลียร์ลูกทั้งหมดของ node นี้
const DAMAGE_NUMBER_SCENE := preload("res://DamageNumber.tscn")
# ระยะเหนือขอบบนของ collision + สุ่มเลื่อนแกน X กันตัวเลขซ้อนกันตอนโดนตีรัวๆ
const HEAD_MARGIN := 10.0
const RANDOM_X_OFFSET := 20.0


func _ready() -> void:
	add_to_group("effects")


func spawn_damage_number(target: Node2D, amount: float, color: Color) -> void:
	var number := DAMAGE_NUMBER_SCENE.instantiate()
	add_child(number)
	number.global_position = target.global_position + Vector2(
		randf_range(-RANDOM_X_OFFSET, RANDOM_X_OFFSET),
		-(_get_half_height(target) + HEAD_MARGIN)
	)
	number.setup(amount, color)


# ครึ่งความสูงของ collision (RectangleShape2D อยู่กึ่งกลาง origin) — Boss ตัวใหญ่ ตัวเลขจึงเกิดสูงกว่าเอง
func _get_half_height(target: Node2D) -> float:
	var collision_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		return collision_shape.shape.size.y * 0.5 * absf(collision_shape.global_scale.y)
	return 0.0
