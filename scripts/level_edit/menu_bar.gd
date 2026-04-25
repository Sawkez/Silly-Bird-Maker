extends MenuBar

enum FileOption {EXPORT}
enum EditOption {ADD_UPGRADE_PICKUP}

@onready var level_edit : LevelEdit = get_node("/root/LevelEdit")

func _on_file_id_pressed(id: int) -> void:
	if id == FileOption.EXPORT:
		level_edit.export()

func _on_edit_id_pressed(id: int) -> void:
	if id == EditOption.ADD_UPGRADE_PICKUP:
		%Rooms.get_child(%Viewport.current_room).add_object(UpgradePickup.new())
