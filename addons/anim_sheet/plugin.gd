@tool
extends EditorPlugin

var main_panel: Control

func _enter_tree() -> void:
	main_panel = preload("res://addons/tiled_image_scanner/tiled_scanner_window.tscn").instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_panel)
	_make_visible(false)

func _exit_tree() -> void:
	if main_panel:
		main_panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel:
		main_panel.visible = visible

func _get_plugin_name() -> String:
	return "AnimSheet"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Image", "EditorIcons")
