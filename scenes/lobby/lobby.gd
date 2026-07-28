extends Control

## Lobby / Hub screen. Main entry point — routes to the app's top-level sections.

@onready var quests_button: Button = $Margin/Root/QuestsButton
@onready var stats_button: Button = $Margin/Root/StatsButton
@onready var training_log_button: Button = $Margin/Root/TrainingLogButton
@onready var settings_button: Button = $Margin/Root/SettingsButton


func _ready() -> void:
	quests_button.pressed.connect(_on_quests_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	training_log_button.pressed.connect(_on_training_log_pressed)
	settings_button.pressed.connect(_on_settings_pressed)


func _on_quests_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")


func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stats/stats.tscn")


func _on_training_log_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/training_log/training_log.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")
