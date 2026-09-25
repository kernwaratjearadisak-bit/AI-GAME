extends ColorRect

const MAX_HEROES := 4
const STAT_UPGRADE_COST: int = preload("res://Hero.gd").STAT_UPGRADE_COST

@onready var atk_label: Label = $ATKLabel
@onready var hp_max_label: Label = $HPMaxLabel
@onready var atk_speed_label: Label = $AttackSpeedLabel
@onready var heroes_label: Label = $HeroesLabel
@onready var str_label: Label = $STRLabel
@onready var vit_label: Label = $VITLabel
@onready var agi_label: Label = $AGILabel
@onready var def_label: Label = $DEFLabel
@onready var str_plus_button: Button = $STRPlusButton
@onready var vit_plus_button: Button = $VITPlusButton
@onready var agi_plus_button: Button = $AGIPlusButton
@onready var recruit_button: Button = $RecruitButton


func _ready() -> void:
	recruit_button.pressed.connect(_on_recruit_pressed)
	str_plus_button.pressed.connect(_on_stat_plus_pressed.bind(&"strength"))
	vit_plus_button.pressed.connect(_on_stat_plus_pressed.bind(&"vitality"))
	agi_plus_button.pressed.connect(_on_stat_plus_pressed.bind(&"agility"))


func _process(_delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader:
		# ค่าจริงหลังคิด stat แล้ว (สูตรใน CombatStats.gd)
		atk_label.text = "ATK: %.2f" % CombatStats.get_damage_output(leader.attack_damage, leader.strength)
		hp_max_label.text = "HP Max: %.2f" % leader.max_hp
		atk_speed_label.text = "Attack interval: %.2fs" % leader.attack_interval
		def_label.text = "DEF: %.2f%%" % (CombatStats.get_damage_reduction(leader.vitality) * 100.0)
		str_label.text = "STR: %d" % leader.strength
		vit_label.text = "VIT: %d" % leader.vitality
		agi_label.text = "AGI: %d" % leader.agility

	# ไม่มี leader หรือ coin กองกลางไม่พอ = กดไม่ได้
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	var can_upgrade: bool = leader != null and hero_party != null and hero_party.can_afford(STAT_UPGRADE_COST)
	str_plus_button.disabled = not can_upgrade
	vit_plus_button.disabled = not can_upgrade
	agi_plus_button.disabled = not can_upgrade

	var hero_count := get_tree().get_nodes_in_group("heroes").size()
	if hero_count >= MAX_HEROES:
		heroes_label.text = "Heroes: %d/%d (Max)" % [hero_count, MAX_HEROES]
		recruit_button.disabled = true
	else:
		heroes_label.text = "Heroes: %d/%d" % [hero_count, MAX_HEROES]
		recruit_button.disabled = false


func _on_recruit_pressed() -> void:
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	if hero_party:
		hero_party.recruit_hero()

# อัป stat ของ Hero ที่ถูกเลือก ด้วย coin กองกลาง — logic อยู่ใน Hero.try_upgrade_stat()
func _on_stat_plus_pressed(stat_name: StringName) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader:
		leader.try_upgrade_stat(stat_name)

# TODO: upgrade buttons จะมาทีหลัง
