extends Control

## Radial rank dial (design system v2, rank visualization 1): the current rank's hexagon at
## the center, a circular gauge tracing progress toward the next rank around it, and every
## rank placed as a hexagon node at a compass point — earned ones lit, the rest dimmed.
##
## Replaces the bare ProgressBar + "XP 0 / 500 to next rank" line the Stats screen used for
## rank progression, which showed the same number twice and carried none of the rank
## system's visual language.
##
## Custom _draw() rather than a ProgressBar plus sprites, same approach as radar_chart.gd:
## the project ships no chart addon and no art for this, and the whole component is a
## handful of arcs and hexagons over the control's own rect. Rank data is passed in (see
## set_state) instead of read off GameManager, so this stays a renderer with no autoload
## dependency — again matching radar_chart.gd.

const DISPLAY_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const TRACK_WIDTH := 14.0
const NODE_RADIUS := 34.0
const CURRENT_NODE_SCALE := 1.25
const GLOW_LAYERS := 3
const ARC_SEGMENTS := 96

var _nodes: Array = []  # [{"letter": String, "color": Color}], lowest rank first
var _current_index: int = 0
var _progress: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `nodes` is the whole rank ladder as [{"letter", "color"}], lowest rank first.
## `progress` is 0..1 toward the next rank — pass 1.0 at the top rank, which has
## nothing left to fill.
func set_state(nodes: Array, current_index: int, progress: float) -> void:
	_nodes = nodes
	_current_index = clampi(current_index, 0, maxi(nodes.size() - 1, 0))
	_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()


## How far around the ladder the Hunter stands, 0..1 — the current rank's position plus the
## within-rank progress toward the next one. Exposed so the "SYNC STATUS: n%" readout beside
## the dial quotes exactly what the gauge draws.
func ladder_fraction() -> float:
	if _nodes.is_empty():
		return 0.0
	return (float(_current_index) + _progress) / float(_nodes.size())


func _draw() -> void:
	if _nodes.is_empty():
		return

	var center := size / 2.0
	var radius: float = minf(center.x, center.y) - NODE_RADIUS * CURRENT_NODE_SCALE - 8.0
	if radius <= 0.0:
		return

	var accent: Color = _nodes[_current_index].color

	draw_arc(center, radius, 0.0, TAU, ARC_SEGMENTS, SystemPalette.DIVIDER, TRACK_WIDTH, true)

	# The gauge fills along the same ring the rank nodes sit on, so its head always lands at
	# (or just past) the current rank's hexagon. Filling it with the within-rank fraction
	# instead put the arc head near D while the center hex read B — the two halves of the
	# component were measuring different things.
	var filled := ladder_fraction()
	if filled > 0.0:
		var start := -PI / 2.0
		var end := start + TAU * filled
		var segments: int = maxi(int(ARC_SEGMENTS * filled), 2)
		# Same fake-bloom trick ChamferedStyleBox uses on its accent line — wider, fainter
		# copies stacked under the crisp arc, so the gauge reads as emissive rather than
		# painted on, without a blur pass or a pre-baked glow texture.
		var glow := SystemPalette.alpha(accent, 0.5 / float(GLOW_LAYERS))
		for i in range(GLOW_LAYERS, 0, -1):
			draw_arc(center, radius, start, end, segments, glow, TRACK_WIDTH * (1.0 + 1.1 * float(i)), true)
		draw_arc(center, radius, start, end, segments, accent, TRACK_WIDTH, true)

	_draw_ladder(center, radius)
	_draw_center_hex(center, radius * 0.42, accent)


## Ranks already earned stay lit in their own tier color; the rest drop to a dim trace, so
## the ladder shows how far there is left to climb without competing with the current rank.
func _draw_ladder(center: Vector2, radius: float) -> void:
	var step := TAU / float(_nodes.size())
	for i in range(_nodes.size()):
		var angle := -PI / 2.0 + step * float(i)
		var at := center + Vector2(cos(angle), sin(angle)) * radius
		var node_color: Color = _nodes[i].color
		var reached: bool = i <= _current_index
		var is_current: bool = i == _current_index
		var node_radius: float = NODE_RADIUS * (CURRENT_NODE_SCALE if is_current else 1.0)
		var points := _hex(at, node_radius)

		if reached:
			draw_colored_polygon(points, node_color.darkened(0.7))
		else:
			draw_colored_polygon(points, SystemPalette.alpha(SystemPalette.SURFACE, 0.85))

		var edge_color: Color = node_color if reached else SystemPalette.alpha(node_color, 0.3)
		draw_polyline(_closed(points), edge_color, 4.0 if is_current else 2.5, true)

		var letter_color: Color = node_color if reached else SystemPalette.alpha(node_color, 0.45)
		_draw_centered_text(String(_nodes[i].letter), at, int(node_radius * 0.9), letter_color)


func _draw_center_hex(center: Vector2, radius: float, accent: Color) -> void:
	var points := _hex(center, radius)
	draw_colored_polygon(points, accent.darkened(0.78))
	var glow := SystemPalette.alpha(accent, 0.5 / float(GLOW_LAYERS))
	for i in range(GLOW_LAYERS, 0, -1):
		draw_polyline(_closed(points), glow, 5.0 * (1.0 + 1.1 * float(i)), true)
	draw_polyline(_closed(points), accent, 5.0, true)
	_draw_centered_text(String(_nodes[_current_index].letter), center, int(radius * 0.95), accent)


## draw_string() anchors at the text baseline, so centering needs the ascent added back —
## passing the raw center lands the glyph roughly half a line too low.
func _draw_centered_text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var text_size := DISPLAY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := at + Vector2(-text_size.x / 2.0, -text_size.y / 2.0 + DISPLAY_FONT.get_ascent(font_size))
	draw_string(DISPLAY_FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _hex(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * float(i) - 90.0)
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop := points.duplicate()
	loop.append(points[0])
	return loop
