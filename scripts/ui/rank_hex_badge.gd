class_name RankHexBadge
extends Control

## Rank hexagon badge (design system v2: rank color applies to rank badge/hexagon
## nodes). Flat hexagon fill with a rank-colored border and centered rank letter.
##
## Lives in scripts/ui/ alongside ChamferedStyleBox and NavButtonStyle rather than
## nested inside one screen's script, so Home and Lobby render the same badge instead
## of each growing its own copy.

var rank_color: Color = Color.WHITE
var rank_letter: String = "E"
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.theme_type_variation = &"HeaderLabel"
	add_child(_label)


func _draw() -> void:
	var points := _hex_points()
	var fill_color := rank_color.darkened(0.75)
	draw_colored_polygon(points, fill_color)

	var border_points := points.duplicate()
	border_points.append(points[0])
	draw_polyline(border_points, rank_color, 4.0, true)

	_label.text = rank_letter
	_label.add_theme_color_override("font_color", rank_color)


func _hex_points() -> PackedVector2Array:
	var center := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 2.0
	var points := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 90.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
