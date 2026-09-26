extends Node2D

# ฉากหลัง parallax 4 ชั้น (ไกล → ใกล้ ตามลำดับลูกใน ParallaxBackground.tscn = ลำดับการวาด)
# scroll_scale.x: 0 = ติดกล้อง (ไกลสุด), 1 = เลื่อนเท่าโลก
const SKY_SCROLL_SCALE := 0.0
const MOUNTAINS_SCROLL_SCALE := 0.2
const HILLS_SCROLL_SCALE := 0.45
const TREES_SCROLL_SCALE := 0.7
# scroll_scale.y = 1 (อิงพิกัด World) แทน 0: กล้องล็อก Y อยู่แล้วจึงเห็นเหมือนกันทุกประการ
# แต่ y ของกล้องขึ้นกับ CAMERA_ZOOM — ถ้าเป็น 0 ฐานภูเขา/ต้นไม้จะหลุดจาก GROUND_Y เมื่อเปลี่ยน zoom
const VERTICAL_SCROLL_SCALE := 1.0
const WORLD_SCRIPT := preload("res://World.gd")


func _ready() -> void:
	# ลูกแต่ละชั้นใช้ z relative = 0 → อยู่ที่ Z_INDEX_BACKGROUND ทั้งหมด แล้วเรียงตามลำดับใน tree
	z_index = WORLD_SCRIPT.Z_INDEX_BACKGROUND
	$Sky.scroll_scale = Vector2(SKY_SCROLL_SCALE, VERTICAL_SCROLL_SCALE)
	$Mountains.scroll_scale = Vector2(MOUNTAINS_SCROLL_SCALE, VERTICAL_SCROLL_SCALE)
	$Hills.scroll_scale = Vector2(HILLS_SCROLL_SCALE, VERTICAL_SCROLL_SCALE)
	$Trees.scroll_scale = Vector2(TREES_SCROLL_SCALE, VERTICAL_SCROLL_SCALE)
