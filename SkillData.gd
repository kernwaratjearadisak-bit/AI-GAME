class_name SkillData
extends RefCounted

# config ของ skill ทุกตัว เก็บที่เดียว — HeroClasses บอกว่า class ไหนมี skill อะไร, HeroSkills.gd เป็นคนใช้
enum SkillId { BASH, REGENERATE_HP, CHARGE_ARROW, PUSH_ARROW }

# ทุก skill เริ่ม stage (รวม reset_stage และ Hero ที่ recruit กลาง stage) ด้วย cooldown นี้
const STAGE_START_COOLDOWN := 30.0
# skill ที่ใช้เวลา (Charge / Push) ตั้ง HeroSkills.is_casting ระหว่างทำงาน: Hero ไม่เดิน ไม่ตีปกติ ไม่หันเอง
# และ skill อื่นรอจนจบ — หลายตัว Ready พร้อมกันใช้ตามลำดับใน HeroClasses "skills"

# Bash: ตีทุก Enemy ในสี่เหลี่ยมยาว BASH_RANGE ไปทางที่หัน สูงเท่า CollisionShape ของ Hero
const BASH_COOLDOWN := 25.0
const BASH_RANGE := 300.0
const BASH_MIN_TARGETS := 3
const BASH_DAMAGE_MULTIPLIER := 2.0
# effect placeholder: แถบเหลืองโปร่งค้าง HOLD วิ แล้วจางใน FADE วิ
const BASH_EFFECT_COLOR := Color(1.0, 0.9, 0.2, 0.45)
const BASH_EFFECT_HOLD := 0.2
const BASH_EFFECT_FADE := 0.2

# Regenerate HP: เมื่อ hp < max_hp * THRESHOLD → heal max_hp * PERCENT_PER_TICK (max_hp ณ ตอน heal) ทุก TICK_INTERVAL วิ
# รวม TICK_COUNT ครั้ง
const REGEN_COOLDOWN := 30.0
const REGEN_HP_THRESHOLD := 0.5
const REGEN_PERCENT_PER_TICK := 0.05
const REGEN_TICK_INTERVAL := 3.0
const REGEN_TICK_COUNT := 5
const REGEN_NUMBER_COLOR := Color(0.4, 1.0, 0.4)
# คูณทับ tint ของ class ที่ self_modulate ตลอดช่วง regen
const REGEN_TINT := Color(0.75, 1.0, 0.75)

# Charge Arrow (Archer): ค้าง frame แรกของ attack CHARGE_TIME วิ → เล่น attack จนจบ → ยิงลูกธนูทะลุ
# โดนทุก Enemy ในแนวยาว CHARGE_PIERCE_RANGE สูงเท่า CollisionShape ของ Hero
# ใกล้สุด = x CHARGE_DAMAGE_MULTIPLIER แล้วตัวถัดไป x CHARGE_FALLOFF ของตัวก่อนหน้า (1.5, 1.125, 0.84, ...)
const CHARGE_COOLDOWN := 25.0
const CHARGE_TIME := 2.5
const CHARGE_PIERCE_RANGE := 800.0
const CHARGE_DAMAGE_MULTIPLIER := 1.5
const CHARGE_FALLOFF := 0.75
# ระหว่างชาร์จ: tint กระพริบระหว่างสีปกติกับ CHARGE_TINT ด้วยความถี่นี้ (ครั้ง/วิ)
const CHARGE_TINT := Color(0.45, 0.7, 1.0)
const CHARGE_PULSE_RATE := 3.0
const CHARGE_ARROW_LENGTH := 90.0
const CHARGE_ARROW_WIDTH := 4.0
const CHARGE_ARROW_COLOR := Color(0.5, 0.8, 1.0)

# Push Arrow (Archer): ยิง PUSH_SHOT_COUNT นัด ห่างกัน PUSH_SHOT_INTERVAL วิ (นัดแรกทันที) — แต่ละนัดตี Enemy ใกล้สุด
# ในระยะโจมตี 1 ตัว แล้วผลักออก PUSH_DISTANCE ภายใน PUSH_KNOCKBACK_DURATION วิ (ผ่าน Enemy.apply_knockback)
const PUSH_COOLDOWN := 35.0
const PUSH_SHOT_COUNT := 3
const PUSH_SHOT_INTERVAL := 0.5
const PUSH_DAMAGE_MULTIPLIER := 1.0
const PUSH_DISTANCE := 150.0
const PUSH_KNOCKBACK_DURATION := 0.2

# short_name: ชื่อสั้นบน HeroStatusPanel ("Bash: 12s")
const CONFIGS := {
	SkillId.BASH: {
		"id": SkillId.BASH,
		"display_name": "Bash",
		"short_name": "Bash",
		"cooldown": BASH_COOLDOWN,
	},
	SkillId.REGENERATE_HP: {
		"id": SkillId.REGENERATE_HP,
		"display_name": "Regenerate HP",
		"short_name": "Regen",
		"cooldown": REGEN_COOLDOWN,
	},
	SkillId.CHARGE_ARROW: {
		"id": SkillId.CHARGE_ARROW,
		"display_name": "Charge Arrow",
		"short_name": "Charge",
		"cooldown": CHARGE_COOLDOWN,
	},
	SkillId.PUSH_ARROW: {
		"id": SkillId.PUSH_ARROW,
		"display_name": "Push Arrow",
		"short_name": "Push",
		"cooldown": PUSH_COOLDOWN,
	},
}


static func get_config(skill_id: SkillId) -> Dictionary:
	return CONFIGS[skill_id]
