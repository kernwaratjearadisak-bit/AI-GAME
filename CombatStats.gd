class_name CombatStats
extends RefCounted

# สูตร stat กลางของ Hero / Enemy / Boss — แก้สมดุลที่ไฟล์นี้ที่เดียว

# STR: damage ที่ส่งออกเพิ่มขึ้น 5% ต่อแต้ม
const STR_DAMAGE_PER_POINT := 0.05
# VIT: ลด damage แบบ diminishing — VIT เท่ากับค่านี้ = ลด 50% และไม่มีวันถึง 100%
const VIT_REDUCTION_CONSTANT := 100.0
# AGI: ความเร็วโจมตีเพิ่ม 3% ต่อแต้ม แต่ interval ไม่ต่ำกว่า MIN_ATTACK_INTERVAL
const AGI_SPEED_PER_POINT := 0.03
const MIN_ATTACK_INTERVAL := 0.25


static func get_damage_output(attack_damage: float, strength: float) -> float:
	return snappedf(attack_damage * (1.0 + strength * STR_DAMAGE_PER_POINT), 0.01)


static func get_damage_reduction(vitality: float) -> float:
	return vitality / (vitality + VIT_REDUCTION_CONSTANT)


static func get_damage_received(incoming: float, vitality: float) -> float:
	return snappedf(incoming * (1.0 - get_damage_reduction(vitality)), 0.01)


static func get_attack_interval(base_interval: float, agility: float) -> float:
	return maxf(MIN_ATTACK_INTERVAL, base_interval / (1.0 + agility * AGI_SPEED_PER_POINT))


# speed ของ animation "attack" ที่ทำให้เล่นจบภายใน attack_interval — ถ้าปกติก็ทันอยู่แล้วคืน 1.0 (ไม่เร่ง ไม่ชะลอ)
static func get_attack_anim_speed(sprite: AnimatedSprite2D, attack_interval: float) -> float:
	var frames := sprite.sprite_frames
	var fps := frames.get_animation_speed("attack")
	if fps <= 0.0 or attack_interval <= 0.0:
		return 1.0
	var total_frame_duration := 0.0
	for i in frames.get_frame_count("attack"):
		total_frame_duration += frames.get_frame_duration("attack", i)
	var anim_length := total_frame_duration / fps
	return maxf(1.0, anim_length / attack_interval)
