@tool
extends EditorPlugin

var main_panel_instance
var popup_window : Window

const MENU_ITEM_NAME = "Sprite Sheet Animator..."

func _enter_tree():

	var MainPanelScene = preload("res://addons/anim_sheet/SpriteSheetAnimatorPanel.tscn")
	main_panel_instance = MainPanelScene.instantiate()

	popup_window = Window.new()
	popup_window.title = "Sprite Sheet Animator"
	popup_window.size = Vector2i(800, 600)
	popup_window.min_size = Vector2i(500, 400)
	popup_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	popup_window.wrap_controls = true
	popup_window.visible = false
	popup_window.transient = true
	popup_window.exclusive = false

	popup_window.add_child(main_panel_instance)
	get_editor_interface().get_editor_main_screen().add_child(popup_window)
	popup_window.close_requested.connect(_on_popup_close_requested)
	add_tool_menu_item(MENU_ITEM_NAME, Callable(self, "_show_popup"))

func _exit_tree():

	remove_tool_menu_item(MENU_ITEM_NAME)

	if is_instance_valid(popup_window):
		popup_window.queue_free()
		popup_window = null

	if is_instance_valid(main_panel_instance):
		main_panel_instance = null

func _on_popup_close_requested():
	if is_instance_valid(popup_window):
		popup_window.hide()

func _show_popup():
	print("Sprite Sheet Animator opened")
	if is_instance_valid(popup_window):
		popup_window.popup_centered()