extends ColorRect

@onready var coin_label: Label = $CoinLabel
@onready var stage_pass_label: Label = $StagePassLabel


func _process(_delta: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		stage_pass_label.text = "Stage pass: %d" % main.stage_pass_count

	# coin กองกลาง — ไม่ขึ้นกับว่าเลือก Hero ตัวไหน
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	if hero_party:
		coin_label.text = "Coin: %d" % hero_party.party_coins
