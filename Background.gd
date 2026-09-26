extends Node2D

# placeholder ฉากหลัง side-view: ท้องฟ้าเหนือ GROUND_Y / ดินใต้ GROUND_Y + เส้นหลักระยะแนวตั้งห่างๆ บอกระยะที่เดินผ่าน
# พื้นจริง (Ground ใน World.gd) วาดทับแถบบนสุดของดิน
const WORLD_SCRIPT := preload("res://World.gd")
const SKY_COLOR := Color(0.45, 0.68, 0.9)
const EARTH_COLOR := Color(0.2, 0.14, 0.1)
# เผื่อวาดเกินขอบ World แกน Y — zoom ต่ำๆ กล้องเห็นเหนือ y 0 / ใต้ SIZE.y ได้
const VERTICAL_OVERDRAW := 2000.0
# 100px = 1 m (สมมติ) → เส้นหลักระยะทุก 5 m
const PIXELS_PER_METER := 100.0
const MARKER_SPACING := 500.0
const MARKER_HEIGHT := 360.0
const MARKER_COLOR := Color(1, 1, 1, 0.35)
const MARKER_WIDTH := 3.0
const MARKER_FONT_SIZE := 28
const MARKER_LABEL_OFFSET := Vector2(8, -8)


func _ready() -> void:
	z_index = WORLD_SCRIPT.Z_INDEX_BACKGROUND
	queue_redraw()


func _draw() -> void:
	var width: float = WORLD_SCRIPT.SIZE.x
	var ground_y: float = WORLD_SCRIPT.GROUND_Y
	draw_rect(Rect2(0, -VERTICAL_OVERDRAW, width, ground_y + VERTICAL_OVERDRAW), SKY_COLOR)
	draw_rect(Rect2(0, ground_y, width, WORLD_SCRIPT.SIZE.y - ground_y + VERTICAL_OVERDRAW), EARTH_COLOR)

	var font := ThemeDB.fallback_font
	var x := 0.0
	while x <= width:
		var top := Vector2(x, ground_y - MARKER_HEIGHT)
		draw_line(top, Vector2(x, ground_y), MARKER_COLOR, MARKER_WIDTH)
		draw_string(font, top + MARKER_LABEL_OFFSET + Vector2(0, MARKER_FONT_SIZE), "%d m" % roundi(x / PIXELS_PER_METER), HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT_SIZE, MARKER_COLOR)
		x += MARKER_SPACING
