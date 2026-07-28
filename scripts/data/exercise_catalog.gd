class_name ExerciseCatalog
extends RefCounted

## Read-only lookup of known exercises by muscle group, used only to power the
## Settings "Swap" picker (spec 4.5 program editing). Not wired into quest
## generation, XP, or PR tracking — exercise identity there stays free-text.

const ENTRIES: Array[Dictionary] = [
	{"name": "Bench Press", "muscle_group": "chest", "equipment": "barbell"},
	{"name": "Incline Dumbbell Press", "muscle_group": "chest", "equipment": "dumbbell"},
	{"name": "Push-Up", "muscle_group": "chest", "equipment": "bodyweight"},
	{"name": "Cable Chest Press", "muscle_group": "chest", "equipment": "cable"},

	{"name": "Barbell Row", "muscle_group": "back", "equipment": "barbell"},
	{"name": "Pull-Up", "muscle_group": "back", "equipment": "bodyweight"},
	{"name": "Deadlift", "muscle_group": "back", "equipment": "barbell"},
	{"name": "Seated Cable Row", "muscle_group": "back", "equipment": "cable"},
	{"name": "Lat Pulldown", "muscle_group": "back", "equipment": "cable"},

	{"name": "Overhead Press", "muscle_group": "shoulders", "equipment": "barbell"},
	{"name": "Lateral Raise", "muscle_group": "shoulders", "equipment": "dumbbell"},
	{"name": "Arnold Press", "muscle_group": "shoulders", "equipment": "dumbbell"},
	{"name": "Face Pull", "muscle_group": "shoulders", "equipment": "cable"},
	{"name": "Pike Push-Up", "muscle_group": "shoulders", "equipment": "bodyweight"},

	{"name": "Squat", "muscle_group": "quads", "equipment": "barbell"},
	{"name": "Leg Press", "muscle_group": "quads", "equipment": "machine"},
	{"name": "Bulgarian Split Squat", "muscle_group": "quads", "equipment": "dumbbell"},
	{"name": "Leg Extension", "muscle_group": "quads", "equipment": "machine"},
	{"name": "Bodyweight Squat", "muscle_group": "quads", "equipment": "bodyweight"},

	{"name": "Romanian Deadlift", "muscle_group": "hamstrings", "equipment": "barbell"},
	{"name": "Leg Curl", "muscle_group": "hamstrings", "equipment": "machine"},
	{"name": "Good Morning", "muscle_group": "hamstrings", "equipment": "barbell"},
	{"name": "Glute Bridge", "muscle_group": "hamstrings", "equipment": "bodyweight"},

	{"name": "Standing Calf Raise", "muscle_group": "calves", "equipment": "machine"},
	{"name": "Seated Calf Raise", "muscle_group": "calves", "equipment": "machine"},
	{"name": "Calf Raise", "muscle_group": "calves", "equipment": "bodyweight"},

	{"name": "Plank", "muscle_group": "core", "equipment": "bodyweight"},
	{"name": "Hanging Leg Raise", "muscle_group": "core", "equipment": "bodyweight"},
	{"name": "Cable Crunch", "muscle_group": "core", "equipment": "cable"},

	{"name": "Barbell Curl", "muscle_group": "biceps", "equipment": "barbell"},
	{"name": "Dumbbell Curl", "muscle_group": "biceps", "equipment": "dumbbell"},
	{"name": "Cable Curl", "muscle_group": "biceps", "equipment": "cable"},

	{"name": "Tricep Pushdown", "muscle_group": "triceps", "equipment": "cable"},
	{"name": "Overhead Tricep Extension", "muscle_group": "triceps", "equipment": "dumbbell"},
	{"name": "Bench Dip", "muscle_group": "triceps", "equipment": "bodyweight"},
]


## Case/whitespace-insensitive match against ENTRIES; {} if the name is fully custom.
static func find_entry(exercise_name: String) -> Dictionary:
	var normalized := exercise_name.strip_edges().to_lower()
	for entry in ENTRIES:
		if String(entry.name).to_lower() == normalized:
			return entry
	return {}


## Up to `limit` other catalog exercises sharing this one's muscle group.
## Empty (rather than erroring) when exercise_name doesn't match the catalog.
static func get_alternatives(exercise_name: String, limit: int = 3) -> Array[String]:
	var entry := find_entry(exercise_name)
	var alternatives: Array[String] = []
	if entry.is_empty():
		return alternatives

	for candidate in ENTRIES:
		if candidate.name == entry.name:
			continue
		if candidate.muscle_group == entry.muscle_group:
			alternatives.append(candidate.name)
		if alternatives.size() >= limit:
			break
	return alternatives
