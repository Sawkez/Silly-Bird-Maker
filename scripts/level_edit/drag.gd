extends Area2D
class_name Drag

var dragged : bool = false
var drag_offset : Vector2

@export var drag_priority : int = 0

var collision : CollisionShape2D

func _init(drag_priority_ : int = 0) -> void:
	if drag_priority == 0: drag_priority = drag_priority_
	collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(16, 16)
	add_child(collision)

func _ready() -> void:
	collision.shape = collision.shape.duplicate()

func set_rect(rect : Rect2) -> void:
	collision.shape.size = rect.size
	collision.position = rect.position + rect.size / 2

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action("drag") and event.is_pressed():
		if Global.level_edit.dragged_node != null:
			if Global.level_edit.dragged_node.drag_priority >= drag_priority: return
			else: Global.level_edit.dragged_node.dragged = false
		
		dragged = true
		Global.level_edit.dragged_node = self
		drag_offset = -get_local_mouse_position()
		
		var properties = get_parent().get("properties")
		if properties != null:
			var left_panel := Global.level_edit.get_node("%LeftPanel")
			for child : Node in left_panel.get_children(): left_panel.remove_child(child)
			left_panel.add_child(properties)

func _input(event : InputEvent) -> void:
	if event.is_action("drag") and not event.is_pressed() and dragged:
		Global.level_edit.dragged_node = null
		dragged = false

func _process(_delta : float) -> void:
	if dragged: get_parent().global_position = LevelEdit.snap_to_grid(get_global_mouse_position() + drag_offset)

func delete_parent() -> void:
	if get_parent().has_method("delete"):
		get_parent().delete()
		var left_panel := Global.level_edit.get_node("%LeftPanel")
		left_panel.get_child(0).queue_free()
