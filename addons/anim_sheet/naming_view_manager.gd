@tool
extends RefCounted
class_name NamingViewManager

const AnimationNameCellScene = preload("res://addons/tiled_image_scanner/components/animation_name_cell.tscn")

var scan_view: Control
var naming_view: Control
var node_name_edit: LineEdit
var animations_grid: GridContainer
var parent_node: Control
var fps: int

var animation_name_inputs: Dictionary = {}
var animation_previews: Array = []
var preview_timer: Timer = null

func _init(p_scan_view: Control, p_naming_view: Control, p_node_name_edit: LineEdit, p_animations_grid: GridContainer, p_parent: Control):
	scan_view = p_scan_view
	naming_view = p_naming_view
	node_name_edit = p_node_name_edit
	animations_grid = p_animations_grid
	parent_node = p_parent

func show_naming_view(animations: Array[Dictionary], p_fps: int, window_width: float) -> void:
	fps = p_fps
	
	scan_view.visible = false
	naming_view.visible = true
	
	node_name_edit.text = "ExportedAnimation"
	
	if preview_timer:
		preview_timer.stop()
		preview_timer.queue_free()
		preview_timer = null
	
	for child in animations_grid.get_children():
		child.queue_free()
	animation_name_inputs.clear()
	animation_previews.clear()
	
	animations_grid.columns = max(1, int(window_width / 220))
	
	preview_timer = Timer.new()
	preview_timer.wait_time = 1.0 / max(fps, 1)
	preview_timer.autostart = true
	preview_timer.timeout.connect(_on_preview_timer_timeout)
	parent_node.add_child(preview_timer)
	
	for anim in animations:
		if not anim.has("frame_rects") or anim.frame_rects.size() == 0:
			continue
		
		var img := Image.new()
		if img.load(anim.img_data.path) != OK:
			continue
		
		var texture := ImageTexture.create_from_image(img)
		var cell = AnimationNameCellScene.instantiate()
		
		var frame_rects: Array[Rect2] = []
		frame_rects.assign(anim.frame_rects)
		
		animations_grid.add_child(cell)
		cell.setup(texture, frame_rects, anim.display_name, anim)
		animation_previews.append(cell)
		animation_name_inputs[anim.original_name] = cell

func _on_preview_timer_timeout():
	for preview in animation_previews:
		if is_instance_valid(preview):
			preview.advance_frame()

func show_scan_view() -> void:
	scan_view.visible = true
	naming_view.visible = false

func get_animation_mappings() -> Dictionary:
	var mappings: Dictionary = {}
	for orig_name in animation_name_inputs:
		var cell = animation_name_inputs[orig_name]
		mappings[orig_name] = cell.get_custom_name()
	return mappings

func get_animations_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for orig_name in animation_name_inputs:
		var cell = animation_name_inputs[orig_name]
		data.append(cell.get_anim_data())
	return data
