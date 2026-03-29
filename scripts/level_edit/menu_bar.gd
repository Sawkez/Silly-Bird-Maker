extends MenuBar

enum FileOption {EXPORT}

@onready var level_edit : LevelEdit = get_node("/root/LevelEdit")

func _on_file_id_pressed(id: int) -> void:
	if id == FileOption.EXPORT:
		level_edit.export()
