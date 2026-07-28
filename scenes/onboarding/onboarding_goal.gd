extends Control

## First-launch onboarding, step 2 of 4 (spec v4 3): single-select goal, drives calorie
## direction + quest emphasis (spec 2.2). Writes straight into ProfileManager.profile,
## the same cross-scene scratch pattern QuestManager.selected_quest_id uses.

@onready var goal_list: VBoxContainer = $Margin/Root/GoalList


func _ready() -> void:
	for goal in ProfileManager.GOALS:
		var button := Button.new()
		button.text = ProfileManager.GOAL_LABELS[goal]
		button.pressed.connect(_on_goal_pressed.bind(goal))
		goal_list.add_child(button)


func _on_goal_pressed(goal: String) -> void:
	ProfileManager.profile.goal = goal
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_metrics.tscn")
