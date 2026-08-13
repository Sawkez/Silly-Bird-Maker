extends MenuBar

enum FileOption {SAVE, EXPORT, TEST_RUN, EXIT_TO_PROJECT}
enum EditOption {ADD_UPGRADE_PICKUP}

@onready var level_edit : LevelEdit = get_node("/root/LevelEdit")

func _on_file_id_pressed(id: int) -> void:
	match id:
		FileOption.SAVE:
			level_edit.export()
			
		FileOption.EXPORT:
			level_edit.export()
			Global.export_sbsq()
			
		FileOption.TEST_RUN:
			level_edit.export()
			var temp_path := OS.get_cache_dir() + "/test_run.sbsq"
			Global.export_sbsq_to(temp_path)
			
			OS.create_process(Global.config.sidequest_path, [
				"loadModLevel",
				temp_path,
				"path",
				Global.subproject_path.split("/")[-1]
			])
			
		FileOption.EXIT_TO_PROJECT:
			get_tree().change_scene_to_file("res://scenes/project/project_menu.tscn")

func _on_edit_id_pressed(id: int) -> void:
	match id:
		EditOption.ADD_UPGRADE_PICKUP:
			%Rooms.get_child(%Viewport.current_room).add_object(UpgradePickup.new())
