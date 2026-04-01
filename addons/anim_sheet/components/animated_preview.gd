@tool
extends Control

var texture_rect: TextureRect

var sprite_texture: Texture2D
var frames: Array[Rect2] = []
var current_frame: int = 0

func _ready():
	texture_rect = $TextureRect
	
	# If setup was called before _ready, apply the settings now
	if sprite_texture and not frames.is_empty():
		_apply_setup()

func setup(texture: Texture2D, frame_rects: Array[Rect2]):
	sprite_texture = texture
	frames = frame_rects
	current_frame = 0
	
	if frames.is_empty():
		return
	
	# If node is ready, apply immediately, otherwise wait for _ready()
	if texture_rect:
		_apply_setup()

func _apply_setup():
	if frames.is_empty() or not sprite_texture or not texture_rect:
		return
	
	_update_frame()

func advance_frame():
	if frames.is_empty():
		return
	
	current_frame = (current_frame + 1) % frames.size()
	_update_frame()

func _update_frame():
	if frames.is_empty() or not sprite_texture or not texture_rect:
		return
	
	var frame_rect = frames[current_frame]
	
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite_texture
	atlas.region = frame_rect
	
	texture_rect.texture = atlas
