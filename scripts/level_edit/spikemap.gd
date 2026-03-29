extends TileMapLayer
class_name SpikeMap

enum {TOP_LEFT, TOP, TOP_RIGHT, LEFT, RIGHT, BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT}

var subcells : Dictionary[Rect2, int] = {
	Rect2(0, 0, 3, 3) : TOP_LEFT,
	Rect2(3, 0, 2, 3) : TOP,
	Rect2(5, 0, 3, 3) : TOP_RIGHT,
	Rect2(0, 3, 3, 2) : LEFT,
	Rect2(5, 3, 3, 2) : RIGHT,
	Rect2(0, 5, 3, 3) : BOTTOM_LEFT,
	Rect2(3, 5, 2, 3) : BOTTOM,
	Rect2(5, 5, 3, 3) : BOTTOM_RIGHT
}

static func get_bit(dir : int) -> int:
	return 1 << dir

static func get_bits(dirs : PackedInt32Array) -> int:
	var value : int = 0
	for d : int in dirs:
		value = value | get_bit(d)
	
	return value

func _init() -> void:
	tile_set = preload("res://resources/tileset_spikes.tres")

func place_tile(pos : Vector2) -> void:
	var cell_pos := local_to_map(to_local(pos))
	var relative_pos := to_local(pos) - map_to_local(cell_pos) + Vector2(4.0, 4.0)
	
	var subcell : int = 0
	for cell : Rect2 in subcells.keys():
		if cell.has_point(relative_pos):
			subcell = subcells[cell]
			break
	
	var atlas := get_cell_atlas_coords(cell_pos)
	if atlas == Vector2i(-1, -1): atlas = Vector2i(0, 0)
	
	var atlas_mask = atlas.x | get_bit(subcell)
	
	print(atlas)
	print(atlas_mask)
	
	set_cell(local_to_map(to_local(pos)), 0, Vector2i(atlas_mask, 0))
