shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 14번 줄에 정의된 함수 이름과 똑같이 써야 합니다.
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    if (intensity > 0.0) {
        // [수정] randon -> random 으로 변경
        uv.x += (random(vec2(TIME, uv.y)) - 0.5) * 0.02 * intensity;
    }
    COLOR = texture(SCREEN_TEXTURE, uv);
}