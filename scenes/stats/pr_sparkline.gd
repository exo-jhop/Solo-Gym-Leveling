extends Control

## Per-exercise PR-history line chart for an expanded PR row on the Stats screen.
## Custom _draw(), same approach as radar_chart.gd — no charting addon.

const MARGIN := 10.0
const POINT_RADIUS := 3.0

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

	draw_polyline(poly, _line_color, 2.0)
	for p in poly:
		draw_circle(p, POINT_RADIUS, _line_color)
