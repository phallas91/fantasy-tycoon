extends TextureRect
class_name GriffinFlight
## Reusable six-frame griffin courier animation for hero UI and bonus flights.
## The map draws the same sheet directly for batching; UI locations use this
## lightweight TextureRect so the premium artwork stays consistent everywhere.

const SHEET := preload("res://assets/art/generated/griffin_flight_sheet.png")
const FRAME_SIZE := Vector2(256.0, 256.0)
const FRAME_COUNT := 6

@export_range(1.0, 18.0, 0.5) var fps := 7.5
@export_range(0, 5, 1) var reduced_motion_frame := 2
@export var phase := 0.0

var _atlas := AtlasTexture.new()
var _clock := 0.0
var _frame := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_atlas.atlas = SHEET
	texture = _atlas
	_set_frame(reduced_motion_frame if Fx.reduce_motion else int(floor(phase)) % FRAME_COUNT)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if Fx.reduce_motion:
		_set_frame(reduced_motion_frame)
		return
	_clock += delta
	_set_frame(int(floor(_clock * fps + phase)) % FRAME_COUNT)

func _set_frame(next_frame: int) -> void:
	if next_frame == _frame:
		return
	_frame = next_frame
	_atlas.region = Rect2(
		float(_frame % 3) * FRAME_SIZE.x,
		float(floori(float(_frame) / 3.0)) * FRAME_SIZE.y,
		FRAME_SIZE.x,
		FRAME_SIZE.y
	)
