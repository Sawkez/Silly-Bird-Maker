extends HBoxContainer

const LEVEL_BUTTON_SCENE := preload("res://scenes/project/level_button.tscn")

const FULL_SHEET_SIZE := Vector2(168, 126)
const SHORT_SHEET_SIZE := Vector2(168, 56)

const TEMPLATE_FULL : int = 128
const TEMPLATE_SHORT : int = 129

const VALID_TERRAIN_PEERING_BITS : PackedInt32Array = [0, 3, 4, 7, 8, 11, 12, 15]

func _ready() -> void:
	var text := FileAccess.get_file_as_string(Global.project_path + "/mod.json")
	if text == "": return
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
	
	# loading tileset
	Global.tile_set = load("res://resources/tileset_templates.tres").duplicate()
	Global.tile_names = []
	
	var sheets_path := Global.project_path + "/tiles/fg/"
	if DirAccess.dir_exists_absolute(sheets_path):
		for sheet : String in DirAccess.get_files_at(sheets_path):
			if not sheet.ends_with(".png"): continue
			
			var sheet_img := Image.load_from_file(sheets_path + sheet)
			var sheet_tex := ImageTexture.create_from_image(sheet_img)
			var sheet_size := sheet_tex.get_size()
			
			var template := 0
			if sheet_size == FULL_SHEET_SIZE: template = TEMPLATE_FULL
			elif sheet_size == SHORT_SHEET_SIZE: template = TEMPLATE_SHORT
			else: return
			
			var template_source : TileSetAtlasSource = Global.tile_set.get_source(template)
			var source := template_source.duplicate()
			source.texture = sheet_tex
			
			Global.tile_set.add_source(source, Global.tile_names.size())
			
			var terrain_id := Global.tile_set.get_terrains_count(0)
			Global.tile_set.add_terrain(0)
			
			# setting up terrain
			for x : int in int(sheet_size.x / 14):
				for y : int in int(sheet_size.y / 14):
					var coords := Vector2i(x, y)
					var data : TileData = source.get_tile_data(coords, 0)
					var template_data : TileData = template_source.get_tile_data(coords, 0)
					
					data.terrain = terrain_id
					
					for i : int in VALID_TERRAIN_PEERING_BITS:
						if template_data.get_terrain_peering_bit(i) == 0:
							data.set_terrain_peering_bit(i, terrain_id)
			
			Global.tile_names.append(sheet)
	
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
