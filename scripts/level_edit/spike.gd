extends Node2D
class_name Spike

const TEXTURE := preload("res://graphics/tiles/special/spikes.png")

enum {TOP_LEFT, TOP, TOP_RIGHT, LEFT, RIGHT, BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT}

const BOTTOM_MIDDLE = Vector2i(0, 0)
const RIGHT_MIDDLE = Vector2i(1, 0)
const TOP_MIDDLE = Vector2i(2, 0)
const LEFT_MIDDLE = Vector2i(3, 0)

const BOTTOM_LEFT_CORNER = Vector2i(0, 1)
const BOTTOM_LEFT_BOTTOM = Vector2i(0, 2)
const BOTTOM_LEFT_LEFT = Vector2i(0, 3)

const BOTTOM_RIGHT_CORNER = Vector2i(1, 1)
const BOTTOM_RIGHT_BOTTOM = Vector2i(1, 2)
const BOTTOM_RIGHT_RIGHT = Vector2i(1, 3)

const TOP_LEFT_CORNER = Vector2i(2, 1)
const TOP_LEFT_TOP = Vector2i(2, 2)
const TOP_LEFT_LEFT = Vector2i(2, 3)

const TOP_RIGHT_CORNER = Vector2i(3, 1)
const TOP_RIGHT_TOP = Vector2i(3, 2)
const TOP_RIGHT_RIGHT = Vector2i(3, 3)

class SubSpike:
	var possibilities : Dictionary[int, Vector2i]
	
	func _init(p : Dictionary[int, Vector2i]) -> void:
		possibilities = p
	
	func get_atlas(bitmask : int) -> Vector2i:
		
		var a := Vector2i(-1, -1)
		
		for p : int in possibilities.keys():
			if (bitmask & p) == p:
				a = possibilities[p]
		
		return a

var subspikes : Array[SubSpike] = [
	SubSpike.new({
		get_bit(TOP_LEFT) : TOP_LEFT_CORNER,
		get_bits([TOP_LEFT, TOP]) : TOP_LEFT_TOP,
		get_bits([TOP_LEFT, LEFT]) : TOP_LEFT_LEFT,
		get_bits([TOP_LEFT, LEFT, TOP]) : TOP_LEFT_CORNER
	}),
	
	SubSpike.new({get_bit(TOP) : TOP_MIDDLE}),
	
	SubSpike.new({
		get_bit(TOP_RIGHT) : TOP_RIGHT_CORNER,
		get_bits([TOP_RIGHT, TOP]) : TOP_RIGHT_TOP,
		get_bits([TOP_RIGHT, RIGHT]) : TOP_RIGHT_RIGHT,
		get_bits([TOP_RIGHT, RIGHT, TOP]) : TOP_RIGHT_CORNER
	}),
	
	SubSpike.new({get_bit(RIGHT) : RIGHT_MIDDLE}),
	
	SubSpike.new({
		get_bit(BOTTOM_RIGHT) : BOTTOM_RIGHT_CORNER,
		get_bits([BOTTOM_RIGHT, BOTTOM]) : BOTTOM_RIGHT_BOTTOM,
		get_bits([BOTTOM_RIGHT, RIGHT]) : BOTTOM_RIGHT_RIGHT,
		get_bits([BOTTOM_RIGHT, RIGHT, BOTTOM]) : BOTTOM_RIGHT_CORNER
	}),
	
	SubSpike.new({get_bit(BOTTOM) : BOTTOM_MIDDLE}),
	
	SubSpike.new({
		get_bit(BOTTOM_LEFT) : BOTTOM_LEFT_CORNER,
		get_bits([BOTTOM_LEFT, BOTTOM]) : BOTTOM_LEFT_BOTTOM,
		get_bits([BOTTOM_LEFT, LEFT]) : BOTTOM_LEFT_LEFT,
		get_bits([BOTTOM_LEFT, LEFT, BOTTOM]) : BOTTOM_LEFT_CORNER
	}),
	
	SubSpike.new({get_bit(LEFT) : LEFT_MIDDLE})
]

var mask : int = 0

static func get_bit(dir : int) -> int:
	return 1 << dir

static func get_bits(dirs : PackedInt32Array) -> int:
	var value : int = 0
	for d : int in dirs:
		value = value | get_bit(d)
	
	return value

func _init(bitmask : int) -> void:
	mask = bitmask
	queue_redraw()

func set_position_async(x : float, y : float) -> void:
	await ready
	position.x = x
	position.y = y

func _ready() -> void:
	position = Vector2(0, 0)

func has_spike(spike : int) -> bool:
	return (mask & (1 << spike)) > 0

func get_source(atlas : Vector2i) -> Rect2:
	return Rect2(Vector2(atlas) * 8.0, Vector2(8, 8))

func _draw() -> void:
	var dest := Rect2(0, 0, 8, 8)
	
	for atlas : Vector2i in get_atlases():
		draw_texture_rect_region(TEXTURE, dest, get_source(atlas))

func get_atlases() -> Array[Vector2i]:
	
	var arr : Array[Vector2i]
	
	for subspike : SubSpike in subspikes:
		var atlas := subspike.get_atlas(mask)
		if atlas != Vector2i(-1, -1): arr.append(atlas)
	
	return arr

func add_spike(spike : int) -> void:
	mask = mask | spike
	queue_redraw()

func remove_spike(spike : int) -> bool:
	mask = mask & ~spike
	if mask == 0:
		queue_free()
		return true
	queue_redraw()
	return false
