@tool
extends Line2D

const SEGMENT_COUNT : int = 10
const TIME_SCALE : float = 4.2
const SINE_SCALE : float = 4
const WIND_DIF : float = -0.8

@export var segment_length : float = 2:
	set(v):
		segment_length = v
		position.x = SEGMENT_COUNT * segment_length / 2 

@export var base_width : float = 1:
	set(v):
		base_width = v
		update_width()

@export var tip_width : float = 1:
	set(v):
		tip_width = v
		update_width()

@export var color : Color = Color.DEEP_PINK:
	set(v):
		color = v
		default_color = v

@export var time : float = 0
@export var weight : float = 0

func _process(delta : float) -> void:
	time += delta
	
	for i : int in SEGMENT_COUNT:
		var segment := Vector2.LEFT * segment_length * i
		segment.y += sin(time * TIME_SCALE + i * WIND_DIF) * SINE_SCALE * (1 - weight) * (float(i) / float(SEGMENT_COUNT))
		set_point_position(i, segment)

func update_width() -> void:
	width = max(base_width, tip_width)
	
	width_curve.clear_points()
	width_curve.add_point(Vector2(0, base_width / width))
	width_curve.add_point(Vector2(1, tip_width / width))
	width_curve.bake()
