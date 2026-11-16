@tool
extends VBoxContainer

@onready var prev_btn: Button = $SelectorContainer/PrevButton
@onready var anim_label: Label = $SelectorContainer/AnimLabel
@onready var next_btn: Button = $SelectorContainer/NextButton
@onready var preview: Control = $AnimatedPreview

var texture: Texture2D
var all_animations: Array[Array] = []
var current_index: int = 0
var fps: int = 10

func _ready() -> void:
	prev_btn.pressed.connect(_on_prev_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	if not all_animations.is_empty():
		_update_display()

func setup(img_data: Dictionary, is_horizontal: bool, p_fps: int) -> bool:
	var img := Image.new()
	if img.load(img_data.path) != OK:
		return false

	texture = ImageTexture.create_from_image(img)
	fps = p_fps
	current_index = 0
	all_animations.clear()
	for frame_array in img_data.animations[is_horizontal]:
		all_animations.append(TiledImageExportUtils.crop_rects(frame_array, img_data.get("preview_rect", Rect2())))

	if is_node_ready() and not all_animations.is_empty():
		_update_display()
	return not all_animations.is_empty()

func _update_display() -> void:
	anim_label.text = "Animation %d / %d" % [current_index + 1, all_animations.size()]
	preview.fps = fps
	preview.setup(texture, all_animations[current_index])

func _on_prev_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_update_display()

func _on_next_pressed() -> void:
	if current_index < all_animations.size() - 1:
		current_index += 1
		_update_display()

func get_animation_count() -> int:
	return all_animations.size()
