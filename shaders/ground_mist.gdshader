shader_type canvas_item;

// Atmospheric Ground Mist Shader (alpha 0.18, cool white/grey)
uniform vec4 mist_color : source_color = vec4(0.78, 0.82, 0.90, 0.18);
uniform float mist_speed : hint_range(0.005, 0.2) = 0.035;
uniform float mist_scale : hint_range(0.5, 10.0) = 2.5;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 id = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(id);
	float b = hash21(id + vec2(1.0, 0.0));
	float c = hash21(id + vec2(0.0, 1.0));
	float d = hash21(id + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 uv) {
	float v = 0.0;
	float a = 0.5;
	vec2 p = uv;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * mist_scale;
	vec2 motion1 = uv + vec2(TIME * mist_speed, TIME * (mist_speed * 0.35));
	vec2 motion2 = uv - vec2(TIME * (mist_speed * 0.6), -TIME * (mist_speed * 0.25));
	
	float n1 = fbm(motion1);
	float n2 = fbm(motion2);
	float mist_val = smoothstep(0.25, 0.75, (n1 + n2) * 0.5);
	
	COLOR = vec4(mist_color.rgb, mist_color.a * mist_val);
}
