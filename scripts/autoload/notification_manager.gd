extends Node

## Owns end-of-day reminder state (spec v2 4.1/7).
## Godot has no core local-notification API on any platform, an OS-level
## notification that fires while the app is closed requires a third-party
## native Android plugin plus switching the export to a custom Gradle build,
## which this project doesn't have. Until that's worth the build-infra cost,
## the reminder is an in-app banner shown when the app is foregrounded/opened
## after reminder_hour with today's quests still incomplete. It cannot fire
## while the app is closed or backgrounded.

var reminder_hour: int = 20  # 24-hour clock, 8 PM default
var reminder_enabled: bool = true


## True if the in-app reminder banner should be shown right now.
func should_remind() -> bool:
	if not reminder_enabled:
		return false
	var hour: int = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system()).hour
	if hour < reminder_hour:
		return false
	return _quests_incomplete()


func _quests_incomplete() -> bool:
	if QuestManager.current_quests.is_empty():
		return false
	for quest in QuestManager.current_quests:
		if not quest.completed:
			return true
	return false
