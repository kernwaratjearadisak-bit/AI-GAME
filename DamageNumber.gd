extends Node2D

# ตัวเลข damage ลอยขึ้นแล้วจางหาย — Effects.gd เป็นคนสร้าง/วางตำแหน่ง
const RISE_DISTANCE := 80.0
const LIFETIME := 1.5
# เริ่ม fade ที่วินาทีนี้ จางจนหายตอนครบ LIFETIME
const FADE_START := 0.9

@onready var label: Label = $Label


# เรียกหลัง add_child และตั้ง global_position แล้ว (tween ลอยขึ้นจากตำแหน่งปัจจุบัน)
func setup(amount: float, color: Color) -> void:
	label.text = "%.2f" % amount
	label.add_theme_color_override("font_color", color)

	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME - FADE_START).set_delay(FADE_START)
	tween.chain().tween_callback(queue_free)
