class_name Exercise
extends Resource

## A single lift within a TrainingDay (e.g. "Bench Press: 4x6-8").

@export var name: String
@export var sets: int = 0
@export var rep_range: String = ""  # e.g. "6-8"


func to_dict() -> Dictionary:
	return {
		"name": name,
		"sets": sets,
		"rep_range": rep_range,
	}


static func from_dict(data: Dictionary) -> Exercise:
	var exercise := Exercise.new()
	exercise.name = data.get("name", "")
	exercise.sets = data.get("sets", 0)
	exercise.rep_range = data.get("rep_range", "")
	return exercise
