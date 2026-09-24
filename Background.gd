extends Node2D

const WORLD_SCRIPT := preload("res://World.gd")
const LINE_SPACING := 150.0
const LINE_COLOR := Color(1, 1, 1, 0.12)
const LINE_WIDTH := 4.0
const BORDER_COLOR := Color(1, 0.3, 0.3, 0.6)
const BORDER_WIDTH := 12.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = WORLD_SCRIPT.SIZE

	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), LINE_COLOR, LINE_WIDTH)
		x += LINE_SPACING

	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), LINE_COLOR, LINE_WIDTH)
		y += LINE_SPACING

	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)
