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

func _init(tileset : TileSet, room_path : String, assume_empty : bool = false) -> void:
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
	tile_set = tileset
	
	if not FileAccess.file_exists(room_path) or assume_empty:
		# queue_free()
		spikemap = SpikeMap.new()
		add_child(spikemap)
		
		checkpoints.add_child(CHECKPOINT_SCENE.instantiate())
		return
	
	var binary := BinaryReader.new(room_path)
	binary.ensure_section("PROP")
	
	position.x = binary.file.get_64()
	position.y = binary.file.get_64()
	binary.file.get_16() # width
	binary.file.get_16() # height
	target_width = binary.file.get_16()
	target_height = binary.file.get_16()
	
	properties.get_node("ViewWidth").value = target_width
	properties.get_node("ViewHeight").value = target_height
	
	var chunk_count := binary.file.get_8()
	var spike_collider_count := binary.file.get_32()
	var checkpoint_count := binary.file.get_8()
	binary.file.get_8() # neighbor count
	binary.file.get_32() # ledge count
	var object_count := binary.file.get_16()
	
	for chunk : int in chunk_count:
		binary.ensure_section("CHNK")
		
		binary.file.get_16() # x
		binary.file.get_16() # y
		binary.file.get_16() # w
		binary.file.get_16() # h
		
		var tile_count := binary.file.get_32()
		binary.file.get_32() # spike count
		
		binary.ensure_section("TLFG")
		for tile : int in tile_count:
			var tile_pos : Vector2i
			tile_pos.x = binary.file.get_16()
			tile_pos.y = binary.file.get_16()
			
			var atlas_pos : Vector2i
			atlas_pos.x = binary.file.get_16()
			atlas_pos.y = binary.file.get_16()
			
			var source_id : int = binary.file.get_8()
			
			set_cell(tile_pos, source_id, atlas_pos)
	
	binary.ensure_section("SKCL")
	spikemap = SpikeMap.new(binary, position, spike_collider_count)
	add_child(spikemap)
	
	binary.ensure_section("CKPT")
	for checkpoint : int in checkpoint_count:
		
		var new_checkpoint := CHECKPOINT_SCENE.instantiate()
		new_checkpoint.set_deferred("global_position:x", binary.file.get_float())
		new_checkpoint.set_deferred("global_position:y", binary.file.get_float())
		checkpoints.add_child(new_checkpoint)
	
	for object : int in object_count:
		binary.find_section("OBJT")
		add_object(RoomObject.make_room_object(binary))

func _ready() -> void:
	tiles_changed()

static func make_empty(tileset : TileSet, roomDirPath : String, pos : Vector2) -> RoomEdit:
	var room := RoomEdit.new(tileset, roomDirPath, true)
	room.position = pos
	return room

# @export_tool_button("export to json") var export_v := export
func export(project_path : String) -> void:
	
	await get_tree().process_frame
	var room_rect := get_room_rect()
	
	var meta := BinarySection.new("PROP")
	meta.push_s64(int(room_rect.position.x))
	meta.push_s64(int(room_rect.position.y))
	meta.push_u16(int(room_rect.size.x))
	meta.push_u16(int(room_rect.size.y))
	meta.push_u16(target_width)
	meta.push_u16(target_height)
	
	@warning_ignore("integer_division")
	var chunk_count : Vector2i = ceil(room_rect.size / Vector2(CHUNK_SIZE))
	
	var chunk_data : Dictionary[Vector2i, Dictionary] = {}
	
	for chunk_x : int in chunk_count.x:
		for chunk_y : int in chunk_count.y:
			chunk_data[Vector2i(chunk_x, chunk_y)] = get_chunk_data(room_rect, Vector2i(chunk_x, chunk_y))
	
	var chunk_sorter := func(a : Vector2i, b : Vector2i) -> bool:
		if a.x > b.x: return true
		if a.x == b.x and a.y > b.y: return true
		return false
	
	var chunk_keys := chunk_data.keys()
	chunk_keys.sort_custom(chunk_sorter)
	
	meta.push_u8(chunk_count.x * chunk_count.y)
	
	var colliders_section := BinarySection.new("TLCL")
	var tile_count : Vector2i = room_rect.size / 8
	var colliders_byte_length := ceili(tile_count.x * tile_count.y / 8.0)
	colliders_section.resize(colliders_byte_length)
	colliders_section.data.fill(0)
	for tile : Vector2i in get_used_cells():
		var bit_index := tile_count.x * tile.y + tile.x
		
		@warning_ignore("integer_division")
		var byte_index := bit_index / 8
		var bit_local_index := bit_index - byte_index * 8
		
		colliders_section.data[byte_index] |= (1 << bit_local_index)
	
	var spike_collider_data := spikemap.get_colliders_section(room_rect.position)
	meta.push_u32(spike_collider_data.count)
	
	var checkpoints_section := BinarySection.new("CKPT")
	for cp : Node2D in checkpoints.get_children():
		checkpoints_section.push_float(cp.global_position.x)
		checkpoints_section.push_float(cp.global_position.y)
	
	meta.push_u8(checkpoints.get_child_count())
	
	var neighbors := BinarySection.new("NGBR")
	var neighbor_count : int = 0
	for room : RoomEdit in get_parent().get_children():
		if room == self: continue
		
		var neighbor_rect := room.get_room_rect()
		if not room_rect.intersects(neighbor_rect, true): continue
		
		neighbors.push_s64(int(neighbor_rect.position.x))
		neighbors.push_s64(int(neighbor_rect.position.y))
		neighbors.push_u16(int(neighbor_rect.size.x))
		neighbors.push_u16(int(neighbor_rect.size.y))
		
		neighbors.push_u32(room.get_index())
		
		neighbor_count += 1
	
	meta.push_u8(neighbor_count)
	
	var ledges := BinarySection.new("LEGE")
	var ledge_count : int = 0
	for tile : Vector2i in get_used_cells():
		if get_cell_atlas_coords(tile) in LEDGE_COORDS:
			ledges.push_s64(tile.x * 8 + int(global_position.x))
			ledges.push_s64(tile.y * 8 + int(global_position.y))
			ledge_count += 1
	
	meta.push_u32(ledge_count);
	
	var object_data : Array[BinarySection] = []
	for object : RoomObject in room_objects.get_children():
		object_data.append(object.export())
	
	meta.push_u16(object_data.size())
	
	var file := FileAccess.open(project_path + "/rooms/%s.room" % get_index(), FileAccess.WRITE)
	
	meta.write(file)
	for key : Vector2i in chunk_keys:
		chunk_data[key].chunk.write(file)
		chunk_data[key].fg_tile.write(file)
		chunk_data[key].spike.write(file)
	
	colliders_section.write(file)
	spike_collider_data.section.write(file)
	checkpoints_section.write(file)
	neighbors.write(file)
	ledges.write(file)
	
	for object : BinarySection in object_data:
		object.write(file)
	
	file.close()

func get_chunk_data(room_rect : Rect2, chunk : Vector2i) -> Dictionary[String, BinarySection]:
	var data := {
		"chunk" : BinarySection.new("CHNK"),
		"fg_tile" : BinarySection.new("TLFG")
	}
	
	var chunk_position : Vector2i = chunk * CHUNK_SIZE
	var chunk_size : Vector2i
	chunk_size.x = mini(CHUNK_SIZE.x, int(room_rect.size.x) - chunk_position.x) + 8
	chunk_size.y = mini(CHUNK_SIZE.y, int(room_rect.size.y) - chunk_position.y) + 8
	
	data.chunk.push_u16(chunk_position.x)
	data.chunk.push_u16(chunk_position.y)
	data.chunk.push_u16(chunk_size.x)
	data.chunk.push_u16(chunk_size.y)
	
	@warning_ignore("integer_division")
	var chunk_first_tile : Vector2i = chunk * CHUNK_SIZE / 8 + chunk_size / 8
	@warning_ignore("integer_division")
	var chunk_last_tile : Vector2i = chunk * CHUNK_SIZE / 8
	
	var tile_count : int = 0
	
	for x : int in range(chunk_first_tile.x - 1, chunk_last_tile.x - 1, -1):
		for y : int in range(chunk_first_tile.y - 1, chunk_last_tile.y - 1, -1):
			
			var cell := Vector2i(x, y)
			
			var atlas := get_cell_atlas_coords(cell)
			if atlas == Vector2i(-1, -1): continue
			
			var source := get_cell_source_id(cell)
			if source == -1: continue
			
			tile_count += 1
			
			data.fg_tile.push_u16(x)
			data.fg_tile.push_u16(y)
			data.fg_tile.push_u16(atlas.x)
			data.fg_tile.push_u16(atlas.y)
			data.fg_tile.push_u8(source)
	
	data.chunk.push_u32(tile_count)
	
	var spike_data := spikemap.get_tile_section(chunk)
	data.spike = spike_data.section
	
	data.chunk.push_u32(spike_data.count)
	
	return data

func optimize_collisions(tiles : Array[Vector2i]) -> Array[Rect2]:
	
	var tile_sorter := func(a : Vector2i, b : Vector2i) -> bool:
		if a.x < b.x: return true
		if a.x == b.x and a.y < b.y: return true
		return false
	
	tiles.sort_custom(tile_sorter)
	
	var result : Array[Rect2] = []
	
	while not tiles.is_empty():
		var rect := Rect2i(tiles[0], Vector2i(0, 0))
		while rect.end in tiles:
			tiles.erase(rect.end)
			rect.end.x += 1
		
		rect.end.y += 1
		
		var extend : bool = true
		while extend:
			for x : int in range(rect.position.x, rect.end.x):
				var check := Vector2i(x, rect.end.y)
				if check not in tiles:
					extend = false
					break
			
			if not extend: break
			
			for x : int in range(rect.position.x, rect.end.x):
				tiles.erase(Vector2i(x, rect.end.y))
			
			rect.end.y += 1
		
		result.append(rect)
	
	return result

func grow_collider(collider : Rect2, room_rect : Rect2) -> Rect2:
	collider.position *= 8
	collider.position += global_position
	collider.size *= 8
	
	if collider.position.x == room_rect.position.x:
		collider.position.x -= 8
		collider.size.x += 8
	
	if collider.end.x == room_rect.end.x:
		collider.size.x += 8
	
	if collider.position.y == room_rect.position.y:
		collider.position.y -= 8
		collider.size.y += 8
	
	if collider.end.y == room_rect.end.y:
		collider.size.y += 8
	
	return collider

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
