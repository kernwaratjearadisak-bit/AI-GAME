extends "res://Enemy.gd"

# ส่งหลัง death animation เล่นจบ — Main ใช้นับ Stage pass แล้ว reset stage
signal boss_defeated

const BOSS_HP_MULTIPLIER := 2
# ลำตัว Boss (Boss.tscn) = 152x296 → ครึ่งความกว้าง 76
# Hero หยุดเดินเมื่อ AttackArea (รัศมี 80) แตะ collision ของ Boss: ระยะ center-to-center แนวนอน = 80 + 76 = 156
# Boss ต้องหยุดที่ ≤ 156 ไม่งั้นยืนตีจากระยะที่ Hero ตีไม่ถึง → ใช้ 150 (เผื่อ 6px)
# และยัง ≥ 38 + 76 = 114 (ครึ่งกว้าง Hero + Boss) ลำตัวไม่ทับกัน
const BOSS_STOP_DISTANCE := 150.0
# ตัวใหญ่ หนักกว่า → ลอยสูงแค่ครึ่งของ Enemy ปกติ (ความสูง ∝ speed² จึงคูณ speed ด้วย sqrt ของอัตราส่วน)
const BOSS_KNOCKBACK_HOP_HEIGHT_RATIO := 0.5


func _ready() -> void:
	super()
	stop_distance = BOSS_STOP_DISTANCE
	knockback_hop_speed = KNOCKBACK_HOP_SPEED * sqrt(BOSS_KNOCKBACK_HOP_HEIGHT_RATIO)


# HP x2 ของ Enemy ปกติ แล้ว setup() ค่อยคูณ stage_multiplier ทับ — attack ใช้ BASE_ATTACK เท่า Enemy ปกติ
func _get_base_hp() -> float:
	return BASE_HP * BOSS_HP_MULTIPLIER


func _die() -> void:
	await super()
	boss_defeated.emit()
