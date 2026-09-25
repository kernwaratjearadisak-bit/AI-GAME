extends "res://Enemy.gd"

# ส่งหลัง death animation เล่นจบ — Main ใช้นับ Stage pass แล้ว reset stage
signal boss_defeated

const BOSS_HP_MULTIPLIER := 2
# ลำตัว Boss (Boss.tscn) = 152x296 → ครึ่งความกว้าง 76
# Hero หยุดเดินเมื่อ AttackArea (รัศมี 80) แตะ collision ของ Boss: ระยะ center-to-center แนวนอน = 80 + 76 = 156
# Boss ต้องหยุดที่ ≤ 156 ไม่งั้นยืนตีจากระยะที่ Hero ตีไม่ถึง → ใช้ 150 (เผื่อ 6px)
# และยัง ≥ 38 + 76 = 114 (ครึ่งกว้าง Hero + Boss) ลำตัวไม่ทับกัน
const BOSS_STOP_DISTANCE := 150.0


func _ready() -> void:
	super()
	hp *= BOSS_HP_MULTIPLIER
	stop_distance = BOSS_STOP_DISTANCE


func _die() -> void:
	await super()
	boss_defeated.emit()
