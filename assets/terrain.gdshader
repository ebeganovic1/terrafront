shader_type canvas_item;
render_mode unshaded;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = smoothstep(0.0, 1.0, fract(point));
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	vec2 cells = UV / TEXTURE_PIXEL_SIZE;
	vec2 offset = vec2(noise(cells * 2.0), noise(cells * 2.0 + 90.0)) - 0.5;
	vec3 terrain = texture(TEXTURE, UV + offset * TEXTURE_PIXEL_SIZE * 0.5).rgb;
	float grain = (noise(cells * 7.0) - 0.5) * 0.035;
	COLOR = vec4(terrain + grain, 1.0);
}
