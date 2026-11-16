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
	tree.item_selected.connect(refresh_selection)
	tree.item_edited.connect(_on_item_edited)

func refresh_selection() -> void:
	var selected := tree.get_selected()
	if not selected:
		item_selected.emit({}, false)
		return
	
	var metadata = selected.get_metadata(0)
	if metadata is Dictionary and metadata.get("type") == "anim":
		metadata = selected.get_parent().get_metadata(0)
	if metadata is Dictionary:
		item_selected.emit(metadata, metadata.get("type") == "folder")

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
	for img_data in images:
		var folder_path: String = img_data.path.trim_prefix(base_path).trim_prefix("/").get_base_dir()
		var folder := _get_folder_item(root, folder_path if folder_path != "" else ".")
		var item := _create_checkable_item(folder, img_data.filename, "Image", img_data)
		_add_animation_items(item, img_data)
		tree_items[img_data.path] = item

func _get_folder_item(root: TreeItem, folder_path: String) -> TreeItem:
	if not folder_items.has(folder_path):
		var parent_path := folder_path.get_base_dir()
		var parent := _get_folder_item(root, parent_path) if parent_path != "" else root
		var label := folder_path.get_file() if folder_path != "." else "Root"
		folder_items[folder_path] = _create_checkable_item(parent, label, "Folder", {"type": "folder", "path": folder_path})
	return folder_items[folder_path]

func _add_animation_items(sheet_item: TreeItem, img_data: Dictionary) -> void:
	var count: int = img_data.get("animation_hashes", {}).get(is_horizontal, []).size()
	if count < 2:
		return
	var color := tree.get_theme_color("warning_color", "Editor") if tree.has_theme_color("warning_color", "Editor") else Color(1.0, 0.75, 0.3)
	for i in count:
		var child := _create_checkable_item(sheet_item, TiledImageExportUtils.animation_name(img_data, i, count, is_horizontal),
				"Animation", {"type": "anim", "path": img_data.path, "index": i})
		child.set_custom_color(0, color)
		child.set_checked(1, sheet_item.is_checked(1))
	sheet_item.collapsed = true

func _create_checkable_item(parent: TreeItem, text: String, icon_name: String, metadata: Dictionary) -> TreeItem:
	var item := tree.create_item(parent)
	item.set_text(0, text)
	item.set_icon(0, tree.get_theme_icon(icon_name, "EditorIcons"))
	item.set_metadata(0, metadata)
	item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	item.set_editable(1, true)
	return item

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
	var folder_item: TreeItem = folder_items.get(folder_path)
	return _count_images(folder_item) if folder_item else 0

func _count_images(folder_item: TreeItem) -> int:
	var count := 0
	for child in folder_item.get_children():
		count += _count_images(child) if child.get_metadata(0).get("type") == "folder" else 1
	return count
