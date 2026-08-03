class_name LoadAdjuster
extends RefCounted

## Daily adherence/fatigue check (feature: adaptive daily load, v5). Complements the
## weekly weight-trend check in ProgramRecalibrator: that one reacts to bodyweight trend
## for build_muscle/lose_fat only; this one reacts to lift adherence/completion for every
## goal, so get_stronger/general_fitness finally get an adaptive path too.
## Evaluated in priority order; at most one suggestion is ever returned, since two
## competing modal choices in one launch is unacceptable UX (v5 spec 3.5). Fatigue
## outranks ambition: someone skipping sessions needs rest offered before volume is
## either raised or permanently cut.

const MISSED_SESSIONS_TRIGGER := 2      # v1 spec 2.6
const RECOVERY_WEEK_DAYS := 3           # training days, not calendar days
const REDUCED_DAYS_WINDOW := 7
const REDUCED_DAYS_TRIGGER := 3
const PROGRESS_WINDOW_DAYS := 14
const PROGRESS_RATE_TRIGGER := 0.9
const MIN_TRAINING_DAYS_SEEN := 6       # guards ready_to_progress against a near-empty history
const SET_DELTA := 1
const MIN_SETS := 2
const MAX_SETS := 6                     # keep identical to ProgramRecalibrator.MAX_SETS


## `signals` is assembled by the caller (SaveManager) from HistoryManager helpers, keeping
## this a pure function: {missed_lift_sessions, reduced_days, lift_completion_rate,
## training_days_seen}. Returns {} if no adjustment should be suggested, otherwise a
## Dictionary consumed by QuestManager.apply_load_adjustment() (kind, message, and
## whatever extra fields that kind needs).
static func evaluate(signals: Dictionary) -> Dictionary:
	var missed_lift_sessions: int = signals.get("missed_lift_sessions", 0)
	var reduced_days: int = signals.get("reduced_days", 0)
	var rate: float = signals.get("lift_completion_rate", -1.0)
	var training_days_seen: int = signals.get("training_days_seen", 0)

	if missed_lift_sessions >= MISSED_SESSIONS_TRIGGER:
		return {
			"kind": "recovery_week",
			"recovery_days": RECOVERY_WEEK_DAYS,
			"message": _message("recovery_week"),
		}

	if reduced_days >= REDUCED_DAYS_TRIGGER:
		return {
			"kind": "reduce_volume",
			"set_delta": -SET_DELTA,
			"min_sets": MIN_SETS,
			"message": _message("reduce_volume"),
		}

	if rate >= PROGRESS_RATE_TRIGGER and reduced_days == 0 and training_days_seen >= MIN_TRAINING_DAYS_SEEN:
		return {
			"kind": "ready_to_progress",
			"set_delta": SET_DELTA,
			"max_sets": MAX_SETS,
			"message": _message("ready_to_progress"),
		}

	return {}


static func _message(kind: String) -> String:
	match kind:
		"recovery_week":
			return "Rough stretch — want to run the next 3 sessions a set lighter?"
		"reduce_volume":
			return "You've been going lighter often. Want to drop a set from the program so it fits properly?"
		"ready_to_progress":
			return "You've hit nearly every session lately. Ready to add a set?"
		_:
			return ""
