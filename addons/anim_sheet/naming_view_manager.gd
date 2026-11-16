@tool
extends RefCounted
class_name NamingViewManager

const AnimationNameCellScene = preload("res://addons/anim_sheet/components/animation_name_cell.tscn")

var scan_view: Control
var naming_view: Control
var node_name_edit: LineEdit
var animations_grid: GridContainer

var cells: Array = []

func _init(p_scan_view: Control, p_naming_view: Control, p_node_name_edit: LineEdit, p_animations_grid: GridContainer):
	scan_view = p_scan_view
	naming_view = p_naming_view
	node_name_edit = p_node_name_edit
	animations_grid = p_animations_grid

func show_naming_view(animations: Array[Dictionary], fps: int, window_width: float) -> void:
	scan_view.visible = false
	naming_view.visible = true
	
	node_name_edit.text = "ExportedAnimation"
	
	for child in animations_grid.get_children():
		child.queue_free()
	cells.clear()
	
	animations_grid.columns = max(1, int(window_width / 224))
	
	var textures := {}
	for anim in animations:
		var path: String = anim.img_data.path
		if not textures.has(path):
			var img := Image.new()
			textures[path] = ImageTexture.create_from_image(img) if img.load(path) == OK else null
		var texture: ImageTexture = textures[path]
		if texture == null:
			continue
		var cell = AnimationNameCellScene.instantiate()

		var frame_rects := TiledImageExportUtils.crop_rects(anim.frame_rects, anim.img_data.get("preview_rect", Rect2()))

		animations_grid.add_child(cell)
		cell.setup(texture, frame_rects, anim.display_name, anim, fps)
		cells.append(cell)

func show_scan_view() -> void:
	scan_view.visible = true
	naming_view.visible = false

func get_animations_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for cell in cells:
		data.append(cell.get_anim_data())
	TiledImageExportUtils.make_names_unique(data, "name")
	return data
