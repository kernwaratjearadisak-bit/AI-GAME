extends Node2D

const MOVE_DURATION := 0.4


func _ready() -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader == null:
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(self, "global_position", leader.global_position, MOVE_DURATION)
	tween.finished.connect(_on_arrived.bind(leader))


func _on_arrived(leader: Node2D) -> void:
	if is_instance_valid(leader):
		leader.add_coin(1)
	queue_free()
