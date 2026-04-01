@tool
extends RefCounted
class_name InfoPanel

const InfoHeaderScene = preload("res://addons/tiled_image_scanner/components/info_header.tscn")
const InfoItemScene = preload("res://addons/tiled_image_scanner/components/info_item.tscn")

var panel: VBoxContainer
var theme_owner: Control

func _init(panel_control: VBoxContainer, owner: Control):
	panel = panel_control
	theme_owner = owner

func clear() -> void:
	for child in panel.get_children():
		child.queue_free()

func display_folder_info(folder_path: String, image_count: int) -> void:
	clear()
	
	add_header("Folder Info", "Folder")
	add_spacer()
	
	add_item("Path", folder_path, "FolderBrowse", Color(1.0, 0.9, 0.5))
	add_item("Images", str(image_count), "Image", Color(0.8, 1.0, 0.8))
	add_spacer()

func display_image_info(img_data: Dictionary, direction: int, actual_anim_count: int = -1) -> void:
	clear()
	
	add_header("SpriteSheet Info", "Image")
	add_spacer()
	
	add_item("File", img_data.filename, "File", Color(0.8, 0.8, 1.0))
	add_item("Sheet Size", "%d × %d px" % [img_data.width, img_data.height], "Ruler", Color(0.8, 1.0, 0.8))
	add_spacer()
	
	add_header("Grid Detection", "Grid")
	add_item("Cell Size", "%d × %d px" % [img_data.cell_width, img_data.cell_height], "Vector2", Color(1.0, 0.9, 0.6))
	add_item("Columns", str(img_data.columns), "GuiTreeArrowRight", Color(0.6, 0.8, 1.0))
	add_item("Rows", str(img_data.rows), "GuiTreeArrowDown", Color(0.6, 0.8, 1.0))
	add_item("Total Tiles", str(img_data.total_tiles), "Grid", Color(1.0, 0.8, 0.6))
	add_spacer()
	
	add_header("Animations", "AnimationPlayer")
	var is_horizontal := direction == 0
	
	if actual_anim_count > 0:
		var direction_text := "row" if is_horizontal else "column"
		add_item("Count", "%d %ss)" % [actual_anim_count, direction_text], "Animation", Color(1.0, 0.7, 0.9))

func add_header(text: String, icon_name: String) -> void:
	var header = InfoHeaderScene.instantiate()
	panel.add_child(header)
	header.setup(text, theme_owner.get_theme_icon(icon_name, "EditorIcons"))

func add_item(key: String, value: String, icon_name: String, color: Color) -> void:
	var item = InfoItemScene.instantiate()
	panel.add_child(item)
	item.setup(key, value, theme_owner.get_theme_icon(icon_name, "EditorIcons"), color)

func add_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	panel.add_child(spacer)

func show_placeholder(text: String = "Select an image to view details") -> void:
	clear()
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
