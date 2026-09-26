class_name HeroSkills
extends Node

# ลูกของ Hero (Hero.tscn) — cooldown / เงื่อนไข / ผลของ skill ของ Hero ตัวนี้ ตามรายการใน HeroClasses "skills"
# auto use: cooldown ถึง 0 แล้วเช็กเงื่อนไขทุกเฟรม ตรงเมื่อไหร่ใช้ทันที — skill แต่ละตัว cooldown แยกกัน
# skill ที่ใช้เวลา (Charge / Push) ตั้ง is_casting: Hero.gd หยุด AI/การหัน/animation ของตัวเอง และ skill อื่นรอ

enum ChargePhase { HOLD, RELEASE }

@onready var hero: CharacterBody2D = get_parent()

var skill_ids: Array = []
# SkillId → วินาทีที่เหลือ
var cooldowns := {}
# Regenerate HP ที่กำลังทำงาน: เหลืออีกกี่ครั้ง / อีกกี่วิถึงครั้งถัดไป
var regen_ticks_left := 0
var regen_tick_timer := 0.0
# casting lock — casting_skill = skill ที่กำลังทำงานอยู่ (-1 = ไม่มี)
var is_casting := false
var casting_skill := -1
var cast_elapsed := 0.0
var charge_phase: ChargePhase = ChargePhase.HOLD
var push_shots_fired := 0
var push_shot_timer := 0.0


func _ready() -> void:
	# hero_class ถูกตั้งก่อน add_child (HeroParty) จึงอ่านได้แล้วตรงนี้
	skill_ids = HeroClasses.get_config(hero.hero_class)["skills"]
	reset_for_new_stage()


# เริ่ม stage / recruit กลาง stage: ทุก skill cooldown = STAGE_START_COOLDOWN และยกเลิก effect ที่ค้าง
# (Hero.reset_for_new_stage เล่น idle ต่อจากนี้ animation จึงกลับเป็นปกติเอง)
func reset_for_new_stage() -> void:
	for skill_id in skill_ids:
		cooldowns[skill_id] = SkillData.STAGE_START_COOLDOWN
	_cancel_all()


func _physics_process(delta: float) -> void:
	# ตายแล้วไม่เช็ก/ไม่ใช้ skill และหยุด effect ที่ค้าง (_die เล่น death เอง ไม่ต้องคืน animation)
	if hero.hp <= 0:
		_cancel_all()
		return
	_update_regen(delta)
	if is_casting:
		_update_cast(delta)
	# เรียงตามลำดับใน list ของ class — ระหว่าง casting นับ cooldown ต่อแต่ไม่เริ่ม skill ใหม่
	for skill_id in skill_ids:
		cooldowns[skill_id] = maxf(0.0, cooldowns[skill_id] - delta)
		if is_casting or cooldowns[skill_id] > 0.0 or not _can_use(skill_id):
			continue
		_use(skill_id)
		# นับจากตอนเริ่มใช้
		cooldowns[skill_id] = SkillData.get_config(skill_id)["cooldown"]


func has_skills() -> bool:
	return not skill_ids.is_empty()


func get_cooldown(skill_id: SkillData.SkillId) -> float:
	return cooldowns.get(skill_id, 0.0)


func is_regen_active() -> bool:
	return regen_ticks_left > 0


# สถานะระหว่างทำงานสำหรับ UI เช่น "Active (3/5)", "Charging…", "2/3" — ไม่ได้ทำงานอยู่คืน ""
func get_active_status(skill_id: SkillData.SkillId) -> String:
	match skill_id:
		SkillData.SkillId.REGENERATE_HP:
			if is_regen_active():
				return "Active (%d/%d)" % [SkillData.REGEN_TICK_COUNT - regen_ticks_left, SkillData.REGEN_TICK_COUNT]
		SkillData.SkillId.CHARGE_ARROW:
			if casting_skill == skill_id:
				return "Charging…"
		SkillData.SkillId.PUSH_ARROW:
			if casting_skill == skill_id:
				return "%d/%d" % [push_shots_fired, SkillData.PUSH_SHOT_COUNT]
	return ""


# debug (Main.gd ปุ่ม K)
func debug_clear_cooldowns() -> void:
	for skill_id in skill_ids:
		cooldowns[skill_id] = 0.0


func _can_use(skill_id: SkillData.SkillId) -> bool:
	match skill_id:
		SkillData.SkillId.BASH:
			return _get_targets_in_rect(_get_line_rect(SkillData.BASH_RANGE, _get_facing())).size() >= SkillData.BASH_MIN_TARGETS
		SkillData.SkillId.REGENERATE_HP:
			return not is_regen_active() and hero.hp < hero.max_hp * SkillData.REGEN_HP_THRESHOLD
		SkillData.SkillId.CHARGE_ARROW, SkillData.SkillId.PUSH_ARROW:
			return _find_nearest_in_attack_range() != null
	return false


func _use(skill_id: SkillData.SkillId) -> void:
	match skill_id:
		SkillData.SkillId.BASH:
			_use_bash()
		SkillData.SkillId.REGENERATE_HP:
			_start_regen()
		SkillData.SkillId.CHARGE_ARROW:
			_start_charge()
		SkillData.SkillId.PUSH_ARROW:
			_start_push()


func _update_cast(delta: float) -> void:
	cast_elapsed += delta
	match casting_skill:
		SkillData.SkillId.CHARGE_ARROW:
			_update_charge()
		SkillData.SkillId.PUSH_ARROW:
			_update_push(delta)


func _begin_cast(skill_id: SkillData.SkillId) -> void:
	is_casting = true
	casting_skill = skill_id
	cast_elapsed = 0.0


func _end_cast() -> void:
	is_casting = false
	casting_skill = -1
	_refresh_tint()


# ยกเลิกทุก effect ที่ค้าง (ตาย / reset_stage) — ลูกธนูที่ยังไม่ปล่อยไม่ถูกยิง
# ไม่มีอะไรค้างก็ไม่แตะ tint (ถูกเรียกจาก _ready ก่อน Hero._ready ตอนที่ animated_sprite ยังไม่พร้อม)
func _cancel_all() -> void:
	if not is_regen_active() and not is_casting:
		return
	regen_ticks_left = 0
	_end_cast()


# ---- Bash ----

# ไม่แตะ attack_timer ของการตีปกติ — แค่เล่น animation attack ทับ
func _use_bash() -> void:
	var hitbox := _get_line_rect(SkillData.BASH_RANGE, _get_facing())
	var base_damage := _get_base_damage() * SkillData.BASH_DAMAGE_MULTIPLIER
	for enemy in _get_targets_in_rect(hitbox):
		# สุ่มแยกทีละตัว แล้ว Enemy หัก VIT เองใน take_damage (damage number ขึ้นจากตรงนั้น)
		enemy.take_damage(CombatStats.roll_damage(base_damage))
	_play_attack(hero.attack_interval)
	var effects := _get_effects()
	if effects:
		effects.spawn_area_flash(hitbox, SkillData.BASH_EFFECT_COLOR, SkillData.BASH_EFFECT_HOLD, SkillData.BASH_EFFECT_FADE)


# ---- Regenerate HP ----

# heal ครั้งแรกหลังใช้ REGEN_TICK_INTERVAL วิ — ทำต่อจนครบแม้ HP จะเกิน threshold ระหว่างทาง
func _start_regen() -> void:
	regen_ticks_left = SkillData.REGEN_TICK_COUNT
	regen_tick_timer = SkillData.REGEN_TICK_INTERVAL
	_refresh_tint()


func _update_regen(delta: float) -> void:
	if not is_regen_active():
		return
	regen_tick_timer -= delta
	if regen_tick_timer > 0.0:
		return
	regen_tick_timer += SkillData.REGEN_TICK_INTERVAL
	regen_ticks_left -= 1
	var old_hp: float = hero.hp
	# คิดจาก max_hp ณ ตอน heal ครั้งนี้ (อัป VIT ระหว่าง regen ก็ได้ผลทันที)
	var heal_amount: float = hero.max_hp * SkillData.REGEN_PERCENT_PER_TICK
	hero.hp = snappedf(minf(hero.hp + heal_amount, hero.max_hp), 0.01)
	var effects := _get_effects()
	if effects:
		# ค่าที่ heal ได้จริง (โดน clamp ที่ max_hp อาจน้อยกว่า) ปัดทศนิยม 1 ตำแหน่ง — ".0" ตัดทิ้ง: "+5", "+5.3"
		var healed_text := "%.1f" % snappedf(hero.hp - old_hp, 0.1)
		effects.spawn_floating_text(hero, "+" + healed_text.trim_suffix(".0"), SkillData.REGEN_NUMBER_COLOR)
	if not is_regen_active():
		_refresh_tint()


# ---- Charge Arrow ----

func _start_charge() -> void:
	_begin_cast(SkillData.SkillId.CHARGE_ARROW)
	charge_phase = ChargePhase.HOLD
	var target := _find_nearest_in_attack_range()
	hero.face_toward(target.global_position.x)
	# ค้างที่ frame แรกของ attack
	hero.animated_sprite.play("attack")
	hero.animated_sprite.pause()
	hero.animated_sprite.frame = 0


func _update_charge() -> void:
	var sprite: AnimatedSprite2D = hero.animated_sprite
	if charge_phase == ChargePhase.HOLD:
		_refresh_tint()
		if cast_elapsed < SkillData.CHARGE_TIME:
			return
		charge_phase = ChargePhase.RELEASE
		# play ต่อจาก frame ที่ pause ไว้ (frame 0) จนจบ
		sprite.play("attack", CombatStats.get_attack_anim_speed(sprite, hero.attack_interval))
		_refresh_tint()
		return
	if sprite.animation == &"attack" and sprite.is_playing():
		return
	_fire_charge_arrow()
	_end_cast()


# ทางที่หันตอนปล่อย — ข้างหน้าไม่มีเป้าแต่ด้านหลังมี ให้หันไปทางตัวที่ใกล้สุดก่อนยิง
func _fire_charge_arrow() -> void:
	var facing := _get_facing()
	var targets := _get_targets_in_rect(_get_line_rect(SkillData.CHARGE_PIERCE_RANGE, facing))
	if targets.is_empty():
		var behind := _get_targets_in_rect(_get_line_rect(SkillData.CHARGE_PIERCE_RANGE, -facing))
		if not behind.is_empty():
			facing = -facing
			hero.face_toward(hero.global_position.x + facing)
			targets = behind
	# ใกล้ → ไกล: ตัวแรก x CHARGE_DAMAGE_MULTIPLIER แล้วลดทีละ CHARGE_FALLOFF — roll แยกทีละตัว
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return absf(a.global_position.x - hero.global_position.x) < absf(b.global_position.x - hero.global_position.x))
	var multiplier := SkillData.CHARGE_DAMAGE_MULTIPLIER
	var hits: Array[Dictionary] = []
	for enemy in targets:
		hits.append({"target": enemy, "damage": CombatStats.roll_damage(_get_base_damage() * multiplier)})
		multiplier *= SkillData.CHARGE_FALLOFF
	var effects := _get_effects()
	if effects:
		# damage เกิดตอนลูกธนูบินผ่านแต่ละตัว (Arrow.gd) ไม่ใช่ตอนปล่อย
		effects.spawn_pierce_arrow(hero.get_arrow_release_position(), facing, SkillData.CHARGE_PIERCE_RANGE, hits)


# ---- Push Arrow ----

func _start_push() -> void:
	_begin_cast(SkillData.SkillId.PUSH_ARROW)
	push_shots_fired = 0
	push_shot_timer = 0.0
	# นัดแรกทันที
	_update_push(0.0)


func _update_push(delta: float) -> void:
	push_shot_timer -= delta
	if push_shot_timer > 0.0:
		return
	push_shot_timer += SkillData.PUSH_SHOT_INTERVAL
	push_shots_fired += 1
	var target := _find_nearest_in_attack_range()
	# ไม่มีเป้าในนัดนี้ = ข้าม (ยังนับเป็นนัด)
	if target:
		hero.face_toward(target.global_position.x)
		_play_attack(SkillData.PUSH_SHOT_INTERVAL)
		hero.spawn_arrow(target)
		target.take_damage(CombatStats.roll_damage(_get_base_damage() * SkillData.PUSH_DAMAGE_MULTIPLIER))
		if target.hp > 0:
			var direction := signf(target.global_position.x - hero.global_position.x)
			if direction == 0.0:
				direction = _get_facing()
			target.apply_knockback(Vector2(direction * SkillData.PUSH_DISTANCE, 0.0), SkillData.PUSH_KNOCKBACK_DURATION)
	# lock จบตอนนัดสุดท้ายยิงออกไป (~(PUSH_SHOT_COUNT - 1) * PUSH_SHOT_INTERVAL วิ) — animation attack เล่นต่อจนจบเอง
	if push_shots_fired >= SkillData.PUSH_SHOT_COUNT:
		_end_cast()


# ---- helpers ----

func _get_base_damage() -> float:
	return CombatStats.get_damage_output(hero.attack_damage, hero.strength)


func _get_facing() -> float:
	return -1.0 if hero.animated_sprite.flip_h else 1.0


func _play_attack(duration: float) -> void:
	hero.animated_sprite.play("attack", CombatStats.get_attack_anim_speed(hero.animated_sprite, duration))


func _get_effects() -> Node:
	return get_tree().get_first_node_in_group("effects")


# regen (เขียวค้าง) x charge (ฟ้ากระพริบระหว่าง HOLD) คูณทับ tint ของ class
func _refresh_tint() -> void:
	var tint := Color.WHITE
	if is_regen_active():
		tint *= SkillData.REGEN_TINT
	if casting_skill == SkillData.SkillId.CHARGE_ARROW and charge_phase == ChargePhase.HOLD:
		var pulse := 0.5 + 0.5 * sin(cast_elapsed * TAU * SkillData.CHARGE_PULSE_RATE)
		tint *= Color.WHITE.lerp(SkillData.CHARGE_TINT, pulse)
	hero.set_skill_tint(tint)


# สี่เหลี่ยมเริ่มจาก x ของ Hero ยื่นไปทาง facing ยาว length — ขอบบน/ล่าง = ขอบของ CollisionShape จริงของ Hero
func _get_line_rect(length: float, facing: float) -> Rect2:
	var body_rect := _get_body_rect(hero)
	var start_x: float = hero.global_position.x
	var end_x := start_x + facing * length
	return Rect2(minf(start_x, end_x), body_rect.position.y, length, body_rect.size.y)


# Enemy (รวม Boss) ที่ยังมีชีวิตและลำตัวทับกับ rect
func _get_targets_in_rect(rect: Rect2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _is_alive_enemy(enemy) and rect.intersects(_get_body_rect(enemy)):
			targets.append(enemy)
	return targets


# ระยะโจมตีปกติ = AttackArea ของ Hero (Archer กว้างกว่า Warrior ตาม attack_range_multiplier)
func _find_nearest_in_attack_range() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in hero.enemies_in_attack_range:
		if not _is_alive_enemy(enemy):
			continue
		var dist := absf(enemy.global_position.x - hero.global_position.x)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


static func _is_alive_enemy(enemy: Node) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0


# สี่เหลี่ยมลำตัวในพิกัด World จาก RectangleShape2D ของ CollisionShape2D (รองรับ scale และ offset ของ shape)
static func _get_body_rect(body: Node2D) -> Rect2:
	var collision_shape: CollisionShape2D = body.get_node("CollisionShape2D")
	var size: Vector2 = collision_shape.shape.size * collision_shape.global_scale.abs()
	return Rect2(collision_shape.global_position - size * 0.5, size)
