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

const DRAG_SCENE := preload("res://scenes/level_edit/drag.tscn")
const PROPERTIES_SCENE := preload("res://scenes/level_edit/room_properties.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/level_edit/checkpoint.tscn")

const ROOM_JSON_FILENAME = "room.json"

const CHUNK_TEXTURE_SIZE := Vector2i(512, 512)
const CHUNK_SIZE := CHUNK_TEXTURE_SIZE - Vector2i(8, 8) # allow 1 tile for layering

var sources := []
var should_redraw := false

var drag : Drag
var spikemap : SpikeMap
var properties : Control
var checkpoints : Node2D
var room_objects : Node2D

var dbg_chunks : Array[Rect2] = []

func _init(tileset : TileSet, room_dir_path : String, assume_empty : bool = false) -> void:
	drag = DRAG_SCENE.instantiate()
	add_child(drag)
	
	properties = PROPERTIES_SCENE.instantiate()
	properties.get_node("ViewWidth").value_changed.connect(view_width_changed)
	properties.get_node("ViewHeight").value_changed.connect(view_height_changed)
	properties.get_node("CheckpointCount").value_changed.connect(checkpoint_count_changed)
	
	checkpoints = Node2D.new()
	add_child(checkpoints)
	
	room_objects = Node2D.new()
	add_child(room_objects)
	
	var json_path := room_dir_path + "/" + ROOM_JSON_FILENAME
	tile_set = tileset
	if not FileAccess.file_exists(json_path) or assume_empty:
		# queue_free()
		spikemap = SpikeMap.new()
		add_child(spikemap)
		
		checkpoints.add_child(CHECKPOINT_SCENE.instantiate())
		return
	
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(json_path))
	var room_properties : Dictionary = json.data
	
	position.x = room_properties.position_x
	position.y = room_properties.position_y
	target_width = room_properties.target_width
	target_height = room_properties.target_height
	
	properties.get_node("ViewWidth").value = room_properties.target_width
	properties.get_node("ViewHeight").value = room_properties.target_height
	
	for chunk : int in room_properties.chunks.size():
		var chunk_path = room_dir_path + "/%s.chunk" % chunk
		var tile_file := FileAccess.open(chunk_path, FileAccess.READ)
		
		for tile : int in room_properties.chunks[chunk].tile_count:
			var tile_pos : Vector2i
			@warning_ignore("integer_division")
			tile_pos.x = tile_file.get_16()
			@warning_ignore("integer_division")
			tile_pos.y = tile_file.get_16()
			
			var atlas_pos : Vector2i
			atlas_pos.x = tile_file.get_16()
			atlas_pos.y = tile_file.get_16()
			
			var source_id : int = tile_file.get_16()
			
			set_cell(tile_pos, source_id, atlas_pos)
		
		tile_file.close()
	
	if "checkpoints" in room_properties.keys():
		for checkpoint : Dictionary in room_properties.checkpoints:
			var new_checkpoint := CHECKPOINT_SCENE.instantiate()
			new_checkpoint.set_deferred("global_position", Vector2(checkpoint.x, checkpoint.y))
			checkpoints.add_child(new_checkpoint)
	
	if "room_objects" in room_properties.keys():
		for object : Dictionary in room_properties.room_objects:
			add_object(RoomObject.make_room_object(object))
	
	spikemap = SpikeMap.new("%s/spikes.ow" % room_dir_path, position, room_properties.get("spike_count", 0))
	add_child(spikemap)
	
	#notify_runtime_tile_data_update()

func _ready() -> void:
	tiles_changed()

static func make_empty(tileset : TileSet, roomDirPath : String, pos : Vector2) -> RoomEdit:
	var room := RoomEdit.new(tileset, roomDirPath, true)
	room.position = pos
	return room

# @export_tool_button("export to json") var export_v := export
func export(project_path : String) -> void:
	
	DirAccess.make_dir_recursive_absolute(project_path + "/rooms/%s" % get_index())
	
	var pdir := DirAccess.open(project_path + "/rooms/%s" % get_index())
	
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
		"chunks" : [],
		"collisions" : [],
		"ledges" : [],
		"neighbors" : [],
		"checkpoints": [],
		"room_objects": []
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
				"width": size.x - chunk_pos.x + CHUNK_TEXTURE_SIZE.x,
				"height": size.y - chunk_pos.y + CHUNK_TEXTURE_SIZE.y,
				"tile_count": 0
			})
	
	var chunk_files : Array[FileAccess] = []
	
	for i : int in chunks.size():
		chunk_files.append(FileAccess.open(project_path + "/rooms/%s/%s.chunk" % [get_index(), i], FileAccess.WRITE))
	
	var y := used_rect.position.y + used_rect.size.y - 1
	while y >= used_rect.position.y:
		
		var x := used_rect.position.x + used_rect.size.x - 1
		while x >= used_rect.position.x:
			var coords := Vector2i(x, y)
			var atlas_coords := get_cell_atlas_coords(coords)
			
			if atlas_coords != Vector2i(-1, -1):
				
				# figuring out what chunk this tile is in
				for i : int in chunks.size():
					if chunks[i].has_point(Vector2((x - used_rect.position.x) * 8, (y - used_rect.position.y) * 8)):
						
						chunk_files[i].store_16(x - used_rect.position.x)
						chunk_files[i].store_16(y - used_rect.position.y)
						chunk_files[i].store_16(atlas_coords.x)
						chunk_files[i].store_16(atlas_coords.y)
						chunk_files[i].store_8(get_cell_source_id(coords))
						
						print(i, " ", get_cell_source_id(coords))
						
						rd.chunks[i].tile_count += 1
						break
				
				occupied[coords * 8] = true
			
			if atlas_coords in LEDGE_COORDS:
				rd.ledges.append({
					"x": int(x * 8 + global_position.x),
					"y": int(y * 8 + global_position.y)
				})
			
			#var data := get_cell_tile_data(coords)
			
			
			x -= 1
		
		y -= 1
	
	rd.collisions = optimize_collisions(occupied)
	
	for room : RoomEdit in get_parent().get_children():
		if room == self: continue
		
		var neighbor_rect := room.get_room_rect()
		if room_rect.intersects(neighbor_rect, true):
			rd.neighbors.append({
				"x": neighbor_rect.position.x,
				"y": neighbor_rect.position.y,
				"width": neighbor_rect.size.x,
				"height": neighbor_rect.size.y,
				"index": room.get_index()
			})
	
	for file : FileAccess in chunk_files:
		file.close()
	
	var chunk_spike_counts := spikemap.export(chunks, project_path + "/rooms/%s" % get_index())
	
	for chunk : int in chunk_spike_counts.size():
		rd.chunks[chunk].spike_count = chunk_spike_counts[chunk]
	
	var spike_count := spikemap.export_colliders("%s/rooms/%s/spikes.ow" % [project_path, get_index()], position)
	rd.spike_count = spike_count
	
	for checkpoint : Node2D in checkpoints.get_children():
		rd.checkpoints.append({
			"x" : checkpoint.global_position.x,
			"y" : checkpoint.global_position.y
			})
	
	for object : RoomObject in room_objects.get_children():
		rd.room_objects.append(object.export())
	
	var json := JSON.stringify(rd)
	var f := FileAccess.open("%s/rooms/%s/room.json" % [project_path, get_index()], FileAccess.WRITE)
	
	f.store_string(json)
	f.close()
	
	dbg_chunks = chunks

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
		
		start += Vector2i(position)
		
		if is_equal_approx(start.x, get_room_rect().position.x):
			start.x -= 16
			width += 16
		
		if is_equal_approx(start.y, get_room_rect().position.y):
			start.y -= 16
			height += 16
		
		if is_equal_approx(start.x + width, get_room_rect().end.x):
			width += 16
		
		if is_equal_approx(start.y + height, get_room_rect().end.y):
			height += 16
		
		result.append({
			"x": start.x,
			"y": start.y,
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
	
	for chunk : Rect2 in dbg_chunks:
		draw_rect(chunk, Color.RED, false, 3)
	
	draw_rect(view, Color.YELLOW, false, 3)
	draw_rect(room, Color.BLUE, false, 3)

func place_tile(pos : Vector2, source : int) -> void:
	var map_pos : Vector2i = local_to_map(to_local(pos))
	
	set_cell(map_pos, source)
	set_cells_terrain_connect([map_pos], 0, source)
	
	tiles_changed()

func erase_tile(pos : Vector2) -> void:
	
	var map_pos : Vector2i = local_to_map(to_local(pos))
	
	set_cell(map_pos)
	set_cells_terrain_connect([map_pos], 0, -1)
	
	tiles_changed()

func tiles_changed() -> void:
	should_redraw = true
	var drag_rect := get_room_rect()
	drag_rect.position -= global_position
	drag.set_rect(drag_rect)

func room_selected(room : int) -> void:
	if get_index() == room:
		modulate.a = 1.0
	else:
		modulate.a = 0.25

func view_width_changed(value : int) -> void:
	target_width = value
	should_redraw = true

func view_height_changed(value : int) -> void:
	target_height = value
	should_redraw = true

func checkpoint_count_changed(value : int) -> void:
	var count := checkpoints.get_child_count()
	while count > value:
		count -= 1
		checkpoints.get_child(count).queue_free()
	
	while count < value:
		checkpoints.add_child(CHECKPOINT_SCENE.instantiate())
		count += 1
	

func add_object(object : RoomObject) -> void:
	room_objects.add_child(object)
