extends Node

## Owns the Hunter's intake profile (spec v4): goal + body metrics, and the calculated
## targets that flow from them. The first-launch onboarding flow and Settings > Profile
## both read/write `profile` directly as cross-scene scratch state, mirroring how
## QuestManager.selected_quest_id is set by one scene and read by another.

var profile: HunterProfile = HunterProfile.new()

# Not persisted: set for one app session right after migrate_legacy_save() runs, so
# Lobby can route to Settings > Profile once for the user to confirm/adjust the
# guessed values (spec v4 6), then cleared so it doesn't fire on every future launch.
var just_migrated: bool = false

const GOALS := ["build_muscle", "get_stronger", "lose_fat", "general_fitness"]

const GOAL_LABELS := {
	"build_muscle": "Build Muscle",
	"get_stronger": "Get Stronger",
	"lose_fat": "Lose Fat",
	"general_fitness": "General Fitness",
}

const EQUIPMENT_OPTIONS := ["full_gym", "dumbbells_only", "bodyweight_only"]

const EQUIPMENT_LABELS := {
	"full_gym": "Full Gym",
	"dumbbells_only": "Dumbbells Only",
	"bodyweight_only": "Bodyweight Only",
}

# Direction only, no hard numbers (spec 2.2/7) — points back to the maintenance-formula
# + adjust-by-trend reasoning rather than claiming a precise figure. "increased" wording is
# used once an accepted weekly recalibration suggestion has flagged the logged weight trend
# as contradicting the goal (see ProgramRecalibrator) — still no numbers, just more assertive
# phrasing. maintenance has no "increased" variant: neither goal that maps to it
# (get_stronger/general_fitness) is ever evaluated by ProgramRecalibrator.
const CALORIE_DIRECTION_LABELS := {
	"surplus": {
		"normal": "Slight surplus — eat a bit above maintenance, adjust by watching the weekly trend.",
		"increased": "Bigger surplus — your weight hasn't been trending up, eat further above maintenance.",
	},
	"deficit": {
		"normal": "Slight deficit — eat a bit below maintenance, adjust by watching the weekly trend.",
		"increased": "Bigger deficit — your weight hasn't been trending down, eat further below maintenance.",
	},
	"maintenance": {
		"normal": "Maintenance — eat around your maintenance level, adjust by watching the weekly trend.",
	},
}


## Calorie-direction guidance text for the current profile, keyed by direction then
## intensity, falling back to "normal" if a goal/intensity combination has no entry
## (e.g. maintenance, which never escalates).
func calorie_direction_label() -> String:
	var by_intensity: Dictionary = CALORIE_DIRECTION_LABELS[profile.calorie_direction()]
	return by_intensity.get(profile.calorie_intensity, by_intensity["normal"])


func needs_onboarding() -> bool:
	return not profile.onboarding_complete


## Pushes the profile's calculated protein target into QuestManager (spec 5). Called
## after onboarding finishes and whenever Settings > Profile is saved, so the daily
## protein quest reflects the current profile without needing a restart.
func apply_targets() -> void:
	if profile.weight_kg > 0.0:
		QuestManager.protein_target_g = profile.calculate_protein_target_g()


## Migration for saves from before this feature existed (spec 6). Builds a profile from
## what's already known — the hardcoded build-muscle program — rather than reopening the
## full first-launch flow; the caller (SaveManager) still routes to Settings > Profile
## afterward so the guessed weight can be confirmed/adjusted.
func migrate_legacy_save() -> void:
	profile.goal = "build_muscle"
	if profile.weight_kg <= 0.0:
		profile.weight_kg = _last_logged_bodyweight()
	profile.onboarding_complete = true
	just_migrated = true
	apply_targets()


## Most recent bodyweight quest log, checked in today's in-progress quests first, then
## day-by-day history, since a legacy save may be mid-day at migration time.
func _last_logged_bodyweight() -> float:
	for quest in QuestManager.current_quests:
		if quest.id == "bodyweight" and quest.completed and quest.logged_value > 0.0:
			return quest.logged_value

	var dates := HistoryManager.days.keys()
	dates.sort()
	dates.reverse()
	for date in dates:
		var log: DailyLog = HistoryManager.days[date]
		for summary in log.quest_summaries:
			if summary.get("id", "") == "bodyweight" and summary.get("completed", false) and summary.get("logged_value", 0.0) > 0.0:
				return summary["logged_value"]
	return 0.0
