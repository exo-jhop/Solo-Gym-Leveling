extends Node

## Loads/saves the Hunter's progress as JSON and drives the daily-reset check.

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

var last_opened_date: String = ""


func _ready() -> void:
	load_game()
	GameManager.ensure_title_synced()
	check_new_day()


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
		"cycle_day_index": QuestManager.cycle_day_index,
		"hunter_stats": GameManager.hunter_stats.to_dict(),
		"current_quests": quest_dicts,
		"history": HistoryManager.to_dict(),
		"training_cycle": training_cycle_dicts,
		"protein_target_g": QuestManager.protein_target_g,
		"creatine_target_g": QuestManager.creatine_target_g,
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
	QuestManager.cycle_day_index = data.get("cycle_day_index", 0)
	GameManager.hunter_stats = HunterStats.from_dict(data.get("hunter_stats", {}))

	QuestManager.current_quests.clear()
	for quest_data in data.get("current_quests", []):
		QuestManager.current_quests.append(Quest.from_dict(quest_data))

	HistoryManager.days = HistoryManager.from_dict(data.get("history", {}))

	if data.has("training_cycle"):
		var training_cycle: Array[TrainingDay] = []
		for day_data in data["training_cycle"]:
			training_cycle.append(TrainingDay.from_dict(day_data))
		QuestManager.training_cycle = training_cycle
	QuestManager.protein_target_g = data.get("protein_target_g", QuestManager.protein_target_g)
	QuestManager.creatine_target_g = data.get("creatine_target_g", QuestManager.creatine_target_g)

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
		GameManager.evaluate_streak()
		HistoryManager.record_day(last_opened_date, QuestManager.current_quests)
	QuestManager.generate_daily_quests()
	last_opened_date = today
	save_game()
