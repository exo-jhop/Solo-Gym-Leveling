extends Node

## Owns the day-by-day quest-completion history for the Training Log / calendar view.
## Today's in-progress day is NOT here until SaveManager rolls the day over —
## callers needing "today" should read QuestManager.current_quests directly.

var days: Dictionary = {}  # date string ("YYYY-MM-DD") -> DailyLog


## Builds a DailyLog snapshot for `date` from the day's now-finished quest list and stores it.
func record_day(date: String, quests: Array[Quest], was_reduced_intensity: bool = false) -> void:
	var log := DailyLog.new()
	log.date = date
	log.was_reduced_intensity = was_reduced_intensity

	var xp_earned := 0
	var stat_gains: Dictionary = {}
	var summaries: Array = []
	var is_rest_day := false

	for quest in quests:
		if quest.category == "recovery":
			is_rest_day = true
		if quest.completed:
			xp_earned += quest.xp_reward
			if quest.stat_reward != "":
				stat_gains[quest.stat_reward] = stat_gains.get(quest.stat_reward, 0) + GameManager.STAT_INCREMENT
		summaries.append({
			"id": quest.id,
			"title": quest.title,
			"category": quest.category,
			"stat_reward": quest.stat_reward,
			"completed": quest.completed,
			"logged_value": quest.logged_value,
			"unit": quest.unit,
		})

	log.is_rest_day = is_rest_day
	log.quests_total = quests.size()
	log.quests_completed = quests.filter(func(q): return q.completed).size()
	log.xp_earned = xp_earned
	log.stat_gains = stat_gains
	log.quest_summaries = summaries

	days[date] = log


## Records `date` as a day the app was never opened at all (distinct from a day that
## was opened but had 0/N quests completed). Used to backfill gaps found when
## check_new_day() detects more than one calendar day passed since the last open.
func record_missed_day(date: String) -> void:
	var log := DailyLog.new()
	log.date = date
	log.is_missed = true
	days[date] = log


## Returns the DailyLog for `date`, or null if no entry exists (day not yet reached, or is today).
func get_day(date: String) -> DailyLog:
	return days.get(date)


func to_dict() -> Dictionary:
	var data := {}
	for date in days:
		data[date] = days[date].to_dict()
	return data


static func from_dict(data: Dictionary) -> Dictionary:
	var days: Dictionary = {}
	for date in data:
		days[date] = DailyLog.from_dict(data[date])
	return days
