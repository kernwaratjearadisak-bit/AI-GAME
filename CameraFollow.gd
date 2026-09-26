extends Camera2D

const WORLD_SCRIPT := preload("res://World.gd")
# BattleZone ใน UI (Main.tscn) อยู่ที่ y 192-832 บนจอ — ส่วนบน/ล่างโดน ResourceBar / HeroStatusPanel บัง
const BATTLE_ZONE_TOP := 192
const BATTLE_ZONE_BOTTOM := 832
# เส้นพื้น (World.GROUND_Y) อยู่ที่สัดส่วนนี้ของความสูง BattleZone นับจากขอบบน — 0.8 → จอ y 704
const GROUND_SCREEN_RATIO := 0.8
# < 1 = มองเห็นกว้างขึ้น (Godot 4: zoom 0.7 = ย่อภาพลง) — พื้นยังอยู่ที่ GROUND_SCREEN_RATIO เพราะคำนวณ y ตาม zoom
const CAMERA_ZOOM := 1.0
# เลื่อนกล้องไปทาง HeroParty.formation_facing (ไม่ใช่ flip_h ของ leader ที่หันไปมาตอนตี) ให้เห็นข้างหน้ามากกว่าข้างหลัง
const CAMERA_LOOK_AHEAD := 120.0
# ความเร็ว lerp ของ look-ahead ตอนแถวสลับข้าง (ต่อวินาที, exponential)
const LOOK_AHEAD_SMOOTHING := 3.0
const FOLLOW_SMOOTHING_SPEED := 6.0

var has_snapped_to_leader := false
# ค่า look-ahead ปัจจุบันแกน X — lerp เข้าหา formation_facing * CAMERA_LOOK_AHEAD
var look_ahead_x := CAMERA_LOOK_AHEAD


func _ready() -> void:
	zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	# ขอบซ้าย/ขวาของจอไม่เกินขอบ World (limit คิดจากขอบจอจริงหลัง zoom แล้ว) — แกน Y ล็อกเองใน _get_locked_y()
	limit_left = 0
	limit_right = int(WORLD_SCRIPT.SIZE.x)
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SMOOTHING_SPEED
	make_current()


# ใช้ตอน leader ถูกย้ายข้าม World (เช่น reset stage) — กระโดดไปทันที ไม่ให้ smoothing เลื่อนผ่านทั้ง World
func snap_to_leader() -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	look_ahead_x = _get_formation_facing() * CAMERA_LOOK_AHEAD
	global_position = _get_target_position(leader)
	reset_smoothing()


func _process(delta: float) -> void:
	# Hero ที่ is_selected = true จะอยู่ใน group "party_leader" เสมอ (ดู Hero.select())
	# เปลี่ยนตัวที่เลือก = เป้าเปลี่ยน แล้ว position smoothing เลื่อนไปหาเองแบบนุ่ม ไม่กระโดด
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	var target_look_ahead := _get_formation_facing() * CAMERA_LOOK_AHEAD
	look_ahead_x = lerpf(look_ahead_x, target_look_ahead, 1.0 - exp(-LOOK_AHEAD_SMOOTHING * delta))
	global_position = _get_target_position(leader)
	if not has_snapped_to_leader:
		# เฟรมแรกให้กระโดดไปที่ Hero ทันที ไม่ต้องค่อยๆ เลื่อนมาจาก (0, 0)
		reset_smoothing()
		has_snapped_to_leader = true


# ตามแค่แกน X — แกน Y คงที่
func _get_target_position(leader: Node2D) -> Vector2:
	return Vector2(leader.global_position.x + look_ahead_x, _get_locked_y())


# จอ y = (world y - กล้อง y) * zoom + ครึ่งความสูงจอ → แก้หากล้อง y ที่ทำให้ GROUND_Y ตกที่ ground_screen_y
func _get_locked_y() -> float:
	var ground_screen_y := BATTLE_ZONE_TOP + (BATTLE_ZONE_BOTTOM - BATTLE_ZONE_TOP) * GROUND_SCREEN_RATIO
	var screen_center_y := get_viewport_rect().size.y * 0.5
	return WORLD_SCRIPT.GROUND_Y - (ground_screen_y - screen_center_y) / zoom.y


func _get_formation_facing() -> float:
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	return hero_party.formation_facing if hero_party else 1.0
