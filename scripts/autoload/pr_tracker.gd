extends Node

## Tracks each exercise's best-ever performance from completed lift quests (v3 PR Tracker).
## Lives as its own autoload rather than on HunterStats, mirroring HistoryManager —
## HunterStats is pure progression state (level/xp/rank), this is a separate per-exercise ledger.
##
## "Weighted" vs "bodyweight" isn't a static property of the exercise — Quest/Exercise carry
## no such flag — so it's decided per completion, from whether a weight was actually entered
## (logged_weight > 0.0). A weighted completion's record is measured in logged_weight; a
## bodyweight completion (weight left blank, e.g. Pull-Up) falls back to logged_value (reps).
## The two metrics get their own slot per exercise so they're never compared against each
## other, since ranking "80kg" against "12 reps" would be meaningless — and so logging one
## session of an exercise the other way (a weighted pull-up, or a bench set with the weight
## field left blank) can't overwrite and destroy the record held under the other metric.

signal new_pr(exercise_name: String, value: float, metric: String)  # metric: "weight" or "reps"

# Display order for an exercise that holds a record under both metrics.
const METRICS: Array[String] = ["weight", "reps"]

var personal_records: Dictionary = {}  # exercise_name -> {metric -> best value (float)}

## Time series of every new-best moment per exercise and metric, for the Stats sparkline.
## Not backfilled for pre-existing saves — a save with a personal_records entry but no
## pr_history entry just starts empty and grows from the next PR onward (spec: no fake data).
var pr_history: Dictionary = {}  # exercise_name -> {metric -> Array[{"date": String, "value": float}]}


func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)


func _on_quest_completed(quest: Quest) -> void:
	if quest.category != "lift" or quest.exercise_name == "":
		return

	var is_weighted := quest.logged_weight > 0.0
	var metric := "weight" if is_weighted else "reps"
	var candidate: float = quest.logged_weight if is_weighted else quest.logged_value
	# A quest completed with nothing logged carries no performance to record; without this
	# it registered a "0 reps" personal record and fired the NEW PR popup for it.
	if candidate <= 0.0:
		return

	var records: Dictionary = personal_records.get(quest.exercise_name, {})
	if records.has(metric) and candidate <= float(records[metric]):
		return

	records[metric] = candidate
	personal_records[quest.exercise_name] = records
	new_pr.emit(quest.exercise_name, candidate, metric)

	var by_metric: Dictionary = pr_history.get(quest.exercise_name, {})
	var entries: Array = by_metric.get(metric, [])
	entries.append({"date": Time.get_date_string_from_system(), "value": candidate})
	by_metric[metric] = entries
	pr_history[quest.exercise_name] = by_metric


## Best recorded value for an exercise under one metric, or -1.0 if it holds no record
## there — callers should treat -1.0 as "no row to show", not display it.
func best(exercise_name: String, metric: String) -> float:
	var records: Dictionary = personal_records.get(exercise_name, {})
	return float(records.get(metric, -1.0))


## Metrics this exercise actually holds a record under, in METRICS display order.
func metrics_for(exercise_name: String) -> Array:
	var records: Dictionary = personal_records.get(exercise_name, {})
	var found: Array = []
	for metric in METRICS:
		if records.has(metric):
			found.append(metric)
	return found


## New-best history for one exercise+metric, chronological. Empty if there is none.
func history_for(exercise_name: String, metric: String) -> Array:
	var by_metric: Dictionary = pr_history.get(exercise_name, {})
	var entries: Array = by_metric.get(metric, [])
	return entries


## Shared display formatting so the popup and Stats list render values identically.
func format_value(value: float) -> String:
	if value == floor(value):
		return str(int(value))
	return str(value)


## Human-readable "80" or "12 reps" depending on metric, for popup/Stats display.
func format_record(value: float, metric: String) -> String:
	var text := format_value(value)
	if metric == "reps":
		text += " reps"
	return text


## PR weight ÷ bodyweight, as a plain ratio. Returns -1.0 when not computable: the
## record isn't weight-based (reps-only/bodyweight exercise), or bodyweight_kg isn't
## set yet — callers should treat -1.0 as "omit", not display it.
func relative_strength(value: float, metric: String, bodyweight_kg: float) -> float:
	if metric != "weight" or bodyweight_kg <= 0.0:
		return -1.0
	return value / bodyweight_kg


## "1.35x BW" display string for a relative-strength ratio, or "" if not computable.
func format_relative_strength(value: float, metric: String, bodyweight_kg: float) -> String:
	var ratio := relative_strength(value, metric, bodyweight_kg)
	if ratio < 0.0:
		return ""
	return "%.2fx BW" % ratio


func to_dict() -> Dictionary:
	return personal_records.duplicate(true)


## Migrates the pre-per-metric save shape, which stored one {"metric": ..., "value": ...}
## slot per exercise, into the {metric -> value} map above so an old save keeps its PRs.
static func from_dict(data: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for exercise_name in data:
		var entry = data[exercise_name]
		if not (entry is Dictionary):
			continue
		if entry.has("metric"):
			var legacy: Dictionary = {}
			legacy[String(entry["metric"])] = float(entry.get("value", 0.0))
			records[exercise_name] = legacy
			continue
		var per_metric: Dictionary = {}
		for metric in entry:
			per_metric[String(metric)] = float(entry[metric])
		records[exercise_name] = per_metric
	return records


## Separate save key from personal_records (see save_manager.gd) so old saves —
## which stored personal_records as a flat dict with no pr_history alongside it —
## keep loading correctly with an empty history rather than losing their PRs.
func to_history_dict() -> Dictionary:
	return pr_history.duplicate(true)


## Old saves stored one flat Array per exercise with the metric on each point; regroup
## those by metric so a mixed-metric exercise doesn't draw kg and reps on one sparkline.
static func from_history_dict(data: Dictionary) -> Dictionary:
	var history: Dictionary = {}
	for exercise_name in data:
		var entry = data[exercise_name]
		if entry is Array:
			history[exercise_name] = _regroup_legacy_points(entry)
		elif entry is Dictionary:
			var by_metric: Dictionary = {}
			for metric in entry:
				by_metric[String(metric)] = (entry[metric] as Array).duplicate(true)
			history[exercise_name] = by_metric
	return history


static func _regroup_legacy_points(points: Array) -> Dictionary:
	var by_metric: Dictionary = {}
	for point in points:
		if not (point is Dictionary):
			continue
		var metric := String(point.get("metric", "reps"))
		var entries: Array = by_metric.get(metric, [])
		entries.append({"date": point.get("date", ""), "value": float(point.get("value", 0.0))})
		by_metric[metric] = entries
	return by_metric
