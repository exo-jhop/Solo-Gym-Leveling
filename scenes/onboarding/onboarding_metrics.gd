extends Control

## First-launch onboarding, step 3 of 4 (spec v4 3): weight. Required since it drives
## the protein target (height/age were removed — nothing ever calculated from them).

@onready var weight_input: SpinBox = $Margin/Root/WeightRow/WeightInput
@onready var days_input: SpinBox = $Margin/Root/DaysRow/DaysInput
@onready var equipment_input: OptionButton = $Margin/Root/EquipmentRow/EquipmentInput
@onready var status_label: Label = $Margin/Root/StatusLabel
@onready var continue_button: Button = $Margin/Root/ContinueButton


func _ready() -> void:
	weight_input.value = ProfileManager.profile.weight_kg
	days_input.value = ProfileManager.profile.days_per_week

	for equipment in ProfileManager.EQUIPMENT_OPTIONS:
		equipment_input.add_item(ProfileManager.EQUIPMENT_LABELS[equipment])
	equipment_input.selected = ProfileManager.EQUIPMENT_OPTIONS.find(ProfileManager.profile.equipment_access)

	continue_button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	if weight_input.value <= 0.0:
		status_label.text = "Enter your weight to continue — it drives your protein target."
		return

	ProfileManager.profile.weight_kg = weight_input.value
	ProfileManager.profile.days_per_week = int(days_input.value)
	ProfileManager.profile.equipment_access = ProfileManager.EQUIPMENT_OPTIONS[equipment_input.selected]
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_confirmation.tscn")
