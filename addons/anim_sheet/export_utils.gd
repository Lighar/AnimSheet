@tool
class_name TiledImageExportUtils

static func _is_frame_empty(img: Image, x: int, y: int, width: int, height: int) -> bool:
	var has_visible_pixel := false
	
	for py in range(y, min(y + height, img.get_height())):
		for px in range(x, min(x + width, img.get_width())):
			var pixel := img.get_pixel(px, py)
			if pixel.a > 0.01:  # Has some alpha
				has_visible_pixel = true
				break
		if has_visible_pixel:
			break
	
	return not has_visible_pixel

static func extract_animation_frames(img: Image, img_data: Dictionary, is_horizontal: bool) -> Array[Array]:
	var all_animations: Array[Array] = []
	
	var cell_width: int = img_data.cell_width
	var cell_height: int = img_data.cell_height
	var offset_x: int = img_data.offset_x
	var offset_y: int = img_data.offset_y
	var rows: int = img_data.rows
	var columns: int = img_data.columns
	
	#print("  Cell: %dx%d, Offset: (%d,%d), Grid: %dx%d" % [cell_width, cell_height, offset_x, offset_y, columns, rows])
	
	if is_horizontal:
		for row in range(rows):
			var frame_rects: Array[Rect2] = []
			for col in range(columns):
				var x: int = offset_x + col * cell_width
				var y: int = offset_y + row * cell_height
				
				if x >= 0 and y >= 0 and x + cell_width <= img.get_width() and y + cell_height <= img.get_height():
					var is_empty = _is_frame_empty(img, x, y, cell_width, cell_height)
					if not is_empty:
						frame_rects.append(Rect2(x, y, cell_width, cell_height))
			#print("  Row %d: %d frames" % [row, frame_rects.size()])
			if frame_rects.size() > 0:
				all_animations.append(frame_rects)
	else:
		for col in range(columns):
			var frame_rects: Array[Rect2] = []
			for row in range(rows):
				var x: int = offset_x + col * cell_width
				var y: int = offset_y + row * cell_height
				
				if x >= 0 and y >= 0 and x + cell_width <= img.get_width() and y + cell_height <= img.get_height():
					if not _is_frame_empty(img, x, y, cell_width, cell_height):
						frame_rects.append(Rect2(x, y, cell_width, cell_height))
			if frame_rects.size() > 0:
				all_animations.append(frame_rects)
	
	return all_animations

static func build_animation_list(selected_items: Array, is_horizontal: bool) -> Array[Dictionary]:
	var animations: Array[Dictionary] = []
	
	for img_data in selected_items:
		var base_name: String = img_data.filename.get_basename()
		
		var img := Image.new()
		if img.load(img_data.path) != OK:
			continue
		
		var all_frame_rects := extract_animation_frames(img, img_data, is_horizontal)
		var anim_count := all_frame_rects.size()
		
		if is_horizontal:
			for row in range(anim_count):
				var frame_rects: Array[Rect2] = []
				frame_rects.assign(all_frame_rects[row])
				var anim_name := base_name if anim_count == 1 else base_name + "_row_%d" % row
				animations.append({
					"original_name": anim_name,
					"display_name": anim_name,
					"img_data": img_data,
					"row": row,
					"col": -1,
					"frame_rects": frame_rects
				})
		else:
			for col in range(anim_count):
				var frame_rects: Array[Rect2] = []
				frame_rects.assign(all_frame_rects[col])
				var anim_name := base_name if anim_count == 1 else base_name + "_col_%d" % col
				animations.append({
					"original_name": anim_name,
					"display_name": anim_name,
					"img_data": img_data,
					"row": -1,
					"col": col,
					"frame_rects": frame_rects
				})
	
	return animations

static func _merge_images_into_sheet(selected_items: Array) -> Dictionary:
	if selected_items.is_empty():
		return {}
	
	var max_cell_width := 0
	var max_cell_height := 0
	var total_rows := 0
	var image_infos: Array[Dictionary] = []
	
	for img_data in selected_items:
		var img := Image.new()
		if img.load(img_data.path) != OK:
			continue
		
		max_cell_width = max(max_cell_width, img_data.cell_width)
		max_cell_height = max(max_cell_height, img_data.cell_height)
		
		var info := {
			"image": img,
			"data": img_data,
			"start_row": total_rows
		}
		image_infos.append(info)
		
		if img_data.has("rows"):
			total_rows += img_data.rows
	
	if image_infos.is_empty():
		return {}
	
	var columns: int = image_infos[0].data.columns
	
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
	
	return {
		"image": merged_img,
		"cell_width": max_cell_width,
		"cell_height": max_cell_height,
		"columns": columns,
		"rows": total_rows,
		"image_infos": image_infos
	}

static func export_to_animation_player(selected_items: Array, fps: int, is_horizontal: bool, scene_root: Node, node_name: String, animation_mappings: Dictionary, animations_data: Array = []) -> AnimationPlayer:
	var merged_data := _merge_images_into_sheet(selected_items)
	if merged_data.is_empty():
		return null
	
	var texture := ImageTexture.create_from_image(merged_data.image)
	if not texture:
		return null
	
	var sprite = Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.hframes = merged_data.columns
	sprite.vframes = merged_data.rows
	sprite.frame_coords = Vector2i.ZERO
	

	
	
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	
	
	scene_root.add_child(sprite)
	sprite.owner = scene_root
	sprite.add_child(anim_player)
	anim_player.owner = scene_root
	
	
	var anim_library = AnimationLibrary.new()
	var frame_duration := 1.0 / float(fps) if fps > 0 else 0.1
	
	
	if animations_data.size() > 0:
		for anim_data in animations_data:
			if not anim_data.has("frame_rects") or anim_data.frame_rects.is_empty():
				continue
			
			var anim = Animation.new()
			anim.loop_mode = Animation.LOOP_LINEAR
			
			var track_idx := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track_idx, NodePath(".:frame_coords"))
			anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)
			
			
			var frame_time := 0.0
			var img_data: Dictionary = anim_data.img_data
			var start_row: int = 0
			
			
			for info in merged_data.image_infos:
				if info.data == img_data:
					start_row = info.start_row
					break
			
			
			for frame_rect in anim_data.frame_rects:
				
				var col: int = int((frame_rect.position.x - img_data.offset_x) / img_data.cell_width)
				var row: int = int((frame_rect.position.y - img_data.offset_y) / img_data.cell_height)
				
				anim.track_insert_key(track_idx, frame_time, Vector2i(col, start_row + row))
				frame_time += frame_duration
			
			if frame_time > 0:
				anim.length = frame_time
				var anim_name: String = anim_data.original_name
				var custom_name: String = animation_mappings.get(anim_name, anim_name)
				anim_library.add_animation(custom_name, anim)
	anim_player.add_animation_library("", anim_library)
	
	return anim_player

static func export_to_animated_sprite(selected_items: Array, fps: int, is_horizontal: bool, scene_root: Node, node_name: String, animation_mappings: Dictionary, animations_data: Array = []) -> AnimatedSprite2D:
	var merged_data := _merge_images_into_sheet(selected_items)
	if merged_data.is_empty():
		return null
	
	
	var texture := ImageTexture.create_from_image(merged_data.image)
	if not texture:
		return null
	
	
	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = node_name
	

	
	
	var sprite_frames = SpriteFrames.new()
	
	var cell_width: int = merged_data.cell_width
	var cell_height: int = merged_data.cell_height
	
	
	if animations_data.size() > 0:
		for anim_data in animations_data:
			if not anim_data.has("frame_rects") or anim_data.frame_rects.is_empty():
				continue
			
			var anim_name: String = anim_data.original_name
			var custom_name: String = animation_mappings.get(anim_name, anim_name)
			sprite_frames.add_animation(custom_name)
			sprite_frames.set_animation_speed(custom_name, fps)
			sprite_frames.set_animation_loop(custom_name, true)
			
			var img_data: Dictionary = anim_data.img_data
			var start_row: int = 0
			
			
			for info in merged_data.image_infos:
				if info.data == img_data:
					start_row = info.start_row
					break
			
			
			for frame_rect in anim_data.frame_rects:
				
				var col: int = int((frame_rect.position.x - img_data.offset_x) / img_data.cell_width)
				var row: int = int((frame_rect.position.y - img_data.offset_y) / img_data.cell_height)
				
				var frame_x: int = col * cell_width
				var frame_y: int = (start_row + row) * cell_height
				
				var atlas_texture = AtlasTexture.new()
				atlas_texture.atlas = texture
				atlas_texture.region = Rect2(frame_x, frame_y, cell_width, cell_height)
				sprite_frames.add_frame(custom_name, atlas_texture)
	
	animated_sprite.sprite_frames = sprite_frames
	
	
	var anim_names = sprite_frames.get_animation_names()
	if not anim_names.is_empty():
		animated_sprite.animation = anim_names[0]
	
	
	scene_root.add_child(animated_sprite)
	animated_sprite.owner = scene_root
	
	return animated_sprite
