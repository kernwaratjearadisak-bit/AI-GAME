extends Node2D

# ฐานของของดรอป (Coin / HP Potion): เด้งขึ้นจากจุดที่ Enemy ตาย → ตก gravity ถึงพื้น → เด้งเล็กๆ 1 ครั้ง
# → นอนบนพื้น REST_DURATION วิ → _fly_to_target() (subclass override) ลอยเข้าหาเป้าหมาย
# คำนวณตำแหน่งเองใน _process ไม่ใช้ physics body

const WORLD_SCRIPT := preload("res://World.gd")
const POP_SPEED_Y := 350.0
# สุ่มขนาดความเร็วแกน X ในช่วงนี้ แล้วสุ่มทิศซ้าย/ขวา — แต่ละชิ้นกระจายไม่ซ้อนกันพอดี
const POP_SPEED_X_MIN := 60.0
const POP_SPEED_X_MAX := 120.0
# ตอนแตะพื้นครั้งแรก: เด้งกลับด้วยความเร็วแกน Y เท่านี้ของตอนตก / แกน X เหลือเท่านี้
const BOUNCE_Y_RATIO := 0.3
const BOUNCE_X_RATIO := 0.5
const REST_DURATION := 0.4
# ครึ่งความสูง Sprite2D (16px, centered) — ขอบล่างแตะ GROUND_Y พอดี
const GROUND_OFFSET := 8.0

var velocity := Vector2.ZERO
var has_bounced := false


func _ready() -> void:
	z_index = WORLD_SCRIPT.Z_INDEX_DROP
	# Enemy ตั้ง global_position หลัง add_child (หลัง _ready) — ตรงนี้ตั้งแค่ velocity ส่วนตำแหน่งเริ่มใช้ใน _process เฟรมแรก
	var direction := -1.0 if randf() < 0.5 else 1.0
	velocity = Vector2(direction * randf_range(POP_SPEED_X_MIN, POP_SPEED_X_MAX), -POP_SPEED_Y)


func _process(delta: float) -> void:
	velocity.y += WORLD_SCRIPT.GRAVITY * delta
	global_position += velocity * delta
	global_position.x = clampf(global_position.x, 0.0, WORLD_SCRIPT.SIZE.x)

	var rest_y: float = WORLD_SCRIPT.GROUND_Y - GROUND_OFFSET
	if global_position.y < rest_y or velocity.y <= 0.0:
		return
	global_position.y = rest_y
	if not has_bounced:
		has_bounced = true
		velocity = Vector2(velocity.x * BOUNCE_X_RATIO, -velocity.y * BOUNCE_Y_RATIO)
		return
	set_process(false)
	# ใช้ tween แทน timer — ถูก kill พร้อม node ถ้าโดนลบระหว่างนอนรอ
	var tween := create_tween()
	tween.tween_interval(REST_DURATION)
	tween.tween_callback(_fly_to_target)


func _fly_to_target() -> void:
	queue_free()
