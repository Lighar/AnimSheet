@tool
extends VBoxContainer

signal animation_changed(index: int)

@onready var prev_btn: Button = $SelectorContainer/PrevButton
@onready var anim_label: Label = $SelectorContainer/AnimLabel
@onready var next_btn: Button = $SelectorContainer/NextButton
@onready var preview: Control = $AnimatedPreview

var texture: Texture2D
var all_animations: Array[Array] = []
var current_index: int = 0
var timer: Timer = null
var _pending_fps: int = 10
var _setup_pending: bool = false

func _ready() -> void:
	prev_btn.pressed.connect(_on_prev_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	
	if _setup_pending:
		_setup_pending = false
		_update_display()
		_start_timer(_pending_fps)

func setup(img_path: String, img_data: Dictionary, is_horizontal: bool, fps: int) -> bool:
	var img := Image.new()
	if img.load(img_path) != OK:
		return false
	
	texture = ImageTexture.create_from_image(img)
	all_animations.clear()
	
	var frames := TiledImageExportUtils.extract_animation_frames(img, img_data, is_horizontal)
	for frame_array in frames:
		var typed_array: Array[Rect2] = []
		typed_array.assign(frame_array)
		all_animations.append(typed_array)
	
	current_index = 0
	_pending_fps = fps
	
	if is_inside_tree() and anim_label:
		_update_display()
		_start_timer(fps)
	else:
		_setup_pending = true
	
	return all_animations.size() > 0

func _update_display() -> void:
	var count := all_animations.size()
	anim_label.text = "Animation %d / %d" % [current_index + 1, count]
	
	if count > 0 and current_index < count:
		preview.setup(texture, all_animations[current_index])

func _on_prev_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_update_display()
		animation_changed.emit(current_index)

func _on_next_pressed() -> void:
	if current_index < all_animations.size() - 1:
		current_index += 1
		_update_display()
		animation_changed.emit(current_index)

func _start_timer(fps: int) -> void:
	if timer:
		timer.stop()
		timer.queue_free()
	
	timer = Timer.new()
	timer.wait_time = 1.0 / max(fps, 1)
	timer.autostart = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _on_timer_timeout() -> void:
	if is_instance_valid(preview):
		preview.advance_frame()

func _exit_tree() -> void:
	if timer:
		timer.stop()
		timer.queue_free()
		timer = null

func get_current_index() -> int:
	return current_index

func get_animation_count() -> int:
	return all_animations.size()
