extends Control

## Training Log / History (spec 4.4): month calendar view.
## Past days come from HistoryManager; today is built live from QuestManager.current_quests
## since SaveManager doesn't roll today into HistoryManager until the calendar day changes.

const WEEKDAY_LABELS := ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
const MONTH_NAMES := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const DAYS_IN_MONTH := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

@onready var month_label: Label = $Margin/Root/HeaderRow/MonthLabel
@onready var prev_button: Button = $Margin/Root/HeaderRow/PrevButton
@onready var next_button: Button = $Margin/Root/HeaderRow/NextButton
@onready var weekday_row: HBoxContainer = $Margin/Root/WeekdayRow
@onready var calendar_grid: GridContainer = $Margin/Root/CalendarGrid
@onready var detail_title_label: Label = $Margin/Root/DetailPanel/DetailTitleLabel
@onready var detail_summary_label: Label = $Margin/Root/DetailPanel/DetailSummaryLabel
@onready var detail_quest_list: VBoxContainer = $Margin/Root/DetailPanel/DetailScroll/DetailQuestList
@onready var back_button: Button = $Margin/Root/BackButton

var _view_year: int
var _view_month: int  # 1-12
var _today_str: String
var _selected_date: String = ""


func _ready() -> void:
	var today := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
	_view_year = today.year
	_view_month = today.month
	_today_str = Time.get_date_string_from_system()

	for label_text in WEEKDAY_LABELS:
		var label := Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weekday_row.add_child(label)

	prev_button.pressed.connect(_on_prev_month)
	next_button.pressed.connect(_on_next_month)
	back_button.pressed.connect(_go_back)

	_refresh_calendar()
	_select_date(_today_str)


func _on_prev_month() -> void:
	_view_month -= 1
	if _view_month < 1:
		_view_month = 12
		_view_year -= 1
	_refresh_calendar()


func _on_next_month() -> void:
	_view_month += 1
	if _view_month > 12:
		_view_month = 1
		_view_year += 1
	_refresh_calendar()


func _refresh_calendar() -> void:
	month_label.text = "%s %d" % [MONTH_NAMES[_view_month - 1], _view_year]

	for child in calendar_grid.get_children():
		child.queue_free()

	var first_weekday := _weekday_of(_view_year, _view_month, 1)
	for i in range(first_weekday):
		calendar_grid.add_child(Control.new())  # empty leading cell

	var days_in_month := _days_in_month(_view_year, _view_month)
	for day in range(1, days_in_month + 1):
		var date_str := "%04d-%02d-%02d" % [_view_year, _view_month, day]
		var status := _status_for_date(date_str)

		var cell := Button.new()
		cell.text = str(day)
		cell.toggle_mode = true
		cell.custom_minimum_size = Vector2(0, 40)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.button_pressed = (date_str == _selected_date)
		_style_cell(cell, status, date_str == _today_str)

		if status != CellStatus.NO_DATA:
			cell.pressed.connect(_select_date.bind(date_str))
		else:
			cell.disabled = true

		calendar_grid.add_child(cell)


enum CellStatus { NO_DATA, FULL, PARTIAL, MISSED }


func _status_for_date(date_str: String) -> CellStatus:
	var log := _get_log_for_date(date_str)
	if log == null:
		return CellStatus.NO_DATA
	if log.quests_total == 0:
		return CellStatus.NO_DATA
	if log.quests_completed >= log.quests_total:
		return CellStatus.FULL
	if log.quests_completed > 0:
		return CellStatus.PARTIAL
	return CellStatus.MISSED


# Functional color coding for now — replaced with the System palette in the visual polish pass.
func _style_cell(cell: Button, status: CellStatus, is_today: bool) -> void:
	var color: Color
	match status:
		CellStatus.FULL:
			color = Color(0.2, 0.6, 0.3)
		CellStatus.PARTIAL:
			color = Color(0.7, 0.6, 0.15)
		CellStatus.MISSED:
			color = Color(0.55, 0.2, 0.2)
		_:
			color = Color(0.3, 0.3, 0.3)
	cell.modulate = Color(1, 1, 1) if is_today else Color(0.9, 0.9, 0.9)
	cell.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	if is_today:
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.7, 1.0)
	cell.add_theme_stylebox_override("normal", style)
	cell.add_theme_stylebox_override("hover", style)
	cell.add_theme_stylebox_override("pressed", style)


func _select_date(date_str: String) -> void:
	_selected_date = date_str
	_refresh_calendar()
	_populate_detail(date_str)


func _populate_detail(date_str: String) -> void:
	for child in detail_quest_list.get_children():
		child.queue_free()

	var weekday_name: String = WEEKDAY_LABELS[_weekday_of_date_str(date_str)]
	detail_title_label.text = "%s (%s)%s" % [date_str, weekday_name, "  — Today" if date_str == _today_str else ""]

	var quest_summaries: Array = []
	var is_rest_day := false
	var quests_total := 0
	var quests_completed := 0
	var xp_earned := 0

	if date_str == _today_str:
		for quest in QuestManager.current_quests:
			if quest.category == "recovery":
				is_rest_day = true
			quests_total += 1
			if quest.completed:
				quests_completed += 1
				xp_earned += quest.xp_reward
			quest_summaries.append(quest)
	else:
		var log := _get_log_for_date(date_str)
		if log == null:
			detail_summary_label.text = "No data for this day."
			return
		is_rest_day = log.is_rest_day
		quests_total = log.quests_total
		quests_completed = log.quests_completed
		xp_earned = log.xp_earned
		for summary in log.quest_summaries:
			quest_summaries.append(summary)

	var kind_text := "Rest Day" if is_rest_day else "Training Day"
	detail_summary_label.text = "%s — %d / %d quests complete — %d XP earned" % [kind_text, quests_completed, quests_total, xp_earned]

	for entry in quest_summaries:
		var title: String = entry.title if entry is Quest else entry.get("title", "")
		var completed: bool = entry.completed if entry is Quest else entry.get("completed", false)
		var logged_value: float = entry.logged_value if entry is Quest else entry.get("logged_value", 0.0)
		var unit: String = entry.unit if entry is Quest else entry.get("unit", "")

		var row := HBoxContainer.new()
		var check := CheckBox.new()
		check.text = title
		check.button_pressed = completed
		check.disabled = true
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(check)

		if completed and unit != "":
			var value_label := Label.new()
			value_label.text = "%s %s" % [_format_number(logged_value), unit]
			row.add_child(value_label)

		detail_quest_list.add_child(row)


func _get_log_for_date(date_str: String) -> DailyLog:
	return HistoryManager.get_day(date_str)


func _weekday_of(year: int, month: int, day: int) -> int:
	var datetime := {"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0}
	var unix_time := Time.get_unix_time_from_datetime_dict(datetime)
	return Time.get_datetime_dict_from_unix_time(unix_time).weekday


func _weekday_of_date_str(date_str: String) -> int:
	var parts := date_str.split("-")
	return _weekday_of(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())


func _days_in_month(year: int, month: int) -> int:
	if month == 2 and _is_leap_year(year):
		return 29
	return DAYS_IN_MONTH[month - 1]


func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


func _format_number(value: float) -> String:
	if value == floor(value):
		return str(int(value))
	return str(value)


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
