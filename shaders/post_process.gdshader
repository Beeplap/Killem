shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Cinematic Aberration & Action Shock
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.003;
uniform float action_burst_aberration : hint_range(0.0, 0.08) = 0.0;

// Gritty Industrial Color Grading (Unreal/Gears Palette)
uniform float contrast : hint_range(0.8, 2.0) = 1.26;
uniform float saturation : hint_range(0.0, 1.5) = 0.76;
uniform float crushed_black_level : hint_range(0.0, 0.25) = 0.04;
uniform vec3 shadow_tint : source_color = vec3(0.025, 0.035, 0.05);
uniform vec3 highlight_tint : source_color = vec3(1.05, 1.02, 0.98);

// Vignette & Edge Shadowing
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.42;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.65;

// Dynamic Action: Film Grain & Lens Dirt
uniform float base_grain_intensity : hint_range(0.0, 0.2) = 0.035;
uniform float action_grain_boost : hint_range(0.0, 0.3) = 0.0;
uniform float firing_lens_dirt : hint_range(0.0, 1.0) = 0.0;

// High quality pseudo-random noise for film grain
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float dist_sq = dot(dir, dir);
	
	// Chromatic aberration expands towards edges and pulses on action/explosion
	float ca_strength = (chromatic_aberration + action_burst_aberration) * (dist_sq * 3.2);
	
	float r = texture(screen_texture, uv + dir * ca_strength).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - dir * ca_strength).b;
	vec3 col = vec3(r, g, b);
	
	// Procedural analog film grain
	float grain_rand = hash12(uv * 1280.0 + vec2(TIME * 60.0, TIME * 42.0)) - 0.5;
	float grain_amount = base_grain_intensity + action_grain_boost;
	col += grain_rand * grain_amount;
	
	// Firing / explosion lens dirt and peripheral flash flare
	if (firing_lens_dirt > 0.01) {
		float dirt_pattern = hash12(floor(uv * 320.0));
		float edge_flare = smoothstep(0.2, 0.8, dist_sq * 2.0);
		col += vec3(0.95, 0.75, 0.4) * dirt_pattern * edge_flare * firing_lens_dirt * 0.35;
	}
	
	// Gritty Unreal color grading: Desaturation
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	
	// Crushed blacks & contrast curve
	col = max(vec3(0.0), col - vec3(crushed_black_level));
	col = pow(col, vec3(1.12));
	col = (col - 0.5) * contrast + 0.5;
	col = clamp(col, 0.0, 1.0);
	
	// Industrial cool shadow / warm highlight grading
	col = mix(shadow_tint, highlight_tint, col);
	
	// Cinematic Vignette
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);
	col = mix(col * 0.15, col, mix(1.0, vig, vignette_opacity));
	
	COLOR = vec4(col, 1.0);
}
