extends Node2D
class_name LevelEdit

const TILE_SET_BUTTON_SCENE := preload("res://scenes/level_edit/tile_set.tscn")

const VALID_TERRAIN_PEERING_BITS : PackedInt32Array = [0, 3, 4, 7, 8, 11, 12, 15]

const DEFAULT_TILESHEETS := "res://graphics/tiles/fg/"
const PROJECT_TILESHEETS := "tiles/fg/"
const PROPERTIES_FILENAME := "level.json"

const FULL_SHEET_SIZE := Vector2(168, 126)
const SHORT_SHEET_SIZE := Vector2(168, 56)

const TEMPLATE_FULL : int = 0
const TEMPLATE_SHORT : int = 1

var sources : Array[Dictionary]
var tile_set : TileSet

var dragged_node : Drag = null

func _ready() -> void:
	Global.level_edit = self
	
	import_tilesheets()
	
	var level_properties_path := Global.project_path + "/" + PROPERTIES_FILENAME
	
	if not FileAccess.file_exists(level_properties_path): return
	
	var properties_json = JSON.new()
	properties_json.parse(FileAccess.get_file_as_string(level_properties_path))
	var properties : Dictionary = properties_json.data
	
	$PlayerSpawn.global_position.x = properties.player_x
	$PlayerSpawn.global_position.y = properties.player_y
	
	for i : int in properties.room_count:
		var new_room := RoomEdit.new(tile_set, Global.project_path + "/rooms/%s" % i)
		$Rooms.add_child(new_room)
		%Viewport.room_selected.connect(new_room.room_selected)
	
	%Viewport.room_selected.emit(0)

# @export_tool_button("Import tilesheets") var dbg_import_tilesheets : Callable = import_tilesheets
func import_tilesheets() -> void:
	
	tile_set = load("res://resources/tileset_templates.tres").duplicate()
	
	sources = [
		{
			"custom" : false,
			"name" : "template_full.png"
		},
		
		{
			"custom" : false,
			"name" : "template_short.png"
		}
	]
	
	var id := sources.size()
	for path : String in ["grass.png"]:
		if not path.ends_with(".png"): continue
		
		var tex : Texture2D = load(DEFAULT_TILESHEETS + path)
		
		add_source(tex, id)
		sources.append({
			"custom" : false,
			"name" : path,
		})
		
		add_tile_button(tex, path, id)
		
		id += 1
	
	if not DirAccess.dir_exists_absolute(Global.project_path + "/" + PROJECT_TILESHEETS): return
	
	for path : String in DirAccess.get_files_at(Global.project_path + "/" + PROJECT_TILESHEETS):
		if not path.ends_with(".png"): continue
		
		var sheet_img := Image.load_from_file(Global.project_path + "/" + PROJECT_TILESHEETS + path)
		var sheet := ImageTexture.create_from_image(sheet_img)
		
		add_source(sheet, id)
		
		sources.append({
			"custom" : true,
			"name" : path,
		})
		
		add_tile_button(sheet, path, id)
		
		id += 1

func add_source(sheet : Texture2D, id : int) -> void:
	print(id)
	var template := 0
	if sheet.get_size() == FULL_SHEET_SIZE: template = TEMPLATE_FULL
	elif sheet.get_size() == SHORT_SHEET_SIZE: template = TEMPLATE_SHORT
	else:
		print("Wrong tilesheet size. Please use %s for full or %s for short." % [FULL_SHEET_SIZE, SHORT_SHEET_SIZE])
		return
	
	var template_source : TileSetAtlasSource = tile_set.get_source(template)
	
	var source := template_source.duplicate(true)
	source.texture = sheet
	
	tile_set.add_source(source, id)
	
	var terrain_id := tile_set.get_terrains_count(0)
	print(terrain_id, sheet)
	
	tile_set.add_terrain(0, terrain_id)
	
	# setting up terrain
	for x : int in int(sheet.get_size().x / 14):
		for y : int in int(sheet.get_size().y / 14):
			var coords := Vector2i(x, y)
			var data : TileData = source.get_tile_data(coords, 0)
			var template_data : TileData = template_source.get_tile_data(coords, 0)
			# data = template_data
			
			data.terrain = terrain_id
			#continue
			
			for i : int in VALID_TERRAIN_PEERING_BITS:
				
				if template_data.get_terrain_peering_bit(i) == 0:
					data.set_terrain_peering_bit(i, terrain_id)
			
			#_tile_data_runtime_update(coords, data)

func add_tile_button(texture : Texture2D, path : String, id : int) -> void:
	var new_tile_set_button : Button = TILE_SET_BUTTON_SCENE.instantiate()
	new_tile_set_button.icon = new_tile_set_button.icon.duplicate()
	new_tile_set_button.icon.atlas = texture
	var path_split := path.split("/")
	new_tile_set_button.text = path_split[path_split.size() - 1]
	new_tile_set_button.source = id
	new_tile_set_button.pressed.connect(%Viewport.set_source.bind(new_tile_set_button))
	
	%FGTileSelection.add_child(new_tile_set_button)

# @export_tool_button("Export level") var dbg_export : Callable = export
func export() -> void:
	
	DirAccess.make_dir_recursive_absolute(Global.project_path)
	
	var starting_room := 0
	
	for i : int in $Rooms.get_child_count():
		var room := $Rooms.get_child(i)
		if room.get_room_rect().has_point($PlayerSpawn.position): starting_room = i
	
	var properties := {
		"tilesheet_sources" : sources,
		"room_count" : $Rooms.get_child_count(),
		"starting_room" : starting_room,
		"player_x" : $PlayerSpawn.position.x,
		"player_y" : $PlayerSpawn.position.y
	}
	
	var f := FileAccess.open(Global.project_path + "/" + PROPERTIES_FILENAME, FileAccess.WRITE)
	
	f.store_string(JSON.stringify(properties))
	
	f.close()
	
	for child : RoomEdit in $Rooms.get_children():
		child.export(Global.project_path)

static func snap_to_grid(pos : Vector2) -> Vector2:
	for i : int in 2:
		pos[i] = roundf(pos[i] / 8.0) * 8.0
	return pos
