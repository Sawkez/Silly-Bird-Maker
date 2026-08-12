extends Node2D
class_name LevelEdit

const TILE_SET_BUTTON_SCENE := preload("res://scenes/level_edit/tile_set.tscn")

const DEFAULT_TILESHEETS := "res://graphics/tiles/fg/"
const PROJECT_TILESHEETS := "tiles/fg/"
const PROPERTIES_FILENAME := "level.json"

var last_dragged_node : Drag = null
var dragged_node : Drag = null:
	set(v):
		dragged_node = v
		if v == null: return
		last_dragged_node = v

@onready var viewport : Control = %Viewport

func _ready() -> void:
	Global.level_edit = self
	
	for i : int in Global.tile_set.get_source_count():
		var source_id := Global.tile_set.get_source_id(i)
		var source : TileSetAtlasSource = Global.tile_set.get_source(source_id)
		
		var terrain := source.get_tile_data(Vector2i(0,0), 0).terrain
		add_tile_button(source.texture, "tile", terrain)
	
	var level_properties_path := Global.subproject_path + "/" + PROPERTIES_FILENAME
	
	if not FileAccess.file_exists(level_properties_path): return
	
	var properties_json = JSON.new()
	properties_json.parse(FileAccess.get_file_as_string(level_properties_path))
	var properties : Dictionary = properties_json.data
	
	$PlayerSpawn.global_position.x = properties.player_x
	$PlayerSpawn.global_position.y = properties.player_y
	
	for i : int in properties.room_count:
		var new_room := RoomEdit.new(Global.tile_set, Global.subproject_path + "/rooms/%s.room" % i)
		$Rooms.add_child(new_room)
		%Viewport.room_selected.connect(new_room.room_selected)
	
	%Viewport.room_selected.emit(0)

func add_tile_button(texture : Texture2D, tile_name : String, id : int) -> void:
	var new_tile_set_button : Button = TILE_SET_BUTTON_SCENE.instantiate()
	new_tile_set_button.icon = new_tile_set_button.icon.duplicate()
	new_tile_set_button.icon.atlas = texture
	new_tile_set_button.text = tile_name
	new_tile_set_button.source = id
	new_tile_set_button.pressed.connect(%Viewport.set_source.bind(new_tile_set_button))
	
	%FGTileSelection.add_child(new_tile_set_button)

# @export_tool_button("Export level") var dbg_export : Callable = export
func export() -> void:
	
	DirAccess.make_dir_recursive_absolute(Global.subproject_path + "/rooms")
	
	var starting_room := 0
	
	for i : int in $Rooms.get_child_count():
		var room := $Rooms.get_child(i)
		if room.get_room_rect().has_point($PlayerSpawn.position): starting_room = i
	
	var properties := {
		"tilesheet_sources" : Global.tile_names,
		"room_count" : $Rooms.get_child_count(),
		"starting_room" : starting_room,
		"player_x" : $PlayerSpawn.position.x,
		"player_y" : $PlayerSpawn.position.y
	}
	
	var f := FileAccess.open(Global.subproject_path + "/" + PROPERTIES_FILENAME, FileAccess.WRITE)
	
	f.store_string(JSON.stringify(properties))
	
	f.close()
	
	for child : RoomEdit in $Rooms.get_children():
		child.export(Global.subproject_path)

static func snap_to_grid(pos : Vector2) -> Vector2:
	for i : int in 2:
		pos[i] = roundf(pos[i] / 8.0) * 8.0
	return pos
