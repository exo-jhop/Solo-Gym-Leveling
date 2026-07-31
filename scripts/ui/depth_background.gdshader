shader_type canvas_item;

// Depth background for the System UI (design system v2).
//
// Every screen previously used a flat #0A0E17 ColorRect, which is the main reason the
// app read as flat: with a uniform backdrop there is no spatial cue telling the eye
// that cards sit *above* anything. This layers four analytic effects over that same
// base color — a vertical lift, an accent bloom behind the header, a faint circuit
// grid, and a corner vignette — so the backdrop has its own near/far reading and the
// card shadows have something to fall onto.
//
// Deliberately all closed-form math: no noise texture, no texture samples, no loops,
// no TIME. That keeps it a handful of ALU ops per pixel on the Mobile renderer and
// means it costs nothing on battery, since a static shader only redraws when the
// screen does.

uniform vec3 base_color : source_color = vec3(0.039, 0.055, 0.090);      // #0A0E17
uniform vec3 accent_color : source_color = vec3(0.0, 0.722, 1.0);        // #00B8FF

// Vertical lift: top of the screen brighter than the bottom, implying the same
// overhead light source the card gradients and top highlights assume.
uniform float lift_strength : hint_range(0.0, 2.0) = 0.85;

// Accent bloom centered on the top edge, behind where every screen puts its header.
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.20;
uniform float bloom_radius : hint_range(0.1, 2.0) = 0.80;

// Circuit grid. Sized in physical pixels via FRAGCOORD so the spacing stays constant
// regardless of how the ColorRect is stretched across the viewport.
uniform float grid_spacing : hint_range(8.0, 256.0) = 72.0;
uniform float grid_opacity : hint_range(0.0, 0.25) = 0.040;
uniform float grid_line_width : hint_range(0.5, 4.0) = 1.0;

// Corner falloff, so the frame edges recede and the center reads as nearest.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 col = base_color;

	// Distance from center, corrected so the vignette stays circular on a tall
	// portrait viewport instead of stretching into an ellipse.
	vec2 centered = UV - vec2(0.5);
	centered.y *= 0.55;
	float radial = length(centered);

	col += base_color * (1.0 - UV.y) * lift_strength;

	vec2 bloom_uv = (UV - vec2(0.5, 0.0)) / bloom_radius;
	col += accent_color * exp(-dot(bloom_uv, bloom_uv) * 3.0) * bloom_strength;

	// Distance to the nearest grid line in both axes, then a smoothstep so the lines
	// antialias instead of shimmering when the panel scrolls.
	vec2 cell = fract(FRAGCOORD.xy / grid_spacing);
	vec2 edge = min(cell, 1.0 - cell) * grid_spacing;
	float line = 1.0 - smoothstep(0.0, grid_line_width, min(edge.x, edge.y));

	// Grid fades toward the edges with the vignette — a grid that stayed uniform
	// would flatten out the depth the vignette is establishing.
	col += accent_color * line * grid_opacity * (1.0 - smoothstep(0.1, 0.7, radial));

	col *= 1.0 - vignette_strength * smoothstep(0.25, 0.72, radial);

	COLOR = vec4(col, 1.0);
}
