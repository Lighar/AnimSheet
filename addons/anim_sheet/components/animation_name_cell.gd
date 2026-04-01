@tool
extends VBoxContainer

@onready var preview: Control = $AnimatedPreview
@onready var name_input: LineEdit = $NameInput

var anim_data: Dictionary = {}

func setup(texture: Texture2D, frame_rects: Array[Rect2], display_name: String, data: Dictionary) -> void:
	anim_data = data
	name_input.text = display_name
	preview.setup(texture, frame_rects)

func advance_frame() -> void:
	if is_instance_valid(preview):
		preview.advance_frame()

func get_custom_name() -> String:
	return name_input.text

func get_anim_data() -> Dictionary:
	return anim_data
