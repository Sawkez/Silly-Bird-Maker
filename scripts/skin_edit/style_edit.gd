extends Control

enum {SCARF_HIDDEN, SCARF_EMPTY, SCARF_CHARGED}
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
var scarf_textures : Array[ImageTexture] = []
var scarf_positions : Dictionary[String, Array] = {}

class PngChunk:
	var length_pos : int
	var length : int
	var type_pos : int
	var type : String
	var data_pos : int
	var checksum_pos : int
	var end : int
	
	func _init(png : PackedByteArray, chunk_start_pos : int) -> void:
		length_pos = chunk_start_pos
		
		type_pos = length_pos + 4
		var length_buffer := png.slice(length_pos, type_pos)
		length_buffer.reverse() # big-endian
		length = length_buffer.to_int32_array()[0]
		
		data_pos = type_pos + 4
		type = png.slice(type_pos, data_pos).get_string_from_ascii()
		
		checksum_pos = data_pos + length
		end = checksum_pos + 4

func _ready() -> void:
	var json : Dictionary = {
		"allow_twerk":true,
		"footsteps_run":[],
		"footsteps_slow_run":[],
		"scarf_base_width":2,
		"scarf_tip_width":2,
		"scarf_segment_length":2,
		"scarf_charged_color":[198, 15, 64],
		"scarf_empty_color":[255, 240, 35],
		"scarf_weight":0,
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
	
	# removing extra ", "
	%RunFootsteps.text = %RunFootsteps.text.substr(0, %RunFootsteps.text.length() - 2)
	%SlowRunFootsteps.text = %SlowRunFootsteps.text.substr(0, %SlowRunFootsteps.text.length() - 2)
	
	%ScarfSegmentLength.value = json.scarf_segment_length
	%Scarf.segment_length = json.scarf_segment_length
	%ScarfBaseWidth.value = json.scarf_base_width
	%Scarf.base_width = json.scarf_base_width
	%ScarfTipWidth.value = json.scarf_tip_width
	%Scarf.tip_width = json.scarf_tip_width
	%ScarfWeight.value = json.scarf_weight
	%Scarf.weight = json.scarf_weight
	
	%ChargedScarfColor.color.r8 = json.scarf_charged_color[0]
	%ChargedScarfColor.color.g8 = json.scarf_charged_color[1]
	%ChargedScarfColor.color.b8 = json.scarf_charged_color[2]
	%PreviewScarfOverlay.modulate = %ChargedScarfColor.color
	%Scarf.color = %ChargedScarfColor.color
	
	%EmptyScarfColor.color.r8 = json.scarf_empty_color[0]
	%EmptyScarfColor.color.g8 = json.scarf_empty_color[1]
	%EmptyScarfColor.color.b8 = json.scarf_empty_color[2]
	
	load_textures()
	
	for anim : int in ANIMATION_NAMES.size():
		var new_properties = ANIMATION_PROPERTIES_SCENE.instantiate()
		%AnimationProperties.add_child(new_properties)
		
		%Preview.sprite_frames.add_animation(ANIMATION_NAMES[anim])
		%PreviewScarfOverlay.sprite_frames.add_animation(ANIMATION_NAMES[anim])
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
	%PreviewScarfOverlay.play("idle")
	
	# %Preview.material.set_shader_parameter("base_palette", get_base_palette())
	
	update_palette()

func load_textures() -> void:
	textures.clear()
	scarf_textures.clear()
	scarf_positions.clear()
	
	for anim : String in ANIMATION_NAMES:
		# since godot discards color palette data when loading PNGs,
		# we're gonna do something REALLY FUNNY:
		
		# read PNG directly into binary
		var png := FileAccess.get_file_as_bytes(Global.project_path + "/%s.png" % anim)
		if png.is_empty():
			textures.append(Texture2D.new())
			continue
		
		var palette_chunk := find_palette_chunk(png)
		
		# overwrite palette to grayscale so we can detect it properly in shader
		for i : int in mini(palette_chunk.length, COLOR_PALETTE_OVERRIDE_BUFFER.size()):
			png[palette_chunk.data_pos + i] = COLOR_PALETTE_OVERRIDE_BUFFER[i]
		
		# calculate new chunk's CRC checksum
		var data := png.slice(palette_chunk.type_pos, palette_chunk.checksum_pos)
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
			png[palette_chunk.checksum_pos + i] = crc_buffer[i]
		
		
		# load edited png into texture
		var image := Image.new()
		image.load_png_from_buffer(png)
		textures.append(ImageTexture.create_from_image(image))
		
		var scarf_image := Image.load_from_file("%s/scarf/%s.png" % [Global.project_path, anim])
		scarf_textures.append(ImageTexture.create_from_image(scarf_image))
		
		# importing scarf positions
		scarf_positions[anim] = []
		
		var scarf_pos_image := Image.load_from_file("%s/pin/%s.png" % [Global.project_path, anim])
		if not scarf_pos_image: continue
		
		for frame_row : int in scarf_pos_image.get_size().y / 16:
			for frame_collumn : int in scarf_pos_image.get_size().x / 16:
				
				var pin := Vector2.ZERO
				
				for x : int in 16:
					for y : int in 16:
						if scarf_pos_image.get_pixel(frame_collumn * 16 + x, frame_row * 16 +y).a > 0:
							pin = Vector2i(x, y)
				
				scarf_positions[anim].append(pin)
		
		# insane

func find_palette_chunk(png : PackedByteArray) -> PngChunk:
	var chunk := PngChunk.new(png, 8) # skip PNG signature
	
	while (chunk.end < png.size()):
		if chunk.type == "PLTE": return chunk
		chunk = PngChunk.new(png, chunk.end)
	
	return null

func update_preview_animation(index : int, _value : float = 0) -> void:
	var fps : float = %AnimationProperties.get_child(index).get_child(1).value
	var frame_count : float = %AnimationProperties.get_child(index).get_child(2).value
	var looping : bool = %AnimationProperties.get_child(index).get_child(3).button_pressed
	
	var frame_count_horizontal : int = 1
	while (frame_count_horizontal * frame_count_horizontal) < frame_count:
		frame_count_horizontal *= 2
	
	var frames : SpriteFrames = %Preview.sprite_frames
	var scarf_frames : SpriteFrames = %PreviewScarfOverlay.sprite_frames
	var anim_name := ANIMATION_NAMES[index]
	
	frames.clear(anim_name)
	frames.set_animation_loop(anim_name, looping)
	frames.set_animation_speed(anim_name, fps)
	
	scarf_frames.clear(anim_name)
	scarf_frames.set_animation_loop(anim_name, looping)
	scarf_frames.set_animation_speed(anim_name, fps)
	
	for i : int in frame_count:
		@warning_ignore("integer_division")
		var row : int = i / frame_count_horizontal
		var collumn = i - row * frame_count_horizontal
		
		var frame := AtlasTexture.new()
		frame.atlas = textures[index]
		frame.region.position = Vector2(collumn, row) * 16
		frame.region.size = Vector2(16, 16)
		frames.add_frame(anim_name, frame)
		
		var scarf_frame := frame.duplicate()
		scarf_frame.atlas = scarf_textures[index]
		scarf_frames.add_frame(anim_name, scarf_frame)

func update_palette(_color : Color = Color(0, 0, 0)) -> void:
	var palette : PackedColorArray = []
	for i : int in COLOR_COUNT:
		palette.append(%Colors.get_child(i).color)
	
	%Preview.material.set_shader_parameter("palette", palette)

func _on_animation_select_item_selected(index: int) -> void:
	%Preview.play(ANIMATION_NAMES[index])
	%PreviewScarfOverlay.play(ANIMATION_NAMES[index])

func update_scarf_visibility() -> void:
	pass

func _on_scarf_segment_length_value_changed(value: float) -> void:
	%Scarf.segment_length = value
	var shrink : float = 10
	
	var viewport_size : float = %ScarfPreview.size.x
	while viewport_size / shrink < value * 10: shrink -= 1
	
	%ScarfPreview.stretch_shrink = shrink

func _on_scarf_base_width_value_changed(value: float) -> void:
	%Scarf.base_width = value

func _on_scarf_tip_width_value_changed(value: float) -> void:
	%Scarf.tip_width = value

func _on_scarf_weight_value_changed(value: float) -> void:
	%Scarf.weight = value / 100.0

func _on_charged_scarf_color_color_changed(color: Color) -> void:
	if %ScarfVisibility.selected == SCARF_CHARGED:
		%Scarf.color = color
		%PreviewScarfOverlay.modulate = color

func _on_empty_scarf_color_color_changed(color : Color) -> void:
	if %ScarfVisibility.selected == SCARF_EMPTY:
		%Scarf.color = color
		%PreviewScarfOverlay.modulate = color

func _on_scarf_visibility_item_selected(index: int) -> void:
	%Scarf.visible = index != SCARF_HIDDEN
	%PreviewScarfOverlay.visible = %Scarf.visible
	
	var color := Color.BLACK
	if index == SCARF_EMPTY:
		color = %EmptyScarfColor.color
	elif index == SCARF_CHARGED:
		color = %ChargedScarfColor.color
	
	%Scarf.color = color
	%PreviewScarfOverlay.modulate = color

func _on_preview_frame_changed() -> void:
	if scarf_positions[%Preview.animation].size() <= %Preview.frame: %Pin.position = Vector2.ZERO
	else: %Pin.position = scarf_positions[%Preview.animation][%Preview.frame]

func _on_show_scarf_pin_toggled(toggled_on: bool) -> void:
	%Pin.visible = toggled_on

func _on_reload_images_pressed() -> void:
	load_textures()

func _on_import_colors_pressed() -> void:
	var palette : PackedColorArray = []
	palette.resize(COLOR_COUNT)
	palette.fill(Color.BLACK)
	
	var png := FileAccess.get_file_as_bytes("%s/run.png" % Global.project_path)
	if png.is_empty(): return
	
	var chunk := find_palette_chunk(png)
	for i : int in mini(COLOR_COUNT, chunk.length / 3):
		palette[i].r8 = png[chunk.data_pos + i*3+3 + 0]
		palette[i].g8 = png[chunk.data_pos + i*3+3 + 1]
		palette[i].b8 = png[chunk.data_pos + i*3+3 + 2]
	
	for i : int in COLOR_COUNT:
		%Colors.get_child(i).color = palette[i]
	
	update_palette()

func _on_save_pressed() -> void:
	var json := {
		"allow_twerk" : %AllowTwerk.button_pressed,
		"animations" : [],
		"colors" : [],
		"footsteps_run" : %RunFootsteps.text.split_floats(",", false),
		"footsteps_slow_run" : %SlowRunFootsteps.text.split_floats(",", false),
		"scarf_segment_length" : %ScarfSegmentLength.value,
		"scarf_base_width" : %ScarfBaseWidth.value,
		"scarf_tip_width" : %ScarfTipWidth.value,
		"scarf_charged_color" : [
			%ChargedScarfColor.color.r8,
			%ChargedScarfColor.color.g8,
			%ChargedScarfColor.color.b8
		],
		"scarf_empty_color" : [
			%EmptyScarfColor.color.r8,
			%EmptyScarfColor.color.g8,
			%EmptyScarfColor.color.b8
		],
		"scarf_weight" : %ScarfWeight.value,
		"scarf_positions" : []
	}
	
	for anim : Node in %AnimationProperties.get_children():
		json.animations.append({
			"fps" : anim.get_child(1).value,
			"frame_count" : anim.get_child(2).value,
			"looping" : anim.get_child(3).button_pressed
		})
	
	for color : ColorPickerButton in %Colors.get_children():
		json.colors.append([
			color.color.r8,
			color.color.g8,
			color.color.b8
		])
	
	for anim : int in ANIMATION_NAMES.size():
		var anim_name := ANIMATION_NAMES[anim]
		var positions : Array[int] = []
		var frame_count : int = %AnimationProperties.get_child(anim).get_child(2).value
		
		for frame : int in max(scarf_positions[anim_name].size(), frame_count):
			if scarf_positions[anim_name].size() > frame:
				positions.append(
					int(scarf_positions[anim_name][frame].x) + (int(scarf_positions[anim_name][frame].y) << 4)
				)
		
		json.scarf_positions.append(positions)
	
	var f := FileAccess.open("%s/skin.json" % Global.project_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(json))
	f.close()
