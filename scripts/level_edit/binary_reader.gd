extends Node
class_name BinaryReader

var current_section_tag : String
var current_section_length : int
var current_section_position : int
var file : FileAccess

func _init(path : String) -> void:
	file = FileAccess.open(path, FileAccess.READ)
	current_section_tag = file.get_buffer(4).get_string_from_ascii()
	current_section_length = file.get_32()
	current_section_position = 8

func next_section() -> void:
	current_section_position += current_section_length
	file.seek(current_section_position)
	current_section_tag = file.get_buffer(4).get_string_from_ascii()
	current_section_length = file.get_32()
	current_section_position += 4 + 4

func ensure_section(tag : String) -> void:
	while current_section_tag != tag: next_section()

func find_section(tag : String) -> void:
	next_section()
	ensure_section(tag)
