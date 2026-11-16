@tool
extends Control

const NON_LOOP_PAUSE := 0.7

@onready var texture_rect: TextureRect = $TextureRect

var fps := 10.0
var loop := true
var frames: Array[Rect2] = []
var current_frame := 0
var _atlas := AtlasTexture.new()
var _elapsed := 0.0

func _ready() -> void:
	texture_rect.texture = _atlas

func setup(texture: Texture2D, frame_rects: Array[Rect2]) -> void:
	_atlas.atlas = texture
	frames = frame_rects
	current_frame = 0
	_elapsed = 0.0
	if not frames.is_empty():
		_atlas.region = frames[0]

func _process(delta: float) -> void:
	if frames.is_empty():
		return
	var step := 1.0 / maxf(fps, 1.0)
	if not loop and current_frame == frames.size() - 1:
		step += NON_LOOP_PAUSE
	_elapsed += delta
	if _elapsed >= step:
		_elapsed = fmod(_elapsed, step)
		current_frame = (current_frame + 1) % frames.size()
		_atlas.region = frames[current_frame]
