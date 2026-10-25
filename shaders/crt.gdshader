shader_type spatial;
render_mode unshaded, cull_back;

// Placeholder CRT tube: samples a SubViewport texture and adds barrel
// curvature, scanlines, vignette, glass sheen and a faint flicker.
uniform sampler2D screen_tex : source_color, filter_linear;
uniform float brightness = 1.5;
uniform float curvature = 0.06;
uniform float scanlines = 120.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv *= 1.0 + curvature * dot(uv.yx, uv.yx);
	vec2 suv = uv * 0.5 + 0.5;
	float inside = step(0.0, suv.x) * step(suv.x, 1.0) * step(0.0, suv.y) * step(suv.y, 1.0);

	vec3 c = texture(screen_tex, suv).rgb;
	float scan = 0.8 + 0.2 * sin(suv.y * scanlines * 6.2831853);
	float flicker = 0.985 + 0.015 * sin(TIME * 53.0);
	float vignette = smoothstep(1.45, 0.45, length(uv * vec2(0.85, 1.0)));

	vec3 phosphor_floor = vec3(0.012, 0.03, 0.018);
	c = (c * scan * brightness * flicker + phosphor_floor) * vignette * inside;

	// Soft reflection band across the curved glass.
	float sheen = smoothstep(0.35, 0.0, abs(UV.y + UV.x * 0.35 - 0.38)) * 0.035;
	ALBEDO = c + vec3(sheen);
}
