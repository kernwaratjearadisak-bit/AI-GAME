extends Camera2D

const WORLD_SCRIPT := preload("res://World.gd")
# BattleZone ใน UI อยู่ที่ y 192-832 บนจอ (กึ่งกลาง y=512) แต่กึ่งกลางจอคือ y=640
# เลื่อนกล้องลง 128px เพื่อให้ Hero ไปอยู่กลาง BattleZone ไม่โดน HeroStatusPanel บัง
const BATTLE_ZONE_TOP := 192
const BATTLE_ZONE_BOTTOM := 832
const BATTLE_ZONE_OFFSET := Vector2(0, 128)
const FOLLOW_SMOOTHING_SPEED := 6.0

var has_snapped_to_leader := false


func _ready() -> void:
	offset = BATTLE_ZONE_OFFSET
	limit_left = 0
	limit_right = int(WORLD_SCRIPT.SIZE.x)
	# World สูงเท่าจอพอดี แต่ส่วนที่มองเห็นจริงคือแถบ BattleZone (640px) เท่านั้น
	# จึงเผื่อขอบบน/ล่างเท่ากับความสูงของ UI ที่บังอยู่ ให้แถบ BattleZone เลื่อนไปถึงขอบ World ได้ทั้งบนและล่าง
	limit_top = -BATTLE_ZONE_TOP
	limit_bottom = int(WORLD_SCRIPT.SIZE.y) + (int(get_viewport_rect().size.y) - BATTLE_ZONE_BOTTOM)
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SMOOTHING_SPEED
	make_current()


func _process(_delta: float) -> void:
	# Hero ที่ is_selected = true จะอยู่ใน group "party_leader" เสมอ (ดู Hero.select())
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	global_position = leader.global_position
	if not has_snapped_to_leader:
		# เฟรมแรกให้กระโดดไปที่ Hero ทันที ไม่ต้องค่อยๆ เลื่อนมาจาก (0, 0)
		reset_smoothing()
		has_snapped_to_leader = true
