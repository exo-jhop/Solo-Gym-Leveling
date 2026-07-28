extends Control

## Stats Screen (spec 4.3): radar chart of the 5 stats + rank progress bar.

const STAT_FONT := preload("res://assets/fonts/CascadiaCode.ttf")

@onready var level_rank_label: Label = $Margin/Root/LevelRankLabel
@onready var rank_bar: ProgressBar = $Margin/Root/RankBar
@onready var rank_progress_label: Label = $Margin/Root/RankProgressLabel
@onready var radar_chart: Control = $Margin/Root/RadarChart
@onready var back_button: Button = $Margin/Root/BackButton


func _ready() -> void:
	GameManager.stats_changed.connect(_refresh)
	back_button.pressed.connect(_go_back)
	level_rank_label.add_theme_font_override("font", STAT_FONT)
	_refresh()


func _refresh() -> void:
	var stats := GameManager.hunter_stats
	level_rank_label.text = "Level %d — Rank %s" % [stats.level, stats.rank]
	level_rank_label.add_theme_color_override("font_color", GameManager.rank_color(stats.rank))

	var current_threshold := GameManager.current_rank_threshold()
	var next_threshold := GameManager.next_rank_threshold()
	if next_threshold == -1:
		rank_bar.min_value = 0
		rank_bar.max_value = 1
		rank_bar.value = 1
		rank_progress_label.text = "Max Rank reached (S)"
	else:
		rank_bar.min_value = current_threshold
		rank_bar.max_value = next_threshold
		rank_bar.value = stats.xp
		rank_progress_label.text = "XP %d / %d to next rank" % [stats.xp, next_threshold]

	radar_chart.set_values([stats.str_stat, stats.vit_stat, stats.agi_stat, stats.int_stat, stats.sense_stat])


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
