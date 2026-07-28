extends Control

## Settings (spec 4.5): edit the training program's exercises, protein target, creatine
## dose, and the end-of-day reminder (spec v2 4.1).
## Edits mutate QuestManager/NotificationManager's live data directly; the Save button
## persists it via SaveManager. Program changes take effect starting the next daily
## quest generation, same as any other program edit.

@onready var protein_input: SpinBox = $Margin/Root/Scroll/Content/NutritionSection/ProteinRow/ProteinInput
@onready var creatine_input: SpinBox = $Margin/Root/Scroll/Content/NutritionSection/CreatineRow/CreatineInput
@onready var reminder_list: VBoxContainer = $Margin/Root/Scroll/Content/NotificationSection/ReminderList
@onready var program_list: VBoxContainer = $Margin/Root/Scroll/Content/ProgramSection/ProgramList
@onready var status_label: Label = $Margin/Root/StatusLabel
@onready var save_button: Button = $Margin/Root/ButtonRow/SaveButton
@onready var back_button: Button = $Margin/Root/ButtonRow/BackButton


func _ready() -> void:
	protein_input.value = QuestManager.protein_target_g
	creatine_input.value = QuestManager.creatine_target_g
	protein_input.value_changed.connect(_on_protein_changed)
	creatine_input.value_changed.connect(_on_creatine_changed)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_go_back)

	_refresh_reminders()
	_refresh_program()


func _on_protein_changed(value: float) -> void:
	QuestManager.protein_target_g = value


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
	row.add_theme_constant_override("separation", 8)

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
	hour_input.custom_minimum_size = Vector2(70, 0)
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
	section.add_theme_constant_override("separation", 4)

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
	section.add_child(add_button)

	var separator := HSeparator.new()
	section.add_child(separator)

	return section


func _build_exercise_row(day: TrainingDay, exercise_index: int) -> Control:
	var exercise: Exercise = day.exercises[exercise_index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

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
	sets_input.custom_minimum_size = Vector2(70, 0)
	sets_input.value_changed.connect(func(new_value: float): exercise.sets = int(new_value))
	row.add_child(sets_input)

	var reps_input := LineEdit.new()
	reps_input.text = exercise.rep_range
	reps_input.placeholder_text = "reps"
	reps_input.custom_minimum_size = Vector2(60, 0)
	reps_input.text_changed.connect(func(new_text: String): exercise.rep_range = new_text)
	row.add_child(reps_input)

	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.pressed.connect(_on_remove_exercise.bind(day, exercise_index))
	row.add_child(remove_button)

	return row


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
	SaveManager.save_game()
	status_label.text = "Saved."


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
