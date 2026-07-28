extends Node

## Tracks each exercise's best-ever performance from completed lift quests (v3 PR Tracker).
## Lives as its own autoload rather than on HunterStats, mirroring HistoryManager —
## HunterStats is pure progression state (level/xp/rank), this is a separate per-exercise ledger.
##
## "Weighted" vs "bodyweight" isn't a static property of the exercise — Quest/Exercise carry
## no such flag — so it's decided per completion, from whether a weight was actually entered
## (logged_weight > 0.0). A weighted completion's record is measured in logged_weight; a
## bodyweight completion (weight left blank, e.g. Pull-Up) falls back to logged_value (reps).
## The two metrics are kept in separate slots per exercise so they never get compared against
## each other, since mixing "80kg" against "12 reps" would be meaningless.

signal new_pr(exercise_name: String, value: float, metric: String)  # metric: "weight" or "reps"

var personal_records: Dictionary = {}  # exercise_name -> {"metric": "weight"|"reps", "value": float}


func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)


func _on_quest_completed(quest: Quest) -> void:
	if quest.category != "lift" or quest.exercise_name == "":
		return

	var is_weighted := quest.logged_weight > 0.0
	var metric := "weight" if is_weighted else "reps"
	var candidate: float = quest.logged_weight if is_weighted else quest.logged_value

	var current: Dictionary = personal_records.get(quest.exercise_name, {})
	if current.get("metric", "") == metric and candidate <= current.get("value", 0.0):
		return

	personal_records[quest.exercise_name] = {"metric": metric, "value": candidate}
	new_pr.emit(quest.exercise_name, candidate, metric)


## Shared display formatting so the popup and Stats list render values identically.
func format_value(value: float) -> String:
	if value == floor(value):
		return str(int(value))
	return str(value)


## Human-readable "80" or "12 reps" depending on metric, for popup/Stats display.
func format_record(record: Dictionary) -> String:
	var text := format_value(record.get("value", 0.0))
	if record.get("metric", "") == "reps":
		text += " reps"
	return text


func to_dict() -> Dictionary:
	return personal_records.duplicate(true)


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)
