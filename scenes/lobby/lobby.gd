extends Control

## Lobby / Hub screen. Main entry point — routes to the app's top-level sections.

@onready var reminder_banner: HBoxContainer = $Margin/Root/ReminderBanner
@onready var reminder_label: Label = $Margin/Root/ReminderBanner/ReminderLabel
@onready var dismiss_button: Button = $Margin/Root/ReminderBanner/DismissButton
@onready var rank_title_label: Label = $Margin/Root/RankTitleLabel
@onready var character_panel: TextureRect = $Margin/Root/ContentRow/CharacterPanel
@onready var quests_button: Button = $Margin/Root/ContentRow/ButtonsColumn/QuestsButton
@onready var stats_button: Button = $Margin/Root/ContentRow/ButtonsColumn/StatsButton
@onready var training_log_button: Button = $Margin/Root/ContentRow/ButtonsColumn/TrainingLogButton
@onready var weekly_summary_button: Button = $Margin/Root/ContentRow/ButtonsColumn/WeeklySummaryButton
@onready var settings_button: Button = $Margin/Root/ContentRow/ButtonsColumn/SettingsButton
@onready var notification_sfx: AudioStreamPlayer = $NotificationSfx


func _ready() -> void:
	for button in [quests_button, stats_button, training_log_button, weekly_summary_button, settings_button]:
		NavButtonStyle.apply(button)

	# First-launch gate (spec v4 3): onboarding is skip-able for returning users, so this
	# only fires once, until ProfileManager.profile.onboarding_complete is set.
	if ProfileManager.needs_onboarding():
		SceneTransition.go_to_scene("res://scenes/onboarding/onboarding_welcome.tscn")
		return

	# Post-migration confirmation pass (spec v4 6): route to Settings > Profile once so
	# the guessed goal/weight can be confirmed/adjusted, instead of the full onboarding flow.
	if ProfileManager.just_migrated:
		ProfileManager.just_migrated = false
		SceneTransition.go_to_scene("res://scenes/settings/settings.tscn")
		return

	quests_button.pressed.connect(_on_quests_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	training_log_button.pressed.connect(_on_training_log_pressed)
	weekly_summary_button.pressed.connect(_on_weekly_summary_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	dismiss_button.pressed.connect(_on_dismiss_reminder_pressed)
	for button in [dismiss_button, quests_button, stats_button, training_log_button, weekly_summary_button, settings_button]:
		PressFeedback.attach(button)
	GameManager.stats_changed.connect(_refresh_rank_title)
	GameManager.stats_changed.connect(_refresh_avatar)
	_refresh_rank_title()
	_refresh_avatar()
	reminder_banner.visible = NotificationManager.any_reminder_due()
	if reminder_banner.visible:
		notification_sfx.play()


func _refresh_rank_title() -> void:
	var stats := GameManager.hunter_stats
	rank_title_label.text = "Rank %s — %s" % [stats.rank, stats.current_title]
	rank_title_label.add_theme_color_override("font_color", GameManager.rank_color(stats.rank))


## Swaps the character panel to the current rank's physique tier. The scene's own
## texture is the Rank E render, so this is a no-op on a fresh save.
func _refresh_avatar() -> void:
	var path := GameManager.rank_avatar_path(GameManager.hunter_stats.rank)
	# stats_changed fires on every XP gain, but the avatar only moves at a rank
	# boundary — skip the multi-MB texture load unless the tier actually changed.
	if character_panel.texture and character_panel.texture.resource_path == path:
		return
	character_panel.texture = load(path)


func _on_quests_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/home/home.tscn")


func _on_stats_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/stats/stats.tscn")


func _on_training_log_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/training_log/training_log.tscn")


func _on_weekly_summary_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/weekly_summary/weekly_summary.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/settings/settings.tscn")


func _on_dismiss_reminder_pressed() -> void:
	reminder_banner.visible = false
