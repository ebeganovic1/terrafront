shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 point = UV / TEXTURE_PIXEL_SIZE - 0.5;
	vec2 cell = floor(point);
	vec2 blend = smoothstep(vec2(0.18), vec2(0.82), fract(point));
	vec2 lower = TEXTURE_PIXEL_SIZE * 0.5;
	vec2 upper = vec2(1.0) - lower;
	vec3 top_left = texture(TEXTURE, clamp((cell + vec2(0.5, 0.5)) * TEXTURE_PIXEL_SIZE, lower, upper)).rgb;
	vec3 top_right = texture(TEXTURE, clamp((cell + vec2(1.5, 0.5)) * TEXTURE_PIXEL_SIZE, lower, upper)).rgb;
	vec3 bottom_left = texture(TEXTURE, clamp((cell + vec2(0.5, 1.5)) * TEXTURE_PIXEL_SIZE, lower, upper)).rgb;
	vec3 bottom_right = texture(TEXTURE, clamp((cell + vec2(1.5, 1.5)) * TEXTURE_PIXEL_SIZE, lower, upper)).rgb;
	COLOR = vec4(mix(mix(top_left, top_right, blend.x), mix(bottom_left, bottom_right, blend.x), blend.y), 1.0);
}
