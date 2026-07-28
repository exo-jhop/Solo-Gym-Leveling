extends Node

## Tracks each exercise's best-ever logged_value from completed lift quests (v3 PR Tracker).
## Lives as its own autoload rather than on HunterStats, mirroring HistoryManager —
## HunterStats is pure progression state (level/xp/rank), this is a separate per-exercise ledger.

signal new_pr(exercise_name: String, value: float)

var personal_records: Dictionary = {}  # exercise_name -> best logged_value


func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)


func _on_quest_completed(quest: Quest) -> void:
	if quest.category != "lift" or quest.exercise_name == "":
		return
	var best: float = personal_records.get(quest.exercise_name, 0.0)
	if quest.logged_value > best:
		personal_records[quest.exercise_name] = quest.logged_value
		new_pr.emit(quest.exercise_name, quest.logged_value)


## Shared display formatting so the popup and Stats list render values identically.
func format_value(value: float) -> String:
	if value == floor(value):
		return str(int(value))
	return str(value)


func to_dict() -> Dictionary:
	return personal_records.duplicate()


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate()
