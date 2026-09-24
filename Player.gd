extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sight_area: Area2D = $SightArea
@onready var attack_area: Area2D = $AttackArea

var hp: int = 100
var max_hp: int = 100
var attack_damage: int = 10
var attack_interval: float = 1.0
var attack_timer: float = 0.0
var coin_count: int = 0
var is_leader: bool = false

var enemies_in_sight: Array[Node2D] = []
var enemies_in_attack_range: Array[Node2D] = []


func _ready() -> void:
	add_to_group("heroes")
	animated_sprite.play("walk")
	sight_area.body_entered.connect(_on_sight_area_body_entered)
	sight_area.body_exited.connect(_on_sight_area_body_exited)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)


func set_as_leader() -> void:
	is_leader = true
	add_to_group("party_leader")


func _process(delta: float) -> void:
	if hp <= 0 or enemies_in_attack_range.is_empty():
		attack_timer = 0.0
		return
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		_attack_current_target()


func _attack_current_target() -> void:
	var target: Node2D = enemies_in_attack_range[0]
	if is_instance_valid(target):
		target.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	_flash_hit()
	if hp <= 0:
		print("Hero died")


func add_coin(amount: int) -> void:
	coin_count += amount


func _flash_hit() -> void:
	animated_sprite.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.15)


func _on_sight_area_body_entered(body: Node2D) -> void:
	enemies_in_sight.append(body)
	_update_world_scrolling()


func _on_sight_area_body_exited(body: Node2D) -> void:
	enemies_in_sight.erase(body)
	_update_world_scrolling()


func _on_attack_area_body_entered(body: Node2D) -> void:
	enemies_in_attack_range.append(body)


func _on_attack_area_body_exited(body: Node2D) -> void:
	enemies_in_attack_range.erase(body)


func _update_world_scrolling() -> void:
	if not is_leader:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.scrolling = enemies_in_sight.is_empty()
