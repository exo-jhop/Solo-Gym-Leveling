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


## Last `limit` completed bodyweight-quest values (kg), oldest first. Walks backward from
## the most recent recorded day, taking at most one value per day, and stops once `limit`
## are collected. Used by ProgramRecalibrator's weekly trend check.
func recent_bodyweight_logs(limit: int) -> Array:
	var values: Array = []
	var dates := days.keys()
	dates.sort()
	dates.reverse()
	for date in dates:
		if values.size() >= limit:
			break
		var log: DailyLog = days[date]
		for summary in log.quest_summaries:
			if summary.get("id", "") == "bodyweight" and summary.get("completed", false) and summary.get("logged_value", 0.0) > 0.0:
				values.append(summary["logged_value"])
				break
	values.reverse()
	return values


## Consecutive most-recent training days on which no lift quest was completed.
## Walks backward from the newest recorded day and stops at the first day with a
## completed lift. Rest days are skipped (they carry no lift signal). Days with
## is_missed set are also skipped rather than counted — record_missed_day() writes
## an empty quest_summaries, so an unopened day is an absence, not evidence of fatigue.
func consecutive_missed_lift_sessions() -> int:
	var count := 0
	for date in _sorted_dates_desc():
		var log: DailyLog = days[date]
		if log.is_missed:
			continue
		var has_lift := false
		var completed_lift := false
		for summary in log.quest_summaries:
			if summary.get("category", "") == "lift":
				has_lift = true
				if summary.get("completed", false):
					completed_lift = true
					break
		if not has_lift:
			continue
		if completed_lift:
			break
		count += 1
	return count


## How many of the last `limit` recorded days had was_reduced_intensity set.
func reduced_intensity_count(limit: int) -> int:
	var count := 0
	for date in _sorted_dates_desc().slice(0, limit):
		if days[date].was_reduced_intensity:
			count += 1
	return count


## Completed lift summaries / total lift summaries across the last `limit` recorded
## days. Returns -1.0 when no lift quests appear in the window, so callers can
## distinguish "no data" from "0% completion".
func lift_completion_rate(limit: int) -> float:
	var completed := 0
	var total := 0
	for date in _sorted_dates_desc().slice(0, limit):
		for summary in days[date].quest_summaries:
			if summary.get("category", "") == "lift":
				total += 1
				if summary.get("completed", false):
					completed += 1
	if total == 0:
		return -1.0
	return float(completed) / float(total)


## Count of recorded days in the last `limit` that contained at least one lift quest.
func training_days_seen(limit: int) -> int:
	var count := 0
	for date in _sorted_dates_desc().slice(0, limit):
		for summary in days[date].quest_summaries:
			if summary.get("category", "") == "lift":
				count += 1
				break
	return count


func _sorted_dates_desc() -> Array:
	var dates := days.keys()
	dates.sort()
	dates.reverse()
	return dates


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
