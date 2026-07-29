extends CanvasLayer

## Shared cross-fade wrapper around `change_scene_to_file`, used by every
## scene navigation in the app so all module switches share one motion
## language instead of each being an instant hard cut.

const FADE_SECONDS := 0.2
const FADE_COLOR := Color(0.039, 0.055, 0.094, 1.0)  # project.godot default_clear_color

@onready var fade_rect: ColorRect = $FadeRect

var _busy: bool = false


func _ready() -> void:
	layer = 110
	fade_rect.color = FADE_COLOR
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func go_to_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 1.0, FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "modulate:a", 0.0, FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_out.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
