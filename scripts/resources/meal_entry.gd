class_name MealEntry
extends Resource

## A single planned meal in today's meal plan (see QuestManager.meal_plan). Free-text name
## only — no calorie/macro number, matching the spec's "direction not a number" nutrition
## stance (docs/Solo_Gym_Leveling_App_Spec_v4_Onboarding_Profile.md section 7).

@export var id: String = ""
@export var name: String = ""
@export var completed: bool = false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"completed": completed,
	}


static func from_dict(data: Dictionary) -> MealEntry:
	var entry := MealEntry.new()
	entry.id = data.get("id", "")
	entry.name = data.get("name", "")
	entry.completed = data.get("completed", false)
	return entry
