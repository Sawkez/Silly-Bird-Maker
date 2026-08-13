extends Node

const TILE_SIZE := 8
const CONFIG_PATH := "user://config.tres"

var project_path := ""
var subproject_path := ""

var level_edit : LevelEdit
var tile_set : TileSet
var tile_names : PackedStringArray

var config := SBMConfig.new()

var export_file_picker_window := FileDialog.new()

func _ready() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		config = load(CONFIG_PATH)
	
	export_file_picker_window.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_file_picker_window.filters = ["*.sbsq"]
	export_file_picker_window.size = Vector2i(640, 640)
	export_file_picker_window.access = FileDialog.ACCESS_FILESYSTEM
	export_file_picker_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	export_file_picker_window.file_selected.connect(export_sbsq_to)
	
	add_child(export_file_picker_window)

func save_config() -> void:
	ResourceSaver.save(config, CONFIG_PATH)

func add_dir_to_zip(zip : ZIPPacker, root_path : String, dir_path : String) -> void:
	var dir := DirAccess.open(root_path + dir_path)
	dir.list_dir_begin()
	var entry := dir.get_next()
	
	while entry != "":
		var entry_path := dir_path + "/" + entry
		if dir.current_is_dir():
			add_dir_to_zip(zip, root_path, entry_path)
		
		else:
			zip.start_file(entry_path.trim_prefix("/"))
			var bytes := FileAccess.get_file_as_bytes(root_path + entry_path)
			zip.write_file(bytes)
			zip.close_file()
		
		entry = dir.get_next()

func export_sbsq_to(path : String) -> void:
	var zip := ZIPPacker.new()
	if zip.open(path, ZIPPacker.APPEND_CREATE) != OK: return
	zip.compression_level = ZIPPacker.COMPRESSION_NONE
	
	add_dir_to_zip(zip, Global.project_path, "")
	
	zip.close()

func export_sbsq() -> void:
	export_file_picker_window.show()
