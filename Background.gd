extends Node2D

# debug: เส้นหลักระยะแนวตั้ง "xx m" บอกระยะที่เดินผ่าน — ท้องฟ้า/ดินย้ายไป ParallaxBackground.tscn / World.gd แล้ว
const SHOW_DISTANCE_MARKERS := false
const WORLD_SCRIPT := preload("res://World.gd")
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
	visible = SHOW_DISTANCE_MARKERS
	queue_redraw()


func _draw() -> void:
	var width: float = WORLD_SCRIPT.SIZE.x
	var ground_y: float = WORLD_SCRIPT.GROUND_Y
	var font := ThemeDB.fallback_font
	var x := 0.0
	while x <= width:
		var top := Vector2(x, ground_y - MARKER_HEIGHT)
		draw_line(top, Vector2(x, ground_y), MARKER_COLOR, MARKER_WIDTH)
		draw_string(font, top + MARKER_LABEL_OFFSET + Vector2(0, MARKER_FONT_SIZE), "%d m" % roundi(x / PIXELS_PER_METER), HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT_SIZE, MARKER_COLOR)
		x += MARKER_SPACING
