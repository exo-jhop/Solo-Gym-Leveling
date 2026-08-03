class_name NavButtonStyle
extends RefCounted

## Shared chamfered nav-button treatment (design system v2), factored out so every
## screen's buttons look identical instead of each scene re-deriving its own StyleBoxes
## (previously duplicated near-verbatim across training_log.gd, settings.gd, and
## weekly_summary.gd, and simply missing on stats/home/quest_detail).
##
## apply() with no optional args is the plain "Back" button every screen uses. The
## optional args cover everything else: `accent` recolors the border (hover/pressed)
## and, on the emphasis CTA, its fill tint and breathing pulse; `margins` picks an
## inset from the constants below; `emphasis` promotes a button to the screen's single
## primary CTA.
##
## Buttons deliberately don't use ChamferedStyleBox's diagonal accent trace/glow along
## the chamfer cut (accent_width stays 0 below) — on a button that line read as a
## stray corner artifact rather than the intentional card-shape signature it is on
## non-button panels (Hero Card, stat tiles, ...), which still use it as normal.

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


## Chamfer/shadow tuning for a full-width card-sized button.
const CARD_SHAPE := {"chamfer": 30.0, "shadow": 14.0}
## Tuning for a square icon-only button — a smaller chamfer than the card shape, since
## a 144px square button can't carry the same 30px cut as a wide panel.
const ICON_SHAPE := {"chamfer": 14.0, "shadow": 6.0}

## Idle "breathing" border on the one emphasis (primary CTA) button per screen: a slow
## sine-like pulse of the border's accent alpha, so the screen's single main action
## keeps drawing the eye at rest instead of only reacting to touch.
const BREATH_MIN_BORDER_ALPHA := 0.5
const BREATH_MAX_BORDER_ALPHA := 1.0
const BREATH_HALF_PERIOD := 2.1


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
	# Resting state normally reads as a quiet surface card with a plain divider border.
	# The primary CTA instead carries an accent-tinted fill and a breathing accent
	# border, so a hub screen's one main action is visibly above the secondary cards
	# rather than beside them (design system: one primary action per screen).
	if emphasis:
		normal.fill_color = SURFACE_COLOR.lerp(accent, 0.15)
		normal.border_color = SystemPalette.alpha(accent, 0.75)
		_start_breathing(button, normal, accent)
	else:
		normal.border_color = DIVIDER_COLOR

	# Hover reads as the card lifting toward the viewer: fill warms slightly toward the
	# accent and the shadow grows and drops further (greater implied elevation) — the
	# button looks lit up rather than just outlined.
	var hover := _make(accent, margins, shape)
	hover.border_color = accent
	hover.fill_color = SURFACE_COLOR.lerp(accent, 0.08)
	hover.shadow_size = shape.shadow * 1.25
	hover.shadow_offset = Vector2(0.0, 9.0)

	# Pressed is the opposite move: the card sinks into the surface, so the shadow
	# tightens and pulls in underneath it.
	var pressed := _make(accent, margins, shape)
	pressed.fill_color = SystemPalette.alpha(accent, 0.18)
	pressed.border_color = accent
	pressed.shadow_size = shape.shadow * 0.35
	pressed.shadow_offset = Vector2(0.0, 3.0)

	# Without an explicit disabled box the theme's rounded-rect StyleBoxFlat showed
	# through the moment a button greyed out — so Settings' Swap button (no alternatives
	# for that exercise) and the Training Log's no-data calendar cells changed shape
	# rather than just dimming. Design system: the chamfer is mandatory in every state.
	var disabled := _make(accent, margins, shape)
	disabled.fill_color = SystemPalette.alpha(SURFACE_COLOR, 0.45)
	disabled.border_color = SystemPalette.alpha(DIVIDER_COLOR, 0.5)
	disabled.shadow_size = 0.0

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)


## Loops for as long as the button lives: Node.create_tween() binds the tween to
## `button` and Godot kills it automatically when the button is freed. Re-applying the
## style (e.g. the Lobby CTA re-coloring on day-clear) would otherwise stack a second
## tween driving a StyleBox no one can see anymore, so any previous one is killed first.
static func _start_breathing(button: Button, box: ChamferedStyleBox, accent: Color) -> void:
	# get_meta()'s default-value overload can't tell "no default passed" apart from an
	# explicit null default, so it errors on a missing key either way — has_meta() first
	# sidesteps that instead of relying on the default param.
	if button.has_meta("breathing_tween"):
		var previous: Tween = button.get_meta("breathing_tween")
		previous.kill()

	var tween := button.create_tween()
	tween.set_loops()
	tween.tween_method(Callable(NavButtonStyle, "_set_breath_border").bind(accent, box), BREATH_MIN_BORDER_ALPHA, BREATH_MAX_BORDER_ALPHA, BREATH_HALF_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(Callable(NavButtonStyle, "_set_breath_border").bind(accent, box), BREATH_MAX_BORDER_ALPHA, BREATH_MIN_BORDER_ALPHA, BREATH_HALF_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button.set_meta("breathing_tween", tween)


static func _set_breath_border(value: float, accent: Color, box: ChamferedStyleBox) -> void:
	box.border_color = SystemPalette.alpha(accent, value)
	box.emit_changed()


static func _make(accent: Color, margins: Dictionary, shape: Dictionary) -> ChamferedStyleBox:
	var style := ChamferedStyleBox.new()
	style.border_color = DIVIDER_COLOR
	style.chamfer_size = shape.chamfer
	style.accent_width = 0.0
	style.shadow_size = shape.shadow
	style.content_margin_left = margins.left
	style.content_margin_top = margins.top
	style.content_margin_right = margins.right
	style.content_margin_bottom = margins.bottom
	return style
