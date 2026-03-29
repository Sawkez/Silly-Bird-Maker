extends Area2D
class_name Drag

var dragged : bool = false
var drag_offset : Vector2

@export var drag_priority : int = 0

func _ready() -> void:
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()

func set_rect(rect : Rect2) -> void:
	$CollisionShape2D.shape.size = rect.size
	$CollisionShape2D.position = rect.position + rect.size / 2

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action("drag") and event.is_pressed():
		if Global.level_edit.dragged_node != null:
			if Global.level_edit.dragged_node.drag_priority >= drag_priority: return
			else: Global.level_edit.dragged_node.dragged = false
		
		dragged = true
		Global.level_edit.dragged_node = self
		drag_offset = -get_local_mouse_position()

func _input(event : InputEvent) -> void:
	if event.is_action("drag") and not event.is_pressed() and dragged:
		Global.level_edit.dragged_node = null
		dragged = false

func _process(_delta : float) -> void:
	if dragged: get_parent().global_position = LevelEdit.snap_to_grid(get_global_mouse_position() + drag_offset)
