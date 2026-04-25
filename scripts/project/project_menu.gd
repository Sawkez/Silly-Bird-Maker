extends HBoxContainer

const LEVEL_BUTTON_SCENE := preload("res://scenes/project/level_button.tscn")

func _ready() -> void:
	var text := FileAccess.get_file_as_string(Global.project_path + "/mod.json")
	var json : Dictionary = JSON.parse_string(text)
	
	%Name.text = json.name
	
	for path : String in DirAccess.get_directories_at(Global.project_path + "/levels"):
		var level_name := path
		
		for level_json : Dictionary in json.levels:
			if level_json.path == path:
				level_name = level_json.name
				break
		
		var new_button : HBoxContainer = LEVEL_BUTTON_SCENE.instantiate()
		new_button.get_child(0).text = level_name
		%LevelList.add_child(new_button)
		new_button.get_child(1).pressed.connect(load_level.bind(path))
		new_button.path = path

func load_level(path : String) -> void:
	Global.project_path += "/levels/" + path
	get_tree().change_scene_to_file("res://scenes/level_edit.tscn")


func _on_save_pressed() -> void:
	var properties := {
		"name" : %Name.text,
		"tilesheet_sources" : DirAccess.get_files_at(Global.project_path + "/tiles/fg"),
		"levels" : []
	}
	
	for button : HBoxContainer in %LevelList.get_children():
		properties.levels.append({
			"path" : button.path,
			"name" : button.get_child(0).text
		})
	
	var json := JSON.stringify(properties)
	var file := FileAccess.open(Global.project_path + "/mod.json", FileAccess.WRITE)
	file.store_string(json)
	file.close()
