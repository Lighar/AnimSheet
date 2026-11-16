@tool
class_name TiledImageExportUtils

static func _is_frame_empty(img: Image, x: int, y: int, width: int, height: int) -> bool:
	for py in range(y, y + height):
		for px in range(x, x + width):
			if img.get_pixel(px, py).a > 0.01:
				return false
	return true

static func extract_animation_frames(img: Image, img_data: Dictionary, is_horizontal: bool) -> Array[Array]:
	var all_animations: Array[Array] = []
	var cw: int = img_data.cell_width
	var ch: int = img_data.cell_height
	var outer: int = img_data.rows if is_horizontal else img_data.columns
	var inner: int = img_data.columns if is_horizontal else img_data.rows

	for i in range(outer):
		var frame_rects: Array[Rect2] = []
		for j in range(inner):
			var col := j if is_horizontal else i
			var row := i if is_horizontal else j
			var x: int = img_data.offset_x + col * cw
			var y: int = img_data.offset_y + row * ch
			if x >= 0 and y >= 0 and x + cw <= img.get_width() and y + ch <= img.get_height() \
					and not _is_frame_empty(img, x, y, cw, ch):
				frame_rects.append(Rect2(x, y, cw, ch))
		if not frame_rects.is_empty():
			all_animations.append(frame_rects)

	return all_animations

static func strip_common_prefix(animations: Array[Dictionary]) -> void:
	if animations.size() < 2:
		return
	var prefix: String = animations[0].display_name
	for anim in animations:
		while not anim.display_name.begins_with(prefix):
			prefix = prefix.left(-1)
	var cut := -1
	for sep in ["-", "_", " ", "."]:
		cut = max(cut, prefix.rfind(sep))
	if cut < 0:
		return
	for anim in animations:
		var rest: String = anim.display_name.substr(cut + 1)
		if rest.is_empty() or rest[0].is_valid_int():
			return
	for anim in animations:
		anim.display_name = anim.display_name.substr(cut + 1)

static func share_preview_rects(images: Array[Dictionary]) -> void:
	var by_cell := {}
	for img_data in images:
		var key := Vector2i(img_data.cell_width, img_data.cell_height)
		var u: Rect2 = img_data.get("content_rect", Rect2())
		if u.has_area():
			var cur: Rect2 = by_cell.get(key, Rect2())
			by_cell[key] = cur.merge(u) if cur.has_area() else u
	for img_data in images:
		img_data.preview_rect = by_cell.get(Vector2i(img_data.cell_width, img_data.cell_height), Rect2())

static func crop_rects(rects: Array, used: Rect2) -> Array[Rect2]:
	var cropped: Array[Rect2] = []
	for r: Rect2 in rects:
		cropped.append(Rect2(r.position + used.position, used.size) if used.has_area() else r)
	return cropped

static func short_path(path: String) -> String:
	return path.get_base_dir().get_file().path_join(path.get_file())

static func animation_name(img_data: Dictionary, index: int, count: int, is_horizontal: bool) -> String:
	var base_name: String = img_data.filename.get_basename()
	if count == 1:
		return base_name
	return base_name + ("_row_%d" if is_horizontal else "_col_%d") % index

static func make_names_unique(animations: Array, key: String) -> void:
	var used := {}
	for anim in animations:
		var base: String = anim[key]
		var unique := base
		var n := 1
		while used.has(unique):
			n += 1
			unique = "%s_%d" % [base, n]
		used[unique] = true
		anim[key] = unique

static func build_animation_list(selected_items: Array, is_horizontal: bool) -> Array[Dictionary]:
	var animations: Array[Dictionary] = []

	for img_data in selected_items:
		var all_frame_rects: Array = img_data.animations[is_horizontal]
		var anim_count := all_frame_rects.size()

		var only: Array = img_data.get("anim_selection", [])
		for i in range(anim_count):
			if not only.is_empty() and not only.has(i):
				continue
			var frame_rects: Array[Rect2] = []
			frame_rects.assign(all_frame_rects[i])
			animations.append({
				"display_name": animation_name(img_data, i, anim_count, is_horizontal),
				"img_data": img_data,
				"frame_rects": frame_rects
			})

	strip_common_prefix(animations)
	make_names_unique(animations, "display_name")
	return animations

static func _merge_images_into_sheet(selected_items: Array) -> Dictionary:
	if selected_items.is_empty():
		return {}
	
	var max_cell_width := 0
	var max_cell_height := 0
	var total_rows := 0
	var columns := 0
	var image_infos: Array[Dictionary] = []
	var start_rows := {}

	for img_data in selected_items:
		var img := Image.new()
		if img.load(img_data.path) != OK:
			push_warning("AnimSheet: skipped unreadable image: " + str(img_data.path))
			continue

		max_cell_width = max(max_cell_width, img_data.cell_width)
		max_cell_height = max(max_cell_height, img_data.cell_height)
		columns = max(columns, img_data.columns)
		image_infos.append({"image": img, "data": img_data, "start_row": total_rows})
		start_rows[img_data.path] = total_rows
		total_rows += img_data.rows

	if image_infos.is_empty():
		return {}

	var merged_width := max_cell_width * columns
	var merged_height := max_cell_height * total_rows
	var merged_img := Image.create(merged_width, merged_height, false, Image.FORMAT_RGBA8)
	merged_img.fill(Color(0, 0, 0, 0))
	
	for info in image_infos:
		var img_data: Dictionary = info.data
		var img: Image = info.image
		var start_row: int = info.start_row
		
		for row in range(img_data.rows):
			for col in range(img_data.columns):
				var src_x: int = img_data.offset_x + col * img_data.cell_width
				var src_y: int = img_data.offset_y + row * img_data.cell_height
				var dst_x: int = col * max_cell_width
				var dst_y: int = (start_row + row) * max_cell_height
				
				merged_img.blit_rect(img, Rect2i(src_x, src_y, img_data.cell_width, img_data.cell_height), Vector2i(dst_x, dst_y))
	
	var texture := ImageTexture.create_from_image(merged_img)
	if not texture:
		return {}

	return {
		"texture": texture,
		"cell_width": max_cell_width,
		"cell_height": max_cell_height,
		"columns": columns,
		"rows": total_rows,
		"start_rows": start_rows
	}

static func _frame_coords(anim_data: Dictionary, merged: Dictionary) -> Array[Vector2i]:
	var img_data: Dictionary = anim_data.img_data
	var start_row: int = merged.start_rows.get(img_data.path, 0)
	var coords: Array[Vector2i] = []
	for r: Rect2 in anim_data.frame_rects:
		var col := int((r.position.x - img_data.offset_x) / img_data.cell_width)
		var row := int((r.position.y - img_data.offset_y) / img_data.cell_height)
		coords.append(Vector2i(col, start_row + row))
	return coords

static func export_to_animation_player(selected_items: Array, fps: int, node_name: String, animations_data: Array) -> Sprite2D:
	var merged := _merge_images_into_sheet(selected_items)
	if merged.is_empty():
		return null

	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = merged.texture
	sprite.hframes = merged.columns
	sprite.vframes = merged.rows

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	sprite.add_child(anim_player)

	var anim_library := AnimationLibrary.new()
	for anim_data in animations_data:
		var coords := _frame_coords(anim_data, merged)
		if coords.is_empty():
			continue
		var anim_fps: int = anim_data.get("fps", fps)
		var frame_duration := 1.0 / anim_fps if anim_fps > 0 else 0.1

		var anim := Animation.new()
		anim.loop_mode = Animation.LOOP_LINEAR if anim_data.get("loop", true) else Animation.LOOP_NONE
		var track_idx := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, NodePath(".:frame_coords"))
		anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)
		for i in coords.size():
			anim.track_insert_key(track_idx, i * frame_duration, coords[i])
		anim.length = coords.size() * frame_duration
		anim_library.add_animation(anim_data.name, anim)
	anim_player.add_animation_library("", anim_library)

	return sprite

static func export_to_animated_sprite(selected_items: Array, fps: int, node_name: String, animations_data: Array) -> AnimatedSprite2D:
	var merged := _merge_images_into_sheet(selected_items)
	if merged.is_empty():
		return null

	var cw: int = merged.cell_width
	var ch: int = merged.cell_height
	var sprite_frames := SpriteFrames.new()
	for anim_data in animations_data:
		var coords := _frame_coords(anim_data, merged)
		if coords.is_empty():
			continue
		var anim_name: String = anim_data.name
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, anim_data.get("fps", fps))
		sprite_frames.set_animation_loop(anim_name, anim_data.get("loop", true))
		for c in coords:
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = merged.texture
			atlas_texture.region = Rect2(c.x * cw, c.y * ch, cw, ch)
			sprite_frames.add_frame(anim_name, atlas_texture)

	var animated_sprite := AnimatedSprite2D.new()
	animated_sprite.name = node_name
	animated_sprite.sprite_frames = sprite_frames
	var anim_names := sprite_frames.get_animation_names()
	if not anim_names.is_empty():
		animated_sprite.animation = anim_names[0]

	return animated_sprite
