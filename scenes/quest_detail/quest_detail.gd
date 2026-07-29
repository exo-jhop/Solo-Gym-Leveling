extends Control

## Quest Detail (spec 4.2). Log actual performance and complete the quest. Functional only.

const STAT_FONT := preload("res://assets/fonts/CascadiaCode.ttf")

@onready var title_label: Label = $Margin/Root/TitleLabel
@onready var meta_label: Label = $Margin/Root/MetaLabel
@onready var target_label: Label = $Margin/Root/TargetLabel
@onready var logged_value_input: LineEdit = $Margin/Root/LoggedValueRow/LoggedValueInput
@onready var logged_weight_row: HBoxContainer = $Margin/Root/LoggedWeightRow
@onready var logged_weight_input: LineEdit = $Margin/Root/LoggedWeightRow/LoggedWeightInput
@onready var status_label: Label = $Margin/Root/StatusLabel
@onready var complete_button: Button = $Margin/Root/ButtonRow/CompleteButton
@onready var back_button: Button = $Margin/Root/ButtonRow/BackButton

var quest: Quest


func _ready() -> void:
	quest = QuestManager.get_quest(QuestManager.selected_quest_id)
	complete_button.pressed.connect(_on_complete_pressed)
	back_button.pressed.connect(_go_back)
	PressFeedback.attach(complete_button)
	PressFeedback.attach(back_button)
	NavButtonStyle.apply(back_button)
	target_label.add_theme_font_override("font", STAT_FONT)

	if quest == null:
		push_error("QuestDetail: no quest found for id '%s'" % QuestManager.selected_quest_id)
		_go_back()
		return

	_populate()


func _populate() -> void:
	title_label.text = quest.title
	meta_label.text = "Category: %s   |   Reward: +%d XP -> %s" % [quest.category, quest.xp_reward, quest.stat_reward]
	target_label.text = "Target: %s %s" % [_format_number(quest.target_value), quest.unit]

	logged_weight_row.visible = quest.category == "lift"

	if quest.completed:
		logged_value_input.text = _format_number(quest.logged_value)
		logged_value_input.editable = false
		logged_weight_input.text = _format_number(quest.logged_weight) if quest.logged_weight > 0.0 else ""
		logged_weight_input.editable = false
		complete_button.disabled = true
		var status := "Completed — logged %s %s" % [_format_number(quest.logged_value), quest.unit]
		if quest.logged_weight > 0.0:
			status += " at %s" % _format_number(quest.logged_weight)
		status_label.text = status
	else:
		logged_value_input.text = _format_number(quest.target_value)
		logged_value_input.editable = true
		logged_weight_input.text = ""
		logged_weight_input.editable = true
		complete_button.disabled = false
		status_label.text = "Not completed yet"


func _on_complete_pressed() -> void:
	var value := logged_value_input.text.to_float()
	var weight := logged_weight_input.text.to_float() if logged_weight_input.text.strip_edges() != "" else 0.0
	QuestManager.complete_quest(quest.id, value, weight)
	_populate()


func _go_back() -> void:
	SceneTransition.go_to_scene("res://scenes/home/home.tscn")


func _format_number(value: float) -> String:
	if value == floor(value):
		return str(int(value))
	return str(value)
