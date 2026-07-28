extends Control

## Pentagon radar chart for the 5 Hunter stats (spec 4.3).

const STAT_FONT := preload("res://assets/fonts/CascadiaCode.ttf")

const STAT_LABELS := ["STR", "VIT", "AGI", "INT", "SENSE"]
const RING_COUNT := 4
const LABEL_MARGIN := 36.0
const LABEL_FONT_SIZE := 16

const GRID_COLOR := Color(0.239, 0.545, 1.0, 0.2)
const FILL_COLOR := Color(0.545, 0.361, 0.965, 0.3)
const LINE_COLOR := Color(0.239, 0.545, 1.0, 1.0)
const LABEL_COLOR := Color(0.906, 0.925, 0.98, 1.0)

var _values: Array = [10, 10, 10, 10, 10]


func set_values(values: Array) -> void:
	_values = values
	queue_redraw()


func _draw() -> void:
	var axis_count := STAT_LABELS.size()
	var center := size / 2.0
	var radius: float = min(center.x, center.y) - LABEL_MARGIN
	if radius <= 0.0:
		return
	var angle_step := TAU / axis_count

	var scale_max: float = 20.0
	for v in _values:
		scale_max = max(scale_max, float(v) * 1.1)

	# grid rings
	for ring in range(1, RING_COUNT + 1):
		var ring_radius := radius * ring / RING_COUNT
		var points := PackedVector2Array()
		for i in range(axis_count):
			var angle := -PI / 2.0 + i * angle_step
			points.append(center + Vector2(cos(angle), sin(angle)) * ring_radius)
		points.append(points[0])
		draw_polyline(points, GRID_COLOR, 1.0)

	# axis lines + labels
	var font := STAT_FONT
	var font_size := LABEL_FONT_SIZE
	for i in range(axis_count):
		var angle := -PI / 2.0 + i * angle_step
		var axis_point := center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, axis_point, GRID_COLOR, 1.0)

		var label_point := center + Vector2(cos(angle), sin(angle)) * (radius + LABEL_MARGIN * 0.6)
		var label_text := "%s %d" % [STAT_LABELS[i], _values[i]]
		var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, label_point - text_size / 2.0, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, LABEL_COLOR)

	# value polygon
	var value_points := PackedVector2Array()
	for i in range(axis_count):
		var angle := -PI / 2.0 + i * angle_step
		var fraction: float = clamp(float(_values[i]) / scale_max, 0.0, 1.0)
		value_points.append(center + Vector2(cos(angle), sin(angle)) * radius * fraction)

	draw_colored_polygon(value_points, FILL_COLOR)
	var closed_points := value_points.duplicate()
	closed_points.append(value_points[0])
	draw_polyline(closed_points, LINE_COLOR, 2.0)
	for p in value_points:
		draw_circle(p, 3.0, LINE_COLOR)
