extends Node

## Generates the day's quests from the training cycle and tracks their completion.

signal quest_completed(quest: Quest)
signal quests_generated

# Default 7-day cycle: training on days 0,1,3,4 (spec's "Day 1,2,4,5"), rest on 2,5,6.
# User-editable from Settings (spec 4.5); SaveManager persists whatever the user has here.
var training_cycle: Array[TrainingDay] = []

var cycle_day_index: int = 0
var current_quests: Array[Quest] = []

# Set by Home before navigating to Quest Detail, read there to look up the tapped quest.
var selected_quest_id: String = ""

# User-editable from Settings (spec 4.5). Defaults match the original placeholder values.
var protein_target_g: float = 90.0
var creatine_target_g: float = 5.0

const BODYWEIGHT_LOG_DAYS := [0, 3]  # cycle day indices that include a bodyweight quest


func _ready() -> void:
	_build_placeholder_cycle()


func _build_placeholder_cycle() -> void:
	var upper_a := TrainingDay.new()
	upper_a.day_name = "Upper Body A"
	upper_a.exercises = [
		_exercise("Bench Press", 4, "6-8"),
		_exercise("Barbell Row", 4, "6-8"),
		_exercise("Overhead Press", 3, "8-10"),
	]

	var lower_a := TrainingDay.new()
	lower_a.day_name = "Lower Body A"
	lower_a.exercises = [
		_exercise("Squat", 4, "6-8"),
		_exercise("Romanian Deadlift", 3, "8-10"),
		_exercise("Leg Press", 3, "10-12"),
	]

	var rest := TrainingDay.new()
	rest.day_name = "Rest"
	rest.is_rest_day = true

	var upper_b := TrainingDay.new()
	upper_b.day_name = "Upper Body B"
	upper_b.exercises = [
		_exercise("Incline Dumbbell Press", 4, "8-10"),
		_exercise("Pull-Up", 4, "6-8"),
		_exercise("Lateral Raise", 3, "12-15"),
	]

	var lower_b := TrainingDay.new()
	lower_b.day_name = "Lower Body B"
	lower_b.exercises = [
		_exercise("Deadlift", 3, "5-6"),
		_exercise("Bulgarian Split Squat", 3, "8-10"),
		_exercise("Leg Curl", 3, "10-12"),
	]

	training_cycle = [upper_a, lower_a, rest, upper_b, lower_b, rest, rest]


func _exercise(name: String, sets: int, rep_range: String) -> Exercise:
	var exercise := Exercise.new()
	exercise.name = name
	exercise.sets = sets
	exercise.rep_range = rep_range
	return exercise


## Builds current_quests for the current cycle_day_index, then advances the cycle.
func generate_daily_quests() -> void:
	current_quests.clear()
	var day: TrainingDay = training_cycle[cycle_day_index]

	if day.is_rest_day:
		current_quests.append(_make_quest("recovery_%d" % cycle_day_index, "Rest and Recover", "recovery", "", 5, 0.0, ""))
	else:
		for exercise in day.exercises:
			var stat := "STR" if day.day_name.begins_with("Upper") else "VIT"
			current_quests.append(_make_quest(
				"lift_%s" % exercise.name.to_snake_case(),
				"%s: %dx%s" % [exercise.name, exercise.sets, exercise.rep_range],
				"lift", stat, 15, exercise.sets, "sets"
			))

	current_quests.append(_make_quest("protein", "Hit %dg protein" % int(protein_target_g), "nutrition", "INT", 10, protein_target_g, "g"))
	current_quests.append(_make_quest("creatine", "Take %dg creatine" % int(creatine_target_g), "supplement", "SENSE", 5, creatine_target_g, "g"))

	if cycle_day_index in BODYWEIGHT_LOG_DAYS:
		current_quests.append(_make_quest("bodyweight", "Log bodyweight", "nutrition", "INT", 5, 0.0, "kg"))

	cycle_day_index = (cycle_day_index + 1) % training_cycle.size()
	quests_generated.emit()


func _make_quest(id: String, title: String, category: String, stat_reward: String, xp_reward: int, target_value: float, unit: String) -> Quest:
	var quest := Quest.new()
	quest.id = id
	quest.title = title
	quest.category = category
	quest.stat_reward = stat_reward
	quest.xp_reward = xp_reward
	quest.target_value = target_value
	quest.unit = unit
	return quest


func get_quest(quest_id: String) -> Quest:
	for quest in current_quests:
		if quest.id == quest_id:
			return quest
	return null


## Marks a quest complete by id and emits quest_completed. Returns false if not found or already done.
func complete_quest(quest_id: String, logged_value: float = 0.0) -> bool:
	for quest in current_quests:
		if quest.id == quest_id and not quest.completed:
			quest.completed = true
			quest.logged_value = logged_value
			quest_completed.emit(quest)
			return true
	return false
