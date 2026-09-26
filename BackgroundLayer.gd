extends Parallax2D

# ฉากหลัง 1 ชั้น (ลูกของ ParallaxBackground.tscn) — scroll_scale ตั้งจาก ParallaxBackground.gd
# ไม่มี texture = วาด placeholder สไตล์ pixel ด้วย _draw (random seed คงที่ วนซ้ำต่อกันเนียนทุก placeholder_width)
# มี texture = แสดงภาพนั้นด้วย Sprite2D แทน และวนซ้ำทุกความกว้างภาพ

enum LayerKind { SKY, MOUNTAINS, HILLS, TREES }

const WORLD_SCRIPT := preload("res://World.gd")
const CAMERA_SCRIPT := preload("res://CameraFollow.gd")
# ขนาด "pixel" ของ placeholder (world px) — ทุกรูปทรงวาดเป็นบล็อกขนาดนี้ ขอบแข็ง
const PIXEL := 4.0
# Sky วาดสูงจากขอบฟ้า (GROUND_Y) ขึ้นไปเท่านี้ — กล้อง zoom 0.5 เห็นเหนือพื้น ~1400px ยังไม่หลุด
const SKY_HEIGHT := 2000.0
# gradient ของ Sky ไล่เฉพาะช่วงนี้เหนือขอบฟ้า (ช่วงที่เห็นใน BattleZone) เหนือกว่านั้นเป็นสี SKY_TOP_COLOR ทึบ
const SKY_GRADIENT_HEIGHT := 900.0
const SKY_BAND_HEIGHT := 16.0
# สีจาง → เข้ม ตามระยะใกล้ (atmospheric perspective) ให้ตัวละครเด่นกว่าฉากหลัง
const SKY_TOP_COLOR := Color(0.25, 0.43, 0.72)
const SKY_HORIZON_COLOR := Color(0.72, 0.85, 0.95)
const MOUNTAIN_COLOR := Color(0.58, 0.67, 0.79)
const HILL_COLOR := Color(0.4, 0.55, 0.5)
const TREE_CANOPY_COLOR := Color(0.13, 0.33, 0.2)
const TREE_TRUNK_COLOR := Color(0.25, 0.18, 0.13)

@export var layer_kind: LayerKind = LayerKind.SKY
# ใส่ภาพจริงแทน placeholder — ขอบล่างภาพชิด GROUND_Y (Sky ก็ชิดขอบฟ้าเหมือนกัน เหนือภาพเติมด้วย SKY_TOP_COLOR)
@export var texture: Texture2D
# ความยาว 1 รอบของ placeholder — ต้องกว้างกว่าจอตอน zoom ต่ำสุดที่ใช้ (720 / 0.7 ≈ 1030)
@export var placeholder_width := 1440.0
@export var art_seed := 1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var period := placeholder_width
	if texture:
		period = texture.get_width()
		_add_texture_sprite()
	repeat_size = Vector2(period, 0.0)
	# จำนวนสำเนาที่วาดเผื่อซ้าย/ขวา ให้ครอบความกว้างที่กล้องเห็นตอน zoom ออก
	var visible_width := get_viewport_rect().size.x / CAMERA_SCRIPT.CAMERA_ZOOM
	repeat_times = ceili(visible_width / period) + 1
	queue_redraw()


func _add_texture_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(0.0, WORLD_SCRIPT.GROUND_Y - texture.get_height())
	add_child(sprite)


func _draw() -> void:
	if texture:
		# เหนือภาพ Sky เติมสีทึบกันช่องว่างตอน zoom ออก
		var fill_height := SKY_HEIGHT - texture.get_height()
		if layer_kind == LayerKind.SKY and fill_height > 0.0:
			draw_rect(Rect2(0.0, WORLD_SCRIPT.GROUND_Y - SKY_HEIGHT, texture.get_width(), fill_height), SKY_TOP_COLOR)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = art_seed
	match layer_kind:
		LayerKind.SKY:
			_draw_sky()
		LayerKind.MOUNTAINS:
			_draw_mountains(rng)
		LayerKind.HILLS:
			_draw_hills(rng)
		LayerKind.TREES:
			_draw_trees(rng)


# gradient แบบแถบ (ขั้นละ SKY_BAND_HEIGHT) — เข้มด้านบน อ่อนใกล้ขอบฟ้า
func _draw_sky() -> void:
	var ground_y: float = WORLD_SCRIPT.GROUND_Y
	var gradient_top := ground_y - SKY_GRADIENT_HEIGHT
	draw_rect(Rect2(0.0, ground_y - SKY_HEIGHT, placeholder_width, SKY_HEIGHT - SKY_GRADIENT_HEIGHT), SKY_TOP_COLOR)
	var y := gradient_top
	while y < ground_y:
		var weight := (y - gradient_top) / SKY_GRADIENT_HEIGHT
		draw_rect(Rect2(0.0, y, placeholder_width, SKY_BAND_HEIGHT), SKY_TOP_COLOR.lerp(SKY_HORIZON_COLOR, weight))
		y += SKY_BAND_HEIGHT


# ยอดเขาสุ่มตำแหน่ง/ความสูง/ความชัน สูง(x) = ยอดที่สูงสุดของทุกยอด ณ x — วัดระยะแบบวนรอบ จึงต่อกันเนียนที่จุดวนซ้ำ
func _draw_mountains(rng: RandomNumberGenerator) -> void:
	var peaks: Array[Vector3] = []  # x, ความสูง, ความชัน
	for i in 7:
		peaks.append(Vector3(rng.randf() * placeholder_width, rng.randf_range(220.0, 420.0), rng.randf_range(0.7, 1.2)))
	_draw_columns(MOUNTAIN_COLOR, func(x: float) -> float:
		var height := 80.0
		for peak in peaks:
			height = maxf(height, peak.y - peak.z * _wrapped_distance(x, peak.x))
		return height)


# เนินโค้ง: ผลรวม sine ที่ความถี่เป็นจำนวนเต็มรอบต่อ placeholder_width → วนซ้ำต่อกันเนียน
func _draw_hills(rng: RandomNumberGenerator) -> void:
	var waves: Array[Vector3] = []  # จำนวนรอบ, แอมพลิจูด, เฟส
	for cycles in [1, 2, 3, 5]:
		waves.append(Vector3(cycles, rng.randf_range(12.0, 40.0) / sqrt(cycles), rng.randf() * TAU))
	_draw_columns(HILL_COLOR, func(x: float) -> float:
		var height := 130.0
		for wave in waves:
			height += wave.y * sin(TAU * wave.x * x / placeholder_width + wave.z)
		return height)


func _draw_trees(rng: RandomNumberGenerator) -> void:
	var count := roundi(placeholder_width / 110.0)
	for i in count:
		# กระจายตามช่องเท่าๆ กัน + สุ่มเลื่อน ไม่ให้กองรวมกัน
		var x := (i + rng.randf_range(0.1, 0.9)) * placeholder_width / count
		var trunk_width := _snap(rng.randf_range(8.0, 14.0))
		var trunk_height := _snap(rng.randf_range(24.0, 48.0))
		var canopy_width := _snap(rng.randf_range(48.0, 88.0))
		var canopy_height := _snap(rng.randf_range(64.0, 120.0))
		var is_round := rng.randf() < 0.4
		# ต้นที่คร่อมขอบรอบ วาดซ้ำอีกฝั่งด้วย ไม่งั้นโดนตัดตรงจุดวนซ้ำ
		for shift in [-placeholder_width, 0.0, placeholder_width]:
			var tree_x: float = _snap(x + shift)
			if tree_x + canopy_width < 0.0 or tree_x - canopy_width > placeholder_width:
				continue
			_draw_tree(tree_x, trunk_width, trunk_height, canopy_width, canopy_height, is_round)


# ฐานลำต้นแตะ GROUND_Y — พุ่มสามเหลี่ยม (สนซ้อนแถว) หรือวงกลม ขึ้นเป็นบล็อก PIXEL
func _draw_tree(x: float, trunk_width: float, trunk_height: float, canopy_width: float, canopy_height: float, is_round: bool) -> void:
	var ground_y: float = WORLD_SCRIPT.GROUND_Y
	var canopy_bottom := ground_y - trunk_height
	draw_rect(Rect2(x - trunk_width * 0.5, canopy_bottom, trunk_width, trunk_height), TREE_TRUNK_COLOR)
	var y := 0.0
	while y < canopy_height:
		var half_width: float
		if is_round:
			var radius := canopy_height * 0.5
			var dy := y + PIXEL * 0.5 - radius
			half_width = canopy_width * 0.5 * sqrt(maxf(0.0, 1.0 - (dy * dy) / (radius * radius)))
		else:
			half_width = canopy_width * 0.5 * (1.0 - y / canopy_height)
		half_width = _snap(half_width)
		if half_width > 0.0:
			draw_rect(Rect2(x - half_width, canopy_bottom - y - PIXEL, half_width * 2.0, PIXEL), TREE_CANOPY_COLOR)
		y += PIXEL


# เงาแบบคอลัมน์กว้าง PIXEL จาก GROUND_Y ขึ้นไปตาม height_at(x) (ปัดเป็นขั้น PIXEL) — ขอบเป็นขั้นบันได pixel
func _draw_columns(color: Color, height_at: Callable) -> void:
	var ground_y: float = WORLD_SCRIPT.GROUND_Y
	var x := 0.0
	while x < placeholder_width:
		var height := _snap(height_at.call(x + PIXEL * 0.5))
		draw_rect(Rect2(x, ground_y - height, PIXEL, height), color)
		x += PIXEL


func _wrapped_distance(a: float, b: float) -> float:
	var d := fposmod(a - b, placeholder_width)
	return minf(d, placeholder_width - d)


func _snap(value: float) -> float:
	return roundf(value / PIXEL) * PIXEL
