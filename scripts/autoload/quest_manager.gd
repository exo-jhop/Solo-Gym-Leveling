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

# Today's user-authored meal plan (feature: daily meal plan). Free-text entries only, no
# calorie/macro number — the "meal_plan" quest below is what actually tracks completion,
# this array is just the checklist backing it. Reset to empty every generate_daily_quests()
# call since a meal plan is authored fresh each day, unlike protein/creatine targets.
var meal_plan: Array[MealEntry] = []

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

# Remaining training days in an accepted recovery week (adaptive daily load, v5).
# Persisted — unlike pending_* scratch state, an accepted multi-day commitment must
# survive both restarts and day rollovers, which is exactly what low_energy_mode alone
# cannot do (it resets to false on every generate_daily_quests() call).
var recovery_days_remaining: int = 0

# Staged by SaveManager's daily check (see LoadAdjuster). Not persisted, matching
# pending_recalibration: if the app closes before the user answers, it is simply
# re-evaluated on the next rollover rather than reappearing stale.
var pending_load_adjustment: Dictionary = {}


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
	meal_plan.clear()
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
				# Index-prefixed so two exercises with the same name in one day — or two
				# blank-named rows, which Settings' "+ Add Exercise" creates by default —
				# don't collide. complete_quest()/get_quest() match on id, so a duplicate
				# id left the second quest permanently uncompletable.
				"lift_%d_%s" % [i, exercise.name.to_snake_case()],
				"%s: %dx%s" % [exercise.name, exercise.sets, exercise.rep_range],
				"lift", stat, 15, exercise.sets, "sets"
			)
			quest.exercise_name = exercise.name
			quest.rep_range = exercise.rep_range
			current_quests.append(quest)

		# Recovery week (adaptive daily load, v5): auto-applies the existing single-set
		# reduction for the day's lift quests, mirroring the manual low-energy toggle so
		# there's only one difficulty mechanism. A rest day has no lift quests to reduce
		# and must not consume a recovery day, hence this sits inside the non-rest branch.
		if recovery_days_remaining > 0:
			_apply_set_reduction(true)
			low_energy_mode = true
			recovery_days_remaining -= 1

	current_quests.append(_make_quest("protein", "Hit %dg protein" % int(protein_target_g), "nutrition", "INT", 10, protein_target_g, "g"))
	current_quests.append(_make_quest("creatine", "Take %dg creatine" % int(creatine_target_g), "supplement", "SENSE", 5, creatine_target_g, "g"))
	current_quests.append(_make_quest("meal_plan", "Follow your meal plan", "meal", "INT", 15, 0.0, "meals"))

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


## Adds a planned meal to today's list (feature: daily meal plan). Ignores blank input
## rather than erroring, since the add-meal field has no other validation.
func add_meal_entry(meal_name: String) -> void:
	var trimmed := meal_name.strip_edges()
	if trimmed == "":
		return
	var entry := MealEntry.new()
	# Ticks, not Time.get_unix_time_from_system(): unique enough for user-triggered taps
	# within a single day and doesn't depend on wall-clock/save-load round-tripping.
	entry.id = str(Time.get_ticks_usec())
	entry.name = trimmed
	meal_plan.append(entry)
	_sync_meal_quest()


func remove_meal_entry(entry_id: String) -> void:
	for i in meal_plan.size():
		if meal_plan[i].id == entry_id:
			meal_plan.remove_at(i)
			break
	_sync_meal_quest()


func toggle_meal_entry(entry_id: String) -> void:
	for entry in meal_plan:
		if entry.id == entry_id:
			entry.completed = not entry.completed
			break
	_sync_meal_quest()


## Keeps the "meal_plan" quest's target/logged value mirroring the live meal_plan list, and
## completes it (once, via complete_quest so quest_completed/XP fire normally) the moment
## every planned meal is checked off. An empty plan never auto-completes — no meals planned
## isn't "done", it's just nothing to check off yet.
func _sync_meal_quest() -> void:
	var quest := get_quest("meal_plan")
	if quest == null:
		return
	var eaten := 0
	for entry in meal_plan:
		if entry.completed:
			eaten += 1
	quest.target_value = meal_plan.size()
	quest.logged_value = eaten
	if meal_plan.size() > 0 and eaten == meal_plan.size() and not quest.completed:
		complete_quest("meal_plan", eaten)


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

	_apply_set_reduction(enabled)
	low_energy_mode = enabled
	quests_generated.emit()


## Shared reduction logic for both the manual low-energy toggle and an accepted recovery
## week (adaptive daily load, v5) — one difficulty mechanism, two triggers. Does not emit
## quests_generated itself: callers that build current_quests from scratch (recovery week
## inside generate_daily_quests()) must not double-emit the signal that call already fires.
func _apply_set_reduction(enabled: bool) -> void:
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


## Applies an accepted load adjustment (adaptive daily load, v5). recovery_week only sets
## a counter — the training_cycle is untouched, since a recovery week is a temporary dial,
## not a program change; generate_daily_quests() re-applies the reduction each of the next
## recovery_days_remaining days. reduce_volume/ready_to_progress do edit the cycle, the
## same way apply_recalibration does. Both are capped/floored so repeated accepts can't
## drift volume unbounded in either direction. Caller is expected to save afterward.
func apply_load_adjustment(suggestion: Dictionary) -> void:
	match suggestion.get("kind", ""):
		"recovery_week":
			recovery_days_remaining = suggestion.get("recovery_days", LoadAdjuster.RECOVERY_WEEK_DAYS)
		"reduce_volume":
			var min_sets: int = suggestion.get("min_sets", LoadAdjuster.MIN_SETS)
			for day in training_cycle:
				if day.is_rest_day:
					continue
				for exercise in day.exercises:
					exercise.sets = maxi(exercise.sets + suggestion.get("set_delta", -LoadAdjuster.SET_DELTA), min_sets)
		"ready_to_progress":
			var max_sets: int = suggestion.get("max_sets", LoadAdjuster.MAX_SETS)
			for day in training_cycle:
				if day.is_rest_day:
					continue
				for exercise in day.exercises:
					exercise.sets = mini(exercise.sets + suggestion.get("set_delta", LoadAdjuster.SET_DELTA), max_sets)

	pending_load_adjustment = {}


func dismiss_load_adjustment() -> void:
	pending_load_adjustment = {}


## True while a recovery week is in progress, for Home's indicator and Settings' cancel.
func recovery_week_active() -> bool:
	return recovery_days_remaining > 0


## User override: cancels the remaining recovery week (see home.gd interaction note).
## Only clears the counter so future days stop re-applying the reduction — today's
## already-generated quests are reverted separately by set_low_energy_mode(false), the
## same path the manual toggle uses.
func cancel_recovery_week() -> void:
	recovery_days_remaining = 0
