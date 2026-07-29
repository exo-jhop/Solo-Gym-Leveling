extends Control

## First-launch onboarding, step 4 of 4 (spec v4 3): shows the calculated protein target
## and calorie direction, then finalizes onboarding — applies targets to QuestManager,
## marks onboarding_complete, saves, and lands on the Lobby like a returning user would.

@onready var summary_label: Label = $Margin/Root/SummaryLabel
@onready var finish_button: Button = $Margin/Root/FinishButton


func _ready() -> void:
	var profile := ProfileManager.profile
	var protein := profile.calculate_protein_target_g()
	var direction_text: String = ProfileManager.CALORIE_DIRECTION_LABELS[profile.calorie_direction()]
	summary_label.text = "Calculated protein target: %dg/day\n%s\n\nThese feed into your daily quests — you can revisit them anytime in Settings > Profile." % [int(protein), direction_text]
	finish_button.pressed.connect(_on_finish_pressed)
	PressFeedback.attach(finish_button)


func _on_finish_pressed() -> void:
	var profile := ProfileManager.profile
	profile.onboarding_complete = true
	QuestManager.training_cycle = ProgramGenerator.generate_program(profile.days_per_week, profile.goal, profile.equipment_access)
	ProfileManager.apply_targets()
	SaveManager.save_game()
	SceneTransition.go_to_scene("res://scenes/lobby/lobby.tscn")
