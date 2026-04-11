extends Node2D
class_name SpikeMap

const MAX_15B := 1 << 15
const MAX_16B := 1 << 16

var subcells : Dictionary[Rect2, int] = {
	Rect2(0, 0, 3, 3) : Spike.TOP_LEFT,
	Rect2(3, 0, 2, 3) : Spike.TOP,
	Rect2(5, 0, 3, 3) : Spike.TOP_RIGHT,
	Rect2(0, 3, 3, 2) : Spike.LEFT,
	Rect2(5, 3, 3, 2) : Spike.RIGHT,
	Rect2(0, 5, 3, 3) : Spike.BOTTOM_LEFT,
	Rect2(3, 5, 2, 3) : Spike.BOTTOM,
	Rect2(5, 5, 3, 3) : Spike.BOTTOM_RIGHT
}

var spikes : Dictionary[Vector2i, Spike]

func unsigned16_to_signed(unsigned : int) -> int:
	return (unsigned + MAX_15B) % MAX_16B - MAX_15B

func _init(file_path := "", room_pos := Vector2.ZERO, spike_count : int = 0) -> void:
	if file_path == "": return
	
	var f := FileAccess.open(file_path, FileAccess.READ)
	
	for i : int in spike_count:
		var x := unsigned16_to_signed(f.get_16()) - room_pos.x / 8
		var y := unsigned16_to_signed(f.get_16()) - room_pos.y / 8
		var mask := f.get_8()
		
		print("%s, %s: %s" % [x, y, mask])
		
		var new_spike := Spike.new(mask)
		add_child(new_spike)
		new_spike.set_position_async(x * 8, y * 8)
		spikes[Vector2i(x, y)] = new_spike
		new_spike.queue_redraw()

func local_to_map(pos : Vector2) -> Vector2i:
	return Vector2i(
		floor(pos.x / 8.0),
		floor(pos.y / 8.0)
	)

func map_to_local(pos : Vector2i) -> Vector2:
	return Vector2(
		pos.x * 8.0,
		pos.y * 8.0
	)

func get_subcell(relative_pos : Vector2) -> int:
	for cell : Rect2 in subcells.keys():
		if cell.has_point(relative_pos):
			return subcells[cell]
	return -1

func place_tile(pos : Vector2) -> void:
	var cell_pos := local_to_map(to_local(pos))
	var relative_pos := to_local(pos) - map_to_local(cell_pos)
	
	var subcell := get_subcell(relative_pos)
	
	if cell_pos in spikes.keys():
		spikes[cell_pos].add_spike(Spike.get_bit(subcell))
		return
	
	var new_spike := Spike.new(Spike.get_bit(subcell))
	add_child(new_spike)
	new_spike.position = Vector2(cell_pos * 8)
	spikes[cell_pos] = new_spike

func erase_tile(pos : Vector2) -> void:
	var cell_pos := local_to_map(to_local(pos))
	
	if not cell_pos in spikes.keys(): return
	
	var relative_pos := to_local(pos) - map_to_local(cell_pos)
	var subcell := get_subcell(relative_pos)
	
	if spikes[cell_pos].remove_spike(Spike.get_bit(subcell)): spikes.erase(cell_pos)

func get_colliders() -> Array[Rect2]:
	var arr : Array[Rect2] = []
	
	for pos : Vector2i in spikes.keys():
		for subspike : int in subcells.values():
			if (spikes[pos].mask & (1 << subspike)) > 0:
				var rect : Rect2 = subcells.find_key(subspike)
				rect.position += Vector2(pos) * 8
				arr.append(rect)
	
	return arr

func export_colliders(file_path : String, room_pos : Vector2) -> int:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	
	var spike_count : int = 0
	
	for pos : Vector2i in spikes.keys():
		if spikes[pos].mask == 0: continue
		f.store_16(pos.x + room_pos.x / 8)
		f.store_16(pos.y + room_pos.y / 8)
		f.store_8(spikes[pos].mask)
		
		spike_count += 1
	
	f.close()
	
	return spike_count

func export(chunks : Array[Rect2], room_dir : String) -> PackedInt32Array:
	
	var chunk_files : Array[FileAccess]
	var chunk_spike_counts : PackedInt32Array
	
	for i : int in chunks.size():
		chunk_files.append(FileAccess.open(room_dir + "/%s.spikes" % i, FileAccess.WRITE))
		chunk_spike_counts.append(0)
		
	
	for spike : Vector2i in spikes.keys():
		for i : int in chunks.size():
			if chunks[i].has_point(spike * 8):
				for atlas : Vector2i in spikes[spike].get_atlases():
					chunk_files[i].store_16(spike.x)
					chunk_files[i].store_16(spike.y)
					chunk_files[i].store_16(atlas.x)
					chunk_files[i].store_16(atlas.y)
					chunk_spike_counts[i] += 1
	
	for f : FileAccess in chunk_files:
		f.close()
	
	return chunk_spike_counts
