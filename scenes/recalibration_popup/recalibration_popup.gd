extends CanvasLayer

## Weekly program-recalibration / adaptive-daily-load confirmation (features: weekly
## recalibration, adaptive daily load v5). Distinct from SystemPopup (reserved for
## Level-up/Rank-up/PR moments, tap-to-dismiss only) since this needs an actual
## accept/decline choice, not just acknowledgement.
## Serves both QuestManager.pending_recalibration and pending_load_adjustment — only one
## is ever staged at a time (SaveManager's conflict gating enforces "one decision per
## launch"), so one popup covers both rather than duplicating this scene for no reason.

@onready var panel: PanelContainer = $Dim/CenterContainer/Panel
@onready var message_label: Label = $Dim/CenterContainer/Panel/Margin/VBox/MessageLabel
@onready var accept_button: Button = $Dim/CenterContainer/Panel/Margin/VBox/Buttons/AcceptButton
@onready var dismiss_button: Button = $Dim/CenterContainer/Panel/Margin/VBox/Buttons/DismissButton

var _suggestion: Dictionary = {}
var _source := ""  # "recalibration" or "load_adjustment" — which autoload dict this came from


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
## Recalibration is checked first — it's the longer-standing, weekly-cadence check —
## though SaveManager's conflict gating means in practice at most one is ever non-empty.
func check_pending() -> void:
	if not QuestManager.pending_recalibration.is_empty():
		_suggestion = QuestManager.pending_recalibration
		_source = "recalibration"
	elif not QuestManager.pending_load_adjustment.is_empty():
		_suggestion = QuestManager.pending_load_adjustment
		_source = "load_adjustment"
	else:
		return
	message_label.text = _suggestion.get("message", "")
	visible = true


func _on_accept_pressed() -> void:
	if _source == "load_adjustment":
		QuestManager.apply_load_adjustment(_suggestion)
	else:
		QuestManager.apply_recalibration(_suggestion)
	SaveManager.save_game()
	visible = false


func _on_dismiss_pressed() -> void:
	if _source == "load_adjustment":
		QuestManager.dismiss_load_adjustment()
	else:
		QuestManager.dismiss_recalibration()
	visible = false
