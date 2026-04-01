@tool
extends RefCounted
class_name ImageScanner

const GridDetectorUtils = preload("res://addons/anim_sheet/grid_detector_utils.gd")

var extracted_path: String = ""

func scan_folder(folder_path: String) -> Array[Dictionary]:
	var images: Array[Dictionary] = []
	var image_files := find_image_files(folder_path)
	
	for img_path in image_files:
		var img_data := analyze_image(img_path)
		if img_data.is_empty():
			continue
		images.append(img_data)
	
	return images

func analyze_image(img_path: String) -> Dictionary:
	var img := Image.new()
	if img.load(img_path) != OK:
		push_error("Failed to load image: " + img_path)
		return {}
	
	var grid_info := GridDetectorUtils.detect(img)
	
	if grid_info.is_empty():
		return {}
	
	var cell_width: int = grid_info.get("cell_width", 0)
	var cell_height: int = grid_info.get("cell_height", 0)
	var columns := 1
	var rows := 1
	
	if cell_width > 0:
		columns = int(img.get_width() / cell_width)
	if cell_height > 0:
		rows = int(img.get_height() / cell_height)
	
	return {
		"path": img_path,
		"filename": img_path.get_file(),
		"width": img.get_width(),
		"height": img.get_height(),
		"cell_width": cell_width,
		"cell_height": cell_height,
		"offset_x": grid_info.get("offset_x", 0),
		"offset_y": grid_info.get("offset_y", 0),
		"columns": columns,
		"rows": rows,
		"total_tiles": columns * rows
	}

func find_image_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				result.append_array(find_image_files(full_path))
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "bmp", "webp"]:
				result.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result

func extract_zip(zip_path: String, extract_to: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		push_error("Failed to open ZIP file")
		return false
	
	var files := reader.get_files()
	var has_images := false
	
	for file_path in files:
		var ext := file_path.get_extension().to_lower()
		if ext not in ["png", "jpg", "jpeg", "bmp", "webp"]:
			continue
		
		has_images = true
		var file_data := reader.read_file(file_path)
		var target_path := extract_to.path_join(file_path)
		var target_dir := target_path.get_base_dir()
		
		if not DirAccess.dir_exists_absolute(target_dir):
			DirAccess.make_dir_recursive_absolute(target_dir)
		
		var file := FileAccess.open(target_path, FileAccess.WRITE)
		if file:
			file.store_buffer(file_data)
			file.close()
	
	reader.close()
	return has_images

func get_relative_path(full_path: String, base_path: String) -> String:
	if base_path.is_empty():
		return full_path.get_file()
	
	if full_path.begins_with(base_path):
		var relative := full_path.substr(base_path.length())
		if relative.begins_with("/"):
			relative = relative.substr(1)
		return relative
	
	return full_path.get_file()
