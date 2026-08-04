extends Control

## Per-exercise PR-history line chart for an expanded PR row on the Stats screen.
## Custom _draw(), same approach as radar_chart.gd — no charting addon.

const MARGIN := 10.0
const POINT_RADIUS := 5.0
const LINE_WIDTH := 3.0
## Peak alpha of the area fill directly under the curve, ramping to 0 at the baseline.
const AREA_ALPHA := 0.28

var _points: Array = []  # Array of {"date": String, "value": float}, chronological
var _line_color: Color = Color(0.0, 0.85098, 1.0, 1.0)


## Trend color (green/orange) is decided by the caller — stats.gd knows the
## "sessions since last PR" logic, this control just draws whatever color it's given.
func set_data(points: Array, line_color: Color) -> void:
	_points = points
	_line_color = line_color
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return

	var min_v: float = _points[0].get("value", 0.0)
	var max_v: float = min_v
	for p in _points:
		var v: float = p.get("value", 0.0)
		min_v = min(min_v, v)
		max_v = max(max_v, v)
	if is_equal_approx(max_v, min_v):
		max_v += 1.0

	var w: float = size.x - MARGIN * 2.0
	var h: float = size.y - MARGIN * 2.0
	if w <= 0.0 or h <= 0.0:
		return

	var step: float = w / float(_points.size() - 1)
	var poly := PackedVector2Array()
	for i in range(_points.size()):
		var t: float = (float(_points[i].get("value", 0.0)) - min_v) / (max_v - min_v)
		var x: float = MARGIN + step * i
		var y: float = MARGIN + h * (1.0 - t)
		poly.append(Vector2(x, y))

	_draw_area(poly)
	draw_polyline(poly, _line_color, LINE_WIDTH, true)
	# Visible dot markers: the design system asks for them specifically in Stats contexts
	# (each point here is one real new-best moment, not a sample of a continuous series).
	for p in poly:
		draw_circle(p, POINT_RADIUS, _line_color)


## Gradient area under the curve, fading to transparent toward the X-axis (design system:
## line charts carry a filled gradient area in the accent color). Per-vertex alpha on a
## single polygon, so it costs no extra geometry beyond closing the shape along the baseline.
func _draw_area(poly: PackedVector2Array) -> void:
	var baseline: float = size.y - MARGIN
	var area := poly.duplicate()
	area.append(Vector2(poly[poly.size() - 1].x, baseline))
	area.append(Vector2(poly[0].x, baseline))

	var colors := PackedColorArray()
	for point in area:
		var depth: float = clampf((baseline - point.y) / maxf(size.y - MARGIN * 2.0, 1.0), 0.0, 1.0)
		colors.append(Color(_line_color.r, _line_color.g, _line_color.b, AREA_ALPHA * depth))
	draw_polygon(area, colors)
