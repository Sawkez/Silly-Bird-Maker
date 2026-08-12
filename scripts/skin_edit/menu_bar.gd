extends MenuBar

enum FileOption {SAVE, EXIT_TO_PROJECT}
enum EditOption {IMPORT_PALETTE, RELOAD_IMAGES}

@onready var style_edit : StyleEdit = get_node("../..")

func _on_file_id_pressed(id: int) -> void:
	match id:
		FileOption.SAVE:
			style_edit.save()
		FileOption.EXIT_TO_PROJECT:
			get_tree().change_scene_to_file("res://scenes/project/project_menu.tscn")

func _on_edit_id_pressed(id: int) -> void:
	match id:
		EditOption.IMPORT_PALETTE:
			style_edit.import_colors()
		EditOption.RELOAD_IMAGES:
			style_edit.load_textures()
