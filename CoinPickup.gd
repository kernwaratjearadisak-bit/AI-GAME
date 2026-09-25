extends Node2D

const MOVE_DURATION := 0.4
const COIN_VALUE := 1

# กันนับซ้ำ — _collect() ถูกเรียกได้ทั้งตอนลอยถึง leader และตอนถูกลบกลางทาง
var is_collected := false


func _ready() -> void:
	# ลอยไปหา leader เพื่อความสวยงามเท่านั้น — coin เข้ากองกลางของ party เสมอ ไม่ขึ้นกับ leader
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		_collect()
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(self, "global_position", leader.global_position, MOVE_DURATION)
	tween.finished.connect(_on_arrived)


func _on_arrived() -> void:
	_collect()
	queue_free()


# ถูกลบก่อนลอยถึง (เช่น reset_stage เคลียร์ $Enemies) ก็ยังนับเข้ากองกลาง ไม่ทิ้ง
func _exit_tree() -> void:
	_collect()


func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	if hero_party:
		hero_party.add_coins(COIN_VALUE)
