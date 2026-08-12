extends Control

signal room_selected(room : int)

const ZOOM_SPEED : float = 0.25

@onready var level_edit : LevelEdit = get_node("/root/LevelEdit")
var current_room : int = -1:
	set(v):
		current_room = v
		room_selected.emit(v)
var current_source : TileSetButton = null

func _ready() -> void:
	current_room = -1

var last_paint_tile : Vector2i

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("pan"):
			%Camera2D.position -= event.screen_relative / %Camera2D.zoom
		
		elif Input.is_action_pressed("drag"): pass
		
		elif current_room < 0: pass
		elif current_room >= %Rooms.get_child_count(): pass
		elif current_source == null: pass
		
		elif Input.is_action_pressed("paint"):
			stroke(event, current_source.paint)
		elif Input.is_action_pressed("erase"):
			stroke(event, current_source.erase)
	
	elif not event.is_pressed(): return
	
	elif event.is_action("zoom_in"):
		zoom(true)
	
	elif event.is_action("zoom_out"):
		zoom(false)
	
	elif event.is_action("select_room"):
		
		for i : int in %Rooms.get_child_count():
			var room : RoomEdit = %Rooms.get_child(i)
			
			if room.get_room_rect().has_point(%Camera2D.get_global_mouse_position()):
				current_room = i
				return
		
		if not event.double_click: return
		
		current_room = %Rooms.get_child_count()
		
		var new_room := RoomEdit.make_empty(
			Global.tile_set, 
			Global.subproject_path + "/rooms/%s" % %Rooms.get_child_count(), 
			LevelEdit.snap_to_grid(%Camera2D.get_global_mouse_position())
		)
		
		%Rooms.add_child(new_room)
		room_selected.connect(new_room.room_selected)
	
	elif event.is_action("drag"): pass
	
	elif current_room < 0: pass
	elif current_room >= %Rooms.get_child_count(): pass
	elif current_source == null: pass
	
	elif event.is_action("paint"):
		current_source.paint.call(%Rooms.get_child(current_room), %Camera2D.get_global_mouse_position())
		#%Rooms.get_child(current_room).place_tile(%Camera2D.get_global_mouse_position(), current_source)
	
	elif event.is_action("erase"):
		current_source.erase.call(%Rooms.get_child(current_room), %Camera2D.get_global_mouse_position())
		#%Rooms.get_child(current_room).erase_tile(%Camera2D.get_global_mouse_position())

func stroke(event: InputEventMouseMotion, action: Callable) -> void:
	var room := %Rooms.get_child(current_room)
	var current_pos: Vector2 = %Camera2D.get_global_mouse_position()
	# world-space delta this frame (screen_relative is in screen px, so divide by zoom)
	var world_delta: Vector2 = event.screen_relative / %Camera2D.zoom
	var start_pos: Vector2 = current_pos - world_delta

	# how many steps to take so we don't skip a tile: step every ~half tile
	var dist := world_delta.length()
	var steps := maxi(1, ceili(dist / (Global.TILE_SIZE * 0.5)))

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pos := start_pos.lerp(current_pos, t)
		var tile := Vector2i(floori(pos.x / Global.TILE_SIZE), floori(pos.y / Global.TILE_SIZE))

		if tile != last_paint_tile:
			action.call(room, pos)
			last_paint_tile = tile

func _input(event: InputEvent) -> void:
	if event.is_action("delete") and not event.echo and event.is_pressed():
		if level_edit.last_dragged_node == null: return
		if not level_edit.last_dragged_node.is_inside_tree(): return
		level_edit.last_dragged_node.delete_parent()

func zoom(zoom_in : bool) -> void:
	var speed : float = ZOOM_SPEED
	if not zoom_in: speed = -speed
	
	var old_pos : Vector2 = %Camera2D.get_global_mouse_position()
	
	%Camera2D.zoom *= 1.0 + speed
	
	%Camera2D.global_position += old_pos - %Camera2D.get_global_mouse_position()

func set_source(button : TileSetButton) -> void:
	current_source = button
