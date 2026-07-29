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

# "Feeling low energy today?" toggle (spec v2 4.3). Resets to false on each new day;
# persisted across app restarts within the same day so the choice sticks.
var low_energy_mode: bool = false

# Whether Home has already shown the "all quests complete" toast for today's set.
# Reset on every generate_daily_quests() call so it can fire again tomorrow.
var all_complete_shown: bool = false

const BODYWEIGHT_LOG_DAYS := [0, 3]  # cycle day indices that include a bodyweight quest

# Staged by SaveManager's weekly check (see ProgramRecalibrator) when the logged weight
# trend doesn't match the goal's expectation. Not persisted — if the app closes before the
# user responds, it's simply re-evaluated on the next weekly check rather than reappearing
# stale. Consumed by the recalibration popup.
var pending_recalibration: Dictionary = {}


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


## Maps a training day's name to the stat its lifts train. Covers both the placeholder
## cycle ("Upper/Lower Body A/B") and every split ProgramGenerator produces (Full Body,
## Push/Pull/Legs, Arms & Core). Full Body days alternate STR/VIT per exercise index
## since a single day trains both.
func _stat_for_day(day_name: String, exercise_index: int) -> String:
	if day_name.begins_with("Upper") or day_name.begins_with("Push"):
		return "STR"
	if day_name.begins_with("Lower") or day_name.begins_with("Pull") or day_name.begins_with("Legs"):
		return "VIT"
	if day_name.begins_with("Full Body"):
		return "STR" if exercise_index % 2 == 0 else "VIT"
	if day_name.begins_with("Arms") or day_name.contains("Core"):
		return "AGI"
	return "VIT"


## Builds current_quests for the current cycle_day_index, then advances the cycle.
func generate_daily_quests() -> void:
	current_quests.clear()
	low_energy_mode = false
	all_complete_shown = false
	var day: TrainingDay = training_cycle[cycle_day_index]

	if day.is_rest_day:
		current_quests.append(_make_quest("recovery_%d" % cycle_day_index, "Rest and Recover", "recovery", "", 5, 0.0, ""))
	else:
		for i in day.exercises.size():
			var exercise: Exercise = day.exercises[i]
			var stat := _stat_for_day(day.day_name, i)
			var quest := _make_quest(
				"lift_%s" % exercise.name.to_snake_case(),
				"%s: %dx%s" % [exercise.name, exercise.sets, exercise.rep_range],
				"lift", stat, 15, exercise.sets, "sets"
			)
			quest.exercise_name = exercise.name
			quest.rep_range = exercise.rep_range
			current_quests.append(quest)

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
func complete_quest(quest_id: String, logged_value: float = 0.0, logged_weight: float = 0.0) -> bool:
	for quest in current_quests:
		if quest.id == quest_id and not quest.completed:
			quest.completed = true
			quest.logged_value = logged_value
			quest.logged_weight = logged_weight
			quest_completed.emit(quest)
			return true
	return false


func all_quests_completed() -> bool:
	if current_quests.is_empty():
		return false
	for quest in current_quests:
		if not quest.completed:
			return false
	return true


func has_lift_quests() -> bool:
	for quest in current_quests:
		if quest.category == "lift":
			return true
	return false


func any_lift_quest_completed() -> bool:
	for quest in current_quests:
		if quest.category == "lift" and quest.completed:
			return true
	return false


## Toggles today's "feeling low energy?" mode (spec v2 4.3): drops one set from
## each not-yet-completed lift quest's target, or restores it when turned back off.
## No-op if there's nothing to adjust or a lift quest is already completed today
## (retroactively changing a finished quest's target doesn't make sense).
## Uses each quest's own exercise_name/rep_range/original_target_value fields
## rather than parsing `title`, so display-text changes can't break the reversal.
func set_low_energy_mode(enabled: bool) -> void:
	if enabled == low_energy_mode:
		return
	if not has_lift_quests() or any_lift_quest_completed():
		return

	for quest in current_quests:
		if quest.category != "lift":
			continue
		if enabled:
			quest.original_target_value = quest.target_value
			quest.target_value = max(1, int(quest.target_value) - 1)
		elif quest.original_target_value >= 0:
			quest.target_value = quest.original_target_value
			quest.original_target_value = -1.0
		quest.title = "%s: %dx%s" % [quest.exercise_name, int(quest.target_value), quest.rep_range]

	low_energy_mode = enabled
	quests_generated.emit()


## Applies an accepted weekly recalibration suggestion — a single Accept bundles both the
## training and nutrition reaction, there's no separate opt-in for each (see
## ProgramRecalibrator): adds `set_delta` sets to every lift exercise in the live
## training_cycle (capped at `max_sets` so accepting several weeks running doesn't grow
## volume unbounded), syncs profile.weight_kg to the observed trend and recalculates the
## protein target from it, and bumps calorie_intensity so the calorie guidance text reads
## more assertively. Persisted the same way Regenerate Program is — the caller is expected
## to save afterward.
func apply_recalibration(suggestion: Dictionary) -> void:
	var set_delta: int = suggestion.get("set_delta", 1)
	var max_sets: int = suggestion.get("max_sets", 6)
	for day in training_cycle:
		if day.is_rest_day:
			continue
		for exercise in day.exercises:
			exercise.sets = mini(exercise.sets + set_delta, max_sets)

	if suggestion.has("weight_kg"):
		ProfileManager.profile.weight_kg = suggestion["weight_kg"]
		ProfileManager.profile.calorie_intensity = suggestion.get("calorie_intensity", "normal")
		ProfileManager.apply_targets()

	pending_recalibration = {}


func dismiss_recalibration() -> void:
	pending_recalibration = {}
