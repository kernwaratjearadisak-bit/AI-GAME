extends ColorRect

const MAX_HEROES := 4

@onready var atk_label: Label = $ATKLabel
@onready var hp_max_label: Label = $HPMaxLabel
@onready var atk_speed_label: Label = $AttackSpeedLabel
@onready var heroes_label: Label = $HeroesLabel
@onready var recruit_button: Button = $RecruitButton


func _ready() -> void:
	recruit_button.pressed.connect(_on_recruit_pressed)


func _process(_delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader:
		atk_label.text = "ATK: %d" % leader.attack_damage
		hp_max_label.text = "HP Max: %d" % leader.max_hp
		atk_speed_label.text = "Attack Speed: %.1f/s" % (1.0 / leader.attack_interval)

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
