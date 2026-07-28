class_name DailyLog
extends Resource

## Snapshot of one calendar day's quest activity, for the Training Log / calendar view.

@export var date: String = ""              # "YYYY-MM-DD", matches Time.get_date_string_from_system()
@export var is_rest_day: bool = false
@export var quests_total: int = 0
@export var quests_completed: int = 0
@export var xp_earned: int = 0
@export var stat_gains: Dictionary = {}     # e.g. {"STR": 2, "VIT": 1}
@export var quest_summaries: Array = []     # lightweight dicts: {id, title, category, stat_reward, completed, logged_value, unit}
@export var was_reduced_intensity: bool = false  # true if the "low energy" toggle was used this day (spec v2 4.3)
@export var is_missed: bool = false  # true if the app was never opened this day (backfilled from a multi-day gap)


func to_dict() -> Dictionary:
	return {
		"date": date,
		"is_rest_day": is_rest_day,
		"quests_total": quests_total,
		"quests_completed": quests_completed,
		"xp_earned": xp_earned,
		"stat_gains": stat_gains,
		"quest_summaries": quest_summaries,
		"was_reduced_intensity": was_reduced_intensity,
		"is_missed": is_missed,
	}


static func from_dict(data: Dictionary) -> DailyLog:
	var log := DailyLog.new()
	log.date = data.get("date", "")
	log.is_rest_day = data.get("is_rest_day", false)
	log.quests_total = data.get("quests_total", 0)
	log.quests_completed = data.get("quests_completed", 0)
	log.xp_earned = data.get("xp_earned", 0)
	log.stat_gains = data.get("stat_gains", {})
	log.quest_summaries = data.get("quest_summaries", [])
	log.was_reduced_intensity = data.get("was_reduced_intensity", false)
	log.is_missed = data.get("is_missed", false)
	return log
