@tool
extends Resource
class_name AnimationInfo

@export var frame_count : int = 1
@export var fps : float = 12.0
@export var looping : bool = true

func get_dict() -> Dictionary:
	return {
		"frame_count": frame_count,
		"fps": fps,
		"looping": looping
	}
