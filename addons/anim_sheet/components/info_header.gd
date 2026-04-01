@tool
extends HBoxContainer

@onready var icon: TextureRect = %Icon
@onready var label: Label = %Label

func setup(text: String, icon_texture: Texture2D) -> void:
	label.text = text
	icon.texture = icon_texture
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
