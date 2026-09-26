extends Node2D

# โถงทางเดินยาวแนวนอน: X = 20 เท่าของความกว้างจอ (720), Y = 1280 (~8.9% ของ X, = ความสูงจอพอดี)
# มุมมองด้านข้างระนาบเดียว: Hero/Enemy ยืนบนพื้น (Ground) ตก gravity และเดินแค่แกน X ด้วย velocity + move_and_slide()
const SIZE := Vector2(14400, 1280)
# y ของผิวบนพื้น (ที่เท้าตัวละครแตะ) — ไฟล์อื่นอ้างอิงค่านี้ที่เดียว
# กล้อง (CameraFollow.gd) ล็อกแกน Y ให้เส้นนี้อยู่ที่ GROUND_SCREEN_RATIO ของ BattleZone บนจอ (ค่าเริ่ม 80% → จอ y 704)
const GROUND_Y := 1000.0
const GROUND_THICKNESS := 64.0
# ภาพพื้น placeholder สไตล์ pixel: แถบหญ้าหนา GRASS_THICKNESS บนสุด + ดินลึก GROUND_VISUAL_DEPTH (เกิน collision
# เพื่อไม่ให้เห็นช่องว่างใต้พื้นตอน zoom ออก) + จุดลายสุ่ม seed คงที่ในแถบบนของดิน
const GROUND_VISUAL_DEPTH := 1400.0
const GRASS_THICKNESS := 12.0
const GRASS_COLOR := Color(0.33, 0.6, 0.25)
const GRASS_SHADOW_COLOR := Color(0.24, 0.45, 0.2)
const DIRT_COLOR := Color(0.36, 0.26, 0.18)
const DIRT_SPECKLE_COLORS: Array[Color] = [Color(0.44, 0.32, 0.22), Color(0.28, 0.2, 0.14)]
const DIRT_SPECKLE_CELL := 8.0
const DIRT_SPECKLE_SIZE := 4.0
const DIRT_SPECKLE_BAND := 200.0
const DIRT_SPECKLE_CHANCE := 0.12
const GROUND_ART_SEED := 1337
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

# tile พื้นจริง (ใส่ทีหลัง): วนซ้ำแนวนอนตลอด World ขอบบนภาพ = GROUND_Y — ใต้ภาพเติมด้วย DIRT_COLOR
@export var ground_texture: Texture2D


func _ready() -> void:
	add_to_group("world")
	var ground := _add_static_body("Ground", Rect2(0, GROUND_Y, SIZE.x, GROUND_THICKNESS))
	ground.z_index = Z_INDEX_GROUND
	_add_ground_visual()
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


# Node2D แยกที่ origin ของ World (ใช้พิกัด World ตรงๆ) วาดผ่าน signal draw — ไม่ต้องมี script แยก
func _add_ground_visual() -> void:
	var ground_visual := Node2D.new()
	ground_visual.name = "GroundVisual"
	ground_visual.z_index = Z_INDEX_GROUND
	ground_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_visual.draw.connect(_draw_ground.bind(ground_visual))
	add_child(ground_visual)
	if ground_texture:
		var sprite := Sprite2D.new()
		sprite.texture = ground_texture
		sprite.centered = false
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0.0, 0.0, SIZE.x, ground_texture.get_height())
		sprite.position = Vector2(0.0, GROUND_Y)
		ground_visual.add_child(sprite)


func _draw_ground(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(0.0, GROUND_Y, SIZE.x, GROUND_VISUAL_DEPTH), DIRT_COLOR)
	if ground_texture:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GROUND_ART_SEED
	var y := GROUND_Y + GRASS_THICKNESS
	while y < GROUND_Y + DIRT_SPECKLE_BAND:
		var x := 0.0
		while x < SIZE.x:
			if rng.randf() < DIRT_SPECKLE_CHANCE:
				var color: Color = DIRT_SPECKLE_COLORS[rng.randi() % DIRT_SPECKLE_COLORS.size()]
				canvas.draw_rect(Rect2(Vector2(x, y), Vector2.ONE * DIRT_SPECKLE_SIZE), color)
			x += DIRT_SPECKLE_CELL
		y += DIRT_SPECKLE_CELL
	canvas.draw_rect(Rect2(0.0, GROUND_Y, SIZE.x, GRASS_THICKNESS), GRASS_COLOR)
	# ขอบล่างของหญ้า: จุดเงาสุ่มหนา 4px ห้อยลงในดิน ให้ขอบไม่เป็นเส้นตรงเกินไป
	var grass_x := 0.0
	while grass_x < SIZE.x:
		if rng.randf() < 0.5:
			canvas.draw_rect(Rect2(grass_x, GROUND_Y + GRASS_THICKNESS, DIRT_SPECKLE_SIZE, DIRT_SPECKLE_SIZE), GRASS_SHADOW_COLOR)
		grass_x += DIRT_SPECKLE_SIZE


static func clamp_to_bounds(point: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, SIZE)


# ใช้ตอน spawn / reset เท่านั้น: วางตัวให้ขอบล่างของ CollisionShape2D แตะ GROUND_Y ที่ x ที่กำหนด และล้าง velocity
static func place_on_ground(body: CharacterBody2D, x: float) -> void:
	var collision_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var half_height: float = collision_shape.shape.size.y * 0.5 * absf(collision_shape.global_scale.y)
	body.global_position = Vector2(clampf(x, 0.0, SIZE.x), GROUND_Y - half_height - collision_shape.position.y)
	body.velocity = Vector2.ZERO
