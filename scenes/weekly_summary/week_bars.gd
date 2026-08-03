extends Control

## Seven-day completion bar chart for the Weekly Summary screen.
##
## The screen used to state the week entirely in prose ("Quests completed: 12 / 20"), which
## gave no sense of *shape* — whether that was four solid days and three blanks or seven
## half-finished ones. Custom _draw(), same approach as radar_chart.gd and pr_sparkline.gd:
## no charting addon in the project, and the whole thing is one polygon and one label per day.
##
## Day data is passed in (see set_days) rather than read off HistoryManager, keeping this a
## renderer with no autoload dependency.

const LABEL_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const LABEL_FONT_SIZE := 26
const LABEL_BAND := 46.0
const BAR_WIDTH_RATIO := 0.56
## Bars shorter than this still draw at this height, so a day with 1/8 quests done reads as
## "something happened" rather than as an empty column.
const MIN_VISIBLE_RATIO := 0.03

# State strings accepted in set_days(), kept as constants so weekly_summary.gd and this
# renderer can't drift apart on a typo.
const STATE_DONE := "done"
const STATE_PARTIAL := "partial"
const STATE_NONE := "none"
const STATE_MISSED := "missed"
const STATE_FUTURE := "future"

## Muted red for a day the app was never opened — matches the Training Log calendar's
## missed-day fill so the same fact reads the same way on both screens.
const MISSED_COLOR := Color(0.55, 0.2, 0.22)

var _days: Array = []  # [{"label": String, "ratio": float, "state": String, "is_today": bool}]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_days(days: Array) -> void:
	_days = days
	queue_redraw()


func _draw() -> void:
	if _days.is_empty():
		return

	var chart_height: float = size.y - LABEL_BAND
	if chart_height <= 0.0:
		return
	var baseline: float = chart_height
	var column: float = size.x / float(_days.size())
	var bar_width: float = column * BAR_WIDTH_RATIO

	# Full-completion guide, so a bar reaching the top reads as "cleared the day" instead of
	# just "taller than the others".
	draw_line(Vector2(0.0, 0.0), Vector2(size.x, 0.0), SystemPalette.alpha(SystemPalette.DIVIDER, 0.7), 1.5)
	draw_line(Vector2(0.0, baseline), Vector2(size.x, baseline), SystemPalette.DIVIDER, 2.0)

	for i in range(_days.size()):
		var day: Dictionary = _days[i]
		var center_x: float = column * (float(i) + 0.5)
		var left: float = center_x - bar_width / 2.0
		var state := String(day.get("state", STATE_NONE))
		var is_today := bool(day.get("is_today", false))

		# Track behind every bar, so the seven columns read as a week even where nothing was
		# logged — otherwise a rest-heavy week looks like a rendering failure.
		_draw_bar(left, 0.0, bar_width, chart_height, SystemPalette.alpha(SystemPalette.SURFACE, 0.9))

		var fill_color := _fill_color(state)
		if fill_color.a > 0.0:
			var ratio: float = clampf(float(day.get("ratio", 0.0)), 0.0, 1.0)
			if state == STATE_MISSED:
				ratio = 1.0  # a missed day is a full-height marker, not a zero-height bar
			elif ratio > 0.0:
				ratio = maxf(ratio, MIN_VISIBLE_RATIO)
			if ratio > 0.0:
				var height: float = chart_height * ratio
				_draw_bar(left, baseline - height, bar_width, height, fill_color)

		if is_today:
			# Today's column is outlined rather than recolored, so "today" and "how much of
			# today is done" stay two separate readings.
			_draw_bar_outline(left, 0.0, bar_width, chart_height, SystemPalette.PRIMARY)

		var label_color: Color = SystemPalette.PRIMARY if is_today else SystemPalette.TEXT_SECONDARY
		_draw_label(String(day.get("label", "")), center_x, baseline + LABEL_BAND * 0.66, label_color)


func _fill_color(state: String) -> Color:
	match state:
		STATE_DONE:
			return SystemPalette.SUCCESS
		STATE_PARTIAL:
			return SystemPalette.alpha(SystemPalette.SUCCESS, 0.75)
		STATE_MISSED:
			return SystemPalette.alpha(MISSED_COLOR, 0.85)
		_:
			return Color(0.0, 0.0, 0.0, 0.0)


## Bars carry the same top-right chamfer as every card in the design system, so the chart
## belongs to the same kit rather than looking like a stock widget dropped in.
func _bar_points(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	var cut: float = minf(w * 0.22, h)
	return PackedVector2Array([
		Vector2(x, y),
		Vector2(x + w - cut, y),
		Vector2(x + w, y + cut),
		Vector2(x + w, y + h),
		Vector2(x, y + h),
	])


func _draw_bar(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_colored_polygon(_bar_points(x, y, w, h), color)


func _draw_bar_outline(x: float, y: float, w: float, h: float, color: Color) -> void:
	var points := _bar_points(x, y, w, h)
	points.append(points[0])
	draw_polyline(points, color, 3.0, true)


func _draw_label(text: String, center_x: float, baseline_y: float, color: Color) -> void:
	var text_size := LABEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	draw_string(
		LABEL_FONT,
		Vector2(center_x - text_size.x / 2.0, baseline_y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_FONT_SIZE,
		color
	)
