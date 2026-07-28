class_name Quest
extends Resource

## A single daily quest instance: a lift, a nutrition target, a supplement dose, or recovery.

@export var id: String
@export var title: String
@export var category: String  # "lift", "nutrition", "supplement", "recovery"
@export var stat_reward: String  # "STR", "VIT", "AGI", "INT", "SENSE"
@export var xp_reward: int = 0
@export var target_value: float = 0.0  # e.g. reps, grams, sets
@export var unit: String = ""  # "reps", "g", "kg"
@export var completed: bool = false
@export var logged_value: float = 0.0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"category": category,
		"stat_reward": stat_reward,
		"xp_reward": xp_reward,
		"target_value": target_value,
		"unit": unit,
		"completed": completed,
		"logged_value": logged_value,
	}


static func from_dict(data: Dictionary) -> Quest:
	var quest := Quest.new()
	quest.id = data.get("id", "")
	quest.title = data.get("title", "")
	quest.category = data.get("category", "")
	quest.stat_reward = data.get("stat_reward", "")
	quest.xp_reward = data.get("xp_reward", 0)
	quest.target_value = data.get("target_value", 0.0)
	quest.unit = data.get("unit", "")
	quest.completed = data.get("completed", false)
	quest.logged_value = data.get("logged_value", 0.0)
	return quest
