@tool
extends Node

@export var directory : String
@export var file_name : String
@export var bake_resolution : int
@export var curve : Curve

@export_tool_button("Export") var e := func() -> void:
	ResourceSaver.save(curve, "res://baked_curves/" + file_name + ".tres")
	
	DirAccess.make_dir_recursive_absolute(directory)
	var f := FileAccess.open(directory + "/" + file_name + ".curve", FileAccess.WRITE)
	
	var x := 0.0
	
	f.store_16(bake_resolution)
	
	while x <= 1.0:
		var val : float = curve.sample(x)
		f.store_float(val)
		x += 1.0 / float(bake_resolution)
		print(val)
