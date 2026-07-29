extends Control

## Home / System Dashboard (spec 4.1, layout v2 pass).
##
## No player-name field exists anywhere in the save data (HunterProfile only carries
## goal/weight/onboarding/days-per-week/equipment) — the profile card's identity line
## shows hunter_stats.current_title (the existing cosmetic milestone title) instead of
## an invented name. Quest rows have no drag-reorder (current_quests carries no order
## state) and no per-quest edit/remove/skip actions — only "Log" (navigate to detail)
## exists, so it stays a direct icon button rather than a 3-dot menu with one item in it.
## "Regenerate quests" isn't exposed either: QuestManager.generate_daily_quests() also
## advances the training-cycle index, so calling it outside the real day-rollover would
## silently skip a training day.

const SURFACE_COLOR := Color(0.0745098, 0.101961, 0.168627, 1)
const SUCCESS_COLOR := Color(0.227451, 0.858824, 0.462745, 1)
const PRIMARY_ACCENT := Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF (design system v2)
const GOLD_ACCENT := Color(1.0, 0.721569, 0.0, 1.0)  # #FFB800 (design system v2 streak/gold)
const SECONDARY_TEXT := Color(0.482353, 0.541176, 0.682353, 1)  # #7B8AAE

const WEEKDAY_NAMES := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const MONTH_NAMES := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

@onready var profile_card: PanelContainer = $Margin/ScrollContainer/Root/ProfileCard
@onready var avatar_slot: Control = $Margin/ScrollContainer/Root/ProfileCard/ProfileMargin/ProfileRow/AvatarSlot
@onready var title_label: Label = $Margin/ScrollContainer/Root/ProfileCard/ProfileMargin/ProfileRow/InfoBox/TitleLabel
@onready var level_label: Label = $Margin/ScrollContainer/Root/ProfileCard/ProfileMargin/ProfileRow/InfoBox/StatsRow/LevelLabel
@onready var streak_pill: PanelContainer = $Margin/ScrollContainer/Root/ProfileCard/ProfileMargin/ProfileRow/InfoBox/StatsRow/StreakPill
@onready var streak_count_label: Label = $Margin/ScrollContainer/Root/ProfileCard/ProfileMargin/ProfileRow/InfoBox/StatsRow/StreakPill/StreakMargin/StreakRow/StreakCountLabel
@onready var rank_hex_slot: Control = $Margin/ScrollContainer/Root/ProfileCard/ProfileMargin/ProfileRow/RankHexSlot
@onready var reset_card: PanelContainer = $Margin/ScrollContainer/Root/ResetCard
@onready var reset_label: Label = $Margin/ScrollContainer/Root/ResetCard/ResetMargin/ResetRow/ResetLabel
@onready var date_label: Label = $Margin/ScrollContainer/Root/ResetCard/ResetMargin/ResetRow/DateLabel
@onready var reset_timer: Timer = $Margin/ScrollContainer/Root/ResetCard/ResetTimer
@onready var xp_section: PanelContainer = $Margin/ScrollContainer/Root/XPSection
@onready var xp_bar: ProgressBar = $Margin/ScrollContainer/Root/XPSection/XPMargin/XPBox/XPBarStack/XPBar
@onready var xp_label: Label = $Margin/ScrollContainer/Root/XPSection/XPMargin/XPBox/XPBarStack/XPLabel
@onready var radar_chart: Control = $Margin/ScrollContainer/Root/RadarChart
@onready var low_energy_toggle: CheckBox = $Margin/ScrollContainer/Root/QuestsHeaderRow/LowEnergyToggle
@onready var quest_list: VBoxContainer = $Margin/ScrollContainer/Root/QuestList
@onready var stats_button: Button = $Margin/ScrollContainer/Root/ButtonRow/StatsButton
@onready var lobby_button: Button = $Margin/ScrollContainer/Root/ButtonRow/BackButton

# Set right before a completion-triggered rebuild so the freshly rebuilt card
# for this quest can receive the glow pulse (cards are recreated from scratch
# in _refresh_quests, so the pulse can't be applied to the old node instance).
var _last_completed_id: String = ""

# Rank-tied accents mutated as rank changes (design system v2: rank color always
# applies to rank badge/hexagon nodes), so these can't be fixed constants like the
# Reset card's.
var _profile_card_style: ChamferedStyleBox
var _avatar_ring: AvatarRing
var _rank_hex: RankHexBadge


func _ready() -> void:
	GameManager.stats_changed.connect(_refresh_header)
	QuestManager.quests_generated.connect(_refresh_quests)
	QuestManager.quest_completed.connect(_on_quest_completed)
	stats_button.pressed.connect(_on_stats_pressed)
	lobby_button.pressed.connect(_on_lobby_pressed)
	PressFeedback.attach(stats_button)
	PressFeedback.attach(lobby_button)
	NavButtonStyle.apply(lobby_button)
	low_energy_toggle.toggled.connect(_on_low_energy_toggled)
	reset_timer.timeout.connect(_refresh_reset_card)

	_profile_card_style = ChamferedStyleBox.new()
	profile_card.add_theme_stylebox_override("panel", _profile_card_style)
	streak_pill.add_theme_stylebox_override("panel", _make_chamfered_style(GOLD_ACCENT))
	reset_card.add_theme_stylebox_override("panel", _make_chamfered_style(PRIMARY_ACCENT))
	xp_section.add_theme_stylebox_override("panel", _make_chamfered_style(PRIMARY_ACCENT))

	_avatar_ring = AvatarRing.new()
	_avatar_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_slot.add_child(_avatar_ring)

	_rank_hex = RankHexBadge.new()
	_rank_hex.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_hex_slot.add_child(_rank_hex)

	_refresh_header()
	_refresh_quests()
	_refresh_reset_card()
	_check_all_quests_complete()


func _make_chamfered_style(accent: Color) -> ChamferedStyleBox:
	var style := ChamferedStyleBox.new()
	style.accent_color = accent
	return style


func _refresh_header() -> void:
	var stats := GameManager.hunter_stats
	var xp_needed := GameManager.xp_to_next_level(stats.level)
	var rank_color := GameManager.rank_color(stats.rank)

	title_label.text = stats.current_title.to_upper() if stats.current_title != "" else "HUNTER"
	level_label.text = "LV. %d" % stats.level
	streak_count_label.text = "%d" % stats.current_streak

	_profile_card_style.accent_color = rank_color
	_profile_card_style.emit_changed()
	_avatar_ring.ring_color = rank_color
	_avatar_ring.queue_redraw()
	_rank_hex.rank_color = rank_color
	_rank_hex.rank_letter = stats.rank
	_rank_hex.queue_redraw()

	xp_label.text = "XP: %d / %d" % [stats.xp, xp_needed]
	xp_bar.max_value = xp_needed
	var tween := create_tween()
	tween.tween_property(xp_bar, "value", stats.xp, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	radar_chart.set_values([
		stats.str_stat,
		stats.vit_stat,
		stats.agi_stat,
		stats.int_stat,
		stats.sense_stat,
	])


func _refresh_reset_card() -> void:
	var time := Time.get_time_dict_from_system()
	var seconds_left: int = 86400 - (int(time.hour) * 3600 + int(time.minute) * 60 + int(time.second))
	reset_label.text = "RESET IN %02d:%02d:%02d" % [seconds_left / 3600, (seconds_left / 60) % 60, seconds_left % 60]

	var date := Time.get_datetime_dict_from_system()
	date_label.text = "%s, %s %d" % [WEEKDAY_NAMES[date.weekday], MONTH_NAMES[date.month - 1], date.day]


func _refresh_quests() -> void:
	low_energy_toggle.visible = QuestManager.has_lift_quests()
	low_energy_toggle.set_pressed_no_signal(QuestManager.low_energy_mode)
	low_energy_toggle.disabled = QuestManager.any_lift_quest_completed()

	var tween := create_tween()
	tween.tween_property(quest_list, "modulate:a", 0.0, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_rebuild_quest_cards)
	tween.tween_property(quest_list, "modulate:a", 1.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _rebuild_quest_cards() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	for quest in QuestManager.current_quests:
		var card := PanelContainer.new()
		var card_style := _make_chamfered_style(SUCCESS_COLOR if quest.completed else PRIMARY_ACCENT)
		card.add_theme_stylebox_override("panel", card_style)
		if quest.completed:
			card.modulate.a = 0.55

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 24)
		card_margin.add_theme_constant_override("margin_top", 20)
		card_margin.add_theme_constant_override("margin_right", 24)
		card_margin.add_theme_constant_override("margin_bottom", 20)
		card.add_child(card_margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		card_margin.add_child(row)

		# Lift quests need a real logged value/weight (set via Quest Detail's "LOG" flow) —
		# a bare checkbox here would complete them with target_value (a set count)
		# misrecorded as reps, polluting PRTracker. Only non-lift quests get the checkbox.
		if quest.category != "lift":
			var check := CheckBox.new()
			check.text = ""
			check.custom_minimum_size = Vector2(56, 56)
			check.button_pressed = quest.completed
			check.disabled = quest.completed
			check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			check.toggled.connect(_on_quest_toggled.bind(quest))
			row.add_child(check)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 6)
		row.add_child(info_box)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 14)
		info_box.add_child(name_row)

		var quest_name := quest.exercise_name if quest.exercise_name != "" else quest.title
		name_row.add_child(_quest_text(quest_name, quest.completed))

		if quest.stat_reward != "":
			name_row.add_child(_build_stat_pill(quest.stat_reward))

		var target_text := _target_text(quest)
		if target_text != "":
			info_box.add_child(_quest_text(target_text, quest.completed, &"SecondaryLabel"))

		info_box.add_child(_quest_text("+%d XP" % quest.xp_reward, quest.completed, &"SecondaryLabel"))

		var log_button := Button.new()
		log_button.text = "DONE" if quest.completed else "LOG"
		log_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		log_button.pressed.connect(_on_log_pressed.bind(quest))
		PressFeedback.attach(log_button)
		row.add_child(log_button)

		quest_list.add_child(card)

		if quest.id == _last_completed_id and quest.completed:
			_pulse_card(card_style)
			_last_completed_id = ""


## "STR +1" style pill; +1 is GameManager.STAT_INCREMENT, the actual per-completion
## stat bump, not an invented display number.
func _build_stat_pill(stat_reward: String) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PRIMARY_ACCENT.r, PRIMARY_ACCENT.g, PRIMARY_ACCENT.b, 0.16)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PRIMARY_ACCENT
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 12.0
	style.content_margin_top = 3.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.theme_type_variation = &"AccentLabel"
	label.add_theme_font_size_override("font_size", 24)
	label.text = "%s +%d" % [stat_reward, GameManager.STAT_INCREMENT]
	pill.add_child(label)
	return pill


## Lift quests: sets/rep-range (the real per-completion target). Nutrition/supplement
## quests: their target_value+unit (also real data, e.g. "90 g"). Recovery has neither.
func _target_text(quest: Quest) -> String:
	if quest.category == "lift":
		return "%d sets · %s reps" % [int(quest.target_value), quest.rep_range]
	if quest.unit != "":
		var value_text := str(int(quest.target_value)) if quest.target_value == floor(quest.target_value) else str(quest.target_value)
		return "%s %s" % [value_text, quest.unit]
	return ""


## Quest card text line; struck through once the quest is completed. A RichTextLabel
## is only needed for the strikethrough case — a plain Label can't render [s] markup.
func _quest_text(text: String, completed: bool, variation: StringName = &"") -> Control:
	if not completed:
		var label := Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if variation != &"":
			label.theme_type_variation = variation
		return label

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = "[s]%s[/s]" % text
	rich.fit_content = true
	rich.scroll_active = false
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.add_theme_color_override("default_color", SECONDARY_TEXT)
	if variation != &"":
		rich.add_theme_font_size_override("normal_font_size", 14)
	return rich


func _pulse_card(style: ChamferedStyleBox) -> void:
	var base_width := style.accent_width
	var tween := create_tween()
	tween.tween_method(func(w): _set_accent_width(style, w), base_width, base_width + 4.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(w): _set_accent_width(style, w), base_width + 4.0, base_width, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_accent_width(style: ChamferedStyleBox, width: float) -> void:
	style.accent_width = width
	style.emit_changed()


func _on_low_energy_toggled(pressed: bool) -> void:
	QuestManager.set_low_energy_mode(pressed)
	_refresh_quests()


func _on_quest_toggled(pressed: bool, quest: Quest) -> void:
	if not pressed:
		return
	QuestManager.complete_quest(quest.id, quest.target_value)
	_last_completed_id = quest.id
	_refresh_quests()
	_refresh_header()


func _on_quest_completed(_quest: Quest) -> void:
	_check_all_quests_complete()


## Fires once per day the moment the last quest is completed (whether checked off
## here on Home or logged from Quest Detail), rather than every time Home is revisited
## after that point — QuestManager.all_complete_shown is the day-scoped latch for that.
func _check_all_quests_complete() -> void:
	if QuestManager.all_complete_shown:
		return
	if not QuestManager.all_quests_completed():
		return
	QuestManager.all_complete_shown = true
	_show_all_complete_toast()


## Lightweight banner (per design system v2: routine completion is a toast,
## the Level-up/Rank-up SystemPopup is reserved for those milestones only).
func _show_all_complete_toast() -> void:
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel", _make_chamfered_style(SUCCESS_COLOR))
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.offset_top = -40.0
	toast.offset_bottom = 40.0
	toast.pivot_offset = Vector2(toast.size.x / 2.0, toast.size.y / 2.0)
	toast.modulate.a = 0.0
	add_child(toast)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 16)
	toast.add_child(margin)

	var label := Label.new()
	label.text = "All quests complete.\nRest up, Hunter — come back tomorrow."
	label.theme_type_variation = &"AccentLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(260, 0)
	margin.add_child(label)

	# Re-center now that the label has given the panel its actual size.
	await get_tree().process_frame
	toast.offset_left = -toast.size.x / 2.0
	toast.offset_right = toast.size.x / 2.0

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(toast.queue_free)


func _on_stats_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/stats/stats.tscn")


func _on_lobby_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")


func _on_log_pressed(quest: Quest) -> void:
	QuestManager.selected_quest_id = quest.id
	SceneTransition.go_to_scene("res://scenes/quest_detail/quest_detail.tscn")


## Generic geometric avatar placeholder (no copyrighted character art per design
## system v2 anti-patterns): a head+shoulders silhouette inside an animated,
## rank-colored glow ring.
class AvatarRing extends Control:
	var ring_color: Color = Color.WHITE
	var _pulse: float = 0.0
	var _glow_tween: Tween

	func _ready() -> void:
		_start_glow_loop()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED:
			if _glow_tween != null and _glow_tween.is_valid():
				_glow_tween.pause()
		elif what == NOTIFICATION_APPLICATION_RESUMED:
			if _glow_tween != null and _glow_tween.is_valid():
				_glow_tween.play()

	func _start_glow_loop() -> void:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_method(_set_pulse, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_method(_set_pulse, 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _set_pulse(value: float) -> void:
		_pulse = value
		queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var r: float = min(size.x, size.y) / 2.0 - 4.0

		var glow_radius := r + 5.0 + _pulse * 5.0
		draw_arc(center, glow_radius, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, 0.2 + _pulse * 0.25), 8.0, true)
		draw_arc(center, r, 0.0, TAU, 56, ring_color, 4.0, true)

		draw_circle(center, r - 10.0, Color(0.0745098, 0.101961, 0.168627, 1))

		var icon_color := Color(0.482353, 0.541176, 0.682353, 1)
		draw_circle(center - Vector2(0.0, r * 0.32), r * 0.28, icon_color)
		var shoulder_width := r * 0.95
		var shoulder_top := center.y + r * 0.06
		var shoulder_points := PackedVector2Array([
			Vector2(center.x - shoulder_width * 0.5, center.y + r * 0.7),
			Vector2(center.x - shoulder_width * 0.32, shoulder_top),
			Vector2(center.x + shoulder_width * 0.32, shoulder_top),
			Vector2(center.x + shoulder_width * 0.5, center.y + r * 0.7),
		])
		draw_colored_polygon(shoulder_points, icon_color)


## Rank hexagon badge (design system v2: rank color applies to rank badge/hexagon
## nodes). Flat hexagon fill with a rank-colored border and centered rank letter.
class RankHexBadge extends Control:
	var rank_color: Color = Color.WHITE
	var rank_letter: String = "E"
	var _label: Label

	func _ready() -> void:
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.theme_type_variation = &"HeaderLabel"
		add_child(_label)

	func _draw() -> void:
		var points := _hex_points()
		var fill_color := rank_color.darkened(0.75)
		draw_colored_polygon(points, fill_color)

		var border_points := points.duplicate()
		border_points.append(points[0])
		draw_polyline(border_points, rank_color, 4.0, true)

		_label.text = rank_letter
		_label.add_theme_color_override("font_color", rank_color)

	func _hex_points() -> PackedVector2Array:
		var center := size / 2.0
		var r: float = min(size.x, size.y) / 2.0 - 2.0
		var points := PackedVector2Array()
		for i in range(6):
			var angle := deg_to_rad(60.0 * i - 90.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		return points
