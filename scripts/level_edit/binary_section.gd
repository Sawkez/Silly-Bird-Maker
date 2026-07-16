class_name BinarySection

var tag : String
var data : PackedByteArray
var size : int

func _init(id : String) -> void:
	tag = id

func push_s64(value : int) -> void:
	var pos := size
	size += 8
	data.resize(size)
	data.encode_s64(pos, value)

func push_u32(value : int) -> void:
	var pos := size
	size += 4
	data.resize(size)
	data.encode_u32(pos, value)

func push_u16(value : int) -> void:
	var pos := size
	size += 2
	data.resize(size)
	data.encode_u16(pos, value)

func push_u8(value : int) -> void:
	var pos := size
	size += 1
	data.resize(size)
	data.encode_u8(pos, value)

func push_float(value : float) -> void:
	var pos := size
	size += 4
	data.resize(size)
	data.encode_float(pos, value)

func write(file : FileAccess) -> void:
	file.store_string(tag)
	file.store_32(size)
	file.store_buffer(data)
