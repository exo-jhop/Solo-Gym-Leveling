extends Control

## Pentagon radar chart for the 5 Hunter stats (spec 4.3). Optionally tappable —
## Stats screen listens to stat_tapped to show a per-stat quest breakdown.
##
## Approved, permanent component (system-design skill v2): scoped specifically to the
## 5-stat display (STR/VIT/AGI/INT/SENSE) on Home and Stats. Rank progression uses its
## own dial + hexagon ladder visualization instead — the two are different data domains,
## not competing options for the same one.

signal stat_tapped(stat_index: int)

## Rajdhani, not the monospace CascadiaCode this used to draw with: the design system
## specifies a geometric display sans for numeric readouts and explicitly rules out
## code-style mono, and every other label in the app already uses it.
const STAT_FONT := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const STAT_LABELS := ["STR", "VIT", "AGI", "INT", "SENSE"]
const RING_COUNT := 4
const LABEL_MARGIN := 64.0
const LABEL_FONT_SIZE := 30

# #00B8FF (v2 primary accent, was #00D9FF)
const GRID_COLOR := Color(0.0, 0.721569, 1.0, 0.2)
# Accent cyan, not violet — design system reserves violet specifically for the Rank-up popup moment.
const FILL_COLOR := Color(0.0, 0.721569, 1.0, 0.25)
const LINE_COLOR := Color(0.0, 0.721569, 1.0, 1.0)
const LABEL_COLOR := Color(0.909804, 0.929412, 0.968627, 1.0)

var _values: Array = [10, 10, 10, 10, 10]
var _tappable: bool = false


func set_values(values: Array) -> void:
	_values = values
	queue_redraw()


## Call once (e.g. from Stats screen _ready) to turn on tap detection. Home's radar
## chart leaves this off since it has no breakdown panel to show.
func set_tappable(tappable: bool) -> void:
	_tappable = tappable
	mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if not _tappable:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var axis_count := STAT_LABELS.size()
	var center := size / 2.0
	var radius: float = min(center.x, center.y) - LABEL_MARGIN
	if radius <= 0.0:
		return

	var to_click: Vector2 = event.position - center
	if to_click.length() > radius + LABEL_MARGIN:
		return  # tap landed outside the chart entirely

	# Whole pie-slice per axis is the tap target, not just the small vertex dot —
	# far more forgiving for a touch screen than a pixel-precise hit test.
	var angle_step := TAU / axis_count
	var angle := to_click.angle() + PI / 2.0  # re-base to match the -PI/2 axis start used in _draw
	angle = wrapf(angle, 0.0, TAU)
	var stat_index := int(round(angle / angle_step)) % axis_count
	stat_tapped.emit(stat_index)


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
		draw_polyline(points, GRID_COLOR, 1.5)

	# axis lines + labels
	var font := STAT_FONT
	var font_size := LABEL_FONT_SIZE
	for i in range(axis_count):
		var angle := -PI / 2.0 + i * angle_step
		var axis_point := center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, axis_point, GRID_COLOR, 1.5)

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
	draw_polyline(closed_points, LINE_COLOR, 3.5, true)
	for p in value_points:
		draw_circle(p, 5.0, LINE_COLOR)
