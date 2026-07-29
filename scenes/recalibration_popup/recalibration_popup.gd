extends CanvasLayer

## Weekly program-recalibration confirmation (feature: weekly recalibration). Distinct from
## SystemPopup (reserved for Level-up/Rank-up/PR moments, tap-to-dismiss only) since this
## needs an actual accept/decline choice, not just acknowledgement.

@onready var panel: PanelContainer = $Dim/CenterContainer/Panel
@onready var message_label: Label = $Dim/CenterContainer/Panel/Margin/VBox/MessageLabel
@onready var accept_button: Button = $Dim/CenterContainer/Panel/Margin/VBox/Buttons/AcceptButton
@onready var dismiss_button: Button = $Dim/CenterContainer/Panel/Margin/VBox/Buttons/DismissButton

var _suggestion: Dictionary = {}


func _ready() -> void:
	visible = false
	accept_button.pressed.connect(_on_accept_pressed)
	dismiss_button.pressed.connect(_on_dismiss_pressed)
	# Checked directly rather than via QuestManager.quests_generated: SaveManager (earlier in
	# autoload order) already runs its startup check_new_day() before this node's _ready(),
	# so pending_recalibration is already set by the time we get here on launch.
	check_pending()


## Public so callers that stage a suggestion after this node's _ready() has already run
## (e.g. the test_main debug hook) can ask the popup to check again immediately.
func check_pending() -> void:
	if QuestManager.pending_recalibration.is_empty():
		return
	_suggestion = QuestManager.pending_recalibration
	message_label.text = _suggestion.get("message", "")
	visible = true


func _on_accept_pressed() -> void:
	QuestManager.apply_recalibration(_suggestion)
	SaveManager.save_game()
	visible = false


func _on_dismiss_pressed() -> void:
	QuestManager.dismiss_recalibration()
	visible = false
