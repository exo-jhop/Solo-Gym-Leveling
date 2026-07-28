extends Control

## Lobby / Hub screen. Main entry point — routes to the app's top-level sections.

const PRIMARY_ACCENT := Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF (design system v2)
const DIVIDER_COLOR := Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C

# Chamfered nav buttons (design system v2): normal reads as a quiet card, hover/pressed
# brighten the border to the primary accent — same interaction cue the plain-Button
# hover/pressed styles in system_theme.tres already use, just on the new card shape.
const BUTTON_CONTENT_MARGIN := {"left": 16.0, "top": 10.0, "right": 16.0, "bottom": 10.0}

@onready var reminder_banner: HBoxContainer = $Margin/Root/ReminderBanner
@onready var reminder_label: Label = $Margin/Root/ReminderBanner/ReminderLabel
@onready var dismiss_button: Button = $Margin/Root/ReminderBanner/DismissButton
@onready var rank_title_label: Label = $Margin/Root/RankTitleLabel
@onready var quests_button: Button = $Margin/Root/QuestsButton
@onready var stats_button: Button = $Margin/Root/StatsButton
@onready var training_log_button: Button = $Margin/Root/TrainingLogButton
@onready var weekly_summary_button: Button = $Margin/Root/WeeklySummaryButton
@onready var settings_button: Button = $Margin/Root/SettingsButton


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
	for button in [quests_button, stats_button, training_log_button, weekly_summary_button, settings_button]:
		_apply_chamfered_button_style(button)

	# First-launch gate (spec v4 3): onboarding is skip-able for returning users, so this
	# only fires once, until ProfileManager.profile.onboarding_complete is set.
	if ProfileManager.needs_onboarding():
		get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_welcome.tscn")
		return

	# Post-migration confirmation pass (spec v4 6): route to Settings > Profile once so
	# the guessed goal/weight can be confirmed/adjusted, instead of the full onboarding flow.
	if ProfileManager.just_migrated:
		ProfileManager.just_migrated = false
		get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")
		return

	quests_button.pressed.connect(_on_quests_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	training_log_button.pressed.connect(_on_training_log_pressed)
	weekly_summary_button.pressed.connect(_on_weekly_summary_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	dismiss_button.pressed.connect(_on_dismiss_reminder_pressed)
	GameManager.stats_changed.connect(_refresh_rank_title)
	_refresh_rank_title()
	reminder_banner.visible = NotificationManager.any_reminder_due()


func _refresh_rank_title() -> void:
	var stats := GameManager.hunter_stats
	rank_title_label.text = "Rank %s — %s" % [stats.rank, stats.current_title]
	rank_title_label.add_theme_color_override("font_color", GameManager.rank_color(stats.rank))


func _on_quests_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")


func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stats/stats.tscn")


func _on_training_log_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/training_log/training_log.tscn")


func _on_weekly_summary_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/weekly_summary/weekly_summary.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_dismiss_reminder_pressed() -> void:
	reminder_banner.visible = false
