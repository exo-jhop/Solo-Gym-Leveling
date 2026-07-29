class_name PressFeedback

## Scale-based press feedback for any BaseButton (Button, including
## toggle_mode buttons like the training-log calendar cells). Call
## PressFeedback.attach(button) once per button, right after it's created.

const PRESS_SCALE := Vector2(0.97, 0.97)
const PRESS_DURATION := 0.1
const RELEASE_DURATION := 0.15

const CLICK_STREAM: AudioStream = preload("res://res/sfx/clicksoundeffect.mp3")


static func attach(button: BaseButton) -> void:
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


static func _on_down(button: BaseButton) -> void:
	_animate(button, PRESS_SCALE, PRESS_DURATION)
	_play_click(button)


## One-shot player parented to the pressed button itself — attach() is called across
## every scene with no shared audio node available, so each press spawns and cleans up
## its own AudioStreamPlayer rather than requiring a new autoload just for clicks.
static func _play_click(button: BaseButton) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = CLICK_STREAM
	button.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _on_up(button: BaseButton) -> void:
	_animate(button, Vector2.ONE, RELEASE_DURATION)


static func _animate(button: BaseButton, target_scale: Vector2, duration: float) -> void:
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
