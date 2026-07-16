extends Sprite2D
class_name RoomObject

enum ObjectType {UPGRADE_PICKUP}
var drag : Drag
var type : ObjectType

func _init(binary : BinaryReader) -> void:
	drag = Drag.new(1)
	add_child(drag)

func export() -> BinarySection:
	var section := BinarySection.new("OBJT")
	section.push_u16(type)
	return section

func set_position_async(pos : Vector2) -> void:
	await ready
	global_position = pos

static func make_room_object(binary : BinaryReader) -> RoomObject:
	var type := binary.file.get_16()
	if type == ObjectType.UPGRADE_PICKUP: return UpgradePickup.new(binary)
	
	return null
