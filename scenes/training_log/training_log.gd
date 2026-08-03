extends Control

## Training Log / History (spec 4.4): month calendar view.
## Past days come from HistoryManager; today is built live from QuestManager.current_quests
## since SaveManager doesn't roll today into HistoryManager until the calendar day changes.
##
## Portrait pass (design system v2): the screen had no ScrollContainer at all, so a 6-week
## month plus the day-detail card simply overflowed a 1080x2400 viewport with no way to
## reach the bottom; month paging used bare "<" / ">" buttons on the theme's rounded-rect
## style; and the heatmap encoded completion purely in fill color, with nothing telling the
## user what the colors meant. All three are fixed below.

## Rajdhani for the numeric grid — the theme's default body font is Inter, and the design
## system puts numeric readouts in the geometric display face.
const DISPLAY_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const WEEKDAY_LABELS := ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
const MONTH_NAMES := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const MONTH_ABBR := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const WEEKDAY_ABBR := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const DAYS_IN_MONTH := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

const TOUCH_TARGET := 144.0

## A 7-column month grid can't reach the 144px (48dp) minimum on a 1080px-wide canvas
## without running edge to edge — seven 48dp cells alone need 1008px before any screen
## margin or card padding. The card therefore takes a narrower side inset than the other
## cards on this screen, and cells are given the full 48dp on the axis that is free
## (height), landing at roughly 44dp x 48dp per cell.
const MONTH_CARD_MARGIN := {"left": 18.0, "top": 26.0, "right": 18.0, "bottom": 26.0}
const CELL_HEIGHT := 144.0

@onready var month_label: Label = $Margin/Scroll/Root/MonthCard/MonthBox/MonthRow/MonthLabel
@onready var prev_button: Button = $Margin/Scroll/Root/MonthCard/MonthBox/MonthRow/PrevButton
@onready var next_button: Button = $Margin/Scroll/Root/MonthCard/MonthBox/MonthRow/NextButton
@onready var month_card: PanelContainer = $Margin/Scroll/Root/MonthCard
@onready var weekday_row: HBoxContainer = $Margin/Scroll/Root/MonthCard/MonthBox/WeekdayRow
@onready var calendar_grid: GridContainer = $Margin/Scroll/Root/MonthCard/MonthBox/CalendarGrid
@onready var legend_grid: GridContainer = $Margin/Scroll/Root/MonthCard/MonthBox/LegendGrid
@onready var month_stats_grid: GridContainer = $Margin/Scroll/Root/MonthStatsGrid
@onready var detail_card: PanelContainer = $Margin/Scroll/Root/DetailCard
@onready var detail_glyph_slot: Control = $Margin/Scroll/Root/DetailCard/DetailBox/DetailHeaderRow/DetailGlyphSlot
@onready var detail_title_label: Label = $Margin/Scroll/Root/DetailCard/DetailBox/DetailHeaderRow/DetailTitleLabel
@onready var detail_summary_label: Label = $Margin/Scroll/Root/DetailCard/DetailBox/DetailSummaryLabel
@onready var detail_quest_list: VBoxContainer = $Margin/Scroll/Root/DetailCard/DetailBox/DetailQuestList
@onready var back_button: Button = $Margin/Scroll/Root/BackButton

var _view_year: int
var _view_month: int  # 1-12
var _today_str: String
var _selected_date: String = ""
var _detail_style: ChamferedStyleBox
var _detail_glyph: HudGlyph


func _ready() -> void:
	# Local date, to match _today_str below (get_date_string_from_system() is local while
	# get_unix_time_from_system() is UTC — mixing them opened the calendar on the wrong
	# month, and left no cell matching "today", around midnight in most timezones).
	var today := Time.get_datetime_dict_from_system()
	_view_year = today.year
	_view_month = today.month
	_today_str = Time.get_date_string_from_system()

	_build_chrome()

	for label_text in WEEKDAY_LABELS:
		var label := Label.new()
		label.text = label_text.to_upper()
		label.theme_type_variation = &"SecondaryLabel"
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weekday_row.add_child(label)

	prev_button.pressed.connect(_on_prev_month)
	next_button.pressed.connect(_on_next_month)
	back_button.pressed.connect(_go_back)
	for button in [prev_button, next_button, back_button]:
		PressFeedback.attach(button)

	_build_legend()
	_refresh_calendar()
	_select_date(_today_str)


func _build_chrome() -> void:
	HudCard.apply(month_card, SystemPalette.PRIMARY, MONTH_CARD_MARGIN)
	_detail_style = HudCard.apply(detail_card)
	_detail_glyph = _add_glyph(detail_glyph_slot, HudGlyph.Shape.CALENDAR, SystemPalette.PRIMARY)

	# Icon-only month paging, sized to the touch minimum. The old "<" / ">" text buttons
	# inherited the theme's 44px-inset rounded rect, which made two chevrons the largest
	# elements on the screen.
	for button in [prev_button, next_button]:
		NavButtonStyle.apply_icon(button)
	_add_button_glyph(prev_button, HudGlyph.Shape.CHEVRON_LEFT, SystemPalette.PRIMARY, 40.0)
	_add_button_glyph(next_button, HudGlyph.Shape.CHEVRON_RIGHT, SystemPalette.PRIMARY, 40.0)

	NavButtonStyle.apply(back_button)


func _add_glyph(slot: Control, shape: HudGlyph.Shape, color: Color) -> HudGlyph:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(glyph)
	return glyph


func _add_button_glyph(button: Button, shape: HudGlyph.Shape, color: Color, inset: float) -> HudGlyph:
	var glyph := _add_glyph(button, shape, color)
	glyph.offset_left = inset
	glyph.offset_top = inset
	glyph.offset_right = -inset
	glyph.offset_bottom = -inset
	return glyph


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
	month_label.text = "%s %d" % [MONTH_NAMES[_view_month - 1].to_upper(), _view_year]

	for child in calendar_grid.get_children():
		child.queue_free()

	var first_weekday := _weekday_of(_view_year, _view_month, 1)
	for i in range(first_weekday):
		calendar_grid.add_child(Control.new())  # empty leading cell

	var days_in_month := _days_in_month(_view_year, _view_month)
	for day in range(1, days_in_month + 1):
		var date_str := "%04d-%02d-%02d" % [_view_year, _view_month, day]
		var log := _get_log_for_date(date_str)
		var is_missed := log != null and log.is_missed
		var has_data := _has_data_for_date(date_str)
		var ratio := _ratio_for_date(date_str)

		var cell := Button.new()
		cell.text = str(day)
		cell.toggle_mode = true
		cell.custom_minimum_size = Vector2(0, CELL_HEIGHT)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.button_pressed = (date_str == _selected_date)
		cell.add_theme_font_override("font", DISPLAY_FONT)
		cell.add_theme_font_size_override("font_size", 32)
		_style_cell(cell, has_data, ratio, date_str == _today_str, date_str == _selected_date, is_missed)

		if has_data:
			cell.pressed.connect(_select_date.bind(date_str))
		else:
			cell.disabled = true

		PressFeedback.attach(cell)
		calendar_grid.add_child(cell)

	_refresh_month_stats()


func _has_data_for_date(date_str: String) -> bool:
	if date_str == _today_str:
		return not QuestManager.current_quests.is_empty()
	var log := _get_log_for_date(date_str)
	return log != null and (log.quests_total > 0 or log.is_missed)


## Fraction of that day's quests completed, 0.0 if no data (caller should
## check _has_data_for_date first to distinguish "nothing done" from "no data").
func _ratio_for_date(date_str: String) -> float:
	if date_str == _today_str:
		var quests := QuestManager.current_quests
		if quests.is_empty():
			return 0.0
		var done := 0
		for quest in quests:
			if quest.completed:
				done += 1
		return float(done) / float(quests.size())

	var log := _get_log_for_date(date_str)
	if log == null or log.quests_total == 0:
		return 0.0
	return float(log.quests_completed) / float(log.quests_total)


# Heatmap intensity scales from "opened but nothing done" up to the design system's
# completion green (#3ADB76). Missed days keep a muted red instead: the palette's only
# other alert color is warning orange, which is in active use for "still open today" and
# would read as actionable rather than as a day already gone.
const HEATMAP_LOW_COLOR := Color(0.145, 0.176, 0.263)
const HEATMAP_HIGH_COLOR := SystemPalette.SUCCESS
const STATUS_COLOR_NONE := Color(0.071, 0.094, 0.165)
const STATUS_COLOR_MISSED := Color(0.35, 0.129, 0.145)

## Fill luminance above this gets dark text instead of light. A fully-completed cell is
## filled with bright completion green, where the light body text color fell far below the
## 4.5:1 contrast minimum.
const DARK_TEXT_LUMINANCE := 0.45


func _style_cell(cell: Button, has_data: bool, ratio: float, is_today: bool, is_selected: bool = false, is_missed: bool = false) -> void:
	var color: Color
	if is_missed:
		color = STATUS_COLOR_MISSED
	elif has_data:
		color = HEATMAP_LOW_COLOR.lerp(HEATMAP_HIGH_COLOR, ratio)
	else:
		color = STATUS_COLOR_NONE

	var font_color: Color
	if color.get_luminance() > DARK_TEXT_LUMINANCE:
		font_color = SystemPalette.BACKGROUND
	elif has_data or is_missed:
		font_color = SystemPalette.TEXT
	else:
		font_color = SystemPalette.TEXT_SECONDARY
	cell.add_theme_color_override("font_color", font_color)
	cell.add_theme_color_override("font_disabled_color", font_color)
	cell.add_theme_color_override("font_hover_color", font_color)
	cell.add_theme_color_override("font_pressed_color", font_color)

	# Every cell now carries the chamfered shape (the design system makes it mandatory) at a
	# small chamfer, and today/selected differ by accent rather than by changing shape —
	# which is what the previous plain-StyleBoxFlat-vs-chamfered split did, so the grid
	# visibly reflowed as the selection moved.
	var style := ChamferedStyleBox.new()
	style.fill_color = color
	style.border_color = SystemPalette.DIVIDER
	style.chamfer_size = 10.0
	style.border_width = 1.0
	style.accent_width = 0.0
	style.shadow_size = 0.0
	style.gradient_depth = 0.1
	style.highlight_strength = 0.0

	if is_selected:
		style.accent_color = SystemPalette.PRIMARY
		style.accent_width = 4.0
		style.border_color = SystemPalette.PRIMARY
		style.border_width = 2.0
	elif is_today:
		style.accent_color = SystemPalette.PRIMARY
		style.accent_width = 4.0
		style.border_width = 2.0

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		cell.add_theme_stylebox_override(state, style)


func _build_legend() -> void:
	for child in legend_grid.get_children():
		child.queue_free()

	# The heatmap communicated completion in fill color alone, which the design system
	# bars — the legend is what makes the encoding readable.
	var entries := [
		{"color": HEATMAP_HIGH_COLOR, "text": "ALL QUESTS DONE"},
		{"color": HEATMAP_LOW_COLOR.lerp(HEATMAP_HIGH_COLOR, 0.5), "text": "PARTLY DONE"},
		{"color": STATUS_COLOR_NONE, "text": "NOTHING LOGGED"},
		{"color": STATUS_COLOR_MISSED, "text": "APP NOT OPENED"},
	]
	for entry in entries:
		legend_grid.add_child(_build_legend_chip(entry.color, String(entry.text)))


func _build_legend_chip(color: Color, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Bordered swatch, not a bare ColorRect: the "nothing logged" fill is within a few
	# percent of the card behind it, so unbordered its chip looked like a missing swatch.
	var swatch := Panel.new()
	var swatch_style := StyleBoxFlat.new()
	swatch_style.bg_color = color
	swatch_style.border_color = SystemPalette.DIVIDER
	swatch_style.set_border_width_all(2)
	swatch_style.set_corner_radius_all(0)
	swatch.add_theme_stylebox_override("panel", swatch_style)
	swatch.custom_minimum_size = Vector2(30.0, 30.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var label := Label.new()
	label.theme_type_variation = &"SecondaryLabel"
	label.add_theme_font_size_override("font_size", 24)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text
	row.add_child(label)

	return row


## Month rollup above the day detail, so paging back through the calendar answers "how did
## that month go" without tapping 30 cells one at a time.
func _refresh_month_stats() -> void:
	for child in month_stats_grid.get_children():
		child.queue_free()

	var days_trained := 0
	var quests_completed := 0
	var quests_total := 0
	var xp_earned := 0

	for day in range(1, _days_in_month(_view_year, _view_month) + 1):
		var date_str := "%04d-%02d-%02d" % [_view_year, _view_month, day]
		if date_str == _today_str:
			var day_completed := 0
			for quest in QuestManager.current_quests:
				quests_total += 1
				if quest.completed:
					day_completed += 1
					xp_earned += quest.xp_reward
			quests_completed += day_completed
			if day_completed > 0:
				days_trained += 1
			continue

		var log := _get_log_for_date(date_str)
		if log == null or log.is_missed:
			continue
		quests_total += log.quests_total
		quests_completed += log.quests_completed
		xp_earned += log.xp_earned
		if log.quests_completed > 0:
			days_trained += 1

	var completion: int = 0 if quests_total == 0 else roundi(100.0 * float(quests_completed) / float(quests_total))
	var tiles := [
		{"caption": "DAYS TRAINED", "value": str(days_trained), "accent": SystemPalette.SUCCESS},
		{"caption": "QUESTS DONE", "value": "%d / %d" % [quests_completed, quests_total], "accent": SystemPalette.PRIMARY},
		{"caption": "XP EARNED", "value": str(xp_earned), "accent": SystemPalette.GOLD},
		{"caption": "COMPLETION", "value": "%d%%" % completion, "accent": SystemPalette.SUCCESS},
	]
	for tile_data in tiles:
		var tile := HudCard.metric_tile(String(tile_data.caption), String(tile_data.value), tile_data.accent)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		month_stats_grid.add_child(tile)


func _select_date(date_str: String) -> void:
	_selected_date = date_str
	_refresh_calendar()
	_populate_detail(date_str)


func _populate_detail(date_str: String) -> void:
	for child in detail_quest_list.get_children():
		child.queue_free()

	detail_title_label.text = _format_detail_title(date_str)

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
			_set_detail_state("NO DATA FOR THIS DAY.", SystemPalette.TEXT_SECONDARY, SystemPalette.TEXT_SECONDARY)
			return
		if log.is_missed:
			_set_detail_state("MISSED — the app wasn't opened this day.", STATUS_COLOR_MISSED, STATUS_COLOR_MISSED)
			return
		is_rest_day = log.is_rest_day
		quests_total = log.quests_total
		quests_completed = log.quests_completed
		xp_earned = log.xp_earned
		for summary in log.quest_summaries:
			quest_summaries.append(summary)

	var all_done := quests_total > 0 and quests_completed == quests_total
	var accent: Color = SystemPalette.SUCCESS if all_done else SystemPalette.PRIMARY
	var kind_text := "REST DAY" if is_rest_day else "TRAINING DAY"
	_set_detail_state(
		"%s · %d / %d QUESTS · %d XP" % [kind_text, quests_completed, quests_total, xp_earned],
		SystemPalette.TEXT_SECONDARY,
		accent
	)

	for entry in quest_summaries:
		detail_quest_list.add_child(_build_quest_row(entry))


func _set_detail_state(summary: String, summary_color: Color, accent: Color) -> void:
	detail_summary_label.text = summary
	detail_summary_label.add_theme_color_override("font_color", summary_color)
	_detail_glyph.color = accent
	_detail_style.accent_color = accent
	_detail_style.emit_changed()


func _format_detail_title(date_str: String) -> String:
	var parts := date_str.split("-")
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	var weekday: String = WEEKDAY_ABBR[_weekday_of_date_str(date_str)]
	var title := "%s · %s %d" % [weekday, MONTH_ABBR[month - 1], day]
	return title + " · TODAY" if date_str == _today_str else title


## Read-only history row: a status glyph plus the title, not a disabled CheckBox. A greyed
## checkbox reads as "you may not touch this" rather than "this is a record of what
## happened", and the design system asks for read-only and disabled to look different.
func _build_quest_row(entry: Variant) -> Control:
	var title: String = entry.title if entry is Quest else String(entry.get("title", ""))
	var completed: bool = entry.completed if entry is Quest else bool(entry.get("completed", false))
	var logged_value: float = entry.logged_value if entry is Quest else float(entry.get("logged_value", 0.0))
	var unit: String = entry.unit if entry is Quest else String(entry.get("unit", ""))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var glyph_slot := Control.new()
	glyph_slot.custom_minimum_size = Vector2(40.0, 40.0)
	glyph_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph_slot)
	_add_glyph(
		glyph_slot,
		HudGlyph.Shape.CHECK if completed else HudGlyph.Shape.CIRCLE,
		SystemPalette.SUCCESS if completed else SystemPalette.TEXT_SECONDARY
	)

	var title_label := Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", SystemPalette.TEXT if completed else SystemPalette.TEXT_SECONDARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text = title
	row.add_child(title_label)

	if completed and unit != "":
		var value_label := Label.new()
		value_label.theme_type_variation = &"AccentLabel"
		value_label.add_theme_font_size_override("font_size", 28)
		value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value_label.text = "%s %s" % [_format_number(logged_value), unit]
		row.add_child(value_label)

	return row


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
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")
