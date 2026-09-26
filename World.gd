extends Node2D

# โถงทางเดินยาวแนวนอน: X = 20 เท่าของความกว้างจอ (720), Y = 1280 (~8.9% ของ X, = ความสูงจอพอดี)
# มุมมองด้านข้างระนาบเดียว: Hero/Enemy ยืนบนพื้น (Ground) ตก gravity และเดินแค่แกน X ด้วย velocity + move_and_slide()
const SIZE := Vector2(14400, 1280)
# y ของผิวบนพื้น (ที่เท้าตัวละครแตะ) — ไฟล์อื่นอ้างอิงค่านี้ที่เดียว
# กล้อง (CameraFollow.gd) ล็อกแกน Y ให้เส้นนี้อยู่ที่ GROUND_SCREEN_RATIO ของ BattleZone บนจอ (ค่าเริ่ม 80% → จอ y 704)
const GROUND_Y := 1000.0
const GROUND_THICKNESS := 64.0
const GROUND_COLOR := Color(0.36, 0.27, 0.2)
# กำแพงอยู่นอกขอบ World ซ้าย/ขวา (ขอบในของกำแพง = x 0 และ x SIZE.x)
const WALL_THICKNESS := 64.0
# px/s² — Hero, Enemy, Boss ใช้ค่าเดียวกัน
const GRAVITY := 980.0
# collision layer (bit value): 1 = World/Ground, 2 = Hero, 3 = Enemy (รวม Boss)
# Hero/Enemy มี collision_mask = LAYER_WORLD อย่างเดียว → ไม่ชนกันเอง เดินทับกันได้
const LAYER_WORLD := 1
const LAYER_HERO := 2
const LAYER_ENEMY := 4
# ลำดับการวาด (side-view ไม่ใช้ y-sort): Hero ที่เลือก > Hero อื่น > Enemy > ของดรอป > พื้น > ฉากหลัง
# Arrow (5) และ DamageNumber (10) ตั้งใน .tscn ของตัวเอง อยู่เหนือทั้งหมดนี้
const Z_INDEX_BACKGROUND := -1
const Z_INDEX_GROUND := 0
const Z_INDEX_DROP := 1
const Z_INDEX_ENEMY := 2
const Z_INDEX_HERO := 3
const Z_INDEX_SELECTED_HERO := 4


func _ready() -> void:
	add_to_group("world")
	var ground := _add_static_body("Ground", Rect2(0, GROUND_Y, SIZE.x, GROUND_THICKNESS))
	ground.z_index = Z_INDEX_GROUND
	# placeholder สีทึบ — ColorRect เป็นลูกของ Ground ใช้พิกัด local (Ground อยู่ที่กึ่งกลางของ rect)
	var ground_visual := ColorRect.new()
	ground_visual.color = GROUND_COLOR
	ground_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_visual.position = Vector2(-SIZE.x, -GROUND_THICKNESS) * 0.5
	ground_visual.size = Vector2(SIZE.x, GROUND_THICKNESS)
	ground.add_child(ground_visual)
	_add_static_body("LeftWall", Rect2(-WALL_THICKNESS, 0, WALL_THICKNESS, SIZE.y))
	_add_static_body("RightWall", Rect2(SIZE.x, 0, WALL_THICKNESS, SIZE.y))


func _add_static_body(body_name: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	body.add_child(collision_shape)
	add_child(body)
	return body


static func clamp_to_bounds(point: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, SIZE)


# ใช้ตอน spawn / reset เท่านั้น: วางตัวให้ขอบล่างของ CollisionShape2D แตะ GROUND_Y ที่ x ที่กำหนด และล้าง velocity
static func place_on_ground(body: CharacterBody2D, x: float) -> void:
	var collision_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var half_height: float = collision_shape.shape.size.y * 0.5 * absf(collision_shape.global_scale.y)
	body.global_position = Vector2(clampf(x, 0.0, SIZE.x), GROUND_Y - half_height - collision_shape.position.y)
	body.velocity = Vector2.ZERO
