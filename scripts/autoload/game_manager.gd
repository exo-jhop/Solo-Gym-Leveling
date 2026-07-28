extends Node

## Owns HunterStats: XP, leveling, rank, and the five stats. Reacts to completed quests.

signal leveled_up(new_level: int)
signal ranked_up(new_rank: String)
signal stats_changed

const RANKS: Array[String] = ["E", "D", "C", "B", "A", "S"]

# Rank badge colors, low to high: muted gray up through blue/violet, breaking into
# gold at S to mark it as the rare, stand-apart tier (spec 5's visual direction).
const RANK_COLORS := {
	"E": Color(0.486, 0.533, 0.659),
	"D": Color(0.4, 0.65, 0.95),
	"C": Color(0.239, 0.545, 1.0),
	"B": Color(0.65, 0.5, 0.98),
	"A": Color(0.545, 0.361, 0.965),
	"S": Color(1.0, 0.85, 0.35),
}

# XP totals required to reach each rank. Placeholder values, tune later (see spec 2.2).
const RANK_XP_THRESHOLDS := {
	"E": 0,
	"D": 500,
	"C": 1500,
	"B": 3500,
	"A": 7000,
	"S": 12000,
}

# Small per-completion stat bump. Placeholder, tune later (see spec 2.1).
const STAT_INCREMENT := 1

# Cosmetic-only milestone titles per rank (spec v2 4.2). Only D/B/S were fixed
# by the spec; C and A are proposed fills to keep the naming ramp consistent.
const MILESTONE_TITLES := {
	"E": "Novice",
	"D": "Awakened",
	"C": "Breaker",
	"B": "Vanguard",
	"A": "Sovereign",
	"S": "Monarch",
}

var hunter_stats: HunterStats = HunterStats.new()

# Tracks whether any quest has been completed today, for streak evaluation on day change.
var _completed_something_today: bool = false


func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)


func _on_quest_completed(quest: Quest) -> void:
	_completed_something_today = true
	add_xp(quest.xp_reward, quest.stat_reward)


func add_xp(amount: int, stat_name: String) -> void:
	hunter_stats.xp += amount
	_apply_stat_reward(stat_name)
	_check_level_up()
	_check_rank_up()
	stats_changed.emit()


func _apply_stat_reward(stat_name: String) -> void:
	match stat_name:
		"STR":
			hunter_stats.str_stat += STAT_INCREMENT
		"VIT":
			hunter_stats.vit_stat += STAT_INCREMENT
		"AGI":
			hunter_stats.agi_stat += STAT_INCREMENT
		"INT":
			hunter_stats.int_stat += STAT_INCREMENT
		"SENSE":
			hunter_stats.sense_stat += STAT_INCREMENT
		_:
			pass  # no stat tied to this quest, xp-only


func xp_to_next_level(level: int) -> int:
	return int(100 * pow(level, 1.5))


func _check_level_up() -> void:
	var leveled := false
	while hunter_stats.xp >= xp_to_next_level(hunter_stats.level):
		hunter_stats.level += 1
		leveled = true
	if leveled:
		leveled_up.emit(hunter_stats.level)


func _check_rank_up() -> void:
	var new_rank := hunter_stats.rank
	for rank in RANKS:
		if hunter_stats.xp >= RANK_XP_THRESHOLDS[rank]:
			new_rank = rank
	if new_rank != hunter_stats.rank:
		hunter_stats.rank = new_rank
		hunter_stats.current_title = MILESTONE_TITLES.get(new_rank, "")
		ranked_up.emit(new_rank)


## XP threshold for the Hunter's current rank.
func current_rank_threshold() -> int:
	return RANK_XP_THRESHOLDS[hunter_stats.rank]


## Badge color for a rank letter, for UI display (spec 5).
func rank_color(rank: String) -> Color:
	return RANK_COLORS.get(rank, Color.WHITE)


## Fills in current_title for saves created/loaded before Milestone Titles existed,
## or where it's otherwise out of sync with the current rank. Call after load.
func ensure_title_synced() -> void:
	if hunter_stats.current_title == "":
		hunter_stats.current_title = MILESTONE_TITLES.get(hunter_stats.rank, "")


## XP threshold for the next rank, or -1 if already at the top rank (S).
func next_rank_threshold() -> int:
	var idx := RANKS.find(hunter_stats.rank)
	if idx == -1 or idx >= RANKS.size() - 1:
		return -1
	return RANK_XP_THRESHOLDS[RANKS[idx + 1]]


## Called by SaveManager when the calendar day changes.
func evaluate_streak() -> void:
	if _completed_something_today:
		hunter_stats.current_streak += 1
		hunter_stats.longest_streak = max(hunter_stats.longest_streak, hunter_stats.current_streak)
	elif hunter_stats.streak_freezes_available > 0:
		hunter_stats.streak_freezes_available -= 1
	else:
		hunter_stats.current_streak = 0
	_completed_something_today = false
	stats_changed.emit()
