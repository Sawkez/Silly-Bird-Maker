@tool
extends Node2D

const ANIMS : PackedStringArray = ["duck", "fly", "idle", "jump", "ledge_flip", "ledge_unflip", "run", "run_slow", "slide", "twerk_down", "twerk_up"]

@export var mod_path : String
@export var allow_twerk := true
@export var colors := PackedColorArray()
@export var footsteps_run := PackedInt32Array()
@export var footsteps_slow_run := PackedInt32Array()
@export var animation_settings : Array[AnimationInfo]
@export var scarf_pixels : Array[PackedVector2Array]

@export_tool_button("Import scarf position data") var q := func ___() -> void:
	var f := ConfigFile.new()
	f.load("res://scarf_positions.ini")
	
	for i : int in ANIMS.size():
		for j : int in animation_settings[i].frame_count:
			print("%02d" % j)
			scarf_pixels[i].append(f.get_value(ANIMS[i] + ".png", "%02d" % j, Vector2(-1, -1)))

@export_tool_button("Export") var p := func ___() -> void:
	var json : Dictionary = {
		"allow_twerk": allow_twerk,
		"colors": [],
		"footsteps_run": footsteps_run,
		"footsteps_slow_run": footsteps_slow_run,
		"animations": [],
		"scarf_positions": []
	}
	
	for c : Color in colors:
		json.colors.append([c.r8, c.g8, c.b8])
	
	for a : AnimationInfo in animation_settings:
		json.animations.append(a.get_dict())
	
	for a : PackedVector2Array in scarf_pixels:
		var arr : Array[Array]
		for f : Vector2 in a:
			arr.append([f.x, f.y])
		
		json.scarf_positions.append(arr)
	
	var f := FileAccess.open(mod_path + "/skin.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(json))
	f.close()
