extends Sprite2D
class_name RoomObject

enum ObjectType {UPGRADE_PICKUP}
var drag : Drag
var type : ObjectType

func _init(_dict : Dictionary = {}) -> void:
	drag = Drag.new(1)
	add_child(drag)

func export() -> Dictionary: return {"type" : type}

func set_position_async(pos : Vector2) -> void:
	await ready
	global_position = pos

static func make_room_object(dict : Dictionary) -> RoomObject:
	print("making object: %s" % dict)
	if dict.type == ObjectType.UPGRADE_PICKUP: return UpgradePickup.new(dict)
	
	return null
