@tool
extends TileMapLayer
class_name RoomEdit

@export var target_width := 480
@export var target_height := 270

const LEDGE_COORDS : Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(8, 0), Vector2i(11, 0),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(3, 3),
	
	Vector2i(7, 4), Vector2i(8, 4),
	Vector2i(7, 5), Vector2i(8, 5),
	Vector2i(7, 6), Vector2i(8, 6)
]

const CHUNK_SIZE := Vector2i(512, 512)

var sources := []
var should_redraw := false

@export_tool_button("export to json") var export_v := export
func export(project_path : String) -> void:
	
	DirAccess.make_dir_recursive_absolute(project_path + "rooms")
	
	var pdir := DirAccess.open(project_path + "rooms")
	
	for path : String in pdir.get_files():
		pdir.remove(path)
	
	await get_tree().process_frame
	
	var used_rect := get_used_rect()
	var room_rect := get_room_rect()
	
	var rd := {
		"target_width" : target_width,
		"target_height" : target_height,
		"position_x" : room_rect.position.x,
		"position_y" : room_rect.position.y,
		"width" : room_rect.size.x,
		"height" : room_rect.size.y,
		"tiles" : [],
		"chunks" : [],
		"collisions" : [],
		"ledges" : []
	}
	
	var occupied : Dictionary[Vector2i, bool] = {}
	
	var chunks : Array[Rect2] = []
	
	var size : Vector2i = room_rect.size
	
	while size.x > 0:
		size.x -= CHUNK_SIZE.x
		@warning_ignore("narrowing_conversion")
		size.y = room_rect.size.y
		
		while size.y > 0:
			size.y -= CHUNK_SIZE.y
			
			var chunk_pos := size.max(Vector2i.ZERO)
			
			chunks.append(Rect2(chunk_pos, size - chunk_pos + CHUNK_SIZE))
			rd.chunks.append({
				"x": chunk_pos.x,
				"y": chunk_pos.y,
				"width": size.x - chunk_pos.x + CHUNK_SIZE.x,
				"height": size.y - chunk_pos.y + CHUNK_SIZE.y,
				"tiles": []
			})
	
	var y := used_rect.position.y + used_rect.size.y - 1
	while y >= used_rect.position.y:
		
		var x := used_rect.position.x + used_rect.size.x - 1
		while x >= used_rect.position.x:
			var coords := Vector2i(x, y)
			var atlas_coords := get_cell_atlas_coords(coords)
			
			if atlas_coords != Vector2i(-1, -1):
				
				# figuring out what chunk this tile is in
				for i : int in chunks.size():
					if chunks[i].has_point(Vector2(x, y)):
						
						rd.chunks[i].tiles.append({
							"x": x - used_rect.position.x,
							"y": y - used_rect.position.y,
							"atlas_x": atlas_coords.x,
							"atlas_y": atlas_coords.y,
							"source_id": get_cell_source_id(coords)
						})
				
				occupied[coords * 8] = true
			
			if atlas_coords in LEDGE_COORDS:
				rd.ledges.append({
					"x": x * 8 + global_position.x,
					"y": y * 8 + global_position.y
				})
			
			#var data := get_cell_tile_data(coords)
			
			
			x -= 1
		
		y -= 1
	
	rd.collisions = optimize_collisions(occupied)
	
	var json := JSON.stringify(rd)
	var f := FileAccess.open("%s/rooms/%s.json" % [project_path, get_index()], FileAccess.WRITE)
	
	f.store_string(json)
	f.close()

func optimize_collisions(occupied: Dictionary) -> Array:
	
	var result := []
	
	while occupied.size() > 0:
		# pick topleft square
		var start : Vector2i = occupied.keys()[0]
		for p in occupied.keys():
			if p.y < start.y or (p.y == start.y and p.x < start.x):
				start = p
		
		# expand right
		var width := 8
		while occupied.has(start + Vector2i(width, 0)):
			width += 8
		
		# expand down
		var height := 8
		var can_expand := true
		while can_expand:
			for x in range(0, width, 8):
				if not occupied.has(start + Vector2i(x, height)):
					can_expand = false
					break
			if can_expand:
				height += 8
		
		# erase combined squares
		for y in range(0, height, 8):
			for x in range(0, width, 8):
				occupied.erase(start + Vector2i(x, y))
		
		result.append({
			"x": start.x + position.x,
			"y": start.y + position.y,
			"width": width,
			"height": height
		})
	
	return result

func get_room_rect() -> Rect2:
	var used_rect := get_used_rect()
	var room_rect := Rect2(
		global_position.x + used_rect.position.x * 8,
		global_position.y + used_rect.position.y * 8,
		used_rect.size.x * 8,
		used_rect.size.y * 8
	)
	
	room_rect.size = room_rect.size.max(Vector2(target_width, target_height))
	
	return room_rect

func _on_changed() -> void:
	should_redraw = true

func _process(_d) -> void:
	if should_redraw:
		should_redraw = false
		queue_redraw()

func _draw() -> void:
	var room := get_room_rect()
	room.position = to_local(room.position)
	
	var view := Rect2(
		room.position.x + (room.size.x - target_width) / 2,
		room.position.y + (room.size.y - target_height) / 2,
		target_width,
		target_height
	)
	
	draw_rect(view, Color.YELLOW, false, 3)
	draw_rect(room, Color.BLUE, false, 3)
