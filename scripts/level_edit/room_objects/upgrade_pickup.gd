extends RoomObject
class_name UpgradePickup

const PROPERTIES_SCENE := preload("res://scenes/level_edit/upgrade_pickup_properties.tscn")

enum Upgrade {DIVE, DASH, SLIDE, DIVEBOOST, REJUVENATOR, WALLRUN}
const upgrade_names : PackedStringArray = ["dive", "dash", "slide", "diveboost", "rejuvenator", "wallrun"]

var upgrade : Upgrade = Upgrade.DIVE
var properties : Control

func _init(dict : Dictionary = {}) -> void:
	super._init(dict)
	if dict != {}:
		set_position_async(Vector2(dict.position.x, dict.position.y))
	
	properties = PROPERTIES_SCENE.instantiate()
	properties.get_node("Upgrade").item_selected.connect(set_upgrade)
	
	set_upgrade(dict.get(upgrade, 0))

func export() -> Dictionary:
	var dict : Dictionary = super.export()
	dict.upgrade = upgrade
	dict.position = {
		"x": global_position.x,
		"y": global_position.y
	}
	dict.relative_position = {
		"x": position.x,
		"y": position.y
	}
	return dict

func set_upgrade(new_upgrade : int = 0) -> void:
	upgrade = new_upgrade as Upgrade
	texture = load("res://graphics/upgrades/%s.png" % upgrade_names[upgrade])
	properties.get_node("Upgrade").selected = -1
