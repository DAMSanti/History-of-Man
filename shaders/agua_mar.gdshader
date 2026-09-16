shader_type spatial;
// El mar y la ria del valle (GRAFICOS §7.3). Una lamina plana a la cota del mar de la
// epoca, sobre todo el recuadro; donde el relieve esta por encima, lo tapa el terreno.
//
// Bajo es el mar de siempre -el color, la transparencia y el brillo que tenia el
// `StandardMaterial3D`-. Medio le pone oleaje, color por hondura y espuma donde el agua
// es somera; Alto, rompiente que llega a la orilla en bandas y transparencia de verdad;
// Ultra, el fondo doblado y los reflejos. La hondura se lee del buffer de profundidad:
// el mar no sabe donde esta la costa, la ve.
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform int nivel_de_agua : hint_range(0, 3) = 1;
// Las gotas de lluvia picando el agua (peticion del usuario del 2026-09-16). La pone el
// clima: 0 despejado, 1 temporal.
#include "res://shaders/gotas_en_el_agua.gdshaderinc"
uniform float lluvia_en_el_agua : hint_range(0.0, 1.0) = 0.0;
// Cada cuantos metros pica una gota. Con medio metro los anillos median dos centimetros y
// se leian como culebrillas; metro y medio da anillos que se ven (captura del 2026-09-16).
uniform float gota_cada_m = 1.5;

uniform float metros_por_unidad = 1.0;

// El mar de siempre, el de Bajo: `TerrainGenerator.water_color` y el acabado que tenia.
uniform vec4 color_de_siempre : source_color = vec4(0.09, 0.22, 0.32, 0.88);

// Medio y mas. Decisiones mirando la foto de la ria de Tina Menor (CREDITOS).
uniform vec3 color_somero : source_color = vec3(0.30, 0.50, 0.46);
uniform vec3 color_hondo : source_color = vec3(0.03, 0.12, 0.18);
uniform float absorcion_por_metro : hint_range(0.0, 4.0) = 0.35;
uniform vec3 foam_color : source_color = vec3(0.90, 0.93, 0.94);
// Hasta que hondura, en metros, rompe la espuma de orilla. Eran 1,8: con una costa
// tendida, 1,8 m de hondura son decenas de metros de ancho, y en la costa de prueba la
// ensenada entera salia blanca.
uniform float espuma_hasta_m = 0.5;
uniform float tesela_m = 18.0;
uniform float tesela_de_oleaje_m = 90.0;
uniform float fuerza_de_la_onda : hint_range(0.0, 2.0) = 0.55;
// El oleaje del vertice: alto y largo de la ola, en metros. Suave: una ria cantabrica.
uniform float alto_de_ola_m = 0.25;
uniform float largo_de_ola_m = 70.0;
// Alto: las bandas de rompiente, cuantas por metro de hondura y lo rapido que llegan.
uniform float bandas_por_metro = 0.7;
uniform float llegada = 0.18;
uniform float refraccion : hint_range(0.0, 0.1) = 0.02;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (nivel_de_agua >= 1) {
		// Dos trenes de ola cruzados, largos y bajos: el plano sube y baja sin que se
		// lea un patron.
		float k = 6.2831 / max(largo_de_ola_m / metros_por_unidad, 0.001);
		float a = alto_de_ola_m / metros_por_unidad;
		float fase = TIME * 0.6;
		VERTEX.y += a * sin(dot(mundo.xz, vec2(0.8, 0.6)) * k - fase)
			+ a * 0.6 * sin(dot(mundo.xz, vec2(-0.3, 0.95)) * k * 1.7 - fase * 1.3);
	}
}

void fragment() {
	if (nivel_de_agua <= 0) {
		ALBEDO = color_de_siempre.rgb;
		ALPHA = color_de_siempre.a;
		METALLIC = 0.25;
		ROUGHNESS = 0.06;
	} else {
		// Las ondas pequenas, dos capas que se cruzan en direcciones distintas.
		vec2 uv_a = mundo.xz / max(tesela_m / metros_por_unidad, 0.001) + vec2(TIME * 0.012, TIME * 0.006);
		vec2 uv_b = mundo.xz / max(tesela_de_oleaje_m / metros_por_unidad, 0.001) - vec2(TIME * 0.004, -TIME * 0.007);
		vec3 n_a = texture(water_normal_tex, uv_a).rgb * 2.0 - 1.0;
		vec3 n_b = texture(water_normal_tex, uv_b).rgb * 2.0 - 1.0;
		vec2 onda = (n_a.xy + n_b.xy * 0.8) * fuerza_de_la_onda;
		// Las gotas de lluvia, como en el rio. En metros de mundo, que aqui la unidad no
		// es el metro.
		vec3 gotas = gotas_en_el_agua(mundo.xz * metros_por_unidad, TIME,
			lluvia_en_el_agua, gota_cada_m);
		onda += gotas.xy * 0.9;
		vec3 normal_vista = normalize((VIEW_MATRIX * vec4(normalize(vec3(onda.x, 1.0, onda.y)), 0.0)).xyz);
		float fresnel = pow(1.0 - clamp(dot(normal_vista, VIEW), 0.0, 1.0), 5.0);

		// LA HONDURA, del buffer de profundidad: cuanto agua atraviesa la vista hasta
		// el fondo. Cerca de la costa es poca, y eso es la orilla.
		float bruto = texture(depth_texture, SCREEN_UV).r;
		vec4 detras = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, bruto, 1.0);
		detras.xyz /= detras.w;
		// HONDURA VERTICAL y no a lo largo de la vista: con la camara inclinada, el agua que
		// atraviesa la mirada crece muy deprisa y la costa salia llena de bandas por todo
		// el mar (captura de la costa de prueba, 2026-09-15). Se proyecta sobre la vertical.
		vec3 arriba = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		float a_lo_largo = max(0.0, (-detras.z) - (-VERTEX.z)) * metros_por_unidad;
		float grosor = a_lo_largo * abs(dot(normalize(VERTEX), arriba));
		float opaco = 1.0 - exp(-grosor * absorcion_por_metro);
		vec3 agua = mix(color_somero, color_hondo, opaco);

		// La espuma de orilla: donde el agua es poco honda, rota por la textura.
		vec2 fuv = mundo.xz / max(9.0 / metros_por_unidad, 0.001);
		float roto = texture(water_foam_tex, fuv + vec2(TIME * 0.01, 0.0)).r;
		float somera = 1.0 - smoothstep(0.0, espuma_hasta_m, grosor);
		float foam = somera * smoothstep(0.35, 0.75, roto + somera * 0.3);

		if (nivel_de_agua >= 2) {
			// LA ROMPIENTE: bandas que avanzan hacia la orilla y rompen al llegar a lo
			// somero. La hondura hace de distancia a la costa.
			// Una o dos crestas sueltas, sólo donde el agua ya es poco honda, y rotas: una
			// banda continua cada metro se leía como curvas de nivel.
			float banda = fract(grosor * bandas_por_metro + TIME * llegada);
			float cresta = smoothstep(0.86, 0.93, banda) * (1.0 - smoothstep(0.93, 0.99, banda));
			float donde_rompe = 1.0 - smoothstep(espuma_hasta_m * 0.6, espuma_hasta_m * 1.4, grosor);
			foam = max(foam, cresta * donde_rompe * smoothstep(0.45, 0.72, roto));
		}

		float alpha = nivel_de_agua >= 2 ? mix(0.25 + opaco * 0.75, 1.0, fresnel * 0.6) : 0.9;
		vec3 color = agua;
		if (nivel_de_agua >= 3) {
			vec3 fondo = texture(screen_texture, SCREEN_UV + onda * refraccion * (1.0 - foam)).rgb;
			color = mix(fondo * mix(vec3(1.0), color_somero * 1.6, 0.5), agua, opaco);
			alpha = 1.0;
		}
		// La cresta del anillo, clara: ver el rio.
		foam = max(foam, smoothstep(0.25, 0.9, gotas.z) * 0.55);
		color = mix(color, foam_color, foam * 0.85);
		ALBEDO = color;
		ALPHA = mix(alpha, 1.0, foam);
		NORMAL = normal_vista;
		ROUGHNESS = mix(0.04, 0.7, foam);
		SPECULAR = 0.5;
		METALLIC = 0.0;
	}
}
