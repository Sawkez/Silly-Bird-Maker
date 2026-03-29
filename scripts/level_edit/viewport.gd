extends Control

signal room_selected(room : int)

const ZOOM_SPEED : float = 0.25

@onready var level_edit : LevelEdit = get_node("/root/LevelEdit")
var current_room : int = 0:
	set(v):
		current_room = v
		room_selected.emit(v)
var current_source : TileSetButton = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("pan"):
		
		%Camera2D.position -= event.screen_relative / %Camera2D.zoom
	
	elif not event.is_pressed(): return
	
	elif event.is_action("zoom_in"):
		zoom(true)
	
	elif event.is_action("zoom_out"):
		zoom(false)
	
	elif event.is_action("drag"): pass
	
	elif event.is_action("select_room"):
		
		for i : int in %Rooms.get_child_count():
			var room : RoomEdit = %Rooms.get_child(i)
			
			if room.get_room_rect().has_point(%Camera2D.get_global_mouse_position()):
				current_room = i
				return
		
		if not event.double_click: return
		
		current_room = %Rooms.get_child_count()
		
		%Rooms.add_child(
			RoomEdit.make_empty(
				level_edit.tile_set, 
				Global.project_path + "/rooms/%s" % %Rooms.get_child_count(), 
				%Camera2D.get_global_mouse_position()
			)
		)
	
	elif event.is_action("paint"):
		current_source.paint.call(%Rooms.get_child(current_room), %Camera2D.get_global_mouse_position())
		#%Rooms.get_child(current_room).place_tile(%Camera2D.get_global_mouse_position(), current_source)
	
	elif event.is_action("erase"):
		current_source.erase.call(%Rooms.get_child(current_room), %Camera2D.get_global_mouse_position())
		#%Rooms.get_child(current_room).erase_tile(%Camera2D.get_global_mouse_position())

func _input(event: InputEvent) -> void:
	if event.is_action("delete") and not event.echo and event.is_pressed():
		print("deleding ", current_room)
		%Rooms.get_child(current_room).free()
		current_room = min(current_room, %Rooms.get_child_count() - 1)

func zoom(zoom_in : bool) -> void:
	var speed : float = ZOOM_SPEED
	if not zoom_in: speed = -speed
	
	var old_pos : Vector2 = %Camera2D.get_global_mouse_position()
	
	%Camera2D.zoom *= 1.0 + speed
	
	%Camera2D.global_position += old_pos - %Camera2D.get_global_mouse_position()

func set_source(button : TileSetButton) -> void:
	current_source = button
