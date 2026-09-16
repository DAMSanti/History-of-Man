// El tiempo ENCIMA de las peñas: mojadas y nevadas (GRAFICOS §7.4). Va como
// `material_overlay` de las piedras de `ResourceProps` y `PiedrasDelRio`, así que no toca
// sus materiales: pinta una capa encima.
//
// Lo que decide cuánto moja y dónde cuaja lo calcula `WeatherView` y llega por uniformes:
// lo mojado y la nieve de `ClimaEnPantalla`, y la cota de nieve en metros de `Temporada`,
// la misma que el terreno lee en fracción del relieve. La regla de dónde cuaja es
// `ClimaEnPantalla.cuaja`, y aquí se repite para cada píxel.
shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back;

uniform float mojado : hint_range(0.0, 1.0) = 0.0;
uniform float nieve : hint_range(0.0, 1.0) = 0.0;
uniform float cota_de_nieve_m = 100000.0;

varying vec3 mundo;
varying vec3 normal_mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Ver `ClimaEnPantalla.cuaja`: encima de la cota y en lo que mira hacia arriba.
	float cuaja = nieve * smoothstep(cota_de_nieve_m - 2.0, cota_de_nieve_m + 2.0, mundo.y)
		* smoothstep(0.35, 0.75, normalize(normal_mundo).y);
	float moja = mojado * (1.0 - cuaja);
	if (cuaja + moja < 0.002) {
		discard;
	}
	// Mojada, más oscura y con brillo: una capa oscura y lisa por encima. Nevada, blanca.
	bool nevada = cuaja >= moja * 0.4;
	ALBEDO = nevada ? vec3(0.93, 0.95, 0.98) : vec3(0.02, 0.025, 0.03);
	ALPHA = nevada ? cuaja : moja * 0.38;
	ROUGHNESS = nevada ? 0.85 : 0.18;
	SPECULAR = nevada ? 0.3 : 0.6;
}
