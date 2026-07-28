extends Control

## Training Log placeholder. Not yet implemented.

@onready var back_button: Button = $Margin/Root/BackButton


func _ready() -> void:
	back_button.pressed.connect(_go_back)


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
