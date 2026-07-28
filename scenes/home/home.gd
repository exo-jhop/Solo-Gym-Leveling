extends Control

## Home / System Dashboard (spec 4.1).

const STAT_FONT := preload("res://assets/fonts/CascadiaCode.ttf")

@onready var level_rank_label: Label = $Margin/Root/LevelRankLabel
@onready var xp_bar: ProgressBar = $Margin/Root/XPBar
@onready var xp_label: Label = $Margin/Root/XPLabel
@onready var streak_label: Label = $Margin/Root/StreakLabel
@onready var stats_button: Button = $Margin/Root/StatsButton
@onready var lobby_button: Button = $Margin/Root/LobbyButton
@onready var quest_list: VBoxContainer = $Margin/Root/ScrollContainer/QuestList


func _ready() -> void:
	GameManager.stats_changed.connect(_refresh_header)
	QuestManager.quests_generated.connect(_refresh_quests)
	stats_button.pressed.connect(_on_stats_pressed)
	lobby_button.pressed.connect(_on_lobby_pressed)

	level_rank_label.add_theme_font_override("font", STAT_FONT)
	xp_label.add_theme_font_override("font", STAT_FONT)

	_refresh_header()
	_refresh_quests()


func _refresh_header() -> void:
	var stats := GameManager.hunter_stats
	var xp_needed := GameManager.xp_to_next_level(stats.level)

	level_rank_label.text = "Level %d — Rank %s" % [stats.level, stats.rank]
	level_rank_label.add_theme_color_override("font_color", GameManager.rank_color(stats.rank))
	xp_bar.max_value = xp_needed
	xp_bar.value = stats.xp
	xp_label.text = "XP: %d / %d" % [stats.xp, xp_needed]
	streak_label.text = "Streak: %d day(s)  |  %d freeze(s) left" % [stats.current_streak, stats.streak_freezes_available]


func _refresh_quests() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	for quest in QuestManager.current_quests:
		var row := HBoxContainer.new()

		var check := CheckBox.new()
		check.text = "%s  (+%d XP)" % [quest.title, quest.xp_reward]
		check.button_pressed = quest.completed
		check.disabled = quest.completed
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.toggled.connect(_on_quest_toggled.bind(quest))
		row.add_child(check)

		var log_button := Button.new()
		log_button.text = "Log"
		log_button.pressed.connect(_on_log_pressed.bind(quest))
		row.add_child(log_button)

		quest_list.add_child(row)


func _on_quest_toggled(pressed: bool, quest: Quest) -> void:
	if not pressed:
		return
	QuestManager.complete_quest(quest.id, quest.target_value)
	_refresh_quests()
	_refresh_header()


func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/stats/stats.tscn")


func _on_lobby_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_log_pressed(quest: Quest) -> void:
	QuestManager.selected_quest_id = quest.id
	get_tree().change_scene_to_file("res://scenes/quest_detail/quest_detail.tscn")
