@tool
extends Control

# --- UI Elements ---
@onready var load_texture_button = $HSplitContainer/PanelContainer/VBoxContainer/LoadTextureButton
@onready var sprite_width_spinbox = $HSplitContainer/PanelContainer/VBoxContainer/HBoxContainer/SpriteWidthSpinBox
@onready var sprite_height_spinbox = $HSplitContainer/PanelContainer/VBoxContainer/HBoxContainer/SpriteHeightSpinBox
@onready var direction_option_button = $HSplitContainer/PanelContainer/VBoxContainer/DirectionOptionButton
@onready var frames_per_anim_spinbox = $HSplitContainer/PanelContainer/VBoxContainer/FramesPerAnimSpinBox
@onready var auto_detect_button = $HSplitContainer/PanelContainer/VBoxContainer/AutoDetectButton
@onready var clear_button = $HSplitContainer/PanelContainer/VBoxContainer/ClearButton
@onready var fps_spinbox = $HSplitContainer/PanelContainer/VBoxContainer/FpsSpinBox
# New UI elements for output format selection
@onready var output_format_option = $HSplitContainer/PanelContainer/VBoxContainer/OutputFormatContainer/OutputFormatOption
@onready var generate_button = $HSplitContainer/PanelContainer/VBoxContainer/GenerateButton
@onready var status_label = $HSplitContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var texture_display = $HSplitContainer/PanelContainer2/TextureDisplay

# --- Plugin State ---
var sprite_sheet_texture: Texture2D = null
var sprite_sheet_image: Image = null
var sprite_width: int = 32
var sprite_height: int = 32
var sheet_direction: int = 0 # 0: Horizontal, 1: Vertical
var frames_per_animation: int = 0 # 0 = full row/col
var output_format: int = 0 # 0: AnimationPlayer, 1: AnimatedSprite2D

var animations: Array[Dictionary] = [] # {"name": String, "rect": Rect2, "frames": Array[Vector2i], "color": Color}
var colors: Array[Color] = [
									Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.PURPLE,
									Color.ORANGE, Color.CYAN, Color.MAGENTA, Color.LIME
									]
var next_color_index: int = 0
var next_anim_index: int = 1

# --- Interaction State ---
var dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_current_pos: Vector2 = Vector2.ZERO
var renaming_anim_index: int = -1

# --- Dialogs ---
var file_dialog: FileDialog

# --- Initialization ---
func _ready():
	load_texture_button.pressed.connect(_on_load_texture_pressed)
	sprite_width_spinbox.value_changed.connect(_on_parameter_changed)
	sprite_height_spinbox.value_changed.connect(_on_parameter_changed)
	direction_option_button.item_selected.connect(_on_parameter_changed)
	frames_per_anim_spinbox.value_changed.connect(_on_parameter_changed)
	output_format_option.item_selected.connect(_on_output_format_changed)
	auto_detect_button.pressed.connect(_on_auto_detect_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	generate_button.pressed.connect(_on_generate_pressed)
	texture_display.gui_input.connect(_on_texture_display_gui_input)
	texture_display.draw.connect(_on_texture_display_draw)

	_on_parameter_changed() # Sync script vars

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.png; PNG Image")
	file_dialog.add_filter("*.jpg; JPG Image")
	file_dialog.add_filter("*.jpeg; JPEG Image")
	file_dialog.add_filter("*.webp; WEBP Image")
	file_dialog.add_filter("*.svg; SVG Image")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	update_status("Ready. Load a sprite sheet.")
	update_generate_button_state()


# --- UI Update Functions ---
func update_status(text: String):
	status_label.text = "Status: " + text
	print("[SpriteSheetAnimator] ", text)

func update_generate_button_state():
	var can_generate = sprite_sheet_texture != null and not animations.is_empty()
	generate_button.disabled = not can_generate

	if generate_button.disabled:
		if sprite_sheet_texture == null:
			generate_button.tooltip_text = "Load a sprite sheet first."
		elif animations.is_empty():
			generate_button.tooltip_text = "Define animation outlines first (Auto-Detect or Drag)."
		else:
			generate_button.tooltip_text = ""
	else:
		var format_text = "AnimationPlayer" if output_format == 0 else "AnimatedSprite2D"
		generate_button.tooltip_text = "Generate a new Sprite2D + %s in the current scene." % format_text


# --- Signal Handlers ---
func _on_load_texture_pressed():
	file_dialog.popup_centered_ratio(0.8)

func _on_file_selected(path: String):
	var loaded_texture = ResourceLoader.load(path)
	if loaded_texture is Texture2D:
		sprite_sheet_texture = loaded_texture
		texture_display.texture = sprite_sheet_texture
		sprite_sheet_image = sprite_sheet_texture.get_image()
		if sprite_sheet_image == null:
			update_status("Warning: Could not get image data from texture. Transparency check unavailable.")
		else:
			if sprite_sheet_image.is_compressed():
				var err = sprite_sheet_image.decompress()
				if err != OK:
					update_status("Warning: Error decompressing image. Transparency check might fail.")
			#check if alpha channel is present
			if sprite_sheet_image.get_format() < Image.FORMAT_LA8:
				sprite_sheet_image.convert(Image.FORMAT_RGBA8)

		clear_animations()
		update_status("Sprite sheet loaded: " + path.get_file())
		_on_parameter_changed()
		texture_display.queue_redraw()
	else:
		update_status("Error: Selected file is not a valid Texture2D.")
		sprite_sheet_texture = null
		sprite_sheet_image = null
		texture_display.texture = null
	update_generate_button_state()


func _on_parameter_changed(value = null):
	sprite_width = max(1, int(sprite_width_spinbox.value))
	sprite_height = max(1, int(sprite_height_spinbox.value))
	sheet_direction = direction_option_button.selected
	frames_per_animation = max(0, int(frames_per_anim_spinbox.value))
	texture_display.queue_redraw()

func _on_output_format_changed(index: int):
	output_format = index
	update_generate_button_state()
	var format_text = "AnimationPlayer" if output_format == 0 else "AnimatedSprite2D"
	update_status("Output format changed to: " + format_text)

func _on_auto_detect_pressed():
	if not sprite_sheet_texture:
		update_status("Error: Load a sprite sheet first.")
		return
	if sprite_width <= 0 or sprite_height <= 0:
		update_status("Error: Sprite Width and Height must be greater than 0.")
		return

	clear_animations()

	var tex_w = sprite_sheet_texture.get_width()
	var tex_h = sprite_sheet_texture.get_height()
	var cols = floori(float(tex_w) / sprite_width)
	var rows = floori(float(tex_h) / sprite_height)

	if cols == 0 or rows == 0:
		update_status("Error: Sprite dimensions (%sx%s) are larger than texture dimensions (%sx%s)." % [sprite_width, sprite_height, tex_w, tex_h])
		return
	if cols * sprite_width != tex_w or rows * sprite_height != tex_h:
		update_status("Warning: Texture dimensions are not exact multiples of sprite size. Detection might miss edges.")


	var use_full_line = frames_per_animation == 0
	var max_frames_override = frames_per_animation if not use_full_line else -1

	var anim_index = 0
	var last_line_had_content = false

	if sheet_direction == 0: # Horizontal
		for r in range(rows):
			var current_anim_frames: Array[Vector2i] = []
			var start_col = -1
			var current_frame_count = 0
			var line_has_content = false
			for c in range(cols):
				var frame_coord = Vector2i(c, r)
				if is_sprite_transparent(frame_coord):
					if start_col != -1:
						add_animation_definition(start_col, r, c - 1, r, current_anim_frames)
						start_col = -1
						current_anim_frames = []
						current_frame_count = 0
						last_line_had_content = true
				else:
					line_has_content = true
					if start_col == -1:
						start_col = c
					current_anim_frames.append(frame_coord)
					current_frame_count += 1
					if not use_full_line and current_frame_count >= max_frames_override:
						add_animation_definition(start_col, r, c, r, current_anim_frames)
						start_col = -1
						current_anim_frames = []
						current_frame_count = 0
						last_line_had_content = true

			if start_col != -1:
				add_animation_definition(start_col, r, cols - 1, r, current_anim_frames)
				last_line_had_content = true

			if not line_has_content and last_line_had_content:
				pass
			elif not line_has_content:
				last_line_had_content = false

	else: # Vertical
		for c in range(cols):
			var current_anim_frames: Array[Vector2i] = []
			var start_row = -1
			var current_frame_count = 0
			var line_has_content = false
			for r in range(rows):
				var frame_coord = Vector2i(c, r)
				if is_sprite_transparent(frame_coord):
					if start_row != -1:
						add_animation_definition(c, start_row, c, r - 1, current_anim_frames)
						start_row = -1
						current_anim_frames = []
						current_frame_count = 0
						last_line_had_content = true
				else:
					line_has_content = true
					if start_row == -1:
						start_row = r
					current_anim_frames.append(frame_coord)
					current_frame_count += 1
					if not use_full_line and current_frame_count >= max_frames_override:
						add_animation_definition(c, start_row, c, r, current_anim_frames)
						start_row = -1
						current_anim_frames = []
						current_frame_count = 0
						last_line_had_content = true

			if start_row != -1:
				add_animation_definition(c, start_row, c, rows - 1, current_anim_frames)
				last_line_had_content = true

			if not line_has_content and last_line_had_content:
				pass
			elif not line_has_content:
				last_line_had_content = false

	update_status("Auto-detection complete. Found %d animations." % animations.size())
	texture_display.queue_redraw()
	update_generate_button_state()


func is_sprite_transparent(grid_coord: Vector2i) -> bool:
	if not sprite_sheet_image: return false
	var px = grid_coord.x * sprite_width
	var py = grid_coord.y * sprite_height
	var img_w = sprite_sheet_image.get_width()
	var img_h = sprite_sheet_image.get_height()

	if px >= img_w or py >= img_h: return true
	var check_width = min(sprite_width, img_w - px)
	var check_height = min(sprite_height, img_h - py)
	if check_width <= 0 or check_height <= 0: return true

	for y in range(py, py + check_height):
		for x in range(px, px + check_width):
			var pixel_color = sprite_sheet_image.get_pixel(x, y)
			if pixel_color.a > 0.01:
				return false
	return true


func _on_clear_pressed():
	clear_animations()
	update_status("Animation outlines cleared.")
	texture_display.queue_redraw()
	update_generate_button_state()


# --- Generation Logic ---
func _on_generate_pressed():
	if not sprite_sheet_texture:
		update_status("Error: No sprite sheet loaded.")
		return
	if animations.is_empty():
		update_status("Error: No animations defined.")
		return

	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		update_status("Error: Cannot find the edited scene root. Open a scene first.")
		return

	if output_format == 0:
		generate_animation_player_format()
	else:
		generate_animated_sprite_format()

func generate_animation_player_format():
	# --- Calculate Frame Data ---
	var tex_w = sprite_sheet_texture.get_width()
	var tex_h = sprite_sheet_texture.get_height()
	if sprite_width <= 0 or sprite_height <= 0:
		update_status("Error: Sprite Width and Height must be greater than 0.")
		return
	var hframes = floori(float(tex_w) / sprite_width)
	var vframes = floori(float(tex_h) / sprite_height)

	if hframes <= 0 or vframes <= 0:
		update_status("Error: Calculated hframes/vframes are zero or less. Check sprite dimensions.")
		return

	if hframes * sprite_width != tex_w or vframes * sprite_height != tex_h:
		update_status("Warning: Texture dimensions are not exact multiples of sprite size. Frame calculation might be inaccurate.")

	var scene_root = EditorInterface.get_edited_scene_root()

	# --- Create and Configure New Sprite2D ---
	var new_sprite = Sprite2D.new()
	new_sprite.name = sprite_sheet_texture.resource_path.get_file().get_basename() + "Sprite"

	new_sprite.texture = sprite_sheet_texture
	new_sprite.hframes = hframes
	new_sprite.vframes = vframes
	new_sprite.frame_coords = Vector2i.ZERO

	# --- Create AnimationPlayer ---
	var anim_player = AnimationPlayer.new()
	anim_player.name = new_sprite.name + "AnimationPlayer"

	# --- Add Nodes to Scene ---
	scene_root.add_child(new_sprite)
	new_sprite.owner = scene_root

	new_sprite.add_child(anim_player)
	anim_player.owner = scene_root

	update_status("Created new Sprite2D: '%s'" % new_sprite.name)

	# --- Create Animation Library ---
	var anim_library = AnimationLibrary.new()
	var fps = float(fps_spinbox.value)
	var frame_duration = 1.0 / fps if fps > 0 else 0.1

	for anim_data in animations:
		var anim = Animation.new()
		anim.loop_mode = Animation.LOOP_LINEAR

		var frame_coords_array: Array = anim_data["frames"]
		if frame_coords_array.is_empty():
			print("[SpriteSheetAnimator] Skipping animation '%s' with no frames." % anim_data["name"])
			continue

		anim.length = frame_coords_array.size() * frame_duration

		var track_idx = anim.add_track(Animation.TYPE_VALUE)
		var path_to_sprite = NodePath(".")
		anim.track_set_path(track_idx, str(path_to_sprite) + ":frame_coords")
		anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)

		# Insert keyframes
		for i in range(frame_coords_array.size()):
			var time = i * frame_duration
			var frame_coord: Vector2i = frame_coords_array[i]
			anim.track_insert_key(track_idx, time, frame_coord)

		var anim_name = anim_data["name"]
		if anim_library.has_animation(anim_name):
			var count = 2
			var base_name = anim_name
			while anim_library.has_animation(anim_name):
				anim_name = base_name + str(count)
				count += 1
			update_status("Warning: Duplicate animation name '%s' found, renamed to %s" % [base_name, anim_name])

		anim_library.add_animation(anim_name, anim)

	anim_player.add_animation_library("", anim_library)

	update_status("AnimationPlayer generated successfully for '%s'!" % new_sprite.name)
	EditorInterface.edit_node(new_sprite)

func generate_animated_sprite_format():
	var scene_root = EditorInterface.get_edited_scene_root()

	# --- Create AnimatedSprite2D ---
	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = sprite_sheet_texture.resource_path.get_file().get_basename() + "AnimatedSprite"

	# --- Create SpriteFrames ---
	var sprite_frames = SpriteFrames.new()
	var fps = float(fps_spinbox.value)

	# --- Calculate frame dimensions ---
	var tex_w = sprite_sheet_texture.get_width()
	var tex_h = sprite_sheet_texture.get_height()
	var frame_width = sprite_width
	var frame_height = sprite_height

	# --- Process each animation ---
	for anim_data in animations:
		var anim_name: String = anim_data["name"]
		var frame_coords_array: Array = anim_data["frames"]

		if frame_coords_array.is_empty():
			continue

		# Add animation to SpriteFrames
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, fps)
		sprite_frames.set_animation_loop(anim_name, true)

		# Create frames for this animation
		for frame_coord in frame_coords_array:
			var coord = frame_coord as Vector2i

			# Create AtlasTexture for each frame
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = sprite_sheet_texture
			atlas_texture.region = Rect2(
				coord.x * frame_width,
				coord.y * frame_height,
				frame_width,
				frame_height
			)

			sprite_frames.add_frame(anim_name, atlas_texture)

	# --- Configure AnimatedSprite2D ---
	animated_sprite.sprite_frames = sprite_frames

	# Set first animation as current if available
	var anim_names = sprite_frames.get_animation_names()
	if not anim_names.is_empty():
		animated_sprite.animation = anim_names[0]

	# --- Add to scene ---
	scene_root.add_child(animated_sprite)
	animated_sprite.owner = scene_root

	update_status("AnimatedSprite2D generated successfully: '%s'!" % animated_sprite.name)
	EditorInterface.edit_node(animated_sprite)

# --- Drawing and Interaction ---
func _on_texture_display_draw():
	if not is_instance_valid(texture_display): return
	if not sprite_sheet_texture: return

	# Draw Grid
	var tex_w = sprite_sheet_texture.get_width()
	var tex_h = sprite_sheet_texture.get_height()
	var grid_color = Color(0.5, 0.5, 0.5, 0.3)
	if sprite_width > 0 and sprite_height > 0:
		for x in range(sprite_width, tex_w, sprite_width):
			texture_display.draw_line(Vector2(x, 0), Vector2(x, tex_h), grid_color, 1.0)
		for y in range(sprite_height, tex_h, sprite_height):
			texture_display.draw_line(Vector2(0, y), Vector2(tex_w, y), grid_color, 1.0)

	# Draw animation outlines and names
	var font = ThemeDB.get_fallback_font()
	var font_size = ThemeDB.get_fallback_font_size()

	for i in range(animations.size()):
		var anim_data = animations[i]
		var rect: Rect2 = anim_data["rect"]
		var color: Color = anim_data["color"]
		var name: String = anim_data["name"]

		texture_display.draw_rect(rect, color, false, 2.0)

		var label_pos = get_label_pos(rect, font_size)
		var label_rect = get_label_rect(name, rect, font, font_size)
		texture_display.draw_string(font, label_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	if dragging:
		var drag_rect = Rect2(drag_start_pos, drag_current_pos - drag_start_pos).abs()
		texture_display.draw_rect(drag_rect, Color.WHITE, false, 1.0)

func get_label_pos(rect: Rect2, font_size: int) -> Vector2:
	var label_pos = rect.position + Vector2(rect.size.x + 2, + (font_size + 2))
	if label_pos.y < 0: label_pos.y = rect.position.y + 2
	if label_pos.x < 0: label_pos.x = 2
	return label_pos

func get_label_rect(animation_name: String, rect: Rect2, font: Font, font_size: int) -> Rect2:
	var label_pos = get_label_pos(rect, font_size)
	var label_size = font.get_string_size(animation_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var label_rect = Rect2(label_pos+Vector2(0,-font_size), label_size)
	return label_rect

func _on_texture_display_gui_input(event: InputEvent):
	if not sprite_sheet_texture: return

	if event is InputEventMouseButton:
		var mouse_pos = texture_display.get_local_mouse_position()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on a name label for renaming
				var clicked_on_name = false
				var font = ThemeDB.get_fallback_font()
				var font_size = ThemeDB.get_fallback_font_size()

				for i in range(animations.size()):
					var anim_data = animations[i]
					var rect: Rect2 = anim_data["rect"]

					var label_rect = get_label_rect(anim_data["name"], rect, font, font_size).grow(2.0)

					if label_rect.has_point(mouse_pos):
						start_rename_animation(i)
						clicked_on_name = true
						accept_event()
						break

				if not clicked_on_name:
					# Start dragging
					dragging = true
					drag_start_pos = mouse_pos
					drag_current_pos = mouse_pos
					texture_display.queue_redraw()
					accept_event()

				# Button released after dragging
			elif dragging:
				dragging = false
				var drag_end_pos = mouse_pos
				var final_rect = Rect2(drag_start_pos, drag_end_pos - drag_start_pos).abs()
				add_manual_animation(final_rect)
				texture_display.queue_redraw()
				accept_event()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Delete animation region on right click
			var deleted = false
			for i in range(animations.size() - 1, -1, -1):
				var anim_data = animations[i]
				var rect: Rect2 = anim_data["rect"]
				if rect.grow(2.0).has_point(mouse_pos):
					var removed_name = animations[i]["name"]
					animations.remove_at(i)
					deleted = true
					update_status("Removed animation: " + removed_name)
					texture_display.queue_redraw()
					update_generate_button_state()
					accept_event()
					break
			if deleted:
				find_next_name_number()

	elif event is InputEventMouseMotion and dragging:
		drag_current_pos = texture_display.get_local_mouse_position()
		texture_display.queue_redraw()
		accept_event()


# --- Animation Definition Logic ---

func clear_animations():
	animations.clear()
	next_anim_index = 1
	next_color_index = 0


func add_manual_animation(pixel_rect: Rect2):
	if sprite_width <= 0 or sprite_height <= 0: return
	if not sprite_sheet_texture: return

	# Convert pixel rect to grid coordinates
	var start_col = floori(pixel_rect.position.x / sprite_width)
	var start_row = floori(pixel_rect.position.y / sprite_height)
	# Subtract small epsilon before dividing for end to handle edge cases
	var end_col = floori((pixel_rect.position.x + pixel_rect.size.x - 0.01) / sprite_width)
	var end_row = floori((pixel_rect.position.y + pixel_rect.size.y - 0.01) / sprite_height)

	# Clamp to valid grid range
	var max_cols = floori(float(sprite_sheet_texture.get_width()) / sprite_width)
	var max_rows = floori(float(sprite_sheet_texture.get_height()) / sprite_height)
	start_col = clamp(start_col, 0, max_cols - 1)
	start_row = clamp(start_row, 0, max_rows - 1)
	end_col = clamp(end_col, 0, max_cols - 1)
	end_row = clamp(end_row, 0, max_rows - 1)

	if start_col > end_col or start_row > end_row:
		update_status("Invalid drag region (zero or negative size in grid).")
		return

	# Gather non-transparent frames within the grid region
	var frame_coords: Array[Vector2i] = []
	if sheet_direction == 0: # Horizontal reading order
		for r in range(start_row, end_row + 1):
			for c in range(start_col, end_col + 1):
				var coord = Vector2i(c, r)
				if not is_sprite_transparent(coord):
					frame_coords.append(coord)
	else: # Vertical reading order
		for c in range(start_col, end_col + 1):
			for r in range(start_row, end_row + 1):
				var coord = Vector2i(c, r)
				if not is_sprite_transparent(coord):
					frame_coords.append(coord)

	if frame_coords.is_empty():
		update_status("Manual region contains no non-transparent frames.")
		return

	# Add the definition
	add_animation_definition(start_col, start_row, end_col, end_row, frame_coords)
	if not animations.is_empty():
		update_status("Manually added animation: " + animations[-1]["name"])
		texture_display.queue_redraw()
		update_generate_button_state()


func add_animation_definition(start_col: int, start_row: int, end_col: int, end_row: int, frame_coords: Array[Vector2i]):
	if frame_coords.is_empty(): return

	# Generate unique default name
	var base_name = "Anim"
	var anim_name = base_name + str(next_anim_index).pad_zeros(3)
	var name_exists = true
	while name_exists:
		name_exists = false
		for existing_anim in animations:
			if existing_anim["name"] == anim_name:
				next_anim_index += 1
				anim_name = base_name + str(next_anim_index).pad_zeros(3)
				name_exists = true
				break
	next_anim_index += 1 # Increment for the *next* animation

	# Calculate pixel rectangle for drawing
	var anim_rect = Rect2(
						start_col * sprite_width,
						start_row * sprite_height,
						(end_col - start_col + 1) * sprite_width,
						(end_row - start_row + 1) * sprite_height
					)

	# Assign next color
	var anim_color = colors[next_color_index % colors.size()]
	next_color_index += 1

	# Store the animation data
	animations.append({
		"name": anim_name,
		"rect": anim_rect,
		"frames": frame_coords,
		"color": anim_color
	})

func find_next_name_number():
	var max_default_num = 0
	for anim_data in animations:
		var name: String = anim_data["name"]
		if name.begins_with("Anim") and name.substr(4).is_valid_int():
			max_default_num = max(max_default_num, name.substr(4).to_int())
	next_anim_index = max_default_num + 1


# --- Renaming Logic ---
func start_rename_animation(index: int):
	if index < 0 or index >= animations.size(): return

	renaming_anim_index = index
	var anim_data = animations[index]

	var popup = ConfirmationDialog.new()
	popup.title = "Rename Animation"
	var line_edit = LineEdit.new()
	line_edit.text = anim_data["name"]
	line_edit.placeholder_text = "Enter new animation name"
	line_edit.select_all_on_focus = true
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup.add_child(line_edit)
	# Defer focus grab until popup is shown
	line_edit.grab_focus.call_deferred()

	popup.connect("confirmed", Callable(self, "_on_rename_confirmed").bind(popup, line_edit, index), CONNECT_ONE_SHOT)
	popup.connect("canceled", Callable(self, "_on_rename_canceled"), CONNECT_ONE_SHOT)
	# Ensure popup is freed when closed
	popup.connect("popup_hide", Callable(popup, "queue_free"))

	add_child(popup)
	popup.popup_centered()


func _on_rename_confirmed(popup: ConfirmationDialog, line_edit: LineEdit, index: int):
	var new_name = line_edit.text.strip_edges()
	if index >= 0 and index < animations.size():
		if not new_name.is_empty():
			var name_exists = false
			for i in range(animations.size()):
				if i != index and animations[i]["name"] == new_name:
					name_exists = true
					break
			if name_exists:
				update_status("Error: Animation name '%s' already exists." % new_name)
				var err_dialog = AcceptDialog.new()
				err_dialog.dialog_text = "Error: Animation name '%s' already exists." % new_name
				add_child(err_dialog)
				err_dialog.popup_centered()
				err_dialog.connect("popup_hide", Callable(err_dialog, "queue_free"), CONNECT_ONE_SHOT)
				line_edit.grab_focus()
			else:
				animations[index]["name"] = new_name
				update_status("Renamed animation to '%s'." % new_name)
				texture_display.queue_redraw()
				renaming_anim_index = -1
		else:
			update_status("Error: Animation name cannot be empty.")
			line_edit.grab_focus()
	else:
		update_status("Error: Could not rename animation (invalid index).")
		renaming_anim_index = -1

func _on_rename_canceled():
	renaming_anim_index = -1
	update_status("Rename canceled.")

func _exit_tree():
	if is_instance_valid(file_dialog):
		file_dialog.queue_free()
