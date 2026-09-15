shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// Lo que en el mapa regional va encima del relieve y tiene que quedar debajo de
// la niebla: el mar y la cinta de la frontera. SISTEMAS §4 y GRAFICOS §3.
//
// El relieve tiene su propia niebla en `triplanar.gdshader`; estas dos cosas son
// mallas aparte y no la leían, así que el mar dibujaba la costa entera por
// encima de la calima y la frontera cruzaba lo que nadie ha visto.
//
// Dos maneras de estar bajo la niebla:
//   - el mar se TAPA: donde no se ha visto, se pinta del color de la calima;
//   - la frontera se BORRA: donde no se ha visto, no se dibuja.

uniform vec4 albedo : source_color = vec4(0.1, 0.2, 0.3, 0.8);
uniform float metallic = 0.0;
uniform float roughness = 1.0;
// Sin luz: la frontera es una línea de lectura, no un material.
uniform bool sin_luz = false;
uniform bool se_borra = false;

uniform sampler2D fog_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 fog_world_size = vec2(1.0, 1.0);
uniform vec3 fog_color : source_color = vec3(0.80, 0.79, 0.74);
// Cuánto se funde el borde, en unidades del mundo. Ver `triplanar.gdshader`.
uniform float fog_blur = 3.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float vista(vec2 xz) {
	vec2 uv = xz / max(fog_world_size, vec2(0.001));
	vec2 d = vec2(fog_blur) / max(fog_world_size, vec2(0.001));
	float suma = texture(fog_tex, uv).r * 2.0;
	suma += texture(fog_tex, uv + vec2(d.x, 0.0)).r;
	suma += texture(fog_tex, uv - vec2(d.x, 0.0)).r;
	suma += texture(fog_tex, uv + vec2(0.0, d.y)).r;
	suma += texture(fog_tex, uv - vec2(0.0, d.y)).r;
	return clamp(suma / 6.0, 0.0, 1.0);
}

void fragment() {
	float visto = vista(world_position.xz);
	if (se_borra) {
		if (visto < 0.5) {
			discard;
		}
		ALBEDO = albedo.rgb;
		ALPHA = albedo.a;
	} else {
		float niebla = 1.0 - visto;
		ALBEDO = mix(albedo.rgb, fog_color, niebla);
		ALPHA = mix(albedo.a, 1.0, niebla);
		ROUGHNESS = mix(roughness, 1.0, niebla);
		METALLIC = mix(metallic, 0.0, niebla);
		SPECULAR = mix(0.5, 0.0, niebla);
	}
	if (sin_luz) {
		EMISSION = ALBEDO;
		ALBEDO = vec3(0.0);
	}
}
