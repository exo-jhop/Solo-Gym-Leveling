extends Control

## Stats Screen (spec 4.3): radar chart of the 5 stats + rank progress bar + PR list.
## Radar points are tappable (this-week quest breakdown per stat) and PR rows are
## expandable (PR-history sparkline) — both read existing PRTracker/HistoryManager
## data, no new tracking mechanism.

const PRSparklineScript := preload("res://scenes/stats/pr_sparkline.gd")

const STAT_NAMES := ["STR", "VIT", "AGI", "INT", "SENSE"]  # order matches radar_chart.gd STAT_LABELS

# Sparkline trend colors. Raw values (not theme lookups) because these are drawn
# inside a custom _draw() control, same exemption radar_chart.gd already relies on
# for its own GRID_COLOR/FILL_COLOR/LINE_COLOR constants.
const ACCENT_COLOR := Color(0.0, 0.85098, 1.0, 1.0)
const SUCCESS_COLOR := Color(0.227451, 0.858824, 0.462745, 1.0)
const WARNING_COLOR := Color(1.0, 0.419608, 0.207843, 1.0)

# "Session" = a calendar day with at least one completed lift quest (any exercise) —
# the closest proxy to "workout ago" the existing data supports, since PRTracker only
# logs new-best moments, not every non-PR completion. Trending up if the exercise's
# last PR happened within this many sessions of today; plateaued otherwise.
const SESSIONS_TREND_WINDOW := 5

@onready var level_rank_label: Label = $Margin/Root/LevelRankLabel
@onready var rank_bar: ProgressBar = $Margin/Root/RankBar
@onready var rank_progress_label: Label = $Margin/Root/RankProgressLabel
@onready var radar_chart: Control = $Margin/Root/RadarChart
@onready var breakdown_panel: PanelContainer = $Margin/Root/StatBreakdownPanel
@onready var breakdown_header: Label = $Margin/Root/StatBreakdownPanel/StatBreakdownMargin/StatBreakdownBox/StatBreakdownHeader
@onready var breakdown_list: VBoxContainer = $Margin/Root/StatBreakdownPanel/StatBreakdownMargin/StatBreakdownBox/StatBreakdownList
@onready var pr_list: VBoxContainer = $Margin/Root/ScrollContainer/PRList
@onready var back_button: Button = $BackButton


func _ready() -> void:
	GameManager.stats_changed.connect(_refresh)
	radar_chart.set_tappable(true)
	radar_chart.stat_tapped.connect(_on_stat_tapped)
	back_button.pressed.connect(_go_back)
	_refresh()


func _refresh() -> void:
	var stats := GameManager.hunter_stats
	level_rank_label.text = "Level %d — Rank %s" % [stats.level, stats.rank]
	level_rank_label.add_theme_color_override("font_color", GameManager.rank_color(stats.rank))

	var current_threshold := GameManager.current_rank_threshold()
	var next_threshold := GameManager.next_rank_threshold()
	if next_threshold == -1:
		rank_bar.min_value = 0
		rank_bar.max_value = 1
		rank_bar.value = 1
		rank_progress_label.text = "Max Rank reached (S)"
	else:
		rank_bar.min_value = current_threshold
		rank_bar.max_value = next_threshold
		rank_bar.value = stats.xp
		rank_progress_label.text = "XP %d / %d to next rank" % [stats.xp, next_threshold]

	radar_chart.set_values([stats.str_stat, stats.vit_stat, stats.agi_stat, stats.int_stat, stats.sense_stat])
	breakdown_panel.visible = false
	_refresh_pr_list()


## ---- Radar tap breakdown ----

func _on_stat_tapped(stat_index: int) -> void:
	_show_stat_breakdown(STAT_NAMES[stat_index])


func _show_stat_breakdown(stat_name: String) -> void:
	breakdown_header.text = "%s this week" % stat_name
	for child in breakdown_list.get_children():
		child.queue_free()

	var today_str := Time.get_date_string_from_system()
	var contributions: Array = []  # {date, title}

	for date_str in _dates_for_week_containing(today_str):
		if date_str == today_str:
			for quest in QuestManager.current_quests:
				if quest.completed and quest.stat_reward == stat_name:
					contributions.append({"date": date_str, "title": quest.title})
		else:
			var log := HistoryManager.get_day(date_str)
			if log == null:
				continue
			for summary in log.quest_summaries:
				if summary.get("completed", false) and summary.get("stat_reward", "") == stat_name:
					contributions.append({"date": date_str, "title": summary.get("title", "")})

	if contributions.is_empty():
		var empty_label := Label.new()
		empty_label.theme_type_variation = &"SecondaryLabel"
		empty_label.text = "No %s quests completed yet this week." % stat_name
		breakdown_list.add_child(empty_label)
	else:
		for contribution in contributions:
			var row := Label.new()
			row.theme_type_variation = &"SecondaryLabel"
			row.text = "%s — %s" % [contribution.date, contribution.title]
			breakdown_list.add_child(row)

	breakdown_panel.visible = true


## Same Sunday-through-Saturday week convention as weekly_summary.gd's helper of the
## same name — duplicated locally since the project has no shared date-utility module.
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


## ---- PR list + sparkline ----

func _refresh_pr_list() -> void:
	for child in pr_list.get_children():
		child.queue_free()
	var exercise_names := PRTracker.personal_records.keys()
	exercise_names.sort()
	for exercise_name in exercise_names:
		pr_list.add_child(_build_pr_row(exercise_name))


func _build_pr_row(exercise_name: String) -> PanelContainer:
	var record: Dictionary = PRTracker.personal_records[exercise_name]

	var card := PanelContainer.new()
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(card_margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card_margin.add_child(col)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	col.add_child(header_row)

	var text := "%s: %s" % [exercise_name, PRTracker.format_record(record)]
	var relative_text := PRTracker.format_relative_strength(record, ProfileManager.profile.weight_kg)
	if relative_text != "":
		text += " (%s)" % relative_text

	var label := Label.new()
	label.theme_type_variation = &"AccentLabel"
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(label)

	var expand_button := Button.new()
	expand_button.text = "▼"
	expand_button.custom_minimum_size = Vector2(44, 0)
	header_row.add_child(expand_button)

	var detail_container := VBoxContainer.new()
	detail_container.visible = false
	col.add_child(detail_container)
	detail_container.add_child(_build_pr_detail(exercise_name))

	expand_button.pressed.connect(func():
		detail_container.visible = not detail_container.visible
		expand_button.text = "▲" if detail_container.visible else "▼"
	)

	return card


func _build_pr_detail(exercise_name: String) -> Control:
	var history: Array = PRTracker.pr_history.get(exercise_name, [])
	if history.size() < 2:
		var note := Label.new()
		note.theme_type_variation = &"SecondaryLabel"
		note.text = "Not enough data yet — keep logging this exercise to build a trend."
		return note

	var sparkline := Control.new()
	sparkline.set_script(PRSparklineScript)
	sparkline.custom_minimum_size = Vector2(0, 80)
	sparkline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sparkline.set_data(history, _trend_color(exercise_name))
	return sparkline


## Green if the exercise's last PR is within SESSIONS_TREND_WINDOW sessions of today
## (still trending up), orange if more sessions than that have passed with no new PR
## (plateaued). See SESSIONS_TREND_WINDOW doc comment for what "session" means here.
func _trend_color(exercise_name: String) -> Color:
	var history: Array = PRTracker.pr_history.get(exercise_name, [])
	if history.is_empty():
		return ACCENT_COLOR
	var last_date: String = history[-1].get("date", "")
	return SUCCESS_COLOR if _sessions_since(last_date) < SESSIONS_TREND_WINDOW else WARNING_COLOR


func _sessions_since(date_str: String) -> int:
	var count := 0
	for session_date in _all_lift_session_dates():
		if session_date > date_str:
			count += 1
	return count


## Ascending dates where at least one lift quest was completed, including today if
## applicable (today isn't in HistoryManager until the day rolls over).
func _all_lift_session_dates() -> Array:
	var dates: Array = []
	for date_str in HistoryManager.days:
		var log: DailyLog = HistoryManager.days[date_str]
		for summary in log.quest_summaries:
			if summary.get("category", "") == "lift" and summary.get("completed", false):
				dates.append(date_str)
				break

	var today_str := Time.get_date_string_from_system()
	if not dates.has(today_str):
		for quest in QuestManager.current_quests:
			if quest.category == "lift" and quest.completed:
				dates.append(today_str)
				break

	dates.sort()
	return dates


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
