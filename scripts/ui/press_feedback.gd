class_name PressFeedback

## Scale-based press feedback for any BaseButton (Button, including
## toggle_mode buttons like the training-log calendar cells). Call
## PressFeedback.attach(button) once per button, right after it's created.

const PRESS_SCALE := Vector2(0.97, 0.97)
const PRESS_DURATION := 0.1
const RELEASE_DURATION := 0.15


static func attach(button: BaseButton) -> void:
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


static func _on_down(button: BaseButton) -> void:
	_animate(button, PRESS_SCALE, PRESS_DURATION)


static func _on_up(button: BaseButton) -> void:
	_animate(button, Vector2.ONE, RELEASE_DURATION)


static func _animate(button: BaseButton, target_scale: Vector2, duration: float) -> void:
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
