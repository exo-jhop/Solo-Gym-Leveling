class_name NavButtonStyle
extends RefCounted

## Shared chamfered "Back" nav-button treatment (design system v2), factored out so
## every screen's back button looks identical instead of each scene re-deriving its
## own StyleBoxes (previously duplicated near-verbatim across training_log.gd,
## settings.gd, and weekly_summary.gd, and simply missing on stats/home/quest_detail).

const PRIMARY_ACCENT := Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF (design system v2)
const DIVIDER_COLOR := Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C
const CONTENT_MARGIN := {"left": 28.0, "top": 18.0, "right": 28.0, "bottom": 18.0}


static func apply(button: Button) -> void:
	var normal := ChamferedStyleBox.new()
	normal.border_color = DIVIDER_COLOR
	normal.accent_color = PRIMARY_ACCENT
	_set_margins(normal)

	var hover := ChamferedStyleBox.new()
	hover.border_color = PRIMARY_ACCENT
	hover.accent_color = PRIMARY_ACCENT
	_set_margins(hover)

	var pressed := ChamferedStyleBox.new()
	pressed.fill_color = Color(PRIMARY_ACCENT.r, PRIMARY_ACCENT.g, PRIMARY_ACCENT.b, 0.18)
	pressed.border_color = PRIMARY_ACCENT
	pressed.accent_color = PRIMARY_ACCENT
	_set_margins(pressed)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


static func _set_margins(style: ChamferedStyleBox) -> void:
	style.content_margin_left = CONTENT_MARGIN.left
	style.content_margin_top = CONTENT_MARGIN.top
	style.content_margin_right = CONTENT_MARGIN.right
	style.content_margin_bottom = CONTENT_MARGIN.bottom
