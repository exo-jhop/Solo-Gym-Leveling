class_name TrainingDay
extends Resource

## One day in the training cycle. Rest days carry no exercises.

@export var day_name: String  # "Upper Body A", "Lower Body A", "Rest", etc.
@export var is_rest_day: bool = false
@export var exercises: Array[Exercise] = []


func to_dict() -> Dictionary:
	var exercise_dicts: Array = []
	for exercise in exercises:
		exercise_dicts.append(exercise.to_dict())
	return {
		"day_name": day_name,
		"is_rest_day": is_rest_day,
		"exercises": exercise_dicts,
	}


static func from_dict(data: Dictionary) -> TrainingDay:
	var day := TrainingDay.new()
	day.day_name = data.get("day_name", "")
	day.is_rest_day = data.get("is_rest_day", false)
	var exercises: Array[Exercise] = []
	for exercise_data in data.get("exercises", []):
		exercises.append(Exercise.from_dict(exercise_data))
	day.exercises = exercises
	return day
