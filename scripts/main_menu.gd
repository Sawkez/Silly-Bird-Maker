extends Control

func _on_project_directory_selection_dir_selected(dir: String) -> void:
	Global.project_path = dir
	get_tree().change_scene_to_file("res://scenes/level_edit.tscn")
