class_name HudGlyph
extends Control

## Procedural line-art icons for the System UI (design system v2).
##
## The project ships no icon set, and the design system explicitly bars emoji as
## structural icons — so rather than pull in a raster icon pack, each glyph is a handful
## of draw calls over a normalized 0..1 design space, the same approach home.gd already
## uses for its avatar silhouette. That keeps icons resolution-independent on the Mobile
## renderer, costs no texture memory, and lets one node recolor to any accent (rank
## color, success green, warning orange) without a per-tint asset variant.
##
## Drop one into any Control as a child and give the slot a size; glyphs ignore mouse
## input so they can sit on top of a Button without swallowing its presses.

enum Shape {
	QUESTS,  ## chamfered checkbox + tick — today's quest list
	STATS,  ## bar chart — the five-stat screen
	CALENDAR,  ## day grid — training log
	TREND,  ## rising line + endpoint — weekly summary
	GEAR,  ## toothed ring — settings
	FLAME,  ## filled flame — streak
	ALERT,  ## warning triangle — reminder banner
	CHEVRON_UP,  ## collapse an expanded row
	CHEVRON_DOWN,  ## expand a row (PR history)
	CHEVRON_LEFT,  ## previous month
	CHEVRON_RIGHT,  ## next month
	CHECK,  ## completed quest in a read-only history row
	CIRCLE,  ## incomplete quest in a read-only history row
	TROPHY,  ## personal records
	PLUS,  ## add an exercise
	CLOSE,  ## remove an exercise
	SWAP,  ## swap an exercise for a same-muscle alternative
	PROFILE,  ## head + shoulders — Hunter profile section
	DROP,  ## droplet — nutrition/supplement section
	DUMBBELL,  ## training program section
}

@export var shape: Shape = Shape.QUESTS:
	set(value):
		shape = value
		queue_redraw()

@export var color: Color = Color(0.0, 0.721569, 1.0, 1.0):  # #00B8FF primary accent
	set(value):
		color = value
		queue_redraw()

## Stroke weight as a fraction of the glyph box rather than a pixel value, so line
## weight stays proportional whether the slot is a 34px streak icon or a 56px nav icon.
@export_range(0.02, 0.2) var stroke_ratio: float = 0.085

# Glyphs are laid out in a centered square inside the control, so a non-square slot
# letterboxes the icon instead of skewing it.
var _box_origin: Vector2
var _box_size: float


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_box_size = minf(size.x, size.y)
	_box_origin = (size - Vector2(_box_size, _box_size)) / 2.0
	var w: float = _box_size * stroke_ratio

	match shape:
		Shape.QUESTS:
			_draw_quests(w)
		Shape.STATS:
			_draw_stats(w)
		Shape.CALENDAR:
			_draw_calendar(w)
		Shape.TREND:
			_draw_trend(w)
		Shape.GEAR:
			_draw_gear(w)
		Shape.FLAME:
			_draw_flame()
		Shape.ALERT:
			_draw_alert(w)
		Shape.CHEVRON_UP:
			_draw_chevron(w, Vector2(0.22, 0.64), Vector2(0.50, 0.36), Vector2(0.78, 0.64))
		Shape.CHEVRON_DOWN:
			_draw_chevron(w, Vector2(0.22, 0.36), Vector2(0.50, 0.64), Vector2(0.78, 0.36))
		Shape.CHEVRON_LEFT:
			_draw_chevron(w, Vector2(0.64, 0.20), Vector2(0.34, 0.50), Vector2(0.64, 0.80))
		Shape.CHEVRON_RIGHT:
			_draw_chevron(w, Vector2(0.36, 0.20), Vector2(0.66, 0.50), Vector2(0.36, 0.80))
		Shape.CHECK:
			_draw_check(w)
		Shape.CIRCLE:
			_draw_circle_glyph(w)
		Shape.TROPHY:
			_draw_trophy(w)
		Shape.PLUS:
			_draw_plus(w)
		Shape.CLOSE:
			_draw_close(w)
		Shape.SWAP:
			_draw_swap(w)
		Shape.PROFILE:
			_draw_profile(w)
		Shape.DROP:
			_draw_drop(w)
		Shape.DUMBBELL:
			_draw_dumbbell(w)


## Unit-space point (0..1 on both axes) to a canvas position inside the glyph box.
func _u(x: float, y: float) -> Vector2:
	return _box_origin + Vector2(x, y) * _box_size


func _stroke(points: Array, width: float, closed: bool = false) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(_u(point.x, point.y))
	if closed:
		packed.append(packed[0])
	draw_polyline(packed, color, width, true)


## Box with the top-right corner cut at 45°, echoing the chamfered card shape the whole
## design system is built on — so the primary CTA's icon reads as part of the same kit.
func _draw_quests(w: float) -> void:
	_stroke([
		Vector2(0.08, 0.10), Vector2(0.70, 0.10), Vector2(0.90, 0.30),
		Vector2(0.90, 0.90), Vector2(0.08, 0.90),
	], w, true)
	_stroke([Vector2(0.28, 0.50), Vector2(0.43, 0.68), Vector2(0.72, 0.32)], w)


func _draw_stats(w: float) -> void:
	const BARS := [Vector2(0.22, 0.56), Vector2(0.50, 0.22), Vector2(0.78, 0.40)]
	for bar in BARS:
		draw_line(_u(bar.x, 0.88), _u(bar.x, bar.y), color, w * 1.7, true)
	draw_line(_u(0.06, 0.96), _u(0.94, 0.96), Color(color, color.a * 0.45), w * 0.8, true)


func _draw_calendar(w: float) -> void:
	_stroke([
		Vector2(0.08, 0.20), Vector2(0.92, 0.20), Vector2(0.92, 0.94), Vector2(0.08, 0.94),
	], w, true)
	draw_line(_u(0.08, 0.42), _u(0.92, 0.42), color, w, true)
	draw_line(_u(0.30, 0.06), _u(0.30, 0.28), color, w, true)
	draw_line(_u(0.70, 0.06), _u(0.70, 0.28), color, w, true)
	for x in [0.28, 0.50, 0.72]:
		draw_circle(_u(x, 0.70), _box_size * 0.055, color)


func _draw_trend(w: float) -> void:
	_stroke([
		Vector2(0.08, 0.78), Vector2(0.34, 0.48), Vector2(0.56, 0.63), Vector2(0.88, 0.22),
	], w)
	draw_circle(_u(0.88, 0.22), _box_size * 0.09, color)


func _draw_gear(w: float) -> void:
	var center := _u(0.5, 0.5)
	draw_arc(center, _box_size * 0.27, 0.0, TAU, 32, color, w, true)
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		draw_line(center + direction * _box_size * 0.29, center + direction * _box_size * 0.44, color, w, true)


## Filled rather than outlined: the streak flame sits at pill size next to a big numeral,
## where a hairline outline would disappear. The lighter inner core keeps it readable as
## a flame instead of a blob at small sizes.
func _draw_flame() -> void:
	const OUTER := [
		Vector2(0.50, 0.02), Vector2(0.70, 0.26), Vector2(0.67, 0.44), Vector2(0.84, 0.58),
		Vector2(0.74, 0.86), Vector2(0.50, 0.98), Vector2(0.26, 0.86), Vector2(0.16, 0.58),
		Vector2(0.33, 0.40), Vector2(0.35, 0.16),
	]
	const CORE := [
		Vector2(0.50, 0.42), Vector2(0.63, 0.60), Vector2(0.61, 0.78),
		Vector2(0.50, 0.92), Vector2(0.39, 0.78), Vector2(0.37, 0.60),
	]
	draw_colored_polygon(_polygon(OUTER), color)
	draw_colored_polygon(_polygon(CORE), color.lightened(0.45))


func _draw_alert(w: float) -> void:
	_stroke([Vector2(0.50, 0.08), Vector2(0.95, 0.88), Vector2(0.05, 0.88)], w, true)
	draw_line(_u(0.50, 0.36), _u(0.50, 0.60), color, w, true)
	draw_circle(_u(0.50, 0.74), _box_size * 0.055, color)


## Directional chevrons for month paging and expand/collapse rows. Drawn slightly heavier
## than the line-art icons because they sit alone inside a small square button, where a
## hairline stroke reads as an artifact rather than an affordance.
func _draw_chevron(w: float, from: Vector2, tip: Vector2, to: Vector2) -> void:
	_stroke([from, tip, to], w * 1.5)


func _draw_check(w: float) -> void:
	_stroke([Vector2(0.16, 0.52), Vector2(0.40, 0.78), Vector2(0.84, 0.24)], w * 1.6)


func _draw_circle_glyph(w: float) -> void:
	draw_arc(_u(0.5, 0.5), _box_size * 0.32, 0.0, TAU, 28, color, w * 1.2, true)


func _draw_trophy(w: float) -> void:
	_stroke([
		Vector2(0.28, 0.10), Vector2(0.72, 0.10), Vector2(0.70, 0.42),
		Vector2(0.60, 0.56), Vector2(0.40, 0.56), Vector2(0.30, 0.42),
	], w, true)
	# Side handles, drawn as open strokes off the cup's upper corners.
	_stroke([Vector2(0.28, 0.16), Vector2(0.13, 0.22), Vector2(0.18, 0.36), Vector2(0.30, 0.40)], w)
	_stroke([Vector2(0.72, 0.16), Vector2(0.87, 0.22), Vector2(0.82, 0.36), Vector2(0.70, 0.40)], w)
	draw_line(_u(0.50, 0.56), _u(0.50, 0.78), color, w * 1.4, true)
	draw_line(_u(0.30, 0.90), _u(0.70, 0.90), color, w * 1.8, true)
	draw_line(_u(0.38, 0.78), _u(0.62, 0.78), color, w * 1.4, true)


func _draw_plus(w: float) -> void:
	draw_line(_u(0.50, 0.16), _u(0.50, 0.84), color, w * 1.5, true)
	draw_line(_u(0.16, 0.50), _u(0.84, 0.50), color, w * 1.5, true)


func _draw_close(w: float) -> void:
	draw_line(_u(0.22, 0.22), _u(0.78, 0.78), color, w * 1.5, true)
	draw_line(_u(0.78, 0.22), _u(0.22, 0.78), color, w * 1.5, true)


## Two opposed arrows — the exercise-swap action replaces one lift with another rather
## than reordering, so the icon reads as exchange, not as move.
func _draw_swap(w: float) -> void:
	draw_line(_u(0.14, 0.34), _u(0.84, 0.34), color, w, true)
	_stroke([Vector2(0.68, 0.19), Vector2(0.85, 0.34), Vector2(0.68, 0.49)], w)
	draw_line(_u(0.86, 0.66), _u(0.16, 0.66), color, w, true)
	_stroke([Vector2(0.32, 0.51), Vector2(0.15, 0.66), Vector2(0.32, 0.81)], w)


func _draw_profile(w: float) -> void:
	draw_arc(_u(0.5, 0.30), _box_size * 0.17, 0.0, TAU, 28, color, w, true)
	_stroke([
		Vector2(0.14, 0.92), Vector2(0.17, 0.72), Vector2(0.32, 0.60),
		Vector2(0.68, 0.60), Vector2(0.83, 0.72), Vector2(0.86, 0.92),
	], w)


func _draw_drop(w: float) -> void:
	_stroke([
		Vector2(0.50, 0.06), Vector2(0.70, 0.38), Vector2(0.78, 0.58), Vector2(0.72, 0.80),
		Vector2(0.50, 0.92), Vector2(0.28, 0.80), Vector2(0.22, 0.58), Vector2(0.30, 0.38),
	], w, true)


func _draw_dumbbell(w: float) -> void:
	draw_line(_u(0.30, 0.50), _u(0.70, 0.50), color, w * 1.5, true)
	for x in [0.25, 0.75]:
		draw_line(_u(x, 0.26), _u(x, 0.74), color, w * 2.2, true)
	for x in [0.12, 0.88]:
		draw_line(_u(x, 0.36), _u(x, 0.64), color, w * 1.8, true)


func _polygon(points: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(_u(point.x, point.y))
	return packed
