extends Control

const ANIMATION_NAMES : PackedStringArray = ["duck", "fly", "idle", "jump", "ledge_flip", "ledge_unflip", "run", "slow_run", "slide", "twerk_down", "twerk_up", "wallrun"]
const ANIMATION_PROPERTIES_SCENE := preload("res://scenes/skin_edit/animation_properties.tscn")
const COLOR_COUNT : int = 10
const COLOR_PALETTE_OVERRIDE_BUFFER : PackedByteArray = [
	0x00,0x00,0x00,
	0x00,0x00,0x00,
	0x10,0x10,0x10,
	0x20,0x20,0x20,
	0x30,0x30,0x30,
	0x40,0x40,0x40,
	0x50,0x50,0x50,
	0x60,0x60,0x60,
	0x70,0x70,0x70,
	0x80,0x80,0x80,
	0x90,0x90,0x90
]

var textures : Array[ImageTexture] = []

func _ready() -> void:
	var json : Dictionary = {
		"allow_twerk":true,
		"footsteps_run":[],
		"footsteps_slow_run":[],
		"scarf_base_thickness":1,
		"scarf_tip_thickness":1,
		"scarf_segment_length":2,
		"scarf_charged_color":[198, 15, 64],
		"scarf_empty_color":[255, 240, 35],
		"animations":[
			{"fps":1.0,"frame_count":1,"looping":false},
			{"fps":1.0,"frame_count":1,"looping":false},
			{"fps":10.0,"frame_count":7,"looping":true},
			{"fps":24.0,"frame_count":10,"looping":false},
			{"fps":10.0,"frame_count":4,"looping":false},
			{"fps":10.0,"frame_count":4,"looping":false},
			{"fps":24.0,"frame_count":16,"looping":true},
			{"fps":24.0,"frame_count":16,"looping":true},
			{"fps":1.0,"frame_count":1,"looping":false},
			{"fps":12.0,"frame_count":5,"looping":false},
			{"fps":12.0,"frame_count":5,"looping":false},
			{"fps":48.0,"frame_count":15,"looping":true}
		],
		"colors":[
			[84,84,84],
			[168,168,168],
			[84,84,84],
			[84,84,84],
			[0,0,0],
			[0,0,0],
			[255,153,0],
			[255,0,0],
			[0,255,0],
			[0,0,255]
		]
	}
	
	var json_path := Global.project_path + "/skin.json"
	if FileAccess.file_exists(json_path):
		json = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	
	for step_frame : int in json.footsteps_run:
		%RunFootsteps.text += "%s, " % step_frame
	
	for step_frame : int in json.footsteps_slow_run:
		%SlowRunFootsteps.text += "%s, " % step_frame
	
	%ScarfSegmentLength.value = json.scarf_segment_length
	%ScarfBaseThickness.value = json.scarf_base_thickness
	%ScarfTipThickness.value = json.scarf_tip_thickness
	
	%ChargedScarfColor.color.r8 = json.scarf_charged_color[0]
	%ChargedScarfColor.color.g8 = json.scarf_charged_color[1]
	%ChargedScarfColor.color.b8 = json.scarf_charged_color[2]
	
	%EmptyScarfColor.color.r8 = json.scarf_empty_color[0]
	%EmptyScarfColor.color.g8 = json.scarf_empty_color[1]
	%EmptyScarfColor.color.b8 = json.scarf_empty_color[2]
	
	load_textures()
	
	for anim : int in ANIMATION_NAMES.size():
		var new_properties = ANIMATION_PROPERTIES_SCENE.instantiate()
		%AnimationProperties.add_child(new_properties)
		
		%Preview.sprite_frames.add_animation(ANIMATION_NAMES[anim])
		%AnimationSelect.add_item(ANIMATION_NAMES[anim])
		
		new_properties.get_child(0).text = ANIMATION_NAMES[anim]
		new_properties.get_child(1).value = json.animations[anim].fps
		new_properties.get_child(2).value = json.animations[anim].frame_count
		new_properties.get_child(3).button_pressed = json.animations[anim].looping
		
		var value_changed_callback := func(_value : float = 0) -> void: update_preview_animation(anim)
		
		new_properties.get_child(1).value_changed.connect(value_changed_callback)
		new_properties.get_child(2).value_changed.connect(value_changed_callback)
		new_properties.get_child(3).pressed.connect(update_preview_animation.bind(anim))
		
		update_preview_animation(anim)
	
	for color : int in COLOR_COUNT:
		%Colors.get_child(color).color.r8 = json.colors[color][0]
		%Colors.get_child(color).color.g8 = json.colors[color][1]
		%Colors.get_child(color).color.b8 = json.colors[color][2]
		%Colors.get_child(color).color_changed.connect(update_palette)
	
	%AnimationSelect.select(ANIMATION_NAMES.find("idle"))
	%Preview.play("idle")
	
	# %Preview.material.set_shader_parameter("base_palette", get_base_palette())
	
	update_palette()

func load_textures() -> void:
	textures.clear()
	for anim : String in ANIMATION_NAMES:
		# since godot discards color palette data when loading PNGs,
		# we're gonna do something REALLY FUNNY:
		
		# read PNG directly into binary
		var png := FileAccess.get_file_as_bytes(Global.project_path + "/%s.png" % anim)
		if png.is_empty():
			textures.append(Texture2D.new())
			continue
		
		var chunk_start : int = 8 # skip PNG header
		while chunk_start < png.size(): # scan PNG
			
			var chunk_type_start := chunk_start + 4
			var chunk_data_start := chunk_type_start + 4
			
			var length_buffer := png.slice(chunk_start, chunk_type_start)
			length_buffer.reverse() # big-endian
			var chunk_length := length_buffer.to_int32_array()[0]
			
			var chunk_checksum_start := chunk_data_start + chunk_length
			
			var chunk_type := png.slice(chunk_type_start, chunk_data_start).get_string_from_ascii()
			
			if chunk_type == "PLTE": # found palette chunk
				# overwrite palette to grayscale so we can detect it properly in shader
				for i : int in mini(chunk_length, COLOR_PALETTE_OVERRIDE_BUFFER.size()):
					png[chunk_data_start + i] = COLOR_PALETTE_OVERRIDE_BUFFER[i]
				
				# calculate new chunk's CRC checksum
				var data := png.slice(chunk_type_start, chunk_checksum_start)
				var crc : int = 0xFFFFFFFF
				for byte : int in data:
					crc ^= byte
					for j : int in 8:
						if crc & 1:
							crc = ((crc >> 1) ^ 0xEDB88320) & 0xFFFFFFFF
						else:
							crc = (crc >> 1) & 0xFFFFFFFF
				
				crc ^= 0xFFFFFFFF
				
				var crc_buffer := PackedByteArray()
				crc_buffer.resize(4)
				crc_buffer.encode_u32(0, crc)
				crc_buffer.reverse() # still big-endian
				
				# overwrite checksum
				for i : int in 4:
					png[chunk_checksum_start + i] = crc_buffer[i]
				
				break
			
			else: # not palette chunk
				chunk_start = chunk_checksum_start + 4
		
		# load edited png into texture
		var image := Image.new()
		image.load_png_from_buffer(png)
		textures.append(ImageTexture.create_from_image(image))
		
		# insane

func update_preview_animation(index : int, _value : float = 0) -> void:
	var fps : float = %AnimationProperties.get_child(index).get_child(1).value
	var frame_count : float = %AnimationProperties.get_child(index).get_child(2).value
	var looping : bool = %AnimationProperties.get_child(index).get_child(3).button_pressed
	
	var frame_count_horizontal : int = 1
	while (frame_count_horizontal * frame_count_horizontal) < frame_count:
		frame_count_horizontal *= 2
	
	var frames : SpriteFrames = %Preview.sprite_frames
	var anim_name := ANIMATION_NAMES[index]
	
	frames.clear(anim_name)
	frames.set_animation_loop(anim_name, looping)
	frames.set_animation_speed(anim_name, fps)
	
	for i : int in frame_count:
		@warning_ignore("integer_division")
		var row : int = i / frame_count_horizontal
		var collumn = i - row * frame_count_horizontal
		
		var frame := AtlasTexture.new()
		frame.atlas = textures[index]
		frame.region.position = Vector2(collumn, row) * 16
		frame.region.size = Vector2(16, 16)
		frames.add_frame(anim_name, frame)

func update_palette(_color : Color = Color(0, 0, 0)) -> void:
	var palette : PackedColorArray = []
	for i : int in COLOR_COUNT:
		palette.append(%Colors.get_child(i).color)
	
	%Preview.material.set_shader_parameter("palette", palette)

func _on_animation_select_item_selected(index: int) -> void:
	%Preview.play(ANIMATION_NAMES[index])
