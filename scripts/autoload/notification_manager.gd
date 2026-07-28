extends Node

## Owns end-of-day reminder state (spec v2 4.1/7, generalized per-category in v3).
## Godot has no core local-notification API on any platform, an OS-level
## notification that fires while the app is closed requires a third-party
## native Android plugin plus switching the export to a custom Gradle build,
## which this project doesn't have. Until that's worth the build-infra cost,
## the reminder is an in-app banner shown when the app is foregrounded/opened
## after a category's reminder hour with that category's quests still incomplete.
## It cannot fire while the app is closed or backgrounded.
##
## Reminder time used to be a single flat hour covering every quest. It's now keyed
## by category so e.g. the supplement (creatine) reminder can fire earlier in the day
## (8am) than the general "did you finish everything" check (8pm). "general" is a
## synthetic key, not an actual Quest.category value — it means "any quest of any
## category still incomplete," matching the original single-reminder behavior.

var reminder_hours: Dictionary = {
	"general": 20,
	"supplement": 8,
}  # category (or "general") -> reminder hour, 24-hour clock
var reminder_enabled: Dictionary = {
	"general": true,
	"supplement": true,
}  # category (or "general") -> whether that reminder is active


## True if the in-app reminder banner should be shown right now for `category`.
func should_remind(category: String = "general") -> bool:
	if not reminder_enabled.get(category, false):
		return false
	var hour: int = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system()).hour
	if hour < reminder_hours.get(category, 20):
		return false
	return _quests_incomplete(category)


## True if any configured category's reminder is currently due — drives a single banner.
func any_reminder_due() -> bool:
	for category in reminder_hours.keys():
		if should_remind(category):
			return true
	return false


func _quests_incomplete(category: String) -> bool:
	if QuestManager.current_quests.is_empty():
		return false
	for quest in QuestManager.current_quests:
		if quest.completed:
			continue
		if category == "general" or quest.category == category:
			return true
	return false
