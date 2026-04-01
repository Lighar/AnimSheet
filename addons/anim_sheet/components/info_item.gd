@tool
extends HBoxContainer

@onready var icon: TextureRect = %Icon
@onready var key_label: Label = %Key
@onready var value_label: Label = %Value

func setup(key: String, value: String, icon_texture: Texture2D, color: Color) -> void:
	key_label.text = key + ":"
	value_label.text = value
	icon.texture = icon_texture
	icon.modulate = color
	key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	value_label.add_theme_color_override("font_color", color)
