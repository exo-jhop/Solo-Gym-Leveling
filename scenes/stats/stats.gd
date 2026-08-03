extends Control

## Stats Screen (spec 4.3): rank progression + radar chart of the 5 stats + PR list.
## Radar points are tappable (this-week quest breakdown per stat) and PR rows are
## expandable (PR-history sparkline) — both read existing PRTracker/HistoryManager
## data, no new tracking mechanism.
##
## Portrait pass (design system v2): the screen used to lay four unrelated blocks straight
## onto the background with only an HSeparator between them, and scrolled just the PR list
## — a scroll region nested inside a screen that itself overflowed a 1080x2400 viewport.
## Content is now grouped into chamfered cards inside one page-level ScrollContainer, and
## rank progression uses the design system's radial dial instead of a bare ProgressBar
## that restated the same XP number printed underneath it.

const PRSparklineScript := preload("res://scenes/stats/pr_sparkline.gd")

const STAT_NAMES := ["STR", "VIT", "AGI", "INT", "SENSE"]  # order matches radar_chart.gd STAT_LABELS

# 48dp at this project's 1080px-wide design canvas (= 360dp), the Android minimum
# touch-target size the design system makes mandatory for every tappable element.
const TOUCH_TARGET := 144.0

# "Session" = a calendar day with at least one completed lift quest (any exercise) —
# the closest proxy to "workout ago" the existing data supports, since PRTracker only
# logs new-best moments, not every non-PR completion. Trending up if the exercise's
# last PR happened within this many sessions of today; plateaued otherwise.
const SESSIONS_TREND_WINDOW := 5

@onready var scroll: ScrollContainer = $Margin/Scroll
@onready var level_value_label: Label = $Margin/Scroll/Root/HeaderRow/LevelPill/LevelBox/LevelValueLabel
@onready var level_pill: PanelContainer = $Margin/Scroll/Root/HeaderRow/LevelPill
@onready var rank_card: PanelContainer = $Margin/Scroll/Root/RankCard
@onready var rank_title_label: Label = $Margin/Scroll/Root/RankCard/RankBox/RankHeaderRow/RankTitleLabel
@onready var rank_dial: Control = $Margin/Scroll/Root/RankCard/RankBox/RankDial
@onready var sync_label: Label = $Margin/Scroll/Root/RankCard/RankBox/SyncLabel
@onready var rank_xp_label: Label = $Margin/Scroll/Root/RankCard/RankBox/RankXPLabel
@onready var radar_card: PanelContainer = $Margin/Scroll/Root/RadarCard
@onready var radar_glyph_slot: Control = $Margin/Scroll/Root/RadarCard/RadarBox/RadarHeaderRow/RadarGlyphSlot
@onready var radar_chart: Control = $Margin/Scroll/Root/RadarCard/RadarBox/RadarChart
@onready var breakdown_card: PanelContainer = $Margin/Scroll/Root/BreakdownCard
@onready var breakdown_header: Label = $Margin/Scroll/Root/BreakdownCard/BreakdownBox/BreakdownHeader
@onready var breakdown_list: VBoxContainer = $Margin/Scroll/Root/BreakdownCard/BreakdownBox/BreakdownList
@onready var pr_card: PanelContainer = $Margin/Scroll/Root/PRCard
@onready var pr_glyph_slot: Control = $Margin/Scroll/Root/PRCard/PRBox/PRHeaderRow/PRGlyphSlot
@onready var pr_count_label: Label = $Margin/Scroll/Root/PRCard/PRBox/PRHeaderRow/PRCountLabel
@onready var pr_list: VBoxContainer = $Margin/Scroll/Root/PRCard/PRBox/PRList
@onready var back_button: Button = $Margin/Scroll/Root/BackButton

# Rank-tinted, so it can't be baked into the scene (design system v2: rank color owns the
# rank card's border/accent).
var _rank_style: ChamferedStyleBox
var _level_style: ChamferedStyleBox


func _ready() -> void:
	_build_cards()
	GameManager.stats_changed.connect(_refresh)
	radar_chart.set_tappable(true)
	radar_chart.stat_tapped.connect(_on_stat_tapped)
	back_button.pressed.connect(_go_back)
	PressFeedback.attach(back_button)
	NavButtonStyle.apply(back_button)
	_refresh()


## Card category accents (design system v2): primary blue for progression/attributes,
## gold for the achievement category the PR list belongs to.
func _build_cards() -> void:
	_rank_style = HudCard.apply(rank_card)
	_level_style = HudCard.row_style(SystemPalette.PRIMARY, {"left": 30.0, "top": 12.0, "right": 30.0, "bottom": 16.0})
	level_pill.add_theme_stylebox_override("panel", _level_style)
	HudCard.apply(radar_card)
	HudCard.apply(breakdown_card)
	HudCard.apply(pr_card, SystemPalette.GOLD)

	_add_glyph(radar_glyph_slot, HudGlyph.Shape.STATS, SystemPalette.PRIMARY)
	_add_glyph(pr_glyph_slot, HudGlyph.Shape.TROPHY, SystemPalette.GOLD)


func _add_glyph(slot: Control, shape: HudGlyph.Shape, color: Color) -> HudGlyph:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(glyph)
	return glyph


## Glyph inset inside a button rather than filling it: the button is sized for the 48dp
## touch minimum, which is much larger than the icon should read.
func _add_button_glyph(button: Button, shape: HudGlyph.Shape, color: Color, inset: float) -> HudGlyph:
	var glyph := _add_glyph(button, shape, color)
	glyph.offset_left = inset
	glyph.offset_top = inset
	glyph.offset_right = -inset
	glyph.offset_bottom = -inset
	return glyph


func _refresh() -> void:
	var stats := GameManager.hunter_stats
	var rank_color := GameManager.rank_color(stats.rank)

	level_value_label.text = str(stats.level)
	_level_style.accent_color = rank_color
	_level_style.emit_changed()
	level_value_label.add_theme_color_override("font_color", rank_color)

	_rank_style.accent_color = rank_color
	_rank_style.emit_changed()
	rank_title_label.text = stats.current_title.to_upper() if stats.current_title != "" else "HUNTER"
	rank_title_label.add_theme_color_override("font_color", rank_color)

	_refresh_rank_dial(stats)

	radar_chart.set_values([stats.str_stat, stats.vit_stat, stats.agi_stat, stats.int_stat, stats.sense_stat])
	breakdown_card.visible = false
	_refresh_pr_list()


func _refresh_rank_dial(stats: HunterStats) -> void:
	var nodes: Array = []
	for rank in GameManager.RANKS:
		nodes.append({"letter": rank, "color": GameManager.rank_color(rank)})

	var current_threshold := GameManager.current_rank_threshold()
	var next_threshold := GameManager.next_rank_threshold()
	var rank_index: int = GameManager.RANKS.find(stats.rank)

	var ratio := 1.0
	if next_threshold != -1:
		# Fraction of the way through the *current* rank band, not of the absolute XP total,
		# so the gauge empties again on each rank-up instead of creeping toward S forever.
		var span: int = maxi(next_threshold - current_threshold, 1)
		ratio = clampf(float(stats.xp - current_threshold) / float(span), 0.0, 1.0)

	rank_dial.set_state(nodes, rank_index, ratio)
	# Position on the whole E→S ladder, which is what the dial's gauge draws. The XP line
	# below carries the within-rank number, so the two readouts don't restate each other.
	sync_label.text = "SYNC STATUS: %d%%" % roundi(rank_dial.ladder_fraction() * 100.0)
	sync_label.add_theme_color_override("font_color", GameManager.rank_color(stats.rank))

	if next_threshold == -1:
		rank_xp_label.text = "MAX RANK REACHED"
	else:
		var next_rank: String = GameManager.RANKS[rank_index + 1]
		rank_xp_label.text = "%d XP TO RANK %s" % [next_threshold - stats.xp, next_rank]


## ---- Radar tap breakdown ----

func _on_stat_tapped(stat_index: int) -> void:
	_show_stat_breakdown(STAT_NAMES[stat_index])


func _show_stat_breakdown(stat_name: String) -> void:
	breakdown_header.text = "%s THIS WEEK" % stat_name
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
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "No %s quests completed yet this week." % stat_name
		breakdown_list.add_child(empty_label)
	else:
		for contribution in contributions:
			breakdown_list.add_child(_build_breakdown_row(contribution))

	breakdown_card.visible = true
	# The whole page scrolls now and the breakdown card sits below a 620px radar, so on a
	# phone the tap would otherwise update a card that's entirely off-screen. One frame for
	# the container to lay the newly-visible card out before scrolling to it.
	await get_tree().process_frame
	scroll.ensure_control_visible(breakdown_card)


## Date in its own fixed-width column rather than "date — title" in one string, so the
## titles line up down the list instead of starting at a ragged offset.
func _build_breakdown_row(contribution: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var date_label := Label.new()
	date_label.theme_type_variation = &"SecondaryLabel"
	date_label.add_theme_font_size_override("font_size", 26)
	date_label.custom_minimum_size = Vector2(230.0, 0.0)
	date_label.text = String(contribution.date)
	row.add_child(date_label)

	var title_label := Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text = String(contribution.title)
	row.add_child(title_label)

	return row


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
	var row_count := 0
	for exercise_name in exercise_names:
		# An exercise logged both weighted and bodyweight holds a record under each metric
		# and gets a row for each — the two are never merged or compared (see PRTracker).
		for metric in PRTracker.metrics_for(exercise_name):
			pr_list.add_child(_build_pr_row(exercise_name, metric))
			row_count += 1

	pr_count_label.text = "%d TRACKED" % row_count if row_count > 0 else ""
	if row_count == 0:
		pr_list.add_child(_build_pr_empty_state())


## Empty state rather than a blank card (design system: helpful message and action when
## there's no content), and it names the condition — a lift quest completed with nothing
## logged records no PR at all, which is otherwise invisible.
func _build_pr_empty_state() -> Control:
	var label := Label.new()
	label.theme_type_variation = &"SecondaryLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "No personal records yet. Complete a lift quest with a weight or a rep count logged and your best will start tracking here."
	return label


func _build_pr_row(exercise_name: String, metric: String) -> PanelContainer:
	var value := PRTracker.best(exercise_name, metric)

	var card := PanelContainer.new()
	# Gold accent: PRs are achievement cards, the category the design system assigns
	# #FFB800 to (the same accent the Lobby's streak pill uses).
	card.add_theme_stylebox_override("panel", HudCard.row_style(SystemPalette.GOLD))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	col.add_child(header_row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	header_row.add_child(info)

	var name_label := Label.new()
	name_label.theme_type_variation = &"HeaderLabel"
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = exercise_name.to_upper()
	info.add_child(name_label)

	# The record itself at display scale with its unit demoted to secondary text, rather
	# than the old single "Bench: 80 (1.05x BW)" line where the number the screen exists
	# to show carried no more weight than the punctuation around it.
	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 12)
	info.add_child(value_row)

	var value_label := Label.new()
	value_label.theme_type_variation = &"GoldLabel"
	value_label.add_theme_font_size_override("font_size", 46)
	value_label.text = PRTracker.format_value(value)
	value_row.add_child(value_label)

	var unit_label := Label.new()
	unit_label.theme_type_variation = &"SecondaryLabel"
	unit_label.add_theme_font_size_override("font_size", 26)
	unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
	unit_label.text = _unit_caption(value, metric)
	value_row.add_child(unit_label)

	var detail := VBoxContainer.new()
	detail.visible = false
	detail.add_theme_constant_override("separation", 10)
	col.add_child(detail)
	for child in _build_pr_detail(exercise_name, metric):
		detail.add_child(child)

	var expand_button := Button.new()
	expand_button.custom_minimum_size = Vector2(TOUCH_TARGET, TOUCH_TARGET)
	expand_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	NavButtonStyle.apply_icon(expand_button, SystemPalette.GOLD)
	var chevron := _add_button_glyph(expand_button, HudGlyph.Shape.CHEVRON_DOWN, SystemPalette.GOLD, 38.0)
	expand_button.pressed.connect(func() -> void:
		detail.visible = not detail.visible
		chevron.shape = HudGlyph.Shape.CHEVRON_UP if detail.visible else HudGlyph.Shape.CHEVRON_DOWN
	)
	PressFeedback.attach(expand_button)
	header_row.add_child(expand_button)

	return card


## "KG · 1.05X BW" for a weighted record, "REPS" for a bodyweight one. PRTracker's
## format_record() prints a weight with no unit at all, which reads as a bare number
## next to a display-size numeral.
func _unit_caption(value: float, metric: String) -> String:
	if metric == "reps":
		return "REPS"
	var caption := "KG"
	var relative := PRTracker.format_relative_strength(value, metric, ProfileManager.profile.weight_kg)
	if relative != "":
		caption += " · %s" % relative.to_upper()
	return caption


func _build_pr_detail(exercise_name: String, metric: String) -> Array[Control]:
	var history := PRTracker.history_for(exercise_name, metric)
	if history.size() < 2:
		var note := Label.new()
		note.theme_type_variation = &"SecondaryLabel"
		note.add_theme_font_size_override("font_size", 26)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = "Not enough data yet — keep logging this exercise to build a trend."
		var only_note: Array[Control] = [note]
		return only_note

	var trend := _trend_state(exercise_name, metric)

	var sparkline := Control.new()
	sparkline.set_script(PRSparklineScript)
	sparkline.custom_minimum_size = Vector2(0, 120)
	sparkline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sparkline.set_data(history, trend.color)

	var caption := Label.new()
	caption.theme_type_variation = &"SecondaryLabel"
	caption.add_theme_font_size_override("font_size", 24)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", trend.color)
	caption.text = trend.text

	var parts: Array[Control] = [sparkline, caption]
	return parts


## Green if the exercise's last PR is within SESSIONS_TREND_WINDOW sessions of today (still
## trending up), orange if more have passed with no new PR (plateaued). See
## SESSIONS_TREND_WINDOW for what "session" means here.
##
## The state is returned as color *and* words: the sparkline's color used to be the only
## thing carrying it, and the design system bars conveying information by color alone.
func _trend_state(exercise_name: String, metric: String) -> Dictionary:
	var history := PRTracker.history_for(exercise_name, metric)
	if history.is_empty():
		return {"color": SystemPalette.PRIMARY, "text": ""}

	var last_date := String(history[-1].get("date", ""))
	if _sessions_since(last_date) < SESSIONS_TREND_WINDOW:
		return {
			"color": SystemPalette.SUCCESS,
			"text": "TRENDING UP — new best within the last %d sessions." % SESSIONS_TREND_WINDOW,
		}
	return {
		"color": SystemPalette.WARNING,
		"text": "PLATEAUED — no new best in %d or more sessions." % SESSIONS_TREND_WINDOW,
	}


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
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")
