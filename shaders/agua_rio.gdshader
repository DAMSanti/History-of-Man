shader_type spatial;
// La lamina del rio, en Alto y Ultra (GRAFICOS §7.3). Va encima del cauce, que el
// terreno hunde y oscurece solo al dibujar: aqui se ve el agua con su grosor, el
// lecho a traves de lo somero, la espuma de los rapidos y la orilla, y la que se
// acumula en los remansos. En Ultra, ademas, el fondo se dobla con las ondas.
//
// Lo que decide DONDE rompe viene horneado en la malla, igual que en el terreno:
// COLOR.rg la corriente, COLOR.b agua quieta, COLOR.a la lamina; UV.x la caida del
// cauce y UV.y la orilla (`AguaDelCauce`). Nada de esto toca la partida.
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 2 Alto, 3 Ultra. Por debajo la lamina no se dibuja (el nodo esta apagado).
uniform int nivel_de_agua : hint_range(0, 3) = 2;
// Los umbrales de la caida, los de `AguaDelCauce`, puestos desde el terreno.
uniform float caida_de_rapido = 0.08;
// La estela de espuma detras de las piedras y la espuma viva, comunes con el terreno.
#include "res://shaders/espuma_viva.gdshaderinc"
#include "res://shaders/estela_de_piedras.gdshaderinc"
uniform float veces_para_romper = 5.0;
// La linea del agua: por debajo es ribera mojada, y la lamina se funde ahi.
uniform float linea_del_agua = 0.5;
// Metros por unidad de mundo, para que el grosor del agua se mida en metros.
uniform float metros_por_unidad = 1.0;

// El color del agua segun lo que atraviesa la luz: somera deja ver el lecho tenido
// de verde, honda es azul oscuro. Decisiones mirando las fotos del Nansa y del Pas
// (CREDITOS), no medidas.
// Mas gris y mas clara tras la vuelta del 2026-09-15: desde arriba el Pas es gris de
// grava, y el nuestro se leia como una cinta azul.
uniform vec3 color_somero : source_color = vec3(0.38, 0.42, 0.37);
uniform vec3 color_hondo : source_color = vec3(0.06, 0.15, 0.16);
// Cuanto oscurece cada metro de agua: con 1,0, a 0,7 m deja pasar la mitad.
uniform float absorcion_por_metro : hint_range(0.0, 8.0) = 1.0;
uniform vec3 foam_color : source_color = vec3(0.86, 0.90, 0.92);

// Las gotas de lluvia picando el agua (peticion del usuario del 2026-09-16). La pone el
// clima: 0 despejado, 1 temporal.
#include "res://shaders/gotas_en_el_agua.gdshaderinc"
uniform float lluvia_en_el_agua : hint_range(0.0, 1.0) = 0.0;
// Cada cuantos metros pica una gota. Con medio metro los anillos median dos centimetros y
// se leian como culebrillas; metro y medio da anillos que se ven (captura del 2026-09-16).
uniform float gota_cada_m = 1.5;

uniform float velocidad = 1.4;
uniform float tesela_m = 12.0;
uniform float tesela_de_oleaje_m = 46.0;
uniform float fuerza_de_la_onda : hint_range(0.0, 2.0) = 0.6;
uniform float tesela_de_espuma_m = 8.0;
uniform float deriva_de_la_espuma = 1.35;
// Ultra: cuanto dobla la onda el fondo que se ve a traves.
uniform float refraccion : hint_range(0.0, 0.1) = 0.025;
// Ultra: los reflejos del cielo y la orilla, recorriendo la pantalla. Van AQUI y no en
// el SSR del entorno: aquel solo refleja en materiales opacos -la lamina es
// transparente- y encenderlo reflejaria todo lo liso de la escena (GRAFICOS §7.3).
uniform int pasos_de_reflejo : hint_range(0, 64) = 24;
uniform float largo_de_reflejo_m = 60.0;
uniform float fuerza_de_reflejo : hint_range(0.0, 1.0) = 0.55;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float lamina = clamp(COLOR.a, 0.0, 1.0);
	if (lamina < linea_del_agua - 0.1) {
		discard;
	}
	vec2 flow = COLOR.rg * 2.0 - 1.0;
	float flow_len = length(flow);
	vec2 dir = flow_len > 0.01 ? flow / flow_len : vec2(1.0, 0.0);
	float still = COLOR.b;
	float speed = velocidad * (1.0 - still);

	// Las ondas, como en el terreno: dos fases que bajan con la corriente y se cruzan
	// para que no se vea el salto, y un oleaje grande y lento debajo.
	// PERIODO FIJO Y DESPLAZAMIENTO VARIABLE: la fase no puede ser `fract(TIME * speed)`.
	// `speed` se interpola y cambia de un pixel al siguiente -sobre todo junto al agua
	// quieta-, y con unos segundos de TIME dos pixeles vecinos dan la vuelta al ciclo en
	// sitios distintos: el dibujo se cortaba por lineas que siguen los triangulos de la
	// malla (captura de cerca, 2026-09-15). Todos giran a la vez y la velocidad solo dice
	// cuanto se desplaza el dibujo dentro del ciclo.
	float periodo = 4.0;
	float phase_a = fract(TIME / periodo);
	float phase_b = fract(TIME / periodo + 0.5);
	float cross_fade = abs(1.0 - 2.0 * phase_a);
	vec2 recorrido = flow * speed * periodo / max(tesela_m, 1.0);
	vec2 base_uv = mundo.xz / max(tesela_m, 1.0);
	vec3 n_a = texture(water_normal_tex, base_uv - recorrido * phase_a).rgb * 2.0 - 1.0;
	vec3 n_b = texture(water_normal_tex, base_uv - recorrido * phase_b + 0.37).rgb * 2.0 - 1.0;
	vec3 ripple = mix(n_a, n_b, cross_fade);
	vec2 swell_uv = mundo.xz / max(tesela_de_oleaje_m, 1.0);
	vec2 recorrido_lento = flow * speed * 0.35 * periodo / max(tesela_de_oleaje_m, 1.0);
	vec3 swell = mix(
		texture(water_normal_tex, swell_uv - recorrido_lento * phase_a).rgb,
		texture(water_normal_tex, swell_uv - recorrido_lento * phase_b + 0.53).rgb,
		cross_fade) * 2.0 - 1.0;
	vec2 onda = (ripple.xy + swell.xy * 0.7) * fuerza_de_la_onda;

	// LAS GOTAS DE LLUVIA, encima de la corriente. Algo menos donde corre -en el rapido
	// no se distingue una gota de la espuma-, pero no a la mitad: con 0,45 en el agua que
	// baja, que es casi todo el rio, no se veian (captura del 2026-09-16).
	float pica = lluvia_en_el_agua * mix(0.8, 1.0, still);
	vec3 gotas = gotas_en_el_agua(mundo.xz * metros_por_unidad, TIME, pica, gota_cada_m);
	onda += gotas.xy * 0.9;

	// La espuma de rapido: vetas que bajan con la corriente y crecen con la caida.
	float rapids = smoothstep(caida_de_rapido, caida_de_rapido * veces_para_romper, UV.x)
		* (1.0 - still);
	// El ruido vivo, sólo donde se usa: ver el terreno (`churn` en triplanar).
	float churn = 0.0;
	if (rapids > 0.0) {
		churn = espuma_viva(mundo.xz, flow, speed * deriva_de_la_espuma, tesela_de_espuma_m * 0.35, 1.0, 4);
	}
	float foam = rapids * smoothstep(0.55, 0.85, churn + rapids * 0.2);
	if (con_piedras) {
		// La espuma detras de las piedras (ver el terreno), y el resto casi limpio.
		float estela = 0.0;
		float cerca_de_piedras = smoothstep(caida_de_rapido * 0.25, caida_de_rapido * 0.6, UV.x);
		if (cerca_de_piedras > 0.0 && flow_len > 0.05) {
			estela = estela_viva(mundo.xz, dir, flow, speed * deriva_de_la_espuma, 4, -1.0)
				* smoothstep(0.05, 0.3, flow_len) * cerca_de_piedras;
		}
		// Donde la corriente se anula, `dir` salta a un eje fijo: sin apagarla ahi, la
		// estela y la espuma salian en triangulos sueltos junto a la orilla.
		float suelta = smoothstep(0.70, 0.86, churn) * 0.45;
		foam = max(estela, rapids * suelta);
	}

	// EL GROSOR DEL AGUA: la distancia, a lo largo de la vista, entre la lamina y el
	// lecho que hay detras en el buffer de profundidad. Con eso el agua somera deja
	// ver el fondo y la honda no.
	float bruto = texture(depth_texture, SCREEN_UV).r;
	vec4 detras = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, bruto, 1.0);
	detras.xyz /= detras.w;
	float grosor = max(0.0, (-detras.z) - (-VERTEX.z)) * metros_por_unidad;

	// La de orilla, por dentro de la LINEA DEL AGUA. No por el grosor: el lecho se hunde
	// por vertice (`lecho_hondo`), y el agua somera sale en escalones de celda a lo largo
	// de la margen (vista en falso color de Ultra, 2026-09-15).
	// ENCAJE Y NO MANCHAS: un hilo roto pegado a la linea, y por dentro, las curvas de
	// nivel del ruido vivo -hilos que se forman y se rompen-. Con el ruido umbralizado
	// salian manchas blancas de un metro en la orilla tendida (captura de Ultra).
	float en_la_linea = smoothstep(linea_del_agua - 0.08, linea_del_agua, lamina)
		* (1.0 - smoothstep(linea_del_agua + 0.02, linea_del_agua + 0.1, lamina));
	float cerca_de_la_linea = smoothstep(linea_del_agua - 0.08, linea_del_agua, lamina)
		* (1.0 - smoothstep(linea_del_agua + 0.1, linea_del_agua + 0.3, lamina));
	if (cerca_de_la_linea > 0.0) {
		float lamido = espuma_viva(mundo.xz, flow, 0.15, 1.2, 2.5, 4);
		float hilos = 1.0 - smoothstep(0.0, 0.05, abs(lamido - 0.5));
		foam = max(foam, max(en_la_linea * smoothstep(0.45, 0.7, lamido) * 0.6,
			cerca_de_la_linea * hilos * 0.45));
	}

	// LA QUE SE ACUMULA EN LOS REMANSOS: donde el agua es honda y apenas baja, la
	// espuma que trae la corriente se junta en hilos lentos que giran. Sale donde no
	// hay caida y la lamina es entera, con un ruido grande que se arrastra despacio.
	float remanso = (1.0 - smoothstep(0.0, caida_de_rapido * 0.5, UV.x))
		* smoothstep(0.85, 1.0, lamina);
	// HILOS Y NO MANCHAS: las curvas de nivel de un ruido lento —donde vale la mitad—
	// son lineas finas que serpentean, y otro ruido mas grande deja solo unas pocas.
	// Con manchas umbralizadas la poza entera salia sembrada de tempanos (captura de
	// Alto, 2026-09-15).
	vec2 ruv = mundo.xz / max(tesela_de_espuma_m * 3.0, 1.0);
	float campo = texture(water_foam_tex, ruv - dir * TIME * 0.004).r;
	float linea = 1.0 - smoothstep(0.0, 0.035, abs(campo - 0.5));
	float pocas = smoothstep(0.55, 0.75, texture(water_foam_tex, ruv * 0.31 + vec2(TIME * 0.002, 0.0)).r);
	foam = max(foam, remanso * linea * pocas * 0.55);

	float opaco = 1.0 - exp(-grosor * absorcion_por_metro);
	vec3 agua = mix(color_somero, color_hondo, opaco);

	// La normal de la onda, en el espacio de vista.
	vec3 normal_mundo = normalize(vec3(onda.x, 1.0, onda.y));
	vec3 normal_vista = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(normal_vista, VIEW), 0.0, 1.0), 4.0);

	float alpha = mix(0.15 + opaco * 0.85, 1.0, fresnel * 0.5);
	vec3 color = agua;
	if (nivel_de_agua >= 3) {
		// Ultra: el fondo, doblado por la onda y tenido por el agua que atraviesa.
		vec3 fondo = texture(screen_texture, SCREEN_UV + onda * refraccion * (1.0 - foam)).rgb;
		color = mix(fondo * mix(vec3(1.0), color_somero * 1.8, 0.5), agua, opaco);
		alpha = 1.0;

		// Y LO QUE SE REFLEJA: se avanza por el rayo reflejado en el espacio de vista,
		// se proyecta cada paso a la pantalla y, donde el paso queda detras de lo que hay
		// pintado, eso es lo reflejado. Donde el rayo sale de la pantalla no hay nada que
		// reflejar y se queda el cielo que pone el motor por el brillo especular.
		if (pasos_de_reflejo > 0) {
			vec3 rayo = normalize(reflect(normalize(VERTEX), normal_vista));
			float paso = largo_de_reflejo_m / metros_por_unidad / float(pasos_de_reflejo);
			vec3 donde = VERTEX;
			vec3 reflejado = vec3(0.0);
			float hallado = 0.0;
			for (int k = 0; k < pasos_de_reflejo; k++) {
				donde += rayo * paso;
				vec4 clip = PROJECTION_MATRIX * vec4(donde, 1.0);
				vec2 uv = (clip.xy / clip.w) * 0.5 + 0.5;
				if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || clip.w <= 0.0) {
					break;
				}
				float pintado = texture(depth_texture, uv).r;
				vec4 vista = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, pintado, 1.0);
				vista.xyz /= vista.w;
				if (vista.z > donde.z && vista.z - donde.z < paso * 2.0) {
					reflejado = texture(screen_texture, uv).rgb;
					// Se apaga hacia el borde de la pantalla, para que no corte.
					vec2 borde = min(uv, 1.0 - uv);
					hallado = smoothstep(0.0, 0.08, min(borde.x, borde.y));
					break;
				}
			}
			color = mix(color, reflejado, hallado * fuerza_de_reflejo * mix(0.25, 1.0, fresnel) * (1.0 - foam));
		}
	}
	// LA CRESTA DEL ANILLO, clara. Sin ella el anillo es solo un cambio de normal, y a
	// treinta metros un cambio de normal sobre agua ya ondulada no se lee: se lee la luz
	// en el borde, que es lo que se ve de verdad al llover sobre un rio.
	foam = max(foam, smoothstep(0.25, 0.9, gotas.z) * 0.55);
	color = mix(color, foam_color, foam * 0.8);
	alpha = mix(alpha, 1.0, foam);
	// El borde de la lamina se funde EN LA LINEA DEL AGUA, no en la ribera. En el talud
	// empinado la corta antes el relieve: ver `AguaDelCauce.cota_del_agua`.
	alpha *= smoothstep(linea_del_agua - 0.08, linea_del_agua + 0.05, lamina);

	ALBEDO = color;
	ALPHA = alpha;
	NORMAL = normal_vista;
	ROUGHNESS = mix(0.03, 0.7, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
