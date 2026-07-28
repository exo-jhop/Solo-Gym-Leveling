class_name HunterStats
extends Resource

## The Hunter's persistent progression state: level, rank, five core stats, streak.

@export var level: int = 1
@export var xp: int = 0
@export var rank: String = "E"
@export var str_stat: int = 10
@export var vit_stat: int = 10
@export var agi_stat: int = 10
@export var int_stat: int = 10
@export var sense_stat: int = 10
@export var current_streak: int = 0
@export var longest_streak: int = 0
@export var streak_freezes_available: int = 1


func to_dict() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"rank": rank,
		"str_stat": str_stat,
		"vit_stat": vit_stat,
		"agi_stat": agi_stat,
		"int_stat": int_stat,
		"sense_stat": sense_stat,
		"current_streak": current_streak,
		"longest_streak": longest_streak,
		"streak_freezes_available": streak_freezes_available,
	}


static func from_dict(data: Dictionary) -> HunterStats:
	var stats := HunterStats.new()
	stats.level = data.get("level", 1)
	stats.xp = data.get("xp", 0)
	stats.rank = data.get("rank", "E")
	stats.str_stat = data.get("str_stat", 10)
	stats.vit_stat = data.get("vit_stat", 10)
	stats.agi_stat = data.get("agi_stat", 10)
	stats.int_stat = data.get("int_stat", 10)
	stats.sense_stat = data.get("sense_stat", 10)
	stats.current_streak = data.get("current_streak", 0)
	stats.longest_streak = data.get("longest_streak", 0)
	stats.streak_freezes_available = data.get("streak_freezes_available", 1)
	return stats
