extends Control

## Settings (spec 4.5): edit the training program's exercises, protein target, creatine
## dose, and the end-of-day reminder (spec v2 4.1).
## Edits mutate QuestManager/NotificationManager's live data directly; the Save button
## persists it via SaveManager. Program changes take effect starting the next daily
## quest generation, same as any other program edit.
##
## Portrait pass (design system v2): the four sections were separated by HSeparators that
## duplicated what the card borders already said, the program editor had no card at all,
## every input sat below the 48dp touch minimum, and the five-control exercise row was
## cramped into one line. Save/Back and the status line now sit outside the ScrollContainer
## so the primary action is always reachable rather than buried under a 7-day program.

const TOUCH_TARGET := 144.0

## Status line behaves like a toast: auto-dismissed inside the design system's 3-5s band.
const STATUS_HOLD_TIME := 3.0
const STATUS_FADE_TIME := 0.4

@onready var goal_input: OptionButton = $Margin/Root/Scroll/Content/ProfileCard/ProfileSection/GoalRow/GoalInput
@onready var weight_input: SpinBox = $Margin/Root/Scroll/Content/ProfileCard/ProfileSection/WeightRow/WeightInput
@onready var days_input: SpinBox = $Margin/Root/Scroll/Content/ProfileCard/ProfileSection/DaysRow/DaysInput
@onready var equipment_input: OptionButton = $Margin/Root/Scroll/Content/ProfileCard/ProfileSection/EquipmentRow/EquipmentInput
@onready var calculated_label: Label = $Margin/Root/Scroll/Content/ProfileCard/ProfileSection/CalculatedLabel
@onready var protein_input: SpinBox = $Margin/Root/Scroll/Content/NutritionCard/NutritionSection/ProteinRow/ProteinInput
@onready var creatine_input: SpinBox = $Margin/Root/Scroll/Content/NutritionCard/NutritionSection/CreatineRow/CreatineInput
@onready var reminder_list: VBoxContainer = $Margin/Root/Scroll/Content/NotificationCard/NotificationSection/ReminderList
@onready var program_list: VBoxContainer = $Margin/Root/Scroll/Content/ProgramCard/ProgramSection/ProgramList
@onready var regenerate_button: Button = $Margin/Root/Scroll/Content/ProgramCard/ProgramSection/RegenerateButton
@onready var regenerate_confirm: ConfirmationDialog = $RegenerateConfirm
@onready var unsaved_confirm: ConfirmationDialog = $UnsavedConfirm
@onready var status_label: Label = $Margin/Root/StatusLabel
@onready var save_button: Button = $Margin/Root/ButtonRow/SaveButton
@onready var back_button: Button = $Margin/Root/ButtonRow/BackButton
@onready var profile_card: PanelContainer = $Margin/Root/Scroll/Content/ProfileCard
@onready var nutrition_card: PanelContainer = $Margin/Root/Scroll/Content/NutritionCard
@onready var notification_card: PanelContainer = $Margin/Root/Scroll/Content/NotificationCard
@onready var program_card: PanelContainer = $Margin/Root/Scroll/Content/ProgramCard
@onready var profile_glyph_slot: Control = $Margin/Root/Scroll/Content/ProfileCard/ProfileSection/ProfileHeaderRow/ProfileGlyphSlot
@onready var nutrition_glyph_slot: Control = $Margin/Root/Scroll/Content/NutritionCard/NutritionSection/NutritionHeaderRow/NutritionGlyphSlot
@onready var notification_glyph_slot: Control = $Margin/Root/Scroll/Content/NotificationCard/NotificationSection/NotificationHeaderRow/NotificationGlyphSlot
@onready var program_glyph_slot: Control = $Margin/Root/Scroll/Content/ProgramCard/ProgramSection/ProgramHeaderRow/ProgramGlyphSlot

# Set once the user edits the protein field directly, so Save doesn't clobber a manual
# override with ProfileManager.apply_targets()'s formula-calculated value.
var _protein_manually_edited := false

# Every edit here mutates the live autoloads immediately but only reaches disk on Save, so
# walking away with Back silently loses the edits on the next launch. Tracked to warn first.
var _dirty := false

var _status_tween: Tween


func _ready() -> void:
	_build_cards()

	for goal in ProfileManager.GOALS:
		goal_input.add_item(ProfileManager.GOAL_LABELS[goal])
	goal_input.selected = ProfileManager.GOALS.find(ProfileManager.profile.goal)
	weight_input.value = ProfileManager.profile.weight_kg
	days_input.value = ProfileManager.profile.days_per_week
	for equipment in ProfileManager.EQUIPMENT_OPTIONS:
		equipment_input.add_item(ProfileManager.EQUIPMENT_LABELS[equipment])
	equipment_input.selected = ProfileManager.EQUIPMENT_OPTIONS.find(ProfileManager.profile.equipment_access)

	goal_input.item_selected.connect(_on_goal_selected)
	weight_input.value_changed.connect(_on_weight_changed)
	days_input.value_changed.connect(_on_days_changed)
	equipment_input.item_selected.connect(_on_equipment_selected)

	protein_input.value = QuestManager.protein_target_g
	creatine_input.value = QuestManager.creatine_target_g
	protein_input.value_changed.connect(_on_protein_changed)
	creatine_input.value_changed.connect(_on_creatine_changed)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	for button in [save_button, back_button, regenerate_button]:
		PressFeedback.attach(button)

	regenerate_button.pressed.connect(_on_regenerate_pressed)
	regenerate_confirm.confirmed.connect(_on_regenerate_confirmed)
	unsaved_confirm.confirmed.connect(_go_back)

	_refresh_reminders()
	_refresh_program()
	_refresh_calculated()


## Per-category card accents (design system v2): identity/progression blue for the profile,
## success green for nutrition targets, warning orange for the reminder, gold for the
## program itself. Chamfer padding comes from the StyleBox now, which is why the four
## MarginContainer wrappers this scene used to carry are gone.
func _build_cards() -> void:
	HudCard.apply(profile_card, SystemPalette.PRIMARY)
	HudCard.apply(nutrition_card, SystemPalette.SUCCESS)
	HudCard.apply(notification_card, SystemPalette.WARNING)
	HudCard.apply(program_card, SystemPalette.GOLD)

	_add_glyph(profile_glyph_slot, HudGlyph.Shape.PROFILE, SystemPalette.PRIMARY)
	_add_glyph(nutrition_glyph_slot, HudGlyph.Shape.DROP, SystemPalette.SUCCESS)
	_add_glyph(notification_glyph_slot, HudGlyph.Shape.ALERT, SystemPalette.WARNING)
	_add_glyph(program_glyph_slot, HudGlyph.Shape.DUMBBELL, SystemPalette.GOLD)

	NavButtonStyle.apply(save_button, SystemPalette.PRIMARY, NavButtonStyle.CONTENT_MARGIN, true)
	NavButtonStyle.apply(back_button)
	# Regeneration throws away every manual program edit, so it takes the warning accent and
	# sits below the program it replaces rather than beside the Save button.
	NavButtonStyle.apply(regenerate_button, SystemPalette.WARNING)


func _add_glyph(slot: Control, shape: HudGlyph.Shape, color: Color) -> HudGlyph:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(glyph)
	return glyph


func _add_button_glyph(button: Button, shape: HudGlyph.Shape, color: Color, inset: float) -> HudGlyph:
	var glyph := _add_glyph(button, shape, color)
	glyph.offset_left = inset
	glyph.offset_top = inset
	glyph.offset_right = -inset
	glyph.offset_bottom = -inset
	return glyph


## Square icon-only action, sized to the touch minimum with the glyph inset inside it.
func _build_icon_button(shape: HudGlyph.Shape, accent: Color, tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(TOUCH_TARGET, TOUCH_TARGET)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tooltip
	NavButtonStyle.apply_icon(button, accent)
	_add_button_glyph(button, shape, accent, 42.0)
	PressFeedback.attach(button)
	return button


func _on_goal_selected(index: int) -> void:
	ProfileManager.profile.goal = ProfileManager.GOALS[index]
	_mark_dirty()
	_refresh_calculated()


func _on_weight_changed(value: float) -> void:
	ProfileManager.profile.weight_kg = value
	_mark_dirty()
	_refresh_calculated()


func _on_days_changed(value: float) -> void:
	ProfileManager.profile.days_per_week = int(value)
	_mark_dirty()


func _on_equipment_selected(index: int) -> void:
	ProfileManager.profile.equipment_access = ProfileManager.EQUIPMENT_OPTIONS[index]
	_mark_dirty()


## Regeneration discards any manual program edits, so it only ever runs after explicit
## confirmation — never silently when goal/days/equipment change elsewhere in Settings.
func _on_regenerate_pressed() -> void:
	regenerate_confirm.popup_centered()


func _on_regenerate_confirmed() -> void:
	var profile := ProfileManager.profile
	QuestManager.training_cycle = ProgramGenerator.generate_program(profile.days_per_week, profile.goal, profile.equipment_access)
	_refresh_program()
	_mark_dirty()
	_show_status("PROGRAM REGENERATED — PRESS SAVE TO KEEP IT.", SystemPalette.WARNING)


## Live preview of the protein target/calorie direction the profile currently
## calculates to (spec 3: "recalculates targets immediately on save" — shown live
## here, actually applied to QuestManager on Save so it doesn't jump mid-edit).
func _refresh_calculated() -> void:
	var profile := ProfileManager.profile
	if profile.weight_kg <= 0.0:
		calculated_label.text = "Enter your weight to see calculated targets."
		return
	var protein := profile.calculate_protein_target_g()
	var direction_text: String = ProfileManager.calorie_direction_label()
	calculated_label.text = "Calculated protein target: %dg/day\n%s" % [int(protein), direction_text]


func _on_protein_changed(value: float) -> void:
	QuestManager.protein_target_g = value
	_protein_manually_edited = true
	_mark_dirty()


func _on_creatine_changed(value: float) -> void:
	QuestManager.creatine_target_g = value
	_mark_dirty()


# Display label per reminder category — "general" is the synthetic all-quests bucket,
# the rest match Quest.category values that have their own reminder configured.
const REMINDER_LABELS := {
	"general": "General end-of-day reminder",
	"supplement": "Supplement reminder (creatine)",
}


func _refresh_reminders() -> void:
	for child in reminder_list.get_children():
		child.queue_free()

	var categories := NotificationManager.reminder_hours.keys()
	categories.sort()
	for category in categories:
		reminder_list.add_child(_build_reminder_row(category))


## The enable control used to be a CheckBox, which inherits the theme's Button styles — so a
## toggled-on reminder rendered as a full-width accent-filled rounded rect with a ~24px tick
## buried in it, reading as a pressed button rather than as a checked option. It's now the
## same chamfered icon toggle the rest of the app uses, at the touch minimum, with the state
## in the glyph (check vs. empty ring) rather than in the row's fill.
func _build_reminder_row(category: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var enabled: bool = NotificationManager.reminder_enabled.get(category, true)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.custom_minimum_size = Vector2(TOUCH_TARGET, TOUCH_TARGET)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.tooltip_text = "Turn this reminder on or off"
	# Success green rather than the card's warning accent: this is an on/off state, and
	# warning orange is reserved for the actual overdue-reminder banner on the Lobby — an
	# armed reminder shouldn't read as an error the moment you enable it.
	NavButtonStyle.apply_icon(toggle, SystemPalette.SUCCESS)
	var glyph := _add_button_glyph(
		toggle,
		HudGlyph.Shape.CHECK if enabled else HudGlyph.Shape.CIRCLE,
		SystemPalette.SUCCESS if enabled else SystemPalette.TEXT_SECONDARY,
		42.0
	)
	toggle.toggled.connect(func(pressed: bool) -> void:
		NotificationManager.reminder_enabled[category] = pressed
		glyph.shape = HudGlyph.Shape.CHECK if pressed else HudGlyph.Shape.CIRCLE
		glyph.color = SystemPalette.SUCCESS if pressed else SystemPalette.TEXT_SECONDARY
		_mark_dirty()
	)
	PressFeedback.attach(toggle)
	row.add_child(toggle)

	var label := Label.new()
	label.text = REMINDER_LABELS.get(category, category.capitalize())
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var hour_input := SpinBox.new()
	hour_input.min_value = 0
	hour_input.max_value = 23
	hour_input.step = 1
	hour_input.value = NotificationManager.reminder_hours.get(category, 20)
	# SpinBox puts a space before its suffix, so ":00" rendered as "20 :00" — "h" reads
	# cleanly with the space and still marks the value as an hour rather than a count.
	hour_input.suffix = "h"
	hour_input.custom_minimum_size = Vector2(200.0, TOUCH_TARGET)
	hour_input.value_changed.connect(func(value: float) -> void:
		NotificationManager.reminder_hours[category] = int(value)
		_mark_dirty()
	)
	row.add_child(hour_input)

	return row


func _refresh_program() -> void:
	for child in program_list.get_children():
		child.queue_free()

	for day_index in range(QuestManager.training_cycle.size()):
		var day: TrainingDay = QuestManager.training_cycle[day_index]
		program_list.add_child(_build_day_section(day_index, day))


func _build_day_section(day_index: int, day: TrainingDay) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 14)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	section.add_child(header_row)

	# In the card's gold accent, not body text: between two bordered exercise cards a plain
	# label of the same weight as the rest of the section disappeared, so the seven days ran
	# together into one undifferentiated list.
	var header := Label.new()
	header.theme_type_variation = &"HeaderLabel"
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", SystemPalette.GOLD)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.text = "DAY %d · %s" % [day_index + 1, day.day_name.to_upper()]
	header_row.add_child(header)

	# Rest days used to be marked with a "(Rest)" suffix inside the header string; as its own
	# tag it survives a long day name instead of being pushed off the end of the line.
	if day.is_rest_day:
		var rest_tag := Label.new()
		rest_tag.theme_type_variation = &"SecondaryLabel"
		rest_tag.add_theme_font_size_override("font_size", 26)
		rest_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rest_tag.text = "REST DAY"
		header_row.add_child(rest_tag)
		return section

	for exercise_index in range(day.exercises.size()):
		section.add_child(_build_exercise_row(day, exercise_index))

	var add_button := Button.new()
	add_button.custom_minimum_size = Vector2(0.0, TOUCH_TARGET)
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_button.text = "ADD EXERCISE"
	add_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	NavButtonStyle.apply(add_button, SystemPalette.SUCCESS, NavButtonStyle.ICON_CONTENT_MARGIN)
	_add_leading_glyph(add_button, HudGlyph.Shape.PLUS, SystemPalette.SUCCESS)
	add_button.pressed.connect(_on_add_exercise.bind(day))
	PressFeedback.attach(add_button)
	section.add_child(add_button)

	return section


## Glyph pinned inside the left inset ICON_CONTENT_MARGIN reserves, matching how the Lobby's
## hub cards place theirs — except built in code, since these buttons don't exist in a scene.
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


## Each exercise is its own row card over two lines — name on top, sets/reps/actions below.
## The five controls used to share one 924px line, which left the exercise name about 280px
## wide and every button under the touch minimum.
func _build_exercise_row(day: TrainingDay, exercise_index: int) -> Control:
	var exercise: Exercise = day.exercises[exercise_index]

	var card := PanelContainer.new()
	var card_style := HudCard.row_style(SystemPalette.PRIMARY)
	# Repeated list row: no chamfer cut (reserved for single feature cards, not a
	# container that repeats down a list).
	card_style.chamfer_size = 0.0
	card.add_theme_stylebox_override("panel", card_style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	var name_input := LineEdit.new()
	name_input.text = exercise.name
	name_input.placeholder_text = "Exercise name"
	name_input.custom_minimum_size = Vector2(0.0, TOUCH_TARGET)
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(new_text: String) -> void:
		exercise.name = new_text
		_mark_dirty()
	)
	col.add_child(name_input)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 14)
	col.add_child(controls)

	var sets_input := SpinBox.new()
	sets_input.min_value = 1
	sets_input.max_value = 10
	sets_input.step = 1
	sets_input.value = exercise.sets
	sets_input.suffix = "sets"
	sets_input.custom_minimum_size = Vector2(230.0, TOUCH_TARGET)
	sets_input.value_changed.connect(func(new_value: float) -> void:
		exercise.sets = int(new_value)
		_mark_dirty()
	)
	controls.add_child(sets_input)

	var reps_input := LineEdit.new()
	reps_input.text = exercise.rep_range
	reps_input.placeholder_text = "8-10"
	reps_input.custom_minimum_size = Vector2(180.0, TOUCH_TARGET)
	reps_input.text_changed.connect(func(new_text: String) -> void:
		exercise.rep_range = new_text
		_mark_dirty()
	)
	controls.add_child(reps_input)

	# The rep range is free text, so it needs a visible unit — "8-10" alone is ambiguous
	# next to a sets field that spells its own out.
	var reps_unit := Label.new()
	reps_unit.theme_type_variation = &"SecondaryLabel"
	reps_unit.add_theme_font_size_override("font_size", 26)
	reps_unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reps_unit.text = "REPS"
	controls.add_child(reps_unit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(spacer)

	var alternatives := ExerciseCatalog.get_alternatives(exercise.name)
	var swap_button := _build_icon_button(HudGlyph.Shape.SWAP, SystemPalette.PRIMARY, "Swap for a same-muscle alternative")
	swap_button.disabled = alternatives.is_empty()
	swap_button.pressed.connect(_on_swap_exercise.bind(exercise, alternatives, swap_button))
	controls.add_child(swap_button)

	# Warning accent, and the only one on the row: removal is the destructive action here and
	# the design system asks for destructive controls to be colored and set apart.
	var remove_button := _build_icon_button(HudGlyph.Shape.CLOSE, SystemPalette.WARNING, "Remove this exercise")
	remove_button.pressed.connect(_on_remove_exercise.bind(day, exercise_index))
	controls.add_child(remove_button)

	return card


## Small picker (spec 4.5 program editing) offering same-muscle-group alternatives
## to the exercise in this row. Only the name field changes; sets/rep range stay.
func _on_swap_exercise(exercise: Exercise, alternatives: Array[String], anchor: Control) -> void:
	var popup := PopupMenu.new()
	for alt_name in alternatives:
		popup.add_item(alt_name)
	popup.id_pressed.connect(func(id: int) -> void:
		exercise.name = alternatives[id]
		_mark_dirty()
		_refresh_program()
	)
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	popup.popup(Rect2(anchor.global_position, Vector2(380, 0)))


func _on_add_exercise(day: TrainingDay) -> void:
	var exercise := Exercise.new()
	exercise.name = ""
	exercise.sets = 3
	exercise.rep_range = "8-10"
	day.exercises.append(exercise)
	_mark_dirty()
	_refresh_program()


func _on_remove_exercise(day: TrainingDay, exercise_index: int) -> void:
	day.exercises.remove_at(exercise_index)
	_mark_dirty()
	_refresh_program()


func _on_save_pressed() -> void:
	if not _protein_manually_edited:
		ProfileManager.apply_targets()
		protein_input.set_value_no_signal(QuestManager.protein_target_g)
	SaveManager.save_game()
	_dirty = false
	_show_status("SAVED.", SystemPalette.SUCCESS)


## Every edit is already live in the autoloads but not on disk, so leaving without saving
## looks like nothing happened until the next launch drops the changes. Warn once instead.
func _on_back_pressed() -> void:
	if _dirty:
		unsaved_confirm.popup_centered()
		return
	_go_back()


func _mark_dirty() -> void:
	_dirty = true


func _show_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	status_label.modulate.a = 1.0
	_status_tween = create_tween()
	_status_tween.tween_interval(STATUS_HOLD_TIME)
	_status_tween.tween_property(status_label, "modulate:a", 0.0, STATUS_FADE_TIME)


func _go_back() -> void:
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")
