class_name ChamferedStyleBox
extends StyleBox

## Signature HUD card shape (design system v2): top-right and bottom-left corners cut
## at 45°, top-left and bottom-right stay square, with a colored accent line tracing
## just the two chamfered edges. StyleBoxFlat's corner_radius can only round corners,
## not angle-cut them, so this is a custom StyleBox with its own _draw() instead —
## drop it onto any Panel/PanelContainer via add_theme_stylebox_override("panel", ...)
## exactly like the StyleBoxFlat cards already in home.gd/stats.gd, no new node type
## or scene required at call sites.

@export var fill_color: Color = Color(0.0745098, 0.101961, 0.168627, 1.0)  # #131A2B surface
@export var border_color: Color = Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C divider
@export var accent_color: Color = Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF default; pass per card category (gold, success, ...)
@export var chamfer_size: float = 30.0
@export var border_width: float = 1.5
@export var accent_width: float = 5.0

# Content margins: use the content_margin_left/top/right/bottom properties StyleBox
# already provides natively (default 0) — do NOT redeclare them, StyleBox's default
# _get_style_margin() reads those directly. PanelContainer cards that already wrap
# their content in a MarginContainer (Home's badges, the HUD test cards) can leave
# these at 0; Buttons have no such wrapper, so callers styling a Button directly
# (see lobby.gd) set content_margin_* explicitly on the instance.


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var c: float = min(chamfer_size, min(rect.size.x, rect.size.y) / 2.0)

	var top_left := rect.position
	var top_right := Vector2(rect.position.x + rect.size.x, rect.position.y)
	var bottom_right := rect.position + rect.size
	var bottom_left := Vector2(rect.position.x, rect.position.y + rect.size.y)

	# Clockwise from top-left. TL and BR stay square (single vertex); TR and BL each
	# get two vertices straddling the 45° cut.
	var points := PackedVector2Array([
		top_left,
		top_right - Vector2(c, 0.0),
		top_right + Vector2(0.0, c),
		bottom_right,
		bottom_left + Vector2(c, 0.0),
		bottom_left - Vector2(0.0, c),
	])

	var fill_colors := PackedColorArray()
	fill_colors.resize(points.size())
	fill_colors.fill(fill_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, fill_colors)

	if border_width > 0.0:
		var border_points := points.duplicate()
		border_points.append(points[0])
		var border_colors := PackedColorArray()
		border_colors.resize(border_points.size())
		border_colors.fill(border_color)
		RenderingServer.canvas_item_add_polyline(to_canvas_item, border_points, border_colors, border_width, true)

	if accent_width > 0.0:
		var top_right_cut := PackedVector2Array([points[1], points[2]])
		var bottom_left_cut := PackedVector2Array([points[4], points[5]])
		var accent_colors := PackedColorArray([accent_color, accent_color])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, top_right_cut, accent_colors, accent_width, true)
		RenderingServer.canvas_item_add_polyline(to_canvas_item, bottom_left_cut, accent_colors, accent_width, true)
