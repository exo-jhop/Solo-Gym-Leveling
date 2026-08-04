extends Control

## Meal Plan (feature: daily meal plan). Reached from Home's "meal" quest card via LOG,
## same wiring as Quest Detail — QuestManager.selected_quest_id is set first, this screen
## just resolves it. Unlike Quest Detail's single logged-value form, a meal plan is a
## variable-length checklist, so it gets its own screen instead of a special case bolted
## onto Quest Detail's fixed layout (mirrors why lift quests already have their own
## rep/weight fields there instead of meal_plan mixing in).

const TOUCH_TARGET := 144.0

@onready var meta_label: Label = $Margin/ScrollContainer/Root/MetaLabel
@onready var status_label: Label = $Margin/ScrollContainer/Root/StatusLabel
@onready var meal_list_root: VBoxContainer = $Margin/ScrollContainer/Root/MealListRoot
@onready var add_input: LineEdit = $Margin/ScrollContainer/Root/AddRow/AddInput
@onready var add_button: Button = $Margin/ScrollContainer/Root/AddRow/AddButton
@onready var back_button: Button = $Margin/ScrollContainer/Root/BackButton

var quest: Quest


func _ready() -> void:
	quest = QuestManager.get_quest(QuestManager.selected_quest_id)
	if quest == null:
		push_error("MealPlan: no quest found for id '%s'" % QuestManager.selected_quest_id)
		_go_back()
		return

	add_button.pressed.connect(_on_add_pressed)
	add_input.text_submitted.connect(func(_text: String) -> void: _on_add_pressed())
	back_button.pressed.connect(_go_back)
	PressFeedback.attach(add_button)
	PressFeedback.attach(back_button)
	add_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	NavButtonStyle.apply(add_button, SystemPalette.SUCCESS, NavButtonStyle.ICON_CONTENT_MARGIN)
	NavButtonStyle.apply(back_button)
	_add_leading_glyph(add_button, HudGlyph.Shape.PLUS, SystemPalette.SUCCESS)

	meta_label.text = "Reward: +%d XP -> %s" % [quest.xp_reward, quest.stat_reward]
	_refresh()


func _add_leading_glyph(button: Button, shape: HudGlyph.Shape, color: Color) -> void:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	glyph.offset_left = 38.0
	glyph.offset_top = -26.0
	glyph.offset_right = 90.0
	glyph.offset_bottom = 26.0
	button.add_child(glyph)


func _refresh() -> void:
	var meals := QuestManager.meal_plan
	var eaten := 0
	for entry in meals:
		if entry.completed:
			eaten += 1

	if quest.completed:
		status_label.text = "Completed — followed your meal plan (%d/%d meals)" % [eaten, meals.size()]
	elif meals.is_empty():
		status_label.text = "Add today's meals below, then check them off as you go."
	else:
		status_label.text = "%d/%d meals checked off" % [eaten, meals.size()]

	# No penalty for an unfollowed plan (spec v2: no penalty mechanics) — locking further
	# edits after completion is purely to match Quest Detail's "done means done" convention,
	# not a restriction meant to punish anything.
	add_input.editable = not quest.completed
	add_button.disabled = quest.completed

	_rebuild_list()


func _rebuild_list() -> void:
	for child in meal_list_root.get_children():
		child.queue_free()

	for entry in QuestManager.meal_plan:
		meal_list_root.add_child(_build_meal_row(entry))


func _build_meal_row(entry: MealEntry) -> Control:
	var card := PanelContainer.new()
	var card_style := HudCard.row_style(SystemPalette.SUCCESS if entry.completed else SystemPalette.PRIMARY)
	card_style.chamfer_size = 0.0
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = entry.completed
	toggle.disabled = quest.completed
	toggle.custom_minimum_size = Vector2(TOUCH_TARGET, TOUCH_TARGET)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.tooltip_text = "Mark this meal eaten"
	NavButtonStyle.apply_icon(toggle, SystemPalette.SUCCESS)
	_add_button_glyph(
		toggle,
		HudGlyph.Shape.CHECK if entry.completed else HudGlyph.Shape.CIRCLE,
		SystemPalette.SUCCESS if entry.completed else SystemPalette.TEXT_SECONDARY
	)
	toggle.toggled.connect(_on_meal_toggled.bind(entry))
	PressFeedback.attach(toggle)
	row.add_child(toggle)

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if entry.completed:
		name_label.add_theme_color_override("font_color", SystemPalette.TEXT_SECONDARY)
	row.add_child(name_label)

	var remove_button := Button.new()
	remove_button.custom_minimum_size = Vector2(TOUCH_TARGET, TOUCH_TARGET)
	remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove_button.disabled = quest.completed
	remove_button.tooltip_text = "Remove this meal"
	NavButtonStyle.apply_icon(remove_button, SystemPalette.WARNING)
	_add_button_glyph(remove_button, HudGlyph.Shape.CLOSE, SystemPalette.WARNING)
	remove_button.pressed.connect(_on_meal_removed.bind(entry))
	PressFeedback.attach(remove_button)
	row.add_child(remove_button)

	return card


func _add_button_glyph(button: Button, shape: HudGlyph.Shape, color: Color) -> void:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 42.0
	glyph.offset_top = 42.0
	glyph.offset_right = -42.0
	glyph.offset_bottom = -42.0
	button.add_child(glyph)


func _on_add_pressed() -> void:
	var meal_name := add_input.text
	if meal_name.strip_edges() == "":
		return
	QuestManager.add_meal_entry(meal_name)
	add_input.text = ""
	SaveManager.save_game()
	quest = QuestManager.get_quest(quest.id)
	_refresh()


func _on_meal_toggled(_pressed: bool, entry: MealEntry) -> void:
	QuestManager.toggle_meal_entry(entry.id)
	SaveManager.save_game()
	quest = QuestManager.get_quest(quest.id)
	_refresh()


func _on_meal_removed(entry: MealEntry) -> void:
	QuestManager.remove_meal_entry(entry.id)
	SaveManager.save_game()
	quest = QuestManager.get_quest(quest.id)
	_refresh()


func _go_back() -> void:
	SceneTransition.go_to_scene("res://scenes/home/home.tscn")
