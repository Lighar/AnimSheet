@tool
extends PanelContainer

@onready var preview: Control = %AnimatedPreview
@onready var name_input: LineEdit = %NameInput
@onready var loop_check: CheckBox = %LoopCheck
@onready var fps_spin: SpinBox = %FPSSpin

const NON_LOOP_PAUSE_MS := 700

var anim_data: Dictionary = {}
var _hold_until := 0
var _elapsed := 0.0

func setup(texture: Texture2D, frame_rects: Array[Rect2], display_name: String, data: Dictionary, fps: int) -> void:
	anim_data = data
	name_input.text = display_name
	fps_spin.value = fps
	preview.setup(texture, frame_rects)

func _process(delta: float) -> void:
	var step := 1.0 / maxf(fps_spin.value, 1.0)
	_elapsed += delta
	if _elapsed >= step:
		_elapsed = fmod(_elapsed, step)
		advance_frame()

func advance_frame() -> void:
	if not is_instance_valid(preview):
		return
	if not loop_check.button_pressed and preview.current_frame == preview.frames.size() - 1:
		if _hold_until == 0:
			_hold_until = Time.get_ticks_msec() + NON_LOOP_PAUSE_MS
		if Time.get_ticks_msec() < _hold_until:
			return
		_hold_until = 0
	preview.advance_frame()

func get_anim_data() -> Dictionary:
	var typed := name_input.text.strip_edges()
	anim_data.name = typed if not typed.is_empty() else anim_data.display_name
	anim_data.loop = loop_check.button_pressed
	anim_data.fps = int(fps_spin.value)
	return anim_data
