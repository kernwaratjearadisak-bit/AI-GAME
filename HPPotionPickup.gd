extends "res://Pickup.gd"

const MOVE_DURATION := 0.4
const HP_POTION_HEAL_AMOUNT := 15.0

var start_position := Vector2.ZERO


func _fly_to_target() -> void:
	if _find_selected_hero() == null:
		queue_free()
		return

	# ไล่ตามตำแหน่งปัจจุบันของ Hero ที่ถูกเลือกทุกเฟรม (Hero เดินอยู่ ถ้าล็อกเป้าไว้ตั้งแต่แรกจะไปไม่ถึงตัว)
	start_position = global_position
	var tween := create_tween()
	tween.tween_method(_move_toward_selected_hero, 0.0, 1.0, MOVE_DURATION)
	tween.finished.connect(_on_arrived)


func _find_selected_hero() -> Node2D:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if hero.is_selected:
			return hero
	return null


func _move_toward_selected_hero(weight: float) -> void:
	var hero := _find_selected_hero()
	if hero:
		global_position = start_position.lerp(hero.global_position, weight)


func _on_arrived() -> void:
	# restore เฉพาะ Hero ที่ is_selected ตอนถึงตัวเท่านั้น และไม่ชุบชีวิต Hero ที่ตายไปแล้ว
	var hero := _find_selected_hero()
	if hero and hero.hp > 0:
		hero.hp = snappedf(minf(hero.hp + HP_POTION_HEAL_AMOUNT, hero.max_hp), 0.01)
	queue_free()
