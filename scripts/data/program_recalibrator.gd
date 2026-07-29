class_name ProgramRecalibrator
extends RefCounted

## Weekly weight-trend check against goal expectation (feature: weekly recalibration).
## Only Build Muscle / Lose Fat have a clear weight-direction expectation — Get Stronger
## and General Fitness aren't measured by scale weight, so they're never flagged here.
## Needs at least MIN_LOGS bodyweight-quest entries to compare the most recent pair
## against the pair before it; with fewer, there isn't enough signal to suggest anything.

const MIN_LOGS := 4
const FLAT_THRESHOLD_KG := 0.3
const SET_DELTA := 1
const MAX_SETS := 6


## `logs` is an Array of logged bodyweight-quest values (kg), oldest first.
## `current_weight_kg` is the profile's stored weight, used only to phrase the sync note in
## the message — the proposed new value is always the recent-logs average. Returns {} if no
## recalibration should be suggested, otherwise a Dictionary consumed by QuestManager's
## pending_recalibration (goal, direction, set_delta, max_sets, weight_kg, calorie_intensity,
## message). A single suggestion bundles the training and nutrition reaction together —
## accepting applies both, there's no separate opt-in for each.
static func evaluate(goal: String, logs: Array, current_weight_kg: float) -> Dictionary:
	if goal != "build_muscle" and goal != "lose_fat":
		return {}
	if logs.size() < MIN_LOGS:
		return {}

	var recent: Array = logs.slice(logs.size() - 2, logs.size())
	var previous: Array = logs.slice(logs.size() - 4, logs.size() - 2)
	var recent_avg: float = (recent[0] + recent[1]) / 2.0
	var previous_avg: float = (previous[0] + previous[1]) / 2.0
	var delta := recent_avg - previous_avg

	var direction := "flat"
	if delta > FLAT_THRESHOLD_KG:
		direction = "up"
	elif delta < -FLAT_THRESHOLD_KG:
		direction = "down"

	var stalled := (goal == "build_muscle" and direction != "up") or (goal == "lose_fat" and direction != "down")
	if not stalled:
		return {}

	return {
		"goal": goal,
		"direction": direction,
		"set_delta": SET_DELTA,
		"max_sets": MAX_SETS,
		"weight_kg": recent_avg,
		"calorie_intensity": "increased",
		"message": _message(goal, current_weight_kg, recent_avg),
	}


static func _message(goal: String, current_weight_kg: float, new_weight_kg: float) -> String:
	var weight_note := "Update your logged weight from %.1f to %.1fkg and " % [current_weight_kg, new_weight_kg]
	match goal:
		"build_muscle":
			return "Your weight hasn't trended up this week. %sadd a set + a bigger surplus to push harder?" % weight_note
		"lose_fat":
			return "Your weight hasn't trended down this week. %sadd a set + a bigger deficit for more progress?" % weight_note
		_:
			return ""
