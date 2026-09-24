extends Node2D

# โถงทางเดินยาวแนวนอน: X = 20 เท่าของความกว้างจอ (720), Y = 2560 (~17.8% ของ X, = 2 เท่าของความสูงจอ)
# World ไม่ขยับตัวเองอีกต่อไป — Hero/Enemy เคลื่อนที่ด้วย global_position ของตัวเอง
const SIZE := Vector2(14400, 2560)


func _ready() -> void:
	add_to_group("world")


static func clamp_to_bounds(point: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, SIZE)
