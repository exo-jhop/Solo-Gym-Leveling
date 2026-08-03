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

	print("\n--- LoadAdjuster decision table ---")
	_test_load_adjuster()

	print("\n--- Done ---")
	get_tree().quit()


func _print_stats() -> void:
	var stats := GameManager.hunter_stats
	print("Level %d | Rank %s | XP %d/%d | STR %d VIT %d AGI %d INT %d SENSE %d | Streak %d (freezes %d)" % [
		stats.level, stats.rank, stats.xp, GameManager.xp_to_next_level(stats.level),
		stats.str_stat, stats.vit_stat, stats.agi_stat, stats.int_stat, stats.sense_stat,
		stats.current_streak, stats.streak_freezes_available,
	])


## Pure-function cases from the v5 spec's test plan (section 6) — LoadAdjuster.evaluate()
## takes plain values in, so these need no HistoryManager/save-file setup at all.
func _test_load_adjuster() -> void:
	_check_load_adjustment_case("missed=2 -> recovery_week",
		{"missed_lift_sessions": 2}, "recovery_week")
	_check_load_adjustment_case("missed=1 -> no suggestion",
		{"missed_lift_sessions": 1}, "")
	_check_load_adjustment_case("missed=2 and reduced=5 -> recovery_week wins",
		{"missed_lift_sessions": 2, "reduced_days": 5}, "recovery_week")
	_check_load_adjustment_case("reduced=3, no missed -> reduce_volume",
		{"reduced_days": 3}, "reduce_volume")
	_check_load_adjustment_case("rate=1.0, seen=8, reduced=0 -> ready_to_progress",
		{"lift_completion_rate": 1.0, "training_days_seen": 8}, "ready_to_progress")
	_check_load_adjustment_case("rate=1.0, seen=3 -> no suggestion (insufficient history)",
		{"lift_completion_rate": 1.0, "training_days_seen": 3}, "")
	_check_load_adjustment_case("rate=1.0, reduced=2 -> no suggestion (reductions disqualify progression)",
		{"lift_completion_rate": 1.0, "reduced_days": 2, "training_days_seen": 8}, "")


func _check_load_adjustment_case(label: String, signals: Dictionary, expected_kind: String) -> void:
	var suggestion := LoadAdjuster.evaluate(signals)
	var actual_kind: String = suggestion.get("kind", "")
	var passed := actual_kind == expected_kind
	print("  [%s] %s (got %s)" % ["PASS" if passed else "FAIL", label, actual_kind if actual_kind != "" else "{}"])


func _print_quests() -> void:
	print("Today's quests (day %d in cycle):" % QuestManager.cycle_day_index)
	for quest in QuestManager.current_quests:
		print("  [%s] %s (%s, +%d xp -> %s)" % [
			"x" if quest.completed else " ", quest.title, quest.category, quest.xp_reward, quest.stat_reward,
		])
