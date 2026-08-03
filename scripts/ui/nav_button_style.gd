class_name NavButtonStyle
extends RefCounted

## Shared chamfered nav-button treatment (design system v2), factored out so every
## screen's buttons look identical instead of each scene re-deriving its own StyleBoxes
## (previously duplicated near-verbatim across training_log.gd, settings.gd, and
## weekly_summary.gd, and simply missing on stats/home/quest_detail).
##
## apply() with no optional args is the plain "Back" button every screen uses. The
## optional args cover everything else: `accent` recolors the chamfer trace, `margins`
## picks an inset from the constants below, and `emphasis` promotes a button to the
## screen's single primary CTA.

const PRIMARY_ACCENT := SystemPalette.PRIMARY
const DIVIDER_COLOR := SystemPalette.DIVIDER
const SURFACE_COLOR := SystemPalette.SURFACE

const CONTENT_MARGIN := {"left": 28.0, "top": 18.0, "right": 28.0, "bottom": 18.0}
## Left inset wide enough to clear a glyph slot anchored inside the card's left edge.
const ICON_CONTENT_MARGIN := {"left": 116.0, "top": 30.0, "right": 32.0, "bottom": 30.0}
## Inline action inside a card or list row (Swap, + Add Exercise), where the standard
## nav-button inset would make a three-word button dominate the row it belongs to.
const COMPACT_CONTENT_MARGIN := {"left": 24.0, "top": 14.0, "right": 24.0, "bottom": 14.0}
## Square icon-only button — a HudGlyph child fills the rect, so there's no text to inset
## for, only enough padding to keep the glyph off the chamfer.
const ICON_ONLY_MARGIN := {"left": 12.0, "top": 12.0, "right": 12.0, "bottom": 12.0}


## Chamfer/accent tuning for a full-width card-sized button — the ChamferedStyleBox defaults.
const CARD_SHAPE := {"chamfer": 30.0, "accent": 5.0, "glow": 0.55, "shadow": 14.0}
## Tuning for a square icon-only button. The card values are proportioned for a wide panel;
## on a 144px square a 30px chamfer cuts a fifth off each side and the accent bloom spills
## well past the button, which read as a damaged card rather than as a button.
const ICON_SHAPE := {"chamfer": 14.0, "accent": 3.0, "glow": 0.28, "shadow": 6.0}


static func apply(
	button: Button,
	accent: Color = PRIMARY_ACCENT,
	margins: Dictionary = CONTENT_MARGIN,
	emphasis: bool = false
) -> void:
	_apply_boxes(button, accent, margins, emphasis, CARD_SHAPE)


## Square icon-only button: a HudGlyph child carries the meaning, so there's no text to
## inset for and the shape is scaled down to match the button.
static func apply_icon(button: Button, accent: Color = PRIMARY_ACCENT) -> void:
	_apply_boxes(button, accent, ICON_ONLY_MARGIN, false, ICON_SHAPE)


static func _apply_boxes(
	button: Button,
	accent: Color,
	margins: Dictionary,
	emphasis: bool,
	shape: Dictionary
) -> void:
	var normal := _make(accent, margins, shape)
	# Resting state normally reads as a quiet surface card with only the chamfer lit.
	# The primary CTA instead carries an accent-tinted fill and a lit border, so a hub
	# screen's one main action is visibly above the secondary cards rather than beside
	# them (design system: one primary action per screen).
	if emphasis:
		normal.fill_color = SURFACE_COLOR.lerp(accent, 0.15)
		normal.border_color = SystemPalette.alpha(accent, 0.75)
		normal.glow_strength = 0.8
	else:
		normal.border_color = DIVIDER_COLOR

	var hover := _make(accent, margins, shape)
	hover.border_color = accent

	var pressed := _make(accent, margins, shape)
	pressed.fill_color = SystemPalette.alpha(accent, 0.18)
	pressed.border_color = accent

	# Without an explicit disabled box the theme's rounded-rect StyleBoxFlat showed
	# through the moment a button greyed out — so Settings' Swap button (no alternatives
	# for that exercise) and the Training Log's no-data calendar cells changed shape
	# rather than just dimming. Design system: the chamfer is mandatory in every state.
	var disabled := _make(accent, margins, shape)
	disabled.fill_color = SystemPalette.alpha(SURFACE_COLOR, 0.45)
	disabled.border_color = SystemPalette.alpha(DIVIDER_COLOR, 0.5)
	disabled.accent_color = SystemPalette.alpha(accent, 0.28)
	disabled.glow_strength = 0.0
	disabled.shadow_size = 0.0
	disabled.highlight_strength = 0.0

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)


static func _make(accent: Color, margins: Dictionary, shape: Dictionary) -> ChamferedStyleBox:
	var style := ChamferedStyleBox.new()
	style.accent_color = accent
	style.border_color = DIVIDER_COLOR
	style.chamfer_size = shape.chamfer
	style.accent_width = shape.accent
	style.glow_strength = shape.glow
	style.shadow_size = shape.shadow
	style.content_margin_left = margins.left
	style.content_margin_top = margins.top
	style.content_margin_right = margins.right
	style.content_margin_bottom = margins.bottom
	return style
