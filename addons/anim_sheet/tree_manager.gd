@tool
extends RefCounted
class_name TreeManager

signal item_selected(metadata: Dictionary, is_folder: bool)
signal selection_changed

var tree: Tree
var tree_items: Dictionary = {}
var folder_items: Dictionary = {}
var is_horizontal := true

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
	if metadata is Dictionary and metadata.get("type") == "anim":
		metadata = selected.get_parent().get_metadata(0)
	if metadata is Dictionary:
		var is_folder: bool = metadata.has("type") and metadata.type == "folder"
		item_selected.emit(metadata, is_folder)

func _on_item_edited() -> void:
	var edited := tree.get_edited()
	if not edited:
		return

	edited.propagate_check(1, false)
	selection_changed.emit()

func set_all_checked(checked: bool) -> void:
	var root := tree.get_root()
	var item := root.get_first_child() if root else null
	while item:
		item.set_checked(1, checked)
		item.propagate_check(1, false)
		item = item.get_next()
	selection_changed.emit()

func is_sheet_selected(path: String) -> bool:
	var item: TreeItem = tree_items.get(path)
	return item != null and (item.is_checked(1) or item.is_indeterminate(1))

func checked_animations(path: String) -> Array:
	var result: Array = []
	var item: TreeItem = tree_items.get(path)
	if item:
		for child in item.get_children():
			if child.is_checked(1):
				result.append(child.get_metadata(0).index)
	return result

func set_direction(horizontal: bool) -> void:
	is_horizontal = horizontal
	for item: TreeItem in tree_items.values():
		var selected := item.is_checked(1) or item.is_indeterminate(1)
		for child in item.get_children():
			child.free()
		item.set_indeterminate(1, false)
		item.set_checked(1, selected)
		_add_animation_items(item, item.get_metadata(0))
		item.propagate_check(1, false)
	selection_changed.emit()

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

func populate(images: Array[Dictionary], base_path: String, horizontal: bool) -> void:
	is_horizontal = horizontal
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
	_add_animation_items(item, img_data)
	
	tree_items[img_data.path] = item
	return item

func _add_animation_items(sheet_item: TreeItem, img_data: Dictionary) -> void:
	var count: int = img_data.get("animation_hashes", {}).get(is_horizontal, []).size()
	if count < 2:
		return
	var color := tree.get_theme_color("warning_color", "Editor") if tree.has_theme_color("warning_color", "Editor") else Color(1.0, 0.75, 0.3)
	for i in count:
		var child := tree.create_item(sheet_item)
		child.set_text(0, TiledImageExportUtils.animation_name(img_data, i, count, is_horizontal))
		child.set_icon(0, tree.get_theme_icon("Animation", "EditorIcons"))
		child.set_custom_color(0, color)
		child.set_metadata(0, {"type": "anim", "path": img_data.path, "index": i})
		child.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		child.set_editable(1, true)
		child.set_checked(1, sheet_item.is_checked(1))
	sheet_item.collapsed = true

func _get_relative_path(full_path: String, base_path: String) -> String:
	if base_path.is_empty():
		return full_path.get_file()
	
	if full_path.begins_with(base_path):
		var relative := full_path.substr(base_path.length())
		if relative.begins_with("/"):
			relative = relative.substr(1)
		return relative
	
	return full_path.get_file()

func update_duplicate_warnings(images: Array[Dictionary]) -> void:
	var checked_by_hash := {}
	for img_data in images:
		var sheet: TreeItem = tree_items.get(img_data.path)
		if sheet == null:
			continue
		var hashes: Array = img_data.get("animation_hashes", {}).get(is_horizontal, [])
		for i in hashes.size():
			var anim_item := sheet if sheet.get_child_count() == 0 else sheet.get_child(i)
			if anim_item.is_checked(1):
				checked_by_hash.get_or_add(hashes[i], []).append(anim_item)

	for sheet: TreeItem in tree_items.values():
		_clear_warning(sheet)
		for child in sheet.get_children():
			_clear_warning(child)

	var icon := tree.get_theme_icon("StatusWarning", "EditorIcons")
	for items: Array in checked_by_hash.values():
		if items.size() < 2:
			continue
		for item: TreeItem in items:
			var others: Array = items.filter(func(o): return o != item).map(_label)
			item.add_button(0, icon, -1, false, "Same frames as checked:\n%s\nExporting both duplicates this animation." % "\n".join(others))
			var parent := item.get_parent()
			if parent.get_metadata(0).get("type") != "folder" and parent.get_button_count(0) == 0:
				parent.add_button(0, icon, -1, false, "Some checked animations duplicate other checked animations.")

func _clear_warning(item: TreeItem) -> void:
	if item.get_button_count(0) > 0:
		item.erase_button(0, 0)

func _label(item: TreeItem) -> String:
	var meta: Dictionary = item.get_metadata(0)
	var sheet_label := TiledImageExportUtils.short_path(meta.path)
	return sheet_label + " › " + item.get_text(0) if meta.get("type") == "anim" else sheet_label

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
