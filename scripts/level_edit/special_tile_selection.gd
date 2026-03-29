extends VBoxContainer

func _ready() -> void:
	#await get_tree().process_frame
	
	for child : TileSetButton in get_children():
		child.pressed.connect(%Viewport.set_source.bind(child))
