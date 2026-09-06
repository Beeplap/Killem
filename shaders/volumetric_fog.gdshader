shader_type canvas_item;

uniform float ray_speed : hint_range(0.01, 0.5) = 0.06;
uniform float ray_density : hint_range(5.0, 30.0) = 13.5;
uniform float ray_angle : hint_range(-1.57, 1.57) = -0.52;
uniform float fog_speed : hint_range(0.01, 0.3) = 0.035;
uniform float fog_density : hint_range(0.5, 4.0) = 1.7;
uniform float overall_opacity : hint_range(0.0, 1.0) = 0.08;

uniform vec4 ray_color : source_color = vec4(0.85, 0.90, 0.98, 0.32);
uniform vec4 fog_color : source_color = vec4(0.60, 0.65, 0.72, 0.18);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float smooth_noise(vec2 p) {
	vec2 id = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float bl = hash21(id);
	float br = hash21(id + vec2(1.0, 0.0));
	float tl = hash21(id + vec2(0.0, 1.0));
	float tr = hash21(id + vec2(1.0, 1.0));
	
	return mix(mix(bl, br, f.x), mix(tl, tr, f.x), f.y);
}

float fbm_fog(vec2 uv) {
	float val = 0.0;
	float amp = 0.5;
	vec2 p = uv;
	for (int i = 0; i < 3; i++) {
		val += amp * smooth_noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Coordinate rotation for directional god-ray shafts
	float ca = cos(ray_angle);
	float sa = sin(ray_angle);
	vec2 rot_uv = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca);
	
	// Dual-frequency god-ray shafts cutting through the sector
	float ray1 = sin(rot_uv.x * ray_density + TIME * ray_speed * 1.8) * 0.5 + 0.5;
	float ray2 = sin(rot_uv.x * (ray_density * 2.1) - TIME * ray_speed * 1.1) * 0.5 + 0.5;
	float rays = pow(ray1 * 0.65 + ray2 * 0.35, 2.6);
	
	// Atmospheric drifting mist across the railway yard
	vec2 drift1 = uv * fog_density + vec2(TIME * fog_speed, TIME * (fog_speed * 0.4));
	vec2 drift2 = uv * (fog_density * 1.6) - vec2(TIME * (fog_speed * 0.7), -TIME * (fog_speed * 0.3));
	float fog = fbm_fog(drift1) * 0.6 + fbm_fog(drift2) * 0.4;
	fog = smoothstep(0.35, 0.75, fog);
	
	// Composite volumetric rays + drifting fog
	vec4 comp = (ray_color * rays * 0.75) + (fog_color * fog * 0.55);
	comp.a *= overall_opacity;
	
	COLOR = comp;
}
