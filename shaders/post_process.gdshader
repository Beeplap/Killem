shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.38;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float contrast : hint_range(0.5, 2.0) = 1.15; // +15% contrast boost
uniform vec3 cool_tint : source_color = vec3(0.92, 0.96, 1.05); // faint cool-blue night grading

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	
	// Apply +15% contrast boost
	c.rgb = ((c.rgb - 0.5) * contrast) + 0.5;
	
	// Apply faint cool-blue night color grade
	c.rgb = c.rgb * cool_tint;
	
	// Vignette calculation
	vec2 uv = SCREEN_UV * (1.0 - SCREEN_UV.yx);
	float vig = uv.x * uv.y * 15.0;
	vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);
	c.rgb = mix(c.rgb * 0.18, c.rgb, mix(1.0, vig, vignette_opacity));
	
	COLOR = vec4(c.rgb, 1.0);
}
