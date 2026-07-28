extends Control

## Lobby / Hub screen. Main entry point — routes to the app's top-level sections.

@onready var rank_title_label: Label = $Margin/Root/RankTitleLabel
@onready var quests_button: Button = $Margin/Root/QuestsButton
@onready var stats_button: Button = $Margin/Root/StatsButton
@onready var training_log_button: Button = $Margin/Root/TrainingLogButton
@onready var settings_button: Button = $Margin/Root/SettingsButton


func _ready() -> void:
	quests_button.pressed.connect(_on_quests_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	training_log_button.pressed.connect(_on_training_log_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	GameManager.stats_changed.connect(_refresh_rank_title)
	_refresh_rank_title()


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


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")
