extends Button
class_name TileSetButton

enum TileType {FG, SPIKE}

@export var type : TileType = TileType.FG

var source : int = 0

var paint : Callable
var erase : Callable

func _init(tile_type : TileType = type) -> void:
	type = tile_type

func _ready() -> void:
	
	match type:
		TileType.FG:
			paint = paint_fg
			erase = erase_fg
		
		TileType.SPIKE:
			paint = paint_spike
			erase = erase_spike

func paint_fg(room : RoomEdit, pos : Vector2) -> void:
	room.place_tile(pos, source)

func erase_fg(room : RoomEdit, pos : Vector2) -> void:
	room.erase_tile(pos)

func paint_spike(room : RoomEdit, pos : Vector2) -> void:
	room.get_child(1).place_tile(pos)

func erase_spike(room : RoomEdit, pos : Vector2) -> void:
	room.get_child(1).erase_tile(pos)
