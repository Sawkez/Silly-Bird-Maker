extends Control

func _on_project_directory_selection_dir_selected(path: String) -> void:
	
	var is_empty := DirAccess.get_files_at(path).is_empty() and DirAccess.get_directories_at(path).is_empty()
	var is_project := FileAccess.file_exists(path + "/mod.json")
	
	if is_project and not is_empty:
		Global.project_path = path
		get_tree().change_scene_to_file("res://scenes/project/project_menu.tscn")
	
	else:
		%AcceptDialog.show()

func _on_sidequest_selection_file_selected(path: String) -> void:
	Global.config.sidequest_path = path
	Global.save_config()
