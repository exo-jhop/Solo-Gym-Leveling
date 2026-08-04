class_name ChamferedStyleBox
extends StyleBox

## Signature HUD card shape (design system v2): top-right and bottom-left corners cut
## at 45°, top-left and bottom-right stay square, with a colored accent line tracing
## just the two chamfered edges. StyleBoxFlat's corner_radius can only round corners,
## not angle-cut them, so this is a custom StyleBox with its own _draw() instead —
## drop it onto any Panel/PanelContainer via add_theme_stylebox_override("panel", ...)
## exactly like the StyleBoxFlat cards already in home.gd/stats.gd, no new node type
## or scene required at call sites.
##
## Depth pass: the shape alone read as flat because fill was a single solid color with
## a 1px border and nothing separating a card from the surface behind it. Three cheap
## additions give elevation without any generated art — a drop shadow (card sits above
## the background), a vertical fill gradient (implies a light source above), and a
## bloom along the accent edges (the accent reads as emissive rather than painted on).
## All are derived from fill_color/accent_color, so existing call sites keep working
## unchanged and callers that set a translucent fill (see NavButtonStyle's pressed
## state) still get a translucent card.

@export var fill_color: Color = Color(0.0745098, 0.101961, 0.168627, 1.0)  # #131A2B surface
@export var border_color: Color = Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C divider
@export var accent_color: Color = Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF default; pass per card category (gold, success, ...)
@export var chamfer_size: float = 30.0
@export var border_width: float = 1.5
@export var accent_width: float = 5.0

@export_group("Depth")
## Spread of the drop shadow past the card edge. 0 disables the shadow entirely.
@export var shadow_size: float = 14.0
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var shadow_offset: Vector2 = Vector2(0.0, 7.0)
## How far the fill gradient departs from fill_color at the top/bottom edges.
@export_range(0.0, 1.0) var gradient_depth: float = 0.22
## Total alpha of the bloom stacked outside the accent line. 0 disables the bloom.
@export_range(0.0, 1.0) var glow_strength: float = 0.55

const SHADOW_STEPS := 5
const GLOW_LAYERS := 4

# Content margins: use the content_margin_left/top/right/bottom properties StyleBox
# already provides natively (default 0) — do NOT redeclare them, StyleBox's default
# _get_style_margin() reads those directly. PanelContainer cards that already wrap
# their content in a MarginContainer (Home's badges, the HUD test cards) can leave
# these at 0; Buttons have no such wrapper, so callers styling a Button directly
# (see lobby.gd) set content_margin_* explicitly on the instance.


## Godot culls StyleBox drawing to the rect it reports here, so the shadow and the
## accent bloom — both of which spill outside the card rect — need it grown or they
## get clipped at the card edge.
func _get_draw_rect(rect: Rect2) -> Rect2:
	var spill: float = maxf(shadow_size + shadow_offset.length(), accent_width * float(GLOW_LAYERS))
	return rect.grow(spill)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var c: float = min(chamfer_size, min(rect.size.x, rect.size.y) / 2.0)
	var points := _chamfer_points(rect, c)

	_draw_shadow(to_canvas_item, rect)
	_draw_fill(to_canvas_item, rect, points)

	if border_width > 0.0:
		var border_points := points.duplicate()
		border_points.append(points[0])
		var border_colors := PackedColorArray()
		border_colors.resize(border_points.size())
		border_colors.fill(border_color)
		RenderingServer.canvas_item_add_polyline(to_canvas_item, border_points, border_colors, border_width, true)

	_draw_accent(to_canvas_item, points)


## Clockwise from top-left. TL and BR stay square (single vertex); TR and BL each
## get two vertices straddling the 45° cut.
func _chamfer_points(rect: Rect2, c: float) -> PackedVector2Array:
	var top_left := rect.position
	var top_right := Vector2(rect.position.x + rect.size.x, rect.position.y)
	var bottom_right := rect.position + rect.size
	var bottom_left := Vector2(rect.position.x, rect.position.y + rect.size.y)

	return PackedVector2Array([
		top_left,
		top_right - Vector2(c, 0.0),
		top_right + Vector2(0.0, c),
		bottom_right,
		bottom_left + Vector2(c, 0.0),
		bottom_left - Vector2(0.0, c),
	])


## Concentric offset copies of the card shape, each at a fraction of the total alpha.
## Inner layers overlap every outer one, so the accumulation falls off smoothly toward
## the edge without needing a blur pass or a pre-baked shadow texture.
func _draw_shadow(to_canvas_item: RID, rect: Rect2) -> void:
	if shadow_size <= 0.0 or shadow_color.a <= 0.0:
		return

	var layer_color := Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a / float(SHADOW_STEPS))
	for i in range(SHADOW_STEPS, 0, -1):
		var grow: float = shadow_size * float(i) / float(SHADOW_STEPS)
		var shadow_rect := Rect2(rect.position + shadow_offset, rect.size).grow(grow)
		var c: float = min(chamfer_size, min(shadow_rect.size.x, shadow_rect.size.y) / 2.0)
		var shadow_points := _chamfer_points(shadow_rect, c)
		var colors := PackedColorArray()
		colors.resize(shadow_points.size())
		colors.fill(layer_color)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, shadow_points, colors)


## Vertical gradient via per-vertex colors — the shape is convex, so interpolating
## across its triangulation gives a clean top-to-bottom ramp with no extra geometry.
## Both ends derive from fill_color (rather than a second exported color) so a caller
## overriding the fill keeps its alpha and hue, gradient included.
func _draw_fill(to_canvas_item: RID, rect: Rect2, points: PackedVector2Array) -> void:
	var top_color := fill_color.lightened(gradient_depth * 0.5)
	var bottom_color := fill_color.darkened(gradient_depth)

	var fill_colors := PackedColorArray()
	for point in points:
		var t: float = clampf((point.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
		fill_colors.append(top_color.lerp(bottom_color, t))
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, fill_colors)


## The accent traces only the two chamfered edges (design system v2). Stacking wider,
## fainter copies underneath the crisp line fakes an emissive bloom — the accent stops
## looking like a painted stroke and starts looking like it's throwing light.
func _draw_accent(to_canvas_item: RID, points: PackedVector2Array) -> void:
	if accent_width <= 0.0:
		return

	var top_right_cut := PackedVector2Array([points[1], points[2]])
	var bottom_left_cut := PackedVector2Array([points[4], points[5]])

	if glow_strength > 0.0:
		var glow := Color(accent_color.r, accent_color.g, accent_color.b, glow_strength / float(GLOW_LAYERS))
		var glow_colors := PackedColorArray([glow, glow])
		for i in range(GLOW_LAYERS, 0, -1):
			var width: float = accent_width * (1.0 + 1.6 * float(i))
			RenderingServer.canvas_item_add_polyline(to_canvas_item, top_right_cut, glow_colors, width, true)
			RenderingServer.canvas_item_add_polyline(to_canvas_item, bottom_left_cut, glow_colors, width, true)

	var accent_colors := PackedColorArray([accent_color, accent_color])
	RenderingServer.canvas_item_add_polyline(to_canvas_item, top_right_cut, accent_colors, accent_width, true)
	RenderingServer.canvas_item_add_polyline(to_canvas_item, bottom_left_cut, accent_colors, accent_width, true)
