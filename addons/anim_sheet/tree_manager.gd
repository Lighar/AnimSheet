@tool
extends RefCounted
class_name TreeManager

signal item_selected(metadata: Dictionary, is_folder: bool)
signal item_edited(affected_paths: Array, is_checked: bool)

var tree: Tree
var tree_items: Dictionary = {}
var folder_items: Dictionary = {}

func _init(tree_control: Tree):
	tree = tree_control
	tree.item_selected.connect(_on_item_selected)
	tree.item_edited.connect(_on_item_edited)

func _on_item_selected() -> void:
	var selected := tree.get_selected()
	if not selected:
		item_selected.emit({}, false)
		return
	
	var metadata = selected.get_metadata(0)
	if metadata is Dictionary:
		var is_folder: bool = metadata.has("type") and metadata.type == "folder"
		item_selected.emit(metadata, is_folder)

func _on_item_edited() -> void:
	var edited := tree.get_edited()
	if not edited:
		return
	
	var metadata = edited.get_metadata(0)
	var is_checked := edited.is_checked(1)
	var affected_paths: Array = []
	
	if metadata is Dictionary and metadata.has("type") and metadata.type == "folder":
		set_children_checked(edited, is_checked)
		affected_paths = _collect_image_paths_from_folder(edited)
	else:
		if metadata is Dictionary and metadata.has("path"):
			affected_paths.append(metadata.path)
		update_parent_folder_state(edited)
	
	item_edited.emit(affected_paths, is_checked)

func setup() -> void:
	tree.clear()
	tree.set_column_titles_visible(true)
	tree.set_columns(2)
	tree.set_column_title(0, "File Tree")
	tree.set_column_title(1, "Include")
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 60)
	tree.create_item()
	tree.hide_root = true

func populate(images: Array[Dictionary], base_path: String) -> void:
	tree.clear()
	tree_items.clear()
	folder_items.clear()
	var root := tree.create_item()
	
	var folder_structure := _build_folder_structure(images, base_path)
	
	for folder_path in folder_structure.keys():
		if folder_path == "":
			continue
		_create_folder_tree_item(root, folder_path, folder_structure)

func _build_folder_structure(images: Array[Dictionary], base_path: String) -> Dictionary:
	var structure := {}
	
	for img_data in images:
		var relative_path := _get_relative_path(img_data["path"], base_path)
		var folder_path := relative_path.get_base_dir()
		
		if folder_path == "":
			folder_path = "."
		
		# Build all parent folders in the path
		if folder_path != ".":
			var parts := folder_path.split("/")
			var current_path := ""
			
			for part in parts:
				var parent_path := current_path
				current_path = current_path.path_join(part) if current_path != "" else part
				
				if not structure.has(current_path):
					structure[current_path] = {
						"name": part,
						"path": current_path,
						"parent": parent_path,
						"images": []
					}
		
		if not structure.has(folder_path):
			structure[folder_path] = {
				"name": folder_path.get_file() if folder_path != "." else "Root",
				"path": folder_path,
				"parent": folder_path.get_base_dir(),
				"images": []
			}
		
		structure[folder_path]["images"].append(img_data)
	
	return structure

func _create_folder_tree_item(parent: TreeItem, folder_path: String, structure: Dictionary) -> TreeItem:
	if folder_items.has(folder_path):
		return folder_items[folder_path]
	
	if not structure.has(folder_path):
		return parent
	
	var folder_data: Dictionary = structure[folder_path]
	var parent_path: String = folder_data.get("parent", "")
	
	var actual_parent := parent
	if parent_path != "" and structure.has(parent_path):
		actual_parent = _create_folder_tree_item(parent, parent_path, structure)
	
	var folder_item := tree.create_item(actual_parent)
	folder_item.set_text(0, folder_data.get("name", folder_path.get_file()))
	folder_item.set_icon(0, tree.get_theme_icon("Folder", "EditorIcons"))
	folder_item.set_metadata(0, {"type": "folder", "path": folder_path})
	folder_item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	folder_item.set_editable(1, true)
	folder_item.set_checked(1, false)
	
	folder_items[folder_path] = folder_item
	
	for img_data in folder_data.images:
		_create_image_tree_item(folder_item, img_data)
	
	return folder_item

func _create_image_tree_item(parent: TreeItem, img_data: Dictionary) -> TreeItem:
	var item := tree.create_item(parent)
	item.set_text(0, img_data.filename)
	item.set_icon(0, tree.get_theme_icon("Image", "EditorIcons"))
	item.set_metadata(0, img_data)
	item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	item.set_editable(1, true)
	item.set_checked(1, false)
	
	tree_items[img_data.path] = item
	return item

func _get_relative_path(full_path: String, base_path: String) -> String:
	if base_path.is_empty():
		return full_path.get_file()
	
	if full_path.begins_with(base_path):
		var relative := full_path.substr(base_path.length())
		if relative.begins_with("/"):
			relative = relative.substr(1)
		return relative
	
	return full_path.get_file()

func set_children_checked(folder_item: TreeItem, checked: bool) -> void:
	var child := folder_item.get_first_child()
	while child:
		child.set_checked(1, checked)
		
		var child_metadata = child.get_metadata(0)
		if child_metadata is Dictionary:
			if child_metadata.has("type") and child_metadata.type == "folder":
				set_children_checked(child, checked)
		
		child = child.get_next()

func update_parent_folder_state(item: TreeItem) -> void:
	var parent := item.get_parent()
	if not parent or parent == tree.get_root():
		return
	
	var parent_metadata = parent.get_metadata(0)
	if not parent_metadata is Dictionary or not parent_metadata.has("type"):
		return
	if parent_metadata.type != "folder":
		return
	
	var child := parent.get_first_child()
	var all_checked := true
	
	while child:
		if not child.is_checked(1):
			all_checked = false
		child = child.get_next()
	
	parent.set_checked(1, all_checked)
	update_parent_folder_state(parent)

func count_images_in_folder(folder_path: String) -> int:
	var folder_item = folder_items.get(folder_path)
	if not folder_item:
		return 0
	return _collect_image_paths_from_folder(folder_item).size()

func _collect_image_paths_from_folder(folder_item: TreeItem) -> Array:
	var paths: Array = []
	var child := folder_item.get_first_child()
	
	while child:
		var child_metadata = child.get_metadata(0)
		if child_metadata is Dictionary:
			if child_metadata.has("type") and child_metadata.type == "folder":
				# Recursively collect from subfolders
				paths.append_array(_collect_image_paths_from_folder(child))
			elif child_metadata.has("path"):
				# It's an image file
				paths.append(child_metadata.path)
		
		child = child.get_next()
	
	return paths
