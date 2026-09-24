extends ColorRect

@onready var hp_label: Label = $HPLabel
@onready var coin_label: Label = $CoinLabel


func _process(_delta: float) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		return
	hp_label.text = "HP: %d/%d" % [leader.hp, leader.max_hp]
	coin_label.text = "Coin: %d" % leader.coin_count
