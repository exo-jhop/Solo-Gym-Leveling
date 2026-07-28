class_name ProgramGenerator
extends RefCounted

## Builds a 7-day training_cycle (same shape QuestManager expects) algorithmically from
## days_per_week/goal/equipment_access, pulling exercises from ExerciseCatalog. Only
## invoked explicitly — first at the end of onboarding, later via Settings' "Regenerate
## Program" button — never automatically when a profile field changes elsewhere.

const MAX_EXERCISES_PER_DAY := 6

# Multi-joint lifts get priority pick within a muscle group before accessories.
const COMPOUND_EXERCISES: Array[String] = [
	"Bench Press", "Barbell Row", "Deadlift", "Overhead Press", "Squat",
	"Romanian Deadlift", "Pull-Up", "Incline Dumbbell Press",
]

# Sets/rep range per ProfileManager.GOALS value (spec-driven training focus, not a
# calculated figure). general_fitness has no named bucket in the brief; it sits at a
# moderate default between the muscle and endurance buckets.
const GOAL_SET_REP := {
	"build_muscle": {"sets": 4, "reps": "6-10"},
	"get_stronger": {"sets": 5, "reps": "4-6"},
	"lose_fat": {"sets": 3, "reps": "12-15"},
	"general_fitness": {"sets": 3, "reps": "8-12"},
}
const DEFAULT_SET_REP := {"sets": 3, "reps": "8-12"}

# Used only if an equipment filter empties a muscle group's pool entirely — a safety
# net, not the normal path, since dumbbells_only/bodyweight_only only exclude
# barbell/machine entries and every group keeps at least one non-barbell/machine lift.
const BODYWEIGHT_FALLBACK := {
	"chest": "Push-Up", "back": "Pull-Up", "shoulders": "Pike Push-Up",
	"quads": "Bodyweight Squat", "hamstrings": "Glute Bridge", "core": "Plank",
	"biceps": "Isometric Curl Hold", "triceps": "Bench Dip", "calves": "Calf Raise",
}

const FULL_BODY_GROUPS: Array[String] = ["chest", "back", "quads", "hamstrings", "shoulders", "core"]
const UPPER_GROUPS: Array[String] = ["chest", "back", "shoulders", "biceps", "triceps"]
const LOWER_GROUPS: Array[String] = ["quads", "hamstrings", "calves", "core"]
const PUSH_GROUPS: Array[String] = ["chest", "shoulders", "triceps"]
const PULL_GROUPS: Array[String] = ["back", "biceps"]
const LEGS_GROUPS: Array[String] = ["quads", "hamstrings", "calves", "core"]
const ARMS_CORE_GROUPS: Array[String] = ["biceps", "triceps", "core"]

# 7-slot weekly schedule (T = training, R = rest) per days_per_week, chosen so training
# days aren't back-to-back more than necessary.
const SCHEDULES := {
	3: ["T", "R", "T", "R", "T", "R", "R"],
	4: ["T", "T", "R", "T", "T", "R", "R"],
	5: ["T", "T", "T", "R", "T", "T", "R"],
	6: ["T", "T", "T", "R", "T", "T", "T"],
}


## variant distinguishes repeated day-types in a split ("A" = 0, "B" = 1, ...) so a
## day-type's second occurrence doesn't pick the exact same exercises as its first.
static func generate_program(days_per_week: int, goal: String, equipment: String) -> Array[TrainingDay]:
	var clamped_days: int = clampi(days_per_week, 3, 6)
	var day_labels: Array[String] = []
	var day_groups: Array = []
	var day_variants: Array[int] = []

	match clamped_days:
		3:
			day_labels = ["Full Body A", "Full Body B", "Full Body C"]
			day_groups = [FULL_BODY_GROUPS, FULL_BODY_GROUPS, FULL_BODY_GROUPS]
			day_variants = [0, 1, 2]
		4:
			day_labels = ["Upper Body A", "Lower Body A", "Upper Body B", "Lower Body B"]
			day_groups = [UPPER_GROUPS, LOWER_GROUPS, UPPER_GROUPS, LOWER_GROUPS]
			day_variants = [0, 0, 1, 1]
		5:
			day_labels = ["Push A", "Pull A", "Legs A", "Push B", "Pull B"]
			day_groups = [PUSH_GROUPS, PULL_GROUPS, LEGS_GROUPS, PUSH_GROUPS, PULL_GROUPS]
			day_variants = [0, 0, 0, 1, 1]
		6:
			day_labels = ["Push A", "Pull A", "Legs A", "Push B", "Pull B", "Arms & Core"]
			day_groups = [PUSH_GROUPS, PULL_GROUPS, LEGS_GROUPS, PUSH_GROUPS, PULL_GROUPS, ARMS_CORE_GROUPS]
			day_variants = [0, 0, 0, 1, 1, 0]

	var schedule: Array = SCHEDULES[clamped_days]
	var cycle: Array[TrainingDay] = []
	var training_index := 0
	for slot in schedule:
		if slot == "R":
			var rest := TrainingDay.new()
			rest.day_name = "Rest"
			rest.is_rest_day = true
			cycle.append(rest)
		else:
			cycle.append(_build_day(day_labels[training_index], day_groups[training_index], equipment, goal, day_variants[training_index]))
			training_index += 1

	return cycle


## Round-robins across the day's muscle groups (compounds sorted first within each
## group's pool) until MAX_EXERCISES_PER_DAY is hit or every pool is exhausted — this
## naturally yields ~1 exercise per group for wide splits (full body) and ~2 for narrow
## ones (push/pull), without special-casing each split.
static func _build_day(label: String, groups: Array, equipment: String, goal: String, variant: int) -> TrainingDay:
	var day := TrainingDay.new()
	day.day_name = label

	var pools := {}
	var taken := {}
	for group in groups:
		pools[group] = _filtered_pool(group, equipment, variant)
		taken[group] = 0

	var exercises: Array[Exercise] = []
	var progressed := true
	while exercises.size() < MAX_EXERCISES_PER_DAY and progressed:
		progressed = false
		for group in groups:
			if exercises.size() >= MAX_EXERCISES_PER_DAY:
				break
			var pool: Array = pools[group]
			var index: int = taken[group]
			if index < pool.size():
				exercises.append(_make_exercise(pool[index], goal))
				taken[group] = index + 1
				progressed = true

	day.exercises = exercises
	return day


## Catalog entries for a muscle group allowed under equipment_access. Compounds and
## accessories are rotated independently by `variant` (0 for "A", 1 for "B", ...) so a
## repeated day-type starts from a different compound when the pool has more than one,
## and pulls different accessories too — compounds still lead in every variant.
static func _filtered_pool(muscle_group: String, equipment: String, variant: int) -> Array:
	var compounds: Array = []
	var accessories: Array = []
	for entry in ExerciseCatalog.ENTRIES:
		if entry.muscle_group != muscle_group or not _equipment_allowed(entry.equipment, equipment):
			continue
		if _is_compound(entry.name):
			compounds.append(entry)
		else:
			accessories.append(entry)

	var pool := _rotated(compounds, variant) + _rotated(accessories, variant)

	if pool.is_empty() and BODYWEIGHT_FALLBACK.has(muscle_group):
		pool.append({"name": BODYWEIGHT_FALLBACK[muscle_group], "muscle_group": muscle_group, "equipment": "bodyweight"})
	return pool


static func _rotated(array: Array, offset: int) -> Array:
	if array.is_empty():
		return array
	var shift := offset % array.size()
	if shift == 0:
		return array
	return array.slice(shift, array.size()) + array.slice(0, shift)


static func _equipment_allowed(exercise_equipment: String, access: String) -> bool:
	match access:
		"dumbbells_only", "bodyweight_only":
			return exercise_equipment != "barbell" and exercise_equipment != "machine"
		_:
			return true


static func _is_compound(exercise_name: String) -> bool:
	return exercise_name in COMPOUND_EXERCISES


static func _make_exercise(entry: Dictionary, goal: String) -> Exercise:
	var set_rep: Dictionary = GOAL_SET_REP.get(goal, DEFAULT_SET_REP)
	var exercise := Exercise.new()
	exercise.name = entry.name
	exercise.sets = set_rep.sets
	exercise.rep_range = set_rep.reps
	return exercise
