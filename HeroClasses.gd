class_name HeroClasses
extends RefCounted

# ข้อมูล class ของ Hero เก็บที่เดียว — base stat (HP, attack_damage, STR/VIT/AGI) เหมือนกันทุก class
enum HeroClass { WARRIOR, ARCHER }

# จุดอ้างอิงของสูตร HP Max (CombatStats.get_max_hp) — VIT เริ่มต้น 10 → HP Max 100
const BASE_HP := 100.0
const BASE_VITALITY := 10

# attack_range_multiplier: คูณรัศมี AttackArea เดิมใน Hero.tscn
# attack_speed_multiplier: < 1 = ตีช้าลง (base interval ของ class = base_attack_interval / ค่านี้)
# skills: SkillData.SkillId ที่ class นี้ใช้ (auto use โดย HeroSkills ลูกของ Hero)
# short_name: ตัวย่อบน Tab ของ HeroStatusPanel เช่น "Hero 1 (W)"
# tint: ใส่ที่ self_modulate ของ sprite (modulate ใช้ flash ตอนโดนตี)
const CONFIGS := {
	HeroClass.WARRIOR: {
		"display_name": "Warrior",
		"short_name": "W",
		"skills": [SkillData.SkillId.BASH, SkillData.SkillId.REGENERATE_HP],
		"attack_range_multiplier": 1.0,
		"attack_speed_multiplier": 1.0,
		"tint": Color(1, 1, 1),
	},
	HeroClass.ARCHER: {
		"display_name": "Archer",
		"short_name": "A",
		"skills": [SkillData.SkillId.CHARGE_ARROW, SkillData.SkillId.PUSH_ARROW],
		"attack_range_multiplier": 4.0,
		"attack_speed_multiplier": 0.7,
		"tint": Color(0.7, 1.0, 0.7),
	},
}


static func get_config(hero_class: HeroClass) -> Dictionary:
	return CONFIGS[hero_class]
