extends ColorRect

@onready var hp_label: Label = $HPLabel
@onready var coin_label: Label = $CoinLabel
@onready var stage_pass_label: Label = $StagePassLabel


func _process(_delta: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		stage_pass_label.text = "Stage pass: %d" % main.stage_pass_count

	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	hp_label.text = "HP: %d/%d" % [leader.hp, leader.max_hp]
	coin_label.text = "Coin: %d" % leader.coin_count
