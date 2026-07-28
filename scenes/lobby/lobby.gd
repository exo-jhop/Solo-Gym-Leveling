extends Control

## Lobby / Hub screen. Main entry point — routes to the app's top-level sections.

@onready var reminder_banner: HBoxContainer = $Margin/Root/ReminderBanner
@onready var reminder_label: Label = $Margin/Root/ReminderBanner/ReminderLabel
@onready var dismiss_button: Button = $Margin/Root/ReminderBanner/DismissButton
@onready var rank_title_label: Label = $Margin/Root/RankTitleLabel
@onready var quests_button: Button = $Margin/Root/QuestsButton
@onready var stats_button: Button = $Margin/Root/StatsButton
@onready var training_log_button: Button = $Margin/Root/TrainingLogButton
@onready var weekly_summary_button: Button = $Margin/Root/WeeklySummaryButton
@onready var settings_button: Button = $Margin/Root/SettingsButton


func _ready() -> void:
	quests_button.pressed.connect(_on_quests_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	training_log_button.pressed.connect(_on_training_log_pressed)
	weekly_summary_button.pressed.connect(_on_weekly_summary_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	dismiss_button.pressed.connect(_on_dismiss_reminder_pressed)
	GameManager.stats_changed.connect(_refresh_rank_title)
	_refresh_rank_title()
	reminder_banner.visible = NotificationManager.should_remind()


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
