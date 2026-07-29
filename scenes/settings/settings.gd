extends Control

## Settings (spec 4.5): edit the training program's exercises, protein target, creatine
## dose, and the end-of-day reminder (spec v2 4.1).
## Edits mutate QuestManager/NotificationManager's live data directly; the Save button
## persists it via SaveManager. Program changes take effect starting the next daily
## quest generation, same as any other program edit.

@onready var goal_input: OptionButton = $Margin/Root/Scroll/Content/ProfileCard/ProfileCardMargin/ProfileSection/GoalRow/GoalInput
@onready var weight_input: SpinBox = $Margin/Root/Scroll/Content/ProfileCard/ProfileCardMargin/ProfileSection/WeightRow/WeightInput
@onready var days_input: SpinBox = $Margin/Root/Scroll/Content/ProfileCard/ProfileCardMargin/ProfileSection/DaysRow/DaysInput
@onready var equipment_input: OptionButton = $Margin/Root/Scroll/Content/ProfileCard/ProfileCardMargin/ProfileSection/EquipmentRow/EquipmentInput
@onready var calculated_label: Label = $Margin/Root/Scroll/Content/ProfileCard/ProfileCardMargin/ProfileSection/CalculatedLabel
@onready var protein_input: SpinBox = $Margin/Root/Scroll/Content/NutritionCard/NutritionCardMargin/NutritionSection/ProteinRow/ProteinInput
@onready var creatine_input: SpinBox = $Margin/Root/Scroll/Content/NutritionCard/NutritionCardMargin/NutritionSection/CreatineRow/CreatineInput
@onready var reminder_list: VBoxContainer = $Margin/Root/Scroll/Content/NotificationCard/NotificationCardMargin/NotificationSection/ReminderList
@onready var program_list: VBoxContainer = $Margin/Root/Scroll/Content/ProgramSection/ProgramList
@onready var regenerate_button: Button = $Margin/Root/Scroll/Content/ProgramSection/RegenerateButton
@onready var regenerate_confirm: ConfirmationDialog = $RegenerateConfirm
@onready var status_label: Label = $Margin/Root/StatusLabel
@onready var save_button: Button = $Margin/Root/ButtonRow/SaveButton
@onready var back_button: Button = $Margin/Root/ButtonRow/BackButton
@onready var profile_card: PanelContainer = $Margin/Root/Scroll/Content/ProfileCard
@onready var nutrition_card: PanelContainer = $Margin/Root/Scroll/Content/NutritionCard
@onready var notification_card: PanelContainer = $Margin/Root/Scroll/Content/NotificationCard

# Set once the user edits the protein field directly, so Save doesn't clobber a manual
# override with ProfileManager.apply_targets()'s formula-calculated value.
var _protein_manually_edited := false

func _ready() -> void:
	for card in [profile_card, nutrition_card, notification_card]:
		card.add_theme_stylebox_override("panel", ChamferedStyleBox.new())
	NavButtonStyle.apply(save_button)
	NavButtonStyle.apply(back_button)
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
	back_button.pressed.connect(_go_back)
	PressFeedback.attach(save_button)
	PressFeedback.attach(back_button)
	PressFeedback.attach(regenerate_button)

	regenerate_button.pressed.connect(_on_regenerate_pressed)
	regenerate_confirm.confirmed.connect(_on_regenerate_confirmed)

	_refresh_reminders()
	_refresh_program()
	_refresh_calculated()


func _on_goal_selected(index: int) -> void:
	ProfileManager.profile.goal = ProfileManager.GOALS[index]
	_refresh_calculated()


func _on_weight_changed(value: float) -> void:
	ProfileManager.profile.weight_kg = value
	_refresh_calculated()


func _on_days_changed(value: float) -> void:
	ProfileManager.profile.days_per_week = int(value)


func _on_equipment_selected(index: int) -> void:
	ProfileManager.profile.equipment_access = ProfileManager.EQUIPMENT_OPTIONS[index]


## Regeneration discards any manual program edits, so it only ever runs after explicit
## confirmation — never silently when goal/days/equipment change elsewhere in Settings.
func _on_regenerate_pressed() -> void:
	regenerate_confirm.popup_centered()


func _on_regenerate_confirmed() -> void:
	var profile := ProfileManager.profile
	QuestManager.training_cycle = ProgramGenerator.generate_program(profile.days_per_week, profile.goal, profile.equipment_access)
	_refresh_program()
	status_label.text = "Program regenerated — press Save to keep it."


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


func _on_creatine_changed(value: float) -> void:
	QuestManager.creatine_target_g = value


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


func _build_reminder_row(category: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var enabled_check := CheckBox.new()
	enabled_check.text = REMINDER_LABELS.get(category, category.capitalize())
	enabled_check.button_pressed = NotificationManager.reminder_enabled.get(category, true)
	enabled_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enabled_check.toggled.connect(func(pressed: bool): NotificationManager.reminder_enabled[category] = pressed)
	row.add_child(enabled_check)

	var hour_input := SpinBox.new()
	hour_input.min_value = 0
	hour_input.max_value = 23
	hour_input.step = 1
	hour_input.value = NotificationManager.reminder_hours.get(category, 20)
	hour_input.custom_minimum_size = Vector2(120, 0)
	hour_input.value_changed.connect(func(value: float): NotificationManager.reminder_hours[category] = int(value))
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
	section.add_theme_constant_override("separation", 8)

	var header := Label.new()
	header.text = "Day %d — %s" % [day_index + 1, day.day_name] + ("  (Rest)" if day.is_rest_day else "")
	section.add_child(header)

	if day.is_rest_day:
		return section

	for exercise_index in range(day.exercises.size()):
		section.add_child(_build_exercise_row(day, exercise_index))

	var add_button := Button.new()
	add_button.text = "+ Add Exercise"
	add_button.pressed.connect(_on_add_exercise.bind(day))
	PressFeedback.attach(add_button)
	section.add_child(add_button)

	var separator := HSeparator.new()
	section.add_child(separator)

	return section


func _build_exercise_row(day: TrainingDay, exercise_index: int) -> Control:
	var exercise: Exercise = day.exercises[exercise_index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_input := LineEdit.new()
	name_input.text = exercise.name
	name_input.placeholder_text = "Exercise name"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(new_text: String): exercise.name = new_text)
	row.add_child(name_input)

	var sets_input := SpinBox.new()
	sets_input.min_value = 1
	sets_input.max_value = 10
	sets_input.step = 1
	sets_input.value = exercise.sets
	sets_input.custom_minimum_size = Vector2(120, 0)
	sets_input.value_changed.connect(func(new_value: float): exercise.sets = int(new_value))
	row.add_child(sets_input)

	var reps_input := LineEdit.new()
	reps_input.text = exercise.rep_range
	reps_input.placeholder_text = "reps"
	reps_input.custom_minimum_size = Vector2(100, 0)
	reps_input.text_changed.connect(func(new_text: String): exercise.rep_range = new_text)
	row.add_child(reps_input)

	var alternatives := ExerciseCatalog.get_alternatives(exercise.name)
	var swap_button := Button.new()
	swap_button.text = "Swap"
	swap_button.disabled = alternatives.is_empty()
	swap_button.pressed.connect(_on_swap_exercise.bind(exercise, alternatives, swap_button))
	PressFeedback.attach(swap_button)
	row.add_child(swap_button)

	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.pressed.connect(_on_remove_exercise.bind(day, exercise_index))
	PressFeedback.attach(remove_button)
	row.add_child(remove_button)

	return row


## Small picker (spec 4.5 program editing) offering same-muscle-group alternatives
## to the exercise in this row. Only the name field changes; sets/rep range stay.
func _on_swap_exercise(exercise: Exercise, alternatives: Array[String], anchor: Control) -> void:
	var popup := PopupMenu.new()
	for alt_name in alternatives:
		popup.add_item(alt_name)
	popup.id_pressed.connect(func(id: int):
		exercise.name = alternatives[id]
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
	_refresh_program()


func _on_remove_exercise(day: TrainingDay, exercise_index: int) -> void:
	day.exercises.remove_at(exercise_index)
	_refresh_program()


func _on_save_pressed() -> void:
	if not _protein_manually_edited:
		ProfileManager.apply_targets()
		protein_input.set_value_no_signal(QuestManager.protein_target_g)
	SaveManager.save_game()
	status_label.text = "Saved."


func _go_back() -> void:
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")
