extends Control

## Scratch scene only — proves out ChamferedStyleBox in isolation before it propagates
## to any real screen. Not wired into navigation. Open and run this scene directly.

const ChamferedStyleBoxScript := preload("res://scripts/ui/chamfered_stylebox.gd")

# Palette-defined colors only (system-design skill v2) — no invented hex values.
const TEST_CARDS := [
	{"label": "XP CARD", "accent": Color(0.0, 0.721569, 1.0, 1.0)},        # #00B8FF primary accent
	{"label": "STREAK CARD", "accent": Color(1.0, 0.721569, 0.0, 1.0)},    # #FFB800 gold
	{"label": "CONSISTENCY CARD", "accent": Color(0.227451, 0.858824, 0.462745, 1.0)},  # #3ADB76 success
	{"label": "WARNING CARD", "accent": Color(1.0, 0.419608, 0.207843, 1.0)},  # #FF6B35 warning
]


func _ready() -> void:
	var row := $Margin/Row
	for card_data in TEST_CARDS:
		row.add_child(_build_card(card_data.label, card_data.accent))

	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://scratch_hud_card_capture.png")
		get_tree().quit()


func _build_card(label_text: String, accent_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 140)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := ChamferedStyleBoxScript.new()
	style.accent_color = accent_color
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"SecondaryLabel"
	title.text = label_text
	box.add_child(title)

	var value := Label.new()
	value.theme_type_variation = &"HeaderLabel"
	value.add_theme_color_override("font_color", accent_color)
	value.text = "1,240"
	box.add_child(value)

	return card
