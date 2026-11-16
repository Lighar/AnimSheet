@tool
extends PanelContainer

@onready var preview: Control = %AnimatedPreview
@onready var name_input: LineEdit = %NameInput
@onready var loop_check: CheckBox = %LoopCheck
@onready var fps_spin: SpinBox = %FPSSpin

var anim_data: Dictionary = {}

func _ready() -> void:
	fps_spin.value_changed.connect(func(value: float): preview.fps = value)
	loop_check.toggled.connect(func(on: bool): preview.loop = on)
	preview.loop = loop_check.button_pressed

func setup(texture: Texture2D, frame_rects: Array[Rect2], display_name: String, data: Dictionary, fps: int) -> void:
	anim_data = data
	name_input.text = display_name
	fps_spin.value = fps
	preview.fps = fps
	preview.setup(texture, frame_rects)

func get_anim_data() -> Dictionary:
	var typed := name_input.text.strip_edges()
	anim_data.name = typed if not typed.is_empty() else anim_data.display_name
	anim_data.loop = loop_check.button_pressed
	anim_data.fps = int(fps_spin.value)
	return anim_data
