extends Control

## Weekly Summary screen (spec v2 4.5): read-only rollup of this week's activity.
## Aggregates HistoryManager's DailyLogs for past days this week plus today's
## in-progress quests from QuestManager, same "today isn't in history yet"
## pattern training_log.gd uses.

const STAT_FONT := preload("res://assets/fonts/CascadiaCode.ttf")
const WEEKDAY_LABELS := ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

const PRIMARY_ACCENT := Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF (design system v2)
const DIVIDER_COLOR := Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C
const BUTTON_CONTENT_MARGIN := {"left": 16.0, "top": 10.0, "right": 16.0, "bottom": 10.0}

@onready var stats_card: PanelContainer = $Margin/Root/StatsCard
@onready var xp_label: Label = $Margin/Root/StatsCard/StatsCardMargin/StatsBox/XpLabel
@onready var quests_label: Label = $Margin/Root/StatsCard/StatsCardMargin/StatsBox/QuestsLabel
@onready var streak_label: Label = $Margin/Root/StatsCard/StatsCardMargin/StatsBox/StreakLabel
@onready var top_stat_label: Label = $Margin/Root/StatsCard/StatsCardMargin/StatsBox/TopStatLabel
@onready var back_button: Button = $Margin/Root/BackButton


# Same chamfered nav-button treatment as lobby.gd's helper of the same name.
func _apply_chamfered_button_style(button: Button) -> void:
	var normal := ChamferedStyleBox.new()
	normal.border_color = DIVIDER_COLOR
	normal.accent_color = PRIMARY_ACCENT
	normal.content_margin_left = BUTTON_CONTENT_MARGIN.left
	normal.content_margin_top = BUTTON_CONTENT_MARGIN.top
	normal.content_margin_right = BUTTON_CONTENT_MARGIN.right
	normal.content_margin_bottom = BUTTON_CONTENT_MARGIN.bottom

	var hover := ChamferedStyleBox.new()
	hover.border_color = PRIMARY_ACCENT
	hover.accent_color = PRIMARY_ACCENT
	hover.content_margin_left = BUTTON_CONTENT_MARGIN.left
	hover.content_margin_top = BUTTON_CONTENT_MARGIN.top
	hover.content_margin_right = BUTTON_CONTENT_MARGIN.right
	hover.content_margin_bottom = BUTTON_CONTENT_MARGIN.bottom

	var pressed := ChamferedStyleBox.new()
	pressed.fill_color = Color(PRIMARY_ACCENT.r, PRIMARY_ACCENT.g, PRIMARY_ACCENT.b, 0.18)
	pressed.border_color = PRIMARY_ACCENT
	pressed.accent_color = PRIMARY_ACCENT
	pressed.content_margin_left = BUTTON_CONTENT_MARGIN.left
	pressed.content_margin_top = BUTTON_CONTENT_MARGIN.top
	pressed.content_margin_right = BUTTON_CONTENT_MARGIN.right
	pressed.content_margin_bottom = BUTTON_CONTENT_MARGIN.bottom

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	for label in [xp_label, quests_label, streak_label, top_stat_label]:
		label.add_theme_font_override("font", STAT_FONT)
	stats_card.add_theme_stylebox_override("panel", ChamferedStyleBox.new())
	_apply_chamfered_button_style(back_button)
	_refresh()


func _refresh() -> void:
	var today_str := Time.get_date_string_from_system()
	var week_dates := _dates_for_week_containing(today_str)

	var total_xp := 0
	var quests_completed := 0
	var quests_total := 0
	var stat_gains: Dictionary = {}  # "STR" -> total gained this week

	for date_str in week_dates:
		if date_str == today_str:
			var day_xp := 0
			var day_completed := 0
			for quest in QuestManager.current_quests:
				quests_total += 1
				if quest.completed:
					day_completed += 1
					day_xp += quest.xp_reward
					if quest.stat_reward != "":
						stat_gains[quest.stat_reward] = stat_gains.get(quest.stat_reward, 0) + GameManager.STAT_INCREMENT
			quests_completed += day_completed
			total_xp += day_xp
		else:
			var log := HistoryManager.get_day(date_str)
			if log == null:
				continue
			quests_total += log.quests_total
			quests_completed += log.quests_completed
			total_xp += log.xp_earned
			for stat_name in log.stat_gains:
				stat_gains[stat_name] = stat_gains.get(stat_name, 0) + log.stat_gains[stat_name]

	xp_label.text = "XP earned this week: %d" % total_xp
	quests_label.text = "Quests completed: %d / %d" % [quests_completed, quests_total]
	streak_label.text = "Current streak: %d day%s" % [GameManager.hunter_stats.current_streak, "" if GameManager.hunter_stats.current_streak == 1 else "s"]

	if stat_gains.is_empty():
		top_stat_label.text = "Top stat this week: —"
	else:
		var top_stat := ""
		var top_value := -1
		for stat_name in stat_gains:
			if stat_gains[stat_name] > top_value:
				top_value = stat_gains[stat_name]
				top_stat = stat_name
		top_stat_label.text = "Top stat this week: %s (+%d)" % [top_stat, top_value]


## Returns the "YYYY-MM-DD" dates from Sunday through Saturday of the week
## containing `date_str`, using the same weekday convention as training_log.gd.
func _dates_for_week_containing(date_str: String) -> Array:
	var parts := date_str.split("-")
	var datetime := {"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int(), "hour": 0, "minute": 0, "second": 0}
	var unix_time := Time.get_unix_time_from_datetime_dict(datetime)
	var weekday: int = Time.get_datetime_dict_from_unix_time(unix_time).weekday

	var week_start_unix := unix_time - weekday * 86400
	var dates: Array = []
	for i in range(7):
		var day_unix: int = week_start_unix + i * 86400
		var day_dict := Time.get_datetime_dict_from_unix_time(day_unix)
		dates.append("%04d-%02d-%02d" % [day_dict.year, day_dict.month, day_dict.day])
	return dates


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
