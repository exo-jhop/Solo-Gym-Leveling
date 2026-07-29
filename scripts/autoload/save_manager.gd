extends Node

## Loads/saves the Hunter's progress as JSON and drives the daily-reset check.

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

# Cap on how many missed-day history entries a single startup will backfill, so a
# long reinstall/uninstall gap doesn't generate hundreds of DailyLog entries at once.
const MAX_BACKFILL_DAYS := 30

# How often the weekly weight-trend recalibration check runs (feature: weekly recalibration).
const RECALIBRATION_INTERVAL_DAYS := 7

# How often the streak forgiveness freeze replenishes (spec v2 section 3: "one freeze per
# week, non-negotiable").
const STREAK_FREEZE_INTERVAL_DAYS := 7

var last_opened_date: String = ""
var last_recalibration_date: String = ""
var last_freeze_replenish_date: String = ""


func _ready() -> void:
	load_game()
	GameManager.ensure_title_synced()
	check_new_day()
	QuestManager.quest_completed.connect(_on_quest_completed)


## Quest completions only lived in memory until the next day-rollover call to
## save_game() — stopping/restarting the app mid-day silently reverted every
## quest checked off that day. Persist immediately instead.
func _on_quest_completed(_quest: Quest) -> void:
	save_game()


func save_game() -> void:
	var quest_dicts: Array = []
	for quest in QuestManager.current_quests:
		quest_dicts.append(quest.to_dict())

	var training_cycle_dicts: Array = []
	for day in QuestManager.training_cycle:
		training_cycle_dicts.append(day.to_dict())

	var data := {
		"save_version": SAVE_VERSION,
		"last_opened_date": last_opened_date,
		"last_recalibration_date": last_recalibration_date,
		"last_freeze_replenish_date": last_freeze_replenish_date,
		"cycle_day_index": QuestManager.cycle_day_index,
		"hunter_stats": GameManager.hunter_stats.to_dict(),
		"current_quests": quest_dicts,
		"history": HistoryManager.to_dict(),
		"personal_records": PRTracker.to_dict(),
		"pr_history": PRTracker.to_history_dict(),
		"training_cycle": training_cycle_dicts,
		"protein_target_g": QuestManager.protein_target_g,
		"creatine_target_g": QuestManager.creatine_target_g,
		"hunter_profile": ProfileManager.profile.to_dict(),
		"low_energy_mode": QuestManager.low_energy_mode,
		"reminder_hours": NotificationManager.reminder_hours,
		"reminder_enabled_map": NotificationManager.reminder_enabled,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("SaveManager: saved to ", SAVE_PATH)


## Returns true if an existing save was found and loaded.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: no save file found, starting fresh")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file for reading (%s)" % error_string(FileAccess.get_open_error()))
		return false

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("SaveManager: save file is corrupt or not valid JSON")
		return false

	var data: Dictionary = parsed
	last_opened_date = data.get("last_opened_date", "")
	# Old saves predate this feature: bootstrap from a blank slate rather than defaulting to
	# last_opened_date, so a long-idle reinstall doesn't immediately fire a stale suggestion.
	last_recalibration_date = data.get("last_recalibration_date", "")
	last_freeze_replenish_date = data.get("last_freeze_replenish_date", "")
	QuestManager.cycle_day_index = data.get("cycle_day_index", 0)
	GameManager.hunter_stats = HunterStats.from_dict(data.get("hunter_stats", {}))

	QuestManager.current_quests.clear()
	for quest_data in data.get("current_quests", []):
		QuestManager.current_quests.append(Quest.from_dict(quest_data))

	HistoryManager.days = HistoryManager.from_dict(data.get("history", {}))
	PRTracker.personal_records = PRTracker.from_dict(data.get("personal_records", {}))
	PRTracker.pr_history = PRTracker.from_history_dict(data.get("pr_history", {}))

	if data.has("training_cycle"):
		var training_cycle: Array[TrainingDay] = []
		for day_data in data["training_cycle"]:
			training_cycle.append(TrainingDay.from_dict(day_data))
		QuestManager.training_cycle = training_cycle
	QuestManager.protein_target_g = data.get("protein_target_g", QuestManager.protein_target_g)
	QuestManager.creatine_target_g = data.get("creatine_target_g", QuestManager.creatine_target_g)
	QuestManager.low_energy_mode = data.get("low_energy_mode", false)

	# Migration (spec v4 6): a save from before HunterProfile existed has no "hunter_profile"
	# key at all. Build one from what's already known instead of reopening full onboarding.
	if data.has("hunter_profile"):
		ProfileManager.profile = HunterProfile.from_dict(data["hunter_profile"])
	else:
		ProfileManager.migrate_legacy_save()

	# Legacy flat single-reminder saves (pre-v3): fold into the "general" category.
	if data.has("reminder_hour"):
		NotificationManager.reminder_hours["general"] = data.get("reminder_hour", NotificationManager.reminder_hours["general"])
		NotificationManager.reminder_enabled["general"] = data.get("reminder_enabled", NotificationManager.reminder_enabled["general"])

	var saved_hours = data.get("reminder_hours", {})
	if saved_hours is Dictionary:
		for category in saved_hours:
			NotificationManager.reminder_hours[category] = saved_hours[category]

	var saved_enabled = data.get("reminder_enabled_map", {})
	if saved_enabled is Dictionary:
		for category in saved_enabled:
			NotificationManager.reminder_enabled[category] = saved_enabled[category]

	print("SaveManager: loaded save (version %s, last opened %s)" % [data.get("save_version", "?"), last_opened_date])
	return true


## Call once at startup: if the calendar day has changed since last open,
## evaluate the streak for the day that just ended and generate today's quests.
func check_new_day() -> void:
	var today := Time.get_date_string_from_system()

	if last_opened_date == today:
		print("SaveManager: same day as last open (%s), keeping existing quests" % today)
		if QuestManager.current_quests.is_empty():
			QuestManager.generate_daily_quests()
		return

	print("SaveManager: new day detected (was %s, now %s)" % [last_opened_date if last_opened_date != "" else "never", today])
	if last_opened_date != "":
		var days_gap := _days_between(last_opened_date, today)
		GameManager.evaluate_streak(days_gap)
		HistoryManager.record_day(last_opened_date, QuestManager.current_quests, QuestManager.low_energy_mode)

		var missed_days := mini(days_gap - 1, MAX_BACKFILL_DAYS)
		if days_gap - 1 > MAX_BACKFILL_DAYS:
			print("SaveManager: gap of %d days exceeds backfill cap, only backfilling %d" % [days_gap - 1, MAX_BACKFILL_DAYS])
		for i in range(1, missed_days + 1):
			HistoryManager.record_missed_day(_date_plus_days(last_opened_date, i))

	_check_recalibration(today)
	_check_streak_freeze_replenish(today)
	QuestManager.generate_daily_quests()
	last_opened_date = today
	save_game()


## Weekly weight-trend check (feature: weekly recalibration). Runs at most once every
## RECALIBRATION_INTERVAL_DAYS; stages a suggestion on QuestManager for the recalibration
## popup to pick up if the logged bodyweight trend doesn't match the goal's expectation.
func _check_recalibration(today: String) -> void:
	if last_recalibration_date == "":
		last_recalibration_date = today
		return
	if _days_between(last_recalibration_date, today) < RECALIBRATION_INTERVAL_DAYS:
		return

	var logs := HistoryManager.recent_bodyweight_logs(ProgramRecalibrator.MIN_LOGS)
	var suggestion := ProgramRecalibrator.evaluate(ProfileManager.profile.goal, logs, ProfileManager.profile.weight_kg)
	if not suggestion.is_empty():
		QuestManager.pending_recalibration = suggestion
	elif ProfileManager.profile.calorie_intensity != "normal":
		# Trend realigned with the goal since the last escalation — relax the wording back
		# down. Silent (no popup): this only changes phrasing, not an actual training/nutrition
		# change, so it doesn't need the same confirm-before-apply treatment.
		ProfileManager.profile.calorie_intensity = "normal"
	last_recalibration_date = today


## Weekly streak-freeze replenish (spec v2 section 3: "one freeze per week, non-negotiable").
## Runs at most once every STREAK_FREEZE_INTERVAL_DAYS and resets the freeze to exactly 1
## rather than stacking, so leaving it unused doesn't bank extra freezes for later.
func _check_streak_freeze_replenish(today: String) -> void:
	if last_freeze_replenish_date == "":
		last_freeze_replenish_date = today
		return
	if _days_between(last_freeze_replenish_date, today) < STREAK_FREEZE_INTERVAL_DAYS:
		return

	GameManager.hunter_stats.streak_freezes_available = 1
	last_freeze_replenish_date = today


## Converts a "YYYY-MM-DD" date string to a unix timestamp at midnight, for date arithmetic.
func _date_string_to_unix(date_str: String) -> float:
	var parts := date_str.split("-")
	return Time.get_unix_time_from_datetime_dict({
		"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int(),
		"hour": 0, "minute": 0, "second": 0,
	})


## Number of whole calendar days between two "YYYY-MM-DD" dates (positive if date_b is later).
func _days_between(date_a: String, date_b: String) -> int:
	return int(round((_date_string_to_unix(date_b) - _date_string_to_unix(date_a)) / 86400.0))


## Returns the date string `days` calendar days after `date_str`.
func _date_plus_days(date_str: String, days: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(_date_string_to_unix(date_str) + days * 86400)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
