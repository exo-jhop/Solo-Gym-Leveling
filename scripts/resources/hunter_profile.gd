class_name HunterProfile
extends Resource

## One-time (editable later) intake that drives calculated targets across the app (spec v4).
## height_cm/age were removed (audit found nothing ever calculated from them) — from_dict()
## still tolerates those keys in old save files, it just discards them.

@export var goal: String = "general_fitness"  # "build_muscle", "get_stronger", "lose_fat", "general_fitness"
@export var weight_kg: float = 0.0
@export var onboarding_complete: bool = false
@export var days_per_week: int = 4  # 3-6, drives ProgramGenerator's split choice
@export var equipment_access: String = "full_gym"  # "full_gym", "dumbbells_only", "bodyweight_only"

# "normal" or "increased" — bumped by an accepted weekly recalibration suggestion when the
# logged weight trend contradicts the goal (see ProgramRecalibrator), silently relaxed back
# to "normal" once a later weekly check shows the trend realigned. Only changes the wording
# ProfileManager.calorie_direction_label() shows, never a precise number (spec 2.2/7).
@export var calorie_intensity: String = "normal"


## g/day protein target: weight_kg * a goal-scaled multiplier within the established
## 1.6-2.2 range (spec 2.2). Build Muscle sits at the top of the range, General Fitness
## at the bottom; Lose Fat stays high to preserve muscle in a deficit.
func calculate_protein_target_g() -> float:
	var multiplier := 2.0  # default, mid-high range
	match goal:
		"build_muscle": multiplier = 2.2
		"get_stronger": multiplier = 2.0
		"lose_fat": multiplier = 2.0
		"general_fitness": multiplier = 1.6
	return weight_kg * multiplier


## Calorie *direction*, deliberately not a number (spec 2.2/7: TDEE math needs
## activity-level assumptions this app doesn't collect, and a precise-looking wrong
## number would be trusted too readily).
func calorie_direction() -> String:
	match goal:
		"build_muscle": return "surplus"
		"lose_fat": return "deficit"
		_: return "maintenance"


func to_dict() -> Dictionary:
	return {
		"goal": goal,
		"weight_kg": weight_kg,
		"onboarding_complete": onboarding_complete,
		"days_per_week": days_per_week,
		"equipment_access": equipment_access,
		"calorie_intensity": calorie_intensity,
	}


## Old saves may still carry "height_cm"/"age" keys; Dictionary.get() on keys we
## never read simply leaves them unused here, so those saves still load cleanly.
static func from_dict(data: Dictionary) -> HunterProfile:
	var profile := HunterProfile.new()
	profile.goal = data.get("goal", "general_fitness")
	profile.weight_kg = data.get("weight_kg", 0.0)
	profile.onboarding_complete = data.get("onboarding_complete", false)
	profile.days_per_week = data.get("days_per_week", 4)
	profile.equipment_access = data.get("equipment_access", "full_gym")
	profile.calorie_intensity = data.get("calorie_intensity", "normal")
	return profile
