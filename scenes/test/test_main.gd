extends Node

## Data-layer smoke test. No UI: exercises GameManager/QuestManager/SaveManager
## and prints results so the autoload wiring and JSON round-trip can be verified.


func _ready() -> void:
	GameManager.leveled_up.connect(func(new_level): print("*** LEVEL UP -> %d ***" % new_level))
	GameManager.ranked_up.connect(func(new_rank): print("*** RANK UP -> %s ***" % new_rank))

	print("\n--- Autoloads ready ---")
	_print_stats()
	_print_quests()

	print("\n--- Completing today's quests ---")
	for quest in QuestManager.current_quests:
		QuestManager.complete_quest(quest.id, quest.target_value)

	_print_stats()

	print("\n--- Saving ---")
	SaveManager.save_game()

	print("\n--- Simulating fresh load from disk ---")
	SaveManager.load_game()
	_print_stats()
	_print_quests()

	print("\n--- Done ---")
	get_tree().quit()


func _print_stats() -> void:
	var stats := GameManager.hunter_stats
	print("Level %d | Rank %s | XP %d/%d | STR %d VIT %d AGI %d INT %d SENSE %d | Streak %d (freezes %d)" % [
		stats.level, stats.rank, stats.xp, GameManager.xp_to_next_level(stats.level),
		stats.str_stat, stats.vit_stat, stats.agi_stat, stats.int_stat, stats.sense_stat,
		stats.current_streak, stats.streak_freezes_available,
	])


func _print_quests() -> void:
	print("Today's quests (day %d in cycle):" % QuestManager.cycle_day_index)
	for quest in QuestManager.current_quests:
		print("  [%s] %s (%s, +%d xp -> %s)" % [
			"x" if quest.completed else " ", quest.title, quest.category, quest.xp_reward, quest.stat_reward,
		])
