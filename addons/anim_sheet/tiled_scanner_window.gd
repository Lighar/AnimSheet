@tool
extends Control

# -- Scan view UI --
@onready var select_zip_button: Button = %SelectZipButton
@onready var select_folder_button: Button = %SelectFolderButton
@onready var tree: Tree = %Tree
@onready var info_panel: VBoxContainer = %InfoPanel
@onready var status_label: Label = %StatusLabel
@onready var fps_spinbox: SpinBox = %FPSSpinBox
@onready var direction_option: OptionButton = %DirectionOption
@onready var validate_button: Button = %ValidateButton
@onready var select_all_button: Button = %SelectAllButton
@onready var select_none_button: Button = %SelectNoneButton
@onready var selection_label: Label = %SelectionLabel

# -- Naming view UI --
@onready var scan_view: Control = %ScanView
@onready var naming_view: Control = %NamingView
@onready var node_name_edit: LineEdit = %NodeNameEdit
@onready var animation_count_label: Label = %AnimationCountLabel
@onready var animations_grid: GridContainer = %AnimationsGrid
@onready var back_button: Button = %BackButton
@onready var export_anim_player_button: Button = %ExportAnimPlayerButton
@onready var export_animated_sprite_button: Button = %ExportAnimatedSpriteButton
@onready var github_button: Button = %GithubButton
@onready var github_confirm_dialog: ConfirmationDialog = %GithubConfirmDialog

# -- Source --
var current_zip_path: String = ""
var extracted_path: String = ""

# -- Scan results --
var scanned_images: Array[Dictionary] = []

# -- Animation settings --
var fps: int = 10
var is_horizontal: bool = true

# -- Managers --
var image_scanner: ImageScanner = null
var tree_manager: TreeManager = null
var info_panel_manager: InfoPanel = null
var naming_view_manager: NamingViewManager = null

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	ImageScanner.clear_temp_dirs()
	image_scanner = ImageScanner.new()
	tree_manager = TreeManager.new(tree)
	info_panel_manager = InfoPanel.new(info_panel, self)
	naming_view_manager = NamingViewManager.new(scan_view, naming_view, node_name_edit, animations_grid)

	tree_manager.item_selected.connect(_update_info_panel)
	tree_manager.selection_changed.connect(_on_selection_changed)
	select_zip_button.pressed.connect(_on_select_zip_pressed)
	select_folder_button.pressed.connect(_on_select_folder_pressed)
	validate_button.pressed.connect(_on_validate_pressed)
	select_all_button.pressed.connect(tree_manager.set_all_checked.bind(true))
	select_none_button.pressed.connect(tree_manager.set_all_checked.bind(false))
	back_button.pressed.connect(_on_back_pressed)
	export_anim_player_button.pressed.connect(_on_export_anim_player_pressed)
	export_animated_sprite_button.pressed.connect(_on_export_animated_sprite_pressed)
	github_button.pressed.connect(_on_github_button_pressed)
	github_confirm_dialog.confirmed.connect(_on_github_confirm)

	back_button.icon = get_theme_icon("Back", "EditorIcons")
	export_anim_player_button.icon = get_theme_icon("AnimationPlayer", "EditorIcons")
	export_animated_sprite_button.icon = get_theme_icon("AnimatedSprite2D", "EditorIcons")

	validate_button.disabled = true
	export_anim_player_button.disabled = true
	export_animated_sprite_button.disabled = true

	scan_view.visible = true
	naming_view.visible = false

	fps_spinbox.min_value = 1
	fps_spinbox.max_value = 60
	fps_spinbox.value = fps
	fps_spinbox.step = 1
	fps_spinbox.value_changed.connect(_on_animation_settings_changed)

	direction_option.clear()
	direction_option.add_item("Horizontal (Row-based)", 0)
	direction_option.add_item("Vertical (Column-based)", 1)
	direction_option.selected = 0 if is_horizontal else 1
	direction_option.item_selected.connect(_on_animation_settings_changed)

	tree_manager.setup()
	_update_export_buttons_state()
	_show_info_placeholder()

func _exit_tree() -> void:
	ImageScanner.clear_temp_dirs()

# ============================================================
# GITHUB
# ============================================================

func _on_github_button_pressed() -> void:
	github_confirm_dialog.popup_centered()

func _on_github_confirm() -> void:
	OS.shell_open("https://github.com/Lighar/AnimSheet")

# ============================================================
# FILE SELECTION
# ============================================================

func _on_select_zip_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.zip", "ZIP Archives")
	file_dialog.file_selected.connect(_on_zip_selected)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)

func _on_select_folder_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.dir_selected.connect(_on_folder_selected)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)

func _on_zip_selected(path: String) -> void:
	current_zip_path = path
	status_label.text = "Selected: " + path.get_file() + " - Scanning..."
	await get_tree().process_frame
	_extract_and_scan()

func _on_folder_selected(path: String) -> void:
	extracted_path = path
	status_label.text = "Selected folder: " + path.get_file() + " - Scanning..."
	await get_tree().process_frame
	_scan_images()

# ============================================================
# SCANNING
# ============================================================

func _extract_and_scan() -> void:
	extracted_path = ImageScanner.make_temp_dir()

	if not image_scanner.extract_zip(current_zip_path, extracted_path):
		status_label.text = "Error: Failed to open ZIP file"
		ImageScanner.remove_dir_recursive(extracted_path)
		return

	ImageScanner.clear_temp_dirs(extracted_path)
	_scan_images()

func _scan_images() -> void:
	scanned_images.clear()
	var image_files := image_scanner.find_image_files(extracted_path)

	status_label.text = "Found %d images, analyzing..." % image_files.size()
	await get_tree().process_frame

	var results: Array = []
	results.resize(image_files.size())
	if not image_files.is_empty():
		var group_id := WorkerThreadPool.add_group_task(
			func(i: int): results[i] = image_scanner.analyze_image(image_files[i]), image_files.size())
		while not WorkerThreadPool.is_group_task_completed(group_id):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_group_task_completion(group_id)

	var tiled_count := 0
	for result: Dictionary in results:
		if not result.is_empty():
			result["selected"] = false
			scanned_images.append(result)
			tiled_count += 1

	TiledImageExportUtils.share_preview_rects(scanned_images)
	tree_manager.populate(scanned_images, extracted_path, is_horizontal)

	_update_export_buttons_state()
	if tiled_count > 0:
		status_label.text = "Found %d tiled images out of %d total" % [tiled_count, image_files.size()]
	else:
		status_label.text = "No tiled images found"

# ============================================================
# SELECTION & STATE SYNC
# ============================================================

func _on_selection_changed() -> void:
	for img_data in scanned_images:
		img_data.selected = tree_manager.is_sheet_selected(img_data.path)
		img_data.anim_selection = tree_manager.checked_animations(img_data.path)
	tree_manager.update_duplicate_warnings(scanned_images)
	_update_export_buttons_state()

func _update_export_buttons_state() -> void:
	var count := _get_selected_items().size()
	validate_button.disabled = count == 0
	selection_label.text = "%d / %d selected" % [count, scanned_images.size()]

# ============================================================
# INFO PANEL & PREVIEW
# ============================================================

func _show_info_placeholder() -> void:
	info_panel_manager.show_placeholder()

func _update_info_panel(metadata: Dictionary, is_folder: bool) -> void:
	if metadata.is_empty():
		info_panel_manager.clear()
		return
	if is_folder:
		var folder_path: String = metadata.path
		var image_count := tree_manager.count_images_in_folder(folder_path)
		info_panel_manager.display_folder_info(folder_path, image_count)
	else:
		info_panel_manager.display_image_info(metadata, 0 if is_horizontal else 1)
		_add_animated_preview(metadata)

func _add_animated_preview(img_data: Dictionary) -> void:

	var preview_scene := preload("res://addons/anim_sheet/components/animation_preview_container.tscn")
	var preview_container = preview_scene.instantiate()

	if preview_container.setup(img_data.path, img_data, is_horizontal, fps):
		var selected := tree.get_selected()
		var meta = selected.get_metadata(0) if selected else null
		if meta is Dictionary and meta.get("type") == "anim":
			preview_container.current_index = clampi(meta.index, 0, preview_container.get_animation_count() - 1)

		# Get actual animation count from the preview
		var actual_count = preview_container.get_animation_count()
		
		# Update info panel with correct count
		info_panel_manager.display_image_info(img_data, 0 if is_horizontal else 1, actual_count)
		
		info_panel.add_child(preview_container)
		info_panel.move_child(preview_container, 0)
	else:
		preview_container.queue_free()

# ============================================================
# ANIMATION SETTINGS CHANGED
# ============================================================

func _on_animation_settings_changed(_value = null) -> void:
	fps = int(fps_spinbox.value)
	var horizontal := direction_option.selected == 0
	if horizontal != is_horizontal:
		is_horizontal = horizontal
		tree_manager.set_direction(is_horizontal)
	tree_manager._on_item_selected()

# ============================================================
# VALIDATION
# ============================================================

func _get_selected_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for img_data in scanned_images:
		if img_data.get("selected", false):
			result.append(img_data)
	return result

func _on_validate_pressed() -> void:
	var selected_items := _get_selected_items()

	if selected_items.is_empty():
		status_label.text = "No images selected"
		return

	var animations := TiledImageExportUtils.build_animation_list(selected_items, is_horizontal)
	naming_view_manager.show_naming_view(animations, fps, size.x)
	animation_count_label.text = "%d animation(s) from %d sheet(s)" % [naming_view_manager.animation_previews.size(), selected_items.size()]

	export_anim_player_button.disabled = false
	export_animated_sprite_button.disabled = false

func _on_back_pressed() -> void:
	naming_view_manager.show_scan_view()
	export_anim_player_button.disabled = true
	export_animated_sprite_button.disabled = true

# ============================================================
# EXPORT
# ============================================================

func _prepare_export_data() -> Dictionary:
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		status_label.text = "Error: No scene is currently open"
		return {}

	var animation_mappings := naming_view_manager.get_animation_mappings()
	var animations_data := naming_view_manager.get_animations_data()

	var selected_items := _get_selected_items()

	if selected_items.is_empty():
		status_label.text = "No images selected"
		return {}

	var node_name: String = node_name_edit.text if node_name_edit.text != "" else "MergedAnimations"

	return {
		"scene_root": scene_root,
		"selected_items": selected_items,
		"node_name": node_name,
		"animation_mappings": animation_mappings,
		"animations_data": animations_data
	}

func _get_export_parent(scene_root: Node) -> Node:
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node == scene_root or scene_root.is_ancestor_of(node):
			return node
	return scene_root

func _add_to_scene(node: Node, scene_root: Node) -> Node:
	var parent := _get_export_parent(scene_root)
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("AnimSheet: Export " + node.name, UndoRedo.MERGE_DISABLE, scene_root)
	undo_redo.add_do_method(parent, "add_child", node, true)
	for owned in [node] + node.get_children():
		undo_redo.add_do_method(owned, "set_owner", scene_root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()
	return parent

func _on_export_anim_player_pressed() -> void:
	var export_data := _prepare_export_data()
	if export_data.is_empty():
		return

	var anim_player := TiledImageExportUtils.export_to_animation_player(
		export_data.selected_items, fps,
		export_data.node_name, export_data.animation_mappings, export_data.animations_data
	)

	if anim_player:
		var parent := _add_to_scene(anim_player.get_parent(), export_data.scene_root)
		status_label.text = "Created AnimationPlayer with %d animation(s) under %s" % [anim_player.get_animation_list().size(), parent.name]
		_on_back_pressed()
	else:
		status_label.text = "Failed to create AnimationPlayer"

func _on_export_animated_sprite_pressed() -> void:
	var export_data := _prepare_export_data()
	if export_data.is_empty():
		return

	var animated_sprite := TiledImageExportUtils.export_to_animated_sprite(
		export_data.selected_items, fps,
		export_data.node_name, export_data.animation_mappings, export_data.animations_data
	)

	if animated_sprite:
		var parent := _add_to_scene(animated_sprite, export_data.scene_root)
		status_label.text = "Created AnimatedSprite2D with %d animation(s) under %s" % [animated_sprite.sprite_frames.get_animation_names().size(), parent.name]
		_on_back_pressed()
	else:
		status_label.text = "Failed to create AnimatedSprite2D"
