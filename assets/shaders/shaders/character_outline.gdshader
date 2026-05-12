shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(0.5, 4.0, 0.5) = 1.5;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.1) {
		vec2 texel = outline_size / vec2(textureSize(TEXTURE, 0));
		float a = texture(TEXTURE, UV + vec2( texel.x,       0.0)).a
		        + texture(TEXTURE, UV + vec2(-texel.x,       0.0)).a
		        + texture(TEXTURE, UV + vec2(      0.0,  texel.y)).a
		        + texture(TEXTURE, UV + vec2(      0.0, -texel.y)).a
		        + texture(TEXTURE, UV + vec2( texel.x,  texel.y)).a
		        + texture(TEXTURE, UV + vec2(-texel.x,  texel.y)).a
		        + texture(TEXTURE, UV + vec2( texel.x, -texel.y)).a
		        + texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).a;
		COLOR = (a > 0.1) ? outline_color : col;
	} else {
		COLOR = col;
	}
}
