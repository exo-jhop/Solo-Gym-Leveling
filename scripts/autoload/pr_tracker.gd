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

## Time series of every new-best moment per exercise, for the Stats sparkline.
## Not backfilled for pre-existing saves — a save with a personal_records entry but no
## pr_history entry just starts empty and grows from the next PR onward (spec: no fake data).
var pr_history: Dictionary = {}  # exercise_name -> Array[{"date": String, "value": float, "metric": String}]


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

	var entries: Array = pr_history.get(quest.exercise_name, [])
	entries.append({"date": Time.get_date_string_from_system(), "value": candidate, "metric": metric})
	pr_history[quest.exercise_name] = entries


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


## PR weight ÷ bodyweight, as a plain ratio. Returns -1.0 when not computable: the
## record isn't weight-based (reps-only/bodyweight exercise), or bodyweight_kg isn't
## set yet — callers should treat -1.0 as "omit", not display it.
func relative_strength(record: Dictionary, bodyweight_kg: float) -> float:
	if record.get("metric", "") != "weight" or bodyweight_kg <= 0.0:
		return -1.0
	return record.get("value", 0.0) / bodyweight_kg


## "1.35x BW" display string for a relative-strength ratio, or "" if not computable.
func format_relative_strength(record: Dictionary, bodyweight_kg: float) -> String:
	var ratio := relative_strength(record, bodyweight_kg)
	if ratio < 0.0:
		return ""
	return "%.2fx BW" % ratio


func to_dict() -> Dictionary:
	return personal_records.duplicate(true)


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


## Separate save key from personal_records (see save_manager.gd) so old saves —
## which stored personal_records as a flat dict with no pr_history alongside it —
## keep loading correctly with an empty history rather than losing their PRs.
func to_history_dict() -> Dictionary:
	return pr_history.duplicate(true)


static func from_history_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)
