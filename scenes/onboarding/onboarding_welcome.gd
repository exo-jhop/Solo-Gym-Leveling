extends Control

## First-launch onboarding, step 1 of 4 (spec v4 3): on-theme welcome, no data collected yet.

@onready var begin_button: Button = $Margin/Root/BeginButton


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)


func _on_begin_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_goal.tscn")
