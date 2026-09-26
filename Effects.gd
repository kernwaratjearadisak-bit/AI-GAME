extends Node2D

# node กลางของ effect ใน World (ตัวเลข damage, ลูกธนู ฯลฯ) — ไม่ add เข้าตัวที่โดนตี เพราะถ้าตัวนั้นตาย/ถูก free effect จะหายตาม
# Main.reset_stage() เคลียร์ลูกทั้งหมดของ node นี้
const DAMAGE_NUMBER_SCENE := preload("res://DamageNumber.tscn")
const ARROW_SCENE := preload("res://Arrow.tscn")
# ระยะเหนือขอบบนของ collision + สุ่มเลื่อนแกน X กันตัวเลขซ้อนกันตอนโดนตีรัวๆ
const HEAD_MARGIN := 10.0
const RANDOM_X_OFFSET := 20.0
# เหนือ Hero ที่เลือก (4) ระดับเดียวกับลูกธนู ใต้ตัวเลข damage (10)
const AREA_FLASH_Z_INDEX := 5


func _ready() -> void:
	add_to_group("effects")


func spawn_damage_number(target: Node2D, amount: float, color: Color) -> void:
	_spawn_number_above(target).setup(amount, color)


# ข้อความลอยเหนือหัวแบบเดียวกับตัวเลข damage เช่น "+5" สีเขียวของ Regenerate HP
func spawn_floating_text(target: Node2D, text: String, color: Color) -> void:
	_spawn_number_above(target).setup_text(text, color)


func _spawn_number_above(target: Node2D) -> Node2D:
	var number := DAMAGE_NUMBER_SCENE.instantiate()
	add_child(number)
	number.global_position = target.global_position + Vector2(
		randf_range(-RANDOM_X_OFFSET, RANDOM_X_OFFSET),
		-(_get_half_height(target) + HEAD_MARGIN)
	)
	return number


# ลูกธนูทะลุของ Charge Arrow: บินตรงไปทาง direction (±1) ไกล distance — hits = [{target, damage}]
# แต่ละตัวโดน take_damage ตอนลูกธนูบินผ่าน (damage number ขึ้นตอนนั้น)
func spawn_pierce_arrow(start_position: Vector2, direction: float, distance: float, hits: Array[Dictionary]) -> void:
	var arrow := ARROW_SCENE.instantiate()
	add_child(arrow)
	arrow.setup_pierce(start_position, direction, distance, hits, SkillData.CHARGE_ARROW_LENGTH, SkillData.CHARGE_ARROW_WIDTH, SkillData.CHARGE_ARROW_COLOR)


# สี่เหลี่ยมสีโปร่ง (พิกัด World) ค้าง hold วิ แล้วจางใน fade วิ — placeholder ของ skill แบบพื้นที่ เช่น Bash
func spawn_area_flash(rect: Rect2, color: Color, hold: float, fade: float) -> void:
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	flash.color = color
	flash.z_index = AREA_FLASH_Z_INDEX
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_interval(hold)
	tween.tween_property(flash, "modulate:a", 0.0, fade)
	tween.tween_callback(flash.queue_free)


# ลูกธนูของ Archer (ภาพอย่างเดียว) — บินจาก start_position ตาม target
func spawn_arrow(target: Node2D, start_position: Vector2) -> void:
	var arrow := ARROW_SCENE.instantiate()
	add_child(arrow)
	arrow.setup(target, start_position)


# ครึ่งความสูงของ collision (RectangleShape2D อยู่กึ่งกลาง origin) — Boss ตัวใหญ่ ตัวเลขจึงเกิดสูงกว่าเอง
func _get_half_height(target: Node2D) -> float:
	var collision_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		return collision_shape.shape.size.y * 0.5 * absf(collision_shape.global_scale.y)
	return 0.0
