extends Sprite2D

const PROPERTIES_SCENE := preload("res://scenes/level_edit/player_spawn_properties.tscn")

var properties : Control

func _init() -> void:
	properties = PROPERTIES_SCENE.instantiate()

func set_upgrades(upgrades : int) -> void:
	for i in 6:
		properties.get_node("StartingUpgrades").get_child(i).button_pressed = (upgrades & (1 << i) != 0)

func get_upgrades() -> int:
	
	var upgrades : int = 0
	
	for i in 6:
		if properties.get_node("StartingUpgrades").get_child(i).button_pressed:
			upgrades |= (1 << i)
	
	return upgrades
