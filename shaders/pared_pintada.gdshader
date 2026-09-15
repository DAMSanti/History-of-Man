shader_type spatial;
// La pared del fondo, con lo que hay pintado. SISTEMAS §13 y GRAFICOS §7.2.
//
// La pintura NO va pegada encima como una pegatina: tiñe la roca. El pigmento se
// multiplica sobre el color de la caliza —el ocre se empapa en la piedra, y donde
// la roca es más clara la figura se lee más—, con un grano que deja poros sin
// pigmento. Como la malla lleva el relieve, la luz de la lámpara hace el resto: la
// figura se curva con el bulto sobre el que se pintó.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D roca : source_color, filter_linear_mipmap, repeat_enable;
// Metros que cubre una lámina de la textura de roca.
uniform float roca_m = 2.6;
// RGB: el pigmento. A: cuánto cubre.
uniform sampler2D pinturas : source_color, filter_linear;

varying vec3 posicion;

void vertex() {
	posicion = VERTEX;
}

float grano(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = fract(sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// La caliza, un poco más cálida: dentro de una cueva la luz es de grasa ardiendo.
	// DOS MUESTRAS a escalas y giros distintos, medio y medio: con una sola la
	// lámina se repetía cada metro y pico y se leía como un papel pintado.
	vec2 girado = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * posicion.xy;
	vec3 caliza = mix(texture(roca, posicion.xy / roca_m).rgb,
		texture(roca, girado / (roca_m * 0.37)).rgb, 0.45);
	caliza = mix(vec3(dot(caliza, vec3(0.33))), caliza, 0.55) * vec3(1.05, 0.98, 0.9);
	vec4 pigmento = texture(pinturas, UV);
	// Poros sin pigmento, a la escala de un par de milímetros y de un par de dedos.
	float poros = grano(posicion.xy * 420.0) * 0.5 + grano(posicion.xy * 60.0) * 0.5;
	float cubre = clamp(pigmento.a * smoothstep(0.08, 0.55, poros + 0.25), 0.0, 1.0);
	ALBEDO = mix(caliza, caliza * pigmento.rgb * 1.7, cubre);
	ROUGHNESS = 0.95;
}
