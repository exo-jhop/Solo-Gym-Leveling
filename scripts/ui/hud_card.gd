class_name HudCard
extends RefCounted

## Factory for the chamfered System UI card (design system v2), so screens ask for a card
## instead of re-deriving one.
##
## Two things were being duplicated on every screen. First, the StyleBox itself: stats.gd,
## settings.gd, training_log.gd and weekly_summary.gd each built a bare
## `ChamferedStyleBox.new()` (or a local `_make_chamfered_style` helper) and stats.gd then
## hand-tuned a toned-down variant for its PR rows — see row_style() for that same tuning,
## now shared. Second, the padding: each card wrapped its content in a MarginContainer
## purely for inset. ChamferedStyleBox inherits StyleBox's content_margin_* properties and
## PanelContainer honours them, so that wrapper node was never needed — apply() sets them
## on the box and the scene tree loses a level of nesting per card.

## Standard inset for a full-width section card.
const CONTENT_MARGIN := {"left": 30.0, "top": 26.0, "right": 30.0, "bottom": 26.0}
## Tighter inset for a repeated list row, where the standard padding wastes vertical space.
const ROW_MARGIN := {"left": 24.0, "top": 18.0, "right": 24.0, "bottom": 18.0}
## Inset for a KPI tile, which carries a large numeral and needs room around it.
const TILE_MARGIN := {"left": 26.0, "top": 22.0, "right": 26.0, "bottom": 20.0}


## `show_accent` controls the diagonal accent trace/glow along the chamfer cut. It
## defaults on (the design system's signature card look) but Stats and the Training
## Log turn it off on their section containers, per a request that the trace read as
## a stray line on those screens' cards rather than the intentional shape it is
## elsewhere (Home, Weekly Summary, Settings).
static func style(accent: Color = SystemPalette.PRIMARY, margins: Dictionary = CONTENT_MARGIN, show_accent: bool = true) -> ChamferedStyleBox:
	var box := ChamferedStyleBox.new()
	box.accent_color = accent
	box.content_margin_left = margins.left
	box.content_margin_top = margins.top
	box.content_margin_right = margins.right
	box.content_margin_bottom = margins.bottom
	if not show_accent:
		box.accent_width = 0.0
	return box


## Toned-down card for repeated list rows. At full strength the drop shadow and accent
## bloom stack up down a long list and start competing with the content instead of
## framing it, and a 30px chamfer eats a row that's only ~120px tall.
static func row_style(accent: Color = SystemPalette.PRIMARY, margins: Dictionary = ROW_MARGIN, show_accent: bool = true) -> ChamferedStyleBox:
	var box := style(accent, margins, show_accent)
	box.chamfer_size = 18.0
	box.shadow_size = 8.0
	box.shadow_offset = Vector2(0.0, 4.0)
	if show_accent:
		box.accent_width = 3.0
		box.glow_strength = 0.22
	return box


## Styles an existing PanelContainer and hands the box back, since rank-accented cards
## need to recolor it later (accent_color + emit_changed) as the rank changes.
static func apply(panel: PanelContainer, accent: Color = SystemPalette.PRIMARY, margins: Dictionary = CONTENT_MARGIN, show_accent: bool = true) -> ChamferedStyleBox:
	var box := style(accent, margins, show_accent)
	panel.add_theme_stylebox_override("panel", box)
	return box


## Big-number KPI tile: the readout first at display scale, its label underneath in
## secondary text. Used for the metric grids on Weekly Summary and the Training Log's
## month rollup, where four short numbers say more than four full sentences did.
static func metric_tile(caption: String, value: String, accent: Color = SystemPalette.PRIMARY, show_accent: bool = true) -> PanelContainer:
	var tile := PanelContainer.new()
	apply(tile, accent, TILE_MARGIN, show_accent)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)

	var value_label := Label.new()
	value_label.theme_type_variation = &"HeaderLabel"
	value_label.add_theme_font_size_override("font_size", 52)
	value_label.add_theme_color_override("font_color", accent)
	value_label.text = value
	box.add_child(value_label)

	var caption_label := Label.new()
	caption_label.theme_type_variation = &"SecondaryLabel"
	caption_label.add_theme_font_size_override("font_size", 24)
	caption_label.text = caption
	box.add_child(caption_label)

	return tile
