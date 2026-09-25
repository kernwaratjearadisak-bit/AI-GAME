extends ColorRect

const MAX_HEROES := 4

@onready var atk_label: Label = $ATKLabel
@onready var hp_max_label: Label = $HPMaxLabel
@onready var atk_speed_label: Label = $AttackSpeedLabel
@onready var heroes_label: Label = $HeroesLabel
@onready var str_label: Label = $STRLabel
@onready var vit_label: Label = $VITLabel
@onready var agi_label: Label = $AGILabel
@onready var def_label: Label = $DEFLabel
@onready var recruit_button: Button = $RecruitButton


func _ready() -> void:
	recruit_button.pressed.connect(_on_recruit_pressed)


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

# TODO: upgrade buttons จะมาทีหลัง
