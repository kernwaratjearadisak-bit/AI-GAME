extends "res://Pickup.gd"

const MOVE_DURATION := 0.4
const HP_POTION_HEAL_AMOUNT := 15.0

var start_position := Vector2.ZERO
# ล็อกตอนเริ่มลอย — เปลี่ยนเฉพาะตอนเป้าตาย/ถูกลบก่อนถึง (ไม่สลับกลางทางตาม HP% ที่เปลี่ยน จะได้ไม่ลอยส่าย)
var target_hero: Node2D = null
var move_tween: Tween = null


func _fly_to_target() -> void:
	_retarget()


# หาเป้าใหม่ด้วย HeroParty.get_lowest_hp_hero() แล้วลอยจากตำแหน่งปัจจุบัน — ไม่เหลือใครให้หาย
func _retarget() -> void:
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	target_hero = hero_party.get_lowest_hp_hero() if hero_party else null
	if target_hero == null:
		queue_free()
		return
	# ไล่ตามตำแหน่งปัจจุบันของเป้าทุกเฟรม (Hero เดินอยู่ ถ้าล็อกจุดไว้ตั้งแต่แรกจะไปไม่ถึงตัว)
	start_position = global_position
	move_tween = create_tween()
	move_tween.tween_method(_move_toward_target, 0.0, 1.0, MOVE_DURATION)
	move_tween.finished.connect(_on_arrived)


func _is_target_alive() -> bool:
	return is_instance_valid(target_hero) and target_hero.hp > 0


func _move_toward_target(weight: float) -> void:
	if not _is_target_alive():
		_retarget.call_deferred()
		return
	global_position = start_position.lerp(target_hero.global_position, weight)


# heal เป้าที่ล็อกไว้ (HP% ต่ำสุดตอนเริ่มลอย) — เกิน max_hp ก็ clamp ทิ้ง potion ไม่เก็บไว้
func _on_arrived() -> void:
	if not _is_target_alive():
		_retarget()
		return
	target_hero.hp = snappedf(minf(target_hero.hp + HP_POTION_HEAL_AMOUNT, target_hero.max_hp), 0.01)
	queue_free()
