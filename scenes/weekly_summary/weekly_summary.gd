extends Control

## Weekly Summary screen (spec v2 4.5): read-only rollup of this week's activity.
## Aggregates HistoryManager's DailyLogs for past days this week plus today's
## in-progress quests from QuestManager, same "today isn't in history yet"
## pattern training_log.gd uses.
##
## Portrait pass (design system v2): the whole screen was four sentences in one card
## ("XP earned this week: 0"), set in a monospace face the design system rules out, with
## no sense of how the week was actually shaped. Same four numbers now lead as KPI tiles,
## and the two things prose couldn't show — which days were cleared, and where the training
## actually went — are charted.

const WEEKDAY_LABELS := ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
const MONTH_ABBR := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

@onready var range_label: Label = $Margin/Scroll/Root/TitleBox/RangeLabel
@onready var metrics_grid: GridContainer = $Margin/Scroll/Root/MetricsGrid
@onready var daily_card: PanelContainer = $Margin/Scroll/Root/DailyCard
@onready var daily_glyph_slot: Control = $Margin/Scroll/Root/DailyCard/DailyBox/DailyHeaderRow/DailyGlyphSlot
@onready var week_bars: Control = $Margin/Scroll/Root/DailyCard/DailyBox/WeekBars
@onready var stat_card: PanelContainer = $Margin/Scroll/Root/StatCard
@onready var stat_glyph_slot: Control = $Margin/Scroll/Root/StatCard/StatBox/StatHeaderRow/StatGlyphSlot
@onready var stat_list: VBoxContainer = $Margin/Scroll/Root/StatCard/StatBox/StatList
@onready var back_button: Button = $Margin/Scroll/Root/BackButton


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	PressFeedback.attach(back_button)
	NavButtonStyle.apply(back_button)

	# Analytics cards take the primary accent; stat gains take gold, the achievement
	# category the top-stat highlight below reads against.
	HudCard.apply(daily_card)
	HudCard.apply(stat_card, SystemPalette.GOLD)
	_add_glyph(daily_glyph_slot, HudGlyph.Shape.TREND, SystemPalette.PRIMARY)
	_add_glyph(stat_glyph_slot, HudGlyph.Shape.STATS, SystemPalette.GOLD)

	_refresh()


func _add_glyph(slot: Control, shape: HudGlyph.Shape, color: Color) -> void:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(glyph)


func _refresh() -> void:
	var today_str := Time.get_date_string_from_system()
	var week_dates := _dates_for_week_containing(today_str)

	var total_xp := 0
	var quests_completed := 0
	var quests_total := 0
	var active_days := 0
	var stat_gains: Dictionary = {}  # "STR" -> total gained this week
	var day_rows: Array = []  # week_bars.set_days() payload, Sunday first

	for i in range(week_dates.size()):
		var date_str: String = week_dates[i]
		var day_total := 0
		var day_completed := 0
		var state := "none"

		if date_str == today_str:
			for quest in QuestManager.current_quests:
				day_total += 1
				if quest.completed:
					day_completed += 1
					total_xp += quest.xp_reward
					if quest.stat_reward != "":
						stat_gains[quest.stat_reward] = stat_gains.get(quest.stat_reward, 0) + GameManager.STAT_INCREMENT
		else:
			var log := HistoryManager.get_day(date_str)
			if log == null:
				# No entry at all: a future day this week, or one before the save existed.
				state = "future" if date_str > today_str else "none"
			elif log.is_missed:
				state = "missed"
			else:
				day_total = log.quests_total
				day_completed = log.quests_completed
				total_xp += log.xp_earned
				for stat_name in log.stat_gains:
					stat_gains[stat_name] = stat_gains.get(stat_name, 0) + log.stat_gains[stat_name]

		quests_total += day_total
		quests_completed += day_completed
		if day_completed > 0:
			active_days += 1

		if state == "none" and day_total > 0:
			state = "done" if day_completed == day_total else "partial"

		day_rows.append({
			"label": WEEKDAY_LABELS[i],
			"ratio": 0.0 if day_total == 0 else float(day_completed) / float(day_total),
			"state": state,
			"is_today": date_str == today_str,
		})

	range_label.text = "%s — %s" % [_format_day(week_dates[0]), _format_day(week_dates[6])]
	week_bars.set_days(day_rows)
	_refresh_metrics(total_xp, quests_completed, quests_total, active_days)
	_refresh_stat_gains(stat_gains)


## Category accents follow the design system's assignments: primary for XP/progression,
## success for completion, gold for the streak.
func _refresh_metrics(total_xp: int, quests_completed: int, quests_total: int, active_days: int) -> void:
	for child in metrics_grid.get_children():
		child.queue_free()

	var streak: int = GameManager.hunter_stats.current_streak
	var tiles := [
		{"caption": "XP EARNED", "value": str(total_xp), "accent": SystemPalette.PRIMARY},
		{"caption": "QUESTS DONE", "value": "%d / %d" % [quests_completed, quests_total], "accent": SystemPalette.SUCCESS},
		{"caption": "ACTIVE DAYS", "value": "%d / 7" % active_days, "accent": SystemPalette.PRIMARY},
		{"caption": "DAY STREAK", "value": str(streak), "accent": SystemPalette.GOLD},
	]
	for tile_data in tiles:
		var tile := HudCard.metric_tile(String(tile_data.caption), String(tile_data.value), tile_data.accent)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics_grid.add_child(tile)


## "Top stat this week" used to be a sentence naming one stat. As bars it names the same
## stat by making it the longest and the only gold one, and shows what the rest of the
## week's training went into at the same time.
func _refresh_stat_gains(stat_gains: Dictionary) -> void:
	for child in stat_list.get_children():
		child.queue_free()

	# A DailyLog can carry a stat key at 0 (recorded on a day where that stat's quest wasn't
	# completed), which showed up here as a "+0" row with an empty bar.
	var gains: Dictionary = {}
	for stat_name in stat_gains:
		if int(stat_gains[stat_name]) > 0:
			gains[stat_name] = int(stat_gains[stat_name])

	if gains.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"SecondaryLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "No stat gains logged this week yet. Completing a quest tied to a stat adds to it here."
		stat_list.add_child(empty)
		return

	var stat_names := gains.keys()
	stat_names.sort_custom(func(a, b): return int(gains[a]) > int(gains[b]))
	var top_value: int = int(gains[stat_names[0]])

	for i in range(stat_names.size()):
		var stat_name := String(stat_names[i])
		stat_list.add_child(_build_stat_row(stat_name, int(gains[stat_name]), top_value, i == 0))


func _build_stat_row(stat_name: String, value: int, top_value: int, is_top: bool) -> Control:
	var accent: Color = SystemPalette.GOLD if is_top else SystemPalette.PRIMARY

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var name_label := Label.new()
	name_label.theme_type_variation = &"HeaderLabel"
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", accent)
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.text = stat_name
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 24.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = maxi(top_value, 1)
	bar.value = value
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 12
	fill.corner_radius_top_right = 12
	fill.corner_radius_bottom_left = 12
	fill.corner_radius_bottom_right = 12
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var value_label := Label.new()
	value_label.theme_type_variation = &"HeaderLabel"
	value_label.add_theme_font_size_override("font_size", 30)
	value_label.add_theme_color_override("font_color", accent)
	value_label.custom_minimum_size = Vector2(90.0, 0.0)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "+%d" % value
	row.add_child(value_label)

	return row


func _format_day(date_str: String) -> String:
	var parts := date_str.split("-")
	return "%s %d" % [MONTH_ABBR[parts[1].to_int() - 1], parts[2].to_int()]


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
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")
