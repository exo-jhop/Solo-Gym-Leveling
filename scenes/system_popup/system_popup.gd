extends CanvasLayer

## Global "System" style overlay for level-up / rank-up notifications (spec 4.6 / 5).
## Registered as an autoload scene so it renders above whatever screen is active
## and keeps working regardless of which scene triggered the underlying quest completion.

const DISPLAY_SECONDS := 2.0
const FADE_SECONDS := 0.25
const LEVEL_UP_COLOR := Color(0.906, 0.925, 0.98, 1.0)

# Accent applied to the panel border/glow and kind label — distinct per popup kind so
# Rank-up reads as visually bigger/rarer than Level-up (spec v2 5: violet is reserved
# specifically for Rank-up moments, blue is the general active/positive accent).
const LEVEL_UP_ACCENT := Color(0.239, 0.545, 1.0, 1.0)
const RANK_UP_ACCENT := Color(0.545, 0.361, 0.965, 1.0)
const NEW_PR_ACCENT := Color(0.3, 0.85, 0.4, 1.0)

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Dim/CenterContainer/Panel
@onready var kind_label: Label = $Dim/CenterContainer/Panel/Margin/VBox/KindLabel
@onready var value_label: Label = $Dim/CenterContainer/Panel/Margin/VBox/ValueLabel
@onready var hint_label: Label = $Dim/CenterContainer/Panel/Margin/VBox/HintLabel

var _queue: Array = []
var _showing: bool = false
var _tween: Tween
var _panel_style: StyleBoxFlat


func _ready() -> void:
	visible = false
	dim.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	dim.gui_input.connect(_on_dim_input)
	GameManager.leveled_up.connect(_on_leveled_up)
	GameManager.ranked_up.connect(_on_ranked_up)
	PRTracker.new_pr.connect(_on_new_pr)

	_panel_style = panel.get_theme_stylebox("panel").duplicate()
	panel.add_theme_stylebox_override("panel", _panel_style)


func _on_leveled_up(new_level: int) -> void:
	_queue.append({
		"kind": "LEVEL UP", "value": "Level %d" % new_level, "hint": "Tap to continue",
		"accent": LEVEL_UP_ACCENT, "value_color": LEVEL_UP_COLOR,
	})
	_process_queue()


func _on_ranked_up(new_rank: String) -> void:
	_queue.append({
		"kind": "RANK UP", "value": "Rank %s" % new_rank, "hint": "Tap to continue",
		"accent": RANK_UP_ACCENT, "value_color": GameManager.rank_color(new_rank),
	})
	_process_queue()


func _on_new_pr(exercise_name: String, value: float, metric: String) -> void:
	_queue.append({
		"kind": "NEW PR!", "value": "%s: %s" % [exercise_name, PRTracker.format_record({"value": value, "metric": metric})], "hint": "Tap to continue",
		"accent": NEW_PR_ACCENT, "value_color": LEVEL_UP_COLOR,
	})
	_process_queue()


func _process_queue() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	var entry: Dictionary = _queue.pop_front()
	_show_popup(entry)


func _show_popup(entry: Dictionary) -> void:
	kind_label.text = entry.kind
	value_label.text = entry.value
	hint_label.text = entry.hint
	kind_label.add_theme_color_override("font_color", entry.accent)
	value_label.add_theme_color_override("font_color", entry.value_color)
	_panel_style.border_color = entry.accent
	_panel_style.shadow_color = Color(entry.accent, 0.5)

	visible = true
	dim.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(dim, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_property(panel, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_property(panel, "scale", Vector2.ONE, FADE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(DISPLAY_SECONDS)
	_tween.chain().tween_property(dim, "modulate:a", 0.0, FADE_SECONDS)
	_tween.parallel().tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	_tween.chain().tween_callback(_on_popup_finished)


func _on_popup_finished() -> void:
	visible = false
	_showing = false
	_process_queue()


func _on_dim_input(event: InputEvent) -> void:
	var is_press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not is_press or not _showing:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_on_popup_finished()
