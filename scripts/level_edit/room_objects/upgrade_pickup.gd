extends RoomObject
class_name UpgradePickup

const PROPERTIES_SCENE := preload("res://scenes/level_edit/upgrade_pickup_properties.tscn")

enum Upgrade {DIVE, DASH, SLIDE, DIVEBOOST, REJUVENATOR, WALLRUN}
const upgrade_names : PackedStringArray = ["dive", "dash", "slide", "diveboost", "rejuvenator", "wallrun"]

var upgrade : Upgrade = Upgrade.DIVE
var properties : Control

func _init(binary : BinaryReader = null) -> void:
	super._init(binary)
	
	properties = PROPERTIES_SCENE.instantiate()
	properties.get_node("Upgrade").item_selected.connect(set_upgrade)
	
	if binary != null:
		set_upgrade(binary.file.get_8())
		
		var new_pos : Vector2
		new_pos.x = binary.file.get_float()
		new_pos.y = binary.file.get_float()
		set_position_async(new_pos)

func export() -> BinarySection:
	var section := super.export()
	section.push_u8(upgrade)
	section.push_float(global_position.x)
	section.push_float(global_position.y)
	
	return section

func set_upgrade(new_upgrade : int = 0) -> void:
	upgrade = new_upgrade as Upgrade
	texture = load("res://graphics/upgrades/%s.png" % upgrade_names[upgrade])
	properties.get_node("Upgrade").selected = properties.get_node("Upgrade").item_count - 1
